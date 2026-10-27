"""Run only reviewed fake-MQTT assertion scripts; disable Python socket I/O."""
from pathlib import Path
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
HUB = ROOT / 'SW/rpi5_hub'
# These files contain assertions at module level, not unittest.TestCase suites.
# Never discover arbitrary test_*.py files: an old file was a real publisher.
SCRIPTS = (
    'tests/test_event_manager.py',
    'tests/test_main_runtime.py',
    'tests/test_mqtt_receiver.py',
    'sign_shortcut/tests/test_action_executor.py',
    'sign_shortcut/tests/test_device_control_message.py',
    'sign_shortcut/tests/test_device_control_publisher.py',
    'sign_shortcut/tests/test_main_integration.py',
    'sign_shortcut/tests/test_shortcut_action_integration.py',
    'sign_shortcut/tests/test_shortcut_manager.py',
    'sign_shortcut/tests/test_shortcut_registration_handler.py',
    'sign_shortcut/tests/test_shortcut_store.py',
    'sign_shortcut/tests/test_sign_shortcut_controller.py',
    'sign_shortcut/tests/test_sign_shortcut_cooldown.py',
    'sign_shortcut/tests/test_sign_to_device_mqtt_integration.py',
)
BOOTSTRAP = '''
import runpy
import socket
import sys
def offline_only(*args, **kwargs):
    raise RuntimeError('Python network connections are disabled for hub source checks')
socket.create_connection = offline_only
socket.getaddrinfo = offline_only
socket.socket.connect = offline_only
socket.socket.connect_ex = offline_only
runpy.run_path(sys.argv[1], run_name='__main__')
'''


def run_script(path, **kwargs):
    return subprocess.run([sys.executable, '-c', BOOTSTRAP, str(path)],
                          cwd=ROOT, env={**os.environ, 'PYTHONPATH': str(HUB)},
                          check=True, **kwargs)


def main():
    for relative in SCRIPTS:
        print(f'Checking {relative}', flush=True)
        run_script(HUB / relative)
    print(f'{len(SCRIPTS)} hub assertion scripts passed; no live broker used')


if __name__ == '__main__':
    main()
