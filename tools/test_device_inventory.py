import hashlib
from pathlib import Path
import subprocess
import tempfile
import unittest
from compare_device_inventory import compare


class InventoryTests(unittest.TestCase):
    def test_matches_sources_but_never_declares_binary_provenance(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            subprocess.run(['git', 'init', '-q', folder], check=True)
            (root / 'service.py').write_bytes(b'print("source")\n')
            subprocess.run(['git', 'add', 'service.py'], cwd=root, check=True)
            subprocess.run(['git', '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                            'commit', '-qm', 'fixture'], cwd=root, check=True)
            digest = hashlib.sha256((root / 'service.py').read_bytes()).hexdigest()
            # A Windows working copy may have CRLF; compare the committed LF blob.
            (root / 'service.py').write_bytes(b'print("source")\r\n')
            result = compare('\n'.join(['SAFEHUB_INVENTORY_V1\tpi4',
                f'process-source\t{digest}\t/data/app/service.py',
                f'installed-source\t{"0"*64}\t/data/app/local.py',
                f'process-exe\t{"1"*64}\t/proc/123/exe', 'inventory-complete\tpi4']), root)
            self.assertEqual(result['sources'][0]['matching_repository_paths'], ['service.py'])
            self.assertEqual(result['sources'][1]['matching_repository_paths'], [])
            self.assertEqual(result['running_binaries'][0]['source_commit'], 'unverified')
            self.assertEqual(result['device_equals_repository'], 'unverified')

    def test_incomplete_output_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Incomplete'):
            compare('SAFEHUB_INVENTORY_V1\tpi5\narchitecture\taarch64')


if __name__ == '__main__':
    unittest.main()
