import 'package:flutter_test/flutter_test.dart';
import 'package:safehub_app/core/csi_fall_state.dart';
import 'package:safehub_app/services/situation_service.dart';

void main() {
  final now=DateTime.fromMillisecondsSinceEpoch(1000000);
  Map<String,dynamic> state({String status='monitoring', bool fresh=true}) => {
    'mode':'live','dummy_allowed':false,'connected':true,'fresh':fresh,
    'model':{'labels':['낙상','일상']},
    'recognition':{'running':true,'result':{'label':'낙상','scores':{'낙상':.9,'일상':.1}}},
    'fall_detection':{'status':status,'event':status=='detected'?{
      'message_id':'fall-1','device':'csi_bedroom','event':'fall_detected',
      'confidence':.9,'priority':9,'timestamp':1000}:null},
  };
  test('normal predictions stay quiet and do not claim occupancy', () {
    final view=CsiFallState.fromState(state(),now:now);
    expect(view.headline,'낙상 의심 신호 없음');expect(view.event,isNull);
  });
  test('confirmed fresh real fall reaches the existing event contract', () {
    final view=CsiFallState.fromState(state(status:'detected'),now:now);
    expect(view.event!['event'],'fall_detected');expect(view.headline,'낙상 의심 감지');
  });
  test('dummy, stale, stopped and old events never trigger', () {
    for(final data in [state(status:'detected',fresh:false),
      {...state(status:'detected'),'mode':'dummy'},
      {...state(status:'detected'),'dummy_allowed':true},
      {...state(status:'detected'),'recognition':{'running':false}}]) {
      expect(CsiFallState.fromState(data,now:now).event,isNull);
    }
    expect(CsiFallState.fromState(state(status:'detected'),now:now.add(const Duration(seconds:31))).event,isNull);
  });
  test('current nonfall models require new training', () {
    final data=state();data['model']={'labels':['걷기','앉기','정지']};
    final view=CsiFallState.fromState(data,now:now);
    expect(view.modelReady,isFalse);expect(view.headline,'낙상 모델 학습 필요');
  });
  test('only a confirmed fall opens the same assistance and audio flow', () {
    final service=SituationService(settings:SituationSettings(enabled:false));
    addTearDown(service.dispose);
    final seen=<String>{};
    var alerts=0;service.onScenarioAlert=()=>alerts++;
    for(final status in ['monitoring','confirming','detected','detected']) {
      final view=CsiFallState.fromState(state(status:status),now:now);
      if(view.event!=null&&seen.add(view.event!['message_id'])) {
        service.observeFall(view.event!['message_id'],'낙상 의심 신호');
      }
    }
    expect(alerts,1);expect(service.flow.active,isNotNull);
  });
}
