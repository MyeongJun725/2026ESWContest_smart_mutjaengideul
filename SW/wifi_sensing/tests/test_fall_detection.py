from pathlib import Path
import sys
import unittest
import threading
from unittest.mock import Mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'runtime'))
from fall_detection import FallDetector, fall_training_records
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from bridge import Controller
from recognition import Recognition

MODEL={'labels':['일상','낙상'],'score_threshold':.65,'score_margin':.15}
def prediction(label, score=.9):
    return {'label':label,'scores':{'낙상':score if label=='낙상' else 1-score,'일상':1-score if label=='낙상' else score}}

class FallTests(unittest.TestCase):
    def setUp(self):
        self.detector=FallDetector();self.detector.reset(MODEL)

    def feed(self,label,t,**kwargs):
        self.detector.observe(prediction(label),input_end=t,now=t,**kwargs)

    def test_two_fresh_fall_predictions_confirm_once(self):
        self.feed('낙상',1)
        self.assertIsNone(self.detector.event)
        self.feed('낙상',1.6)
        event=self.detector.event.copy()
        self.assertEqual(event['event'],'fall_detected')
        self.feed('낙상',2.2)
        self.assertEqual(self.detector.event,event)

    def test_same_prediction_poll_is_not_confirmation(self):
        self.feed('낙상',1)
        self.detector.observe(prediction('낙상'),input_end=1,now=1.6)
        self.assertIsNone(self.detector.event)

    def test_spike_then_normal_never_alarms(self):
        for t,label in [(1,'일상'),(1.6,'낙상'),(2.2,'일상'),(2.8,'낙상')]:self.feed(label,t)
        self.assertIsNone(self.detector.event)

    def test_dummy_stale_and_low_confidence_are_rejected(self):
        self.feed('낙상',1,real=False)
        self.detector.observe(prediction('낙상'),input_end=1,now=2)
        self.detector.observe(prediction('낙상',.6),input_end=3,now=3)
        self.assertIsNone(self.detector.event)

    def test_nonfall_model_never_claims_monitoring(self):
        self.detector.reset({'labels':['정지','걷기','앉기']})
        self.feed('낙상',1);self.feed('낙상',1.6)
        self.assertFalse(self.detector.eligible)
        self.assertEqual(self.detector.status,'model_required')

    def test_transport_gap_breaks_confirmation(self):
        self.feed('낙상',1)
        self.detector.unavailable()
        self.feed('낙상',2)
        self.assertIsNone(self.detector.event)
        self.feed('낙상',5)
        self.assertIsNone(self.detector.event)

    def test_no_rearm_until_normal_and_cooldown(self):
        self.feed('낙상',1);self.feed('낙상',1.6)
        event=self.detector.event.copy()
        for t in (2.2,2.8,3.4):self.feed('일상',t)
        self.assertEqual(self.detector.event,event)
        for t in (9,9.6,10.2,10.8,11.4,12):self.feed('일상',t)
        self.assertIsNone(self.detector.event)
        self.feed('낙상',12.6);self.feed('낙상',13.2)
        self.assertNotEqual(self.detector.event['message_id'],event['message_id'])

    def test_unknown_or_invalid_scores_do_not_generate_alerts(self):
        for t,p in enumerate([{'label':'낙상','scores':{}},
            {'label':'낙상','scores':{'낙상':float('nan')}},
            {'label':'판단 보류','scores':{'낙상':.9,'일상':.1}}],1):
            self.detector.observe(p,input_end=t,now=t)
        self.assertIsNone(self.detector.event)

    def test_binary_training_copies_labels_without_mutating_records(self):
        records=[{'id':'a','label':'낙상'},{'id':'b','label':'걷기'},{'id':'c','label':'앉기'}]
        self.assertEqual([r['label'] for r in fall_training_records(records)],['낙상','일상','일상'])
        self.assertEqual(records[1]['label'],'걷기')
        with self.assertRaises(ValueError):fall_training_records(records[1:])
        with self.assertRaises(ValueError):fall_training_records(records+[{'label':'gd'}])

    def test_controller_only_forwards_accepted_fresh_real_inference(self):
        controller=Controller.__new__(Controller)
        controller.lock=threading.RLock();controller.allow_dummy=False
        controller.fall_detector=FallDetector();controller.fall_detector.reset(MODEL)
        controller.recognition=Recognition();controller.recognition.begin('s',0,'model',0)
        controller.stream=Mock();controller.stream.snapshot.return_value={'mode':'live','fresh':True}
        controller.teaching=Mock();controller.teaching.predict_frames.return_value=prediction('낙상')
        generation=controller.recognition.generation
        for t in (1.,1.6):
            controller.stream.now.return_value=t
            controller._predict(generation,{'model_id':'model'},None,[],t)
        self.assertEqual(controller.fall_detector.event['event'],'fall_detected')
        controller.fall_detector.reset(MODEL)
        controller.stream.now.return_value=5
        controller._predict(generation,{'model_id':'model'},None,[],2)
        self.assertIsNone(controller.fall_detector.event)

if __name__=='__main__':unittest.main(verbosity=2)
