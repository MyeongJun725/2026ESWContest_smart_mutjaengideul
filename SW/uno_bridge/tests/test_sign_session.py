"""Exercise actual entrypoint callbacks with a fake MQTT client only."""
import json
from pathlib import Path
from types import SimpleNamespace
import sys
import tempfile
import unittest
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import sign_hub


class SignSessionTests(unittest.TestCase):
    def test_clean_session_can_reuse_ids_without_replaying_same_session_dups(self):
        with tempfile.TemporaryDirectory() as folder:
            store = Path(folder) / 'shortcuts.json'
            store.write_text('[]')  # Existing user store, never a production path.
            client = MagicMock()
            app = SimpleNamespace(client=client, config=SimpleNamespace(
                shortcut_store_path=store, broker_host='localhost', broker_port=1883))
            accepted = MagicMock()
            stopped = MagicMock()
            stopped.wait.return_value = True

            def connected_then_deliver():
                success = SimpleNamespace(is_failure=False)
                failed = SimpleNamespace(is_failure=True)
                def deliver(duplicate):
                    client.on_message(client, None, SimpleNamespace(
                        topic=sign_hub.SIGN_TRANSLATION_TOPIC, mid=71,
                        payload=json.dumps({'text':'도움'}).encode(), dup=duplicate, retain=False))
                client.on_connect(client,None,None,success,None)
                deliver(False)
                deliver(True)
                self.assertEqual(accepted.call_count,1)
                # A rejected connection does not establish a fresh session.
                client.on_connect(client,None,None,failed,None)
                deliver(True)
                self.assertEqual(accepted.call_count,1)
                client.on_connect(client,None,None,success,None)
                deliver(True)
                deliver(True)
                self.assertEqual(accepted.call_count,2)

            client.loop_start.side_effect = connected_then_deliver
            with patch.object(sign_hub,'build_application',return_value=app), \
                 patch.object(sign_hub,'on_message',accepted), \
                 patch.object(sign_hub.signal,'signal'), \
                 patch.object(sign_hub.threading,'Event',return_value=stopped):
                sign_hub.main()
            self.assertEqual(store.read_text(),'[]')
            client.disconnect.assert_called_once()
            client.loop_stop.assert_called_once()


if __name__ == '__main__':
    unittest.main()
