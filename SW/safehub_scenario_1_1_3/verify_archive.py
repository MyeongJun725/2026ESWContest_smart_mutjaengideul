"""Verify the preserved deployment files without connecting to a device."""
from hashlib import sha256
from pathlib import Path

root = Path(__file__).parent
expected = {
    'llm/fast_server_atlas.py': 'c80dd02d8bfecdc0dc1e62ea208587102705cef8a1d16c9bfcd5d7c05cb1b136',
    'dist/com.atlas.app.safehub_scenario_1.1.3_all.ipk': '3f4fd44b9242ffc8795ba672bad146dd453503d5461cd403733fb9e8a7087c9a',
}
for name, digest in expected.items():
    assert sha256((root / name).read_bytes()).hexdigest() == digest, name
print('Both preserved deployment files match their recorded SHA-256.')
