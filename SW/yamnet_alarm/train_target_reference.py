import argparse,json,wave,time,os
from pathlib import Path
import numpy as np
from ai_edge_litert.interpreter import Interpreter
os.nice(15)
parser=argparse.ArgumentParser(description="Fit a target siren reference; manifest identifies negative train/test files.")
parser.add_argument('--data',required=True)
parser.add_argument('--model',required=True)
args=parser.parse_args()
r=Path(args.data)
m=Interpreter(model_path=args.model,num_threads=1)
m.resize_tensor_input(m.get_input_details()[0]['index'],[15600]);m.allocate_tensors()
i=m.get_input_details()[0]['index'];o=m.get_output_details()[1]['index']
def features(file,start=0,end=None):
 with wave.open(str(r/file)) as w:
  assert (w.getframerate(),w.getnchannels(),w.getsampwidth())==(16000,1,2)
  a=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').astype(np.float32)/32768
 a=a[int(start*16000):None if end is None else int(end*16000)]
 xs=[]
 for k in range(0,len(a)-15600+1,7680):
  m.set_tensor(i,a[k:k+15600]);m.invoke();v=m.get_tensor(o)[0];xs.append(v/(np.linalg.norm(v)+1e-9))
 return np.array(xs)
manifest=json.loads((r/'manifest.json').read_text());pos=features('target.wav',0,8);pv=features('target.wav',8,12)
negative=[(x,features(x['file'])) for x in manifest if x['label']==0]
c=pos.mean(axis=0);c/=np.linalg.norm(c)
train=np.concatenate([v for x,v in negative if x['split']=='train'])
protos=np.stack([v.mean(axis=0) for x,v in negative if x['split']=='train']);protos/=np.linalg.norm(protos,axis=1,keepdims=True)
def scores(x):return x@c, x@c-np.max(x@protos.T,axis=1)
ps,pm=scores(pos);ns,nm=scores(train)
threshold=max(.8,float(ns.max()+.03));margin=max(.05,float(nm.max()+.03))
np.savez(r/'target_siren.npz',centroid=c,negative_prototypes=protos,threshold=threshold,margin=margin)
report={'method':'YAMNet 1024-D normalized embedding target centroid vs negative prototypes','train_positive_windows':len(pos),'same_source_validation_note':'8-12s is a held-out time span of the SAME audio, not independent microphone validation','threshold':threshold,'margin':margin,'positive_validation':{},'negative_sources':[]}
vs,vm=scores(pv);report['positive_validation']={'windows':len(pv),'matches':int(((vs>=threshold)&(vm>=margin)).sum()),'min_similarity':float(vs.min()),'min_margin':float(vm.min())}
for x,v in negative:
 s,d=scores(v);report['negative_sources'].append({'file':x['file'],'split':x['split'],'windows':len(v),'matches':int(((s>=threshold)&(d>=margin)).sum()),'max_similarity':float(s.max()),'max_margin':float(d.max())})
(r/'training-report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
