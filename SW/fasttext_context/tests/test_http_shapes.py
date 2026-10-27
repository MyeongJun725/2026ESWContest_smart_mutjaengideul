import unittest, tempfile, socket, subprocess, sys, os, time, http.client, json
from pathlib import Path
class HttpTests(unittest.TestCase):
    def test_invalid_shapes_leave_server_healthy(self):
        with tempfile.TemporaryDirectory() as folder:
            Path(folder,'fasttext.py').write_text('class Model:\n def get_labels(self): return ["FIRE"]\n def predict(self,text,k=1): return ["__label__FIRE"],[0.99]\ndef load_model(path): return Model()\n')
            with socket.socket() as probe:
                probe.bind(('127.0.0.1',0)); port=probe.getsockname()[1]
            process=subprocess.Popen([sys.executable,str(Path(__file__).resolve().parents[1]/'server.py'),'--model','fake','--port',str(port)],env={**os.environ,'PYTHONPATH':folder},stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            def request(path, body=None):
                c=http.client.HTTPConnection('127.0.0.1',port,timeout=3)
                try:
                    c.request('GET' if body is None else 'POST',path,body=body)
                    r=c.getresponse();data=r.read();return r.status,json.loads(data)
                finally:c.close()
            try:
                for _ in range(100):
                    try:
                        if request('/health')[0]==200:break
                    except OSError:time.sleep(.03)
                else:self.fail('server not ready')
                for payload in ('[]','null','{"messages":[]}','{"messages":[5]}','{"messages":[{"content":"[]"}]}','{bad'):
                    with self.subTest(payload=payload):self.assertEqual(request('/v1/chat/completions',payload)[0],400)
                self.assertTrue(request('/classify',json.dumps({'text':'훈련이 아닙니다. 실제 화재가 발생했습니다.'}))[1]['hazard'])
                self.assertEqual(request('/health')[0],200)
            finally:process.terminate();process.wait(timeout=5)
