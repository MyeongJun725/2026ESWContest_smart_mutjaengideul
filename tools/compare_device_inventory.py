"""Compare read-only device hashes with tracked sources; never infer ELF provenance."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def compare(inventory, root=ROOT):
    lines = inventory.lstrip('\ufeff').splitlines()
    if not lines or lines[0] not in ('SAFEHUB_INVENTORY_V1\tpi4', 'SAFEHUB_INVENTORY_V1\tpi5'):
        raise ValueError('Not a SafeHub device inventory')
    role = lines[0].split('\t')[1]
    if lines[-1] != f'inventory-complete\t{role}':
        raise ValueError('Incomplete inventory; do not treat missing output as absent files')
    paths = subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', '-z', 'HEAD'], cwd=root).decode().split('\0')
    index = {}
    for name in filter(None, paths):
        path = Path(name)
        if path.suffix in ('.py', '.sh', '.cpp', '.hpp', '.dart', '.service'):
            # Git blobs avoid false mismatches from Windows autocrlf or local edits.
            content = subprocess.check_output(['git', 'show', f'HEAD:{name}'], cwd=root)
            index.setdefault(hashlib.sha256(content).hexdigest(), []).append(name)
    sources, binaries, models = [], [], []
    for line in lines[1:]:
        fields = line.split('\t')
        if len(fields) != 3:
            continue
        kind, digest, path = fields
        if kind in ('process-source', 'installed-source'):
            sources.append(dict(kind=kind, path=path, sha256=digest,
                                matching_repository_paths=index.get(digest, [])))
        elif kind == 'process-exe':
            binaries.append(dict(path=path, sha256=digest, source_commit='unverified'))
        elif kind == 'external-model':
            models.append(dict(path=path, sha256=digest))
    return dict(role=role, repository_head=subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
        sources=sources, running_binaries=binaries, external_models=models,
        device_equals_repository='unverified',
        limits=['Matching a file does not prove that it is loaded by the running process.',
                'Unmatched files require review; they are not automatically unused.',
                'ELF/kernel/IPK needs its build manifest and source archive comparison.',
                'Only listed roots and readable files were inspected; firmware is not read.'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('inventory', type=Path)
    args = parser.parse_args()
    try:
        result = compare(args.inventory.read_text(encoding='utf-8'))
    except (OSError, ValueError) as error:
        parser.error(str(error))
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
