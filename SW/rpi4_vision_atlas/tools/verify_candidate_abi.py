"""Static ELF/dependency/symbol checks against a SHA256-verified target collection.

Does not execute ELF files or connect to a device. Requires GNU readelf.
"""
import argparse
import hashlib
import json
import pathlib
import re
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate', type=pathlib.Path, required=True)
    parser.add_argument('--target-root', type=pathlib.Path, required=True)
    parser.add_argument('--device-hashes', type=pathlib.Path, required=True)
    parser.add_argument('--output', type=pathlib.Path, required=True)
    args = parser.parse_args()

    def elf(path, *flags):
        return subprocess.check_output(['readelf', *flags, str(path)], text=True)

    verified = set()
    hashes = []
    for line in args.device_hashes.read_text(encoding='utf-8-sig').splitlines():
        expected, name = line.split(None, 1)
        path = (args.target_root / name.strip().lstrip('/')).resolve()
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        hashes.append({'path': name, 'sha256': actual, 'matches_device': actual == expected})
        if actual != expected:
            raise RuntimeError(f'Target hash mismatch: {name}')
        verified.add(path)

    libraries = {}
    for folder in ['usr/lib', 'data/safehub/lib']:
        for path in (args.target_root / folder).iterdir():
            if path.is_file() and path.resolve() in verified:
                libraries[path.name] = path

    def needed(path):
        return re.findall(r'\(NEEDED\).*\[(.*?)\]', elf(path, '-d'))

    closure = {}
    pending = needed(args.candidate) + ['ld-linux-aarch64.so.1']
    while pending:
        name = pending.pop()
        if name in closure:
            continue
        if name not in libraries:
            raise RuntimeError(f'Missing verified target dependency: {name}')
        closure[name] = libraries[name]
        pending.extend(needed(libraries[name]))

    def symbols(path):
        for line in elf(path, '--dyn-syms', '--wide').splitlines():
            fields = line.split()
            if len(fields) >= 8 and fields[0][0].isdigit():
                yield fields[6], fields[4], fields[7].replace('@@', '@')

    files = [args.candidate, *closure.values()]
    exports = set()
    for path in files:
        for section, binding, name in symbols(path):
            # GNU UNIQUE exports (e.g. C++ locale ids) participate in dynamic
            # resolution too; excluding them reports false missing imports.
            if section != 'UND' and binding in ('GLOBAL', 'WEAK', 'UNIQUE'):
                exports.update([name, name.split('@')[0]])

    checks = []
    for path in files:
        header = elf(path, '-h')
        required = [name for section, binding, name in symbols(path)
                    if section == 'UND' and binding == 'GLOBAL']
        checks.append({'file': path.name, 'required_global_symbols': len(required),
                       'missing': sorted(set(required) - exports),
                       'aarch64_elf64_le': all(s in header for s in ['ELF64', 'little endian', 'AArch64'])})
    interpreter = re.search(r'Requesting program interpreter: (.*?)\]', elf(args.candidate, '-l')).group(1)
    report = {'candidate_sha256': hashlib.sha256(args.candidate.read_bytes()).hexdigest(),
              'interpreter': interpreter, 'needed': needed(args.candidate),
              'dependency_closure': sorted(closure), 'target_hash_checks': hashes,
              'symbol_checks': checks, 'target_execution_performed': False, 'deployed': False}
    report['passed'] = interpreter == '/lib/ld-linux-aarch64.so.1' and all(
        c['aarch64_elf64_le'] and not c['missing'] for c in checks)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
    if not report['passed']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
