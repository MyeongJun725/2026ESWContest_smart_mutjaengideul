"""Scenario host packaging; no imports from the legacy UI or CSI service.

Adapted from SW/wifi_sensing/prepare_ui_tests.py at 654e2f3. Keep the
canonical Dart sources/assets unchanged and reject checkout-local outputs.
"""
from pathlib import Path
import re
import shutil


ATLAS_DEPENDENCIES = {'audioplayers_atlas', 'record_atlas'}


def host_pubspec(text: str) -> str:
    """Remove only the two ATLAS path dependencies from the original YAML."""
    lines = text.splitlines(keepends=True)
    output = []
    removed = set()
    section = None
    index = 0
    while index < len(lines):
        line = lines[index]
        top_level = re.match(r'^([A-Za-z_][A-Za-z0-9_]*):', line)
        if top_level:
            section = top_level.group(1)
        dependency = re.match(r'^  ([A-Za-z_][A-Za-z0-9_]*):\s*$', line)
        if (section == 'dependencies' and dependency
                and dependency.group(1) in ATLAS_DEPENDENCIES):
            name = dependency.group(1)
            if name in removed:
                raise ValueError(f'Duplicate dependency: {name}')
            if (index + 1 >= len(lines)
                    or not re.match(r'^    path:\s*\S.*$', lines[index + 1])):
                raise ValueError(f'Expected one path entry for {name}')
            following = index + 2
            if (following < len(lines) and lines[following].strip()
                    and lines[following].startswith('    ')):
                raise ValueError(f'Unexpected extra dependency options: {name}')
            removed.add(name)
            index += 2
            continue
        output.append(line)
        index += 1
    if removed != ATLAS_DEPENDENCIES:
        raise ValueError('The two expected ATLAS path dependencies were not found')
    return ''.join(output)


def validate_target(target: Path, source: Path) -> None:
    repository = source.parents[1]
    if target == Path(target.anchor):
        raise ValueError('A filesystem root cannot be used as the output folder')
    if (target == repository or repository in target.parents
            or target in repository.parents):
        raise ValueError('Use an output folder outside the source repository')
    if target.exists():
        if not target.is_dir() or any(target.iterdir()):
            raise ValueError('The output folder must be new or completely empty')


def prepare(source: Path, target: Path) -> int:
    source = source.resolve()
    target = target.expanduser().resolve()
    validate_target(target, source)
    files = sorted(
        path.relative_to(source)
        for directory in ('lib', 'test', 'assets')
        for path in (source / directory).rglob('*')
        if path.is_file()
    )
    files.append(Path('analysis_options.yaml'))
    pubspec = host_pubspec((source / 'pubspec.yaml').read_text(encoding='utf-8'))
    for relative in files:
        path = source / relative
        if not path.is_file() or not path.resolve().is_relative_to(source):
            raise ValueError(f'Invalid source file: {relative}')

    lock_bytes = (source / 'tool/host_pubspec.lock').read_bytes()
    target.mkdir(parents=True, exist_ok=True)
    for relative in files:
        destination = target / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        if not destination.parent.resolve().is_relative_to(target):
            raise ValueError(f'Output path leaves the target folder: {relative}')
        # Exclusive creation also refuses files added after the empty-folder check.
        with (source / relative).open('rb') as original:
            with destination.open('xb') as copied:
                shutil.copyfileobj(original, copied)
        shutil.copystat(source / relative, destination)
    with (target / 'pubspec.yaml').open('x', encoding='utf-8', newline='\n') as output:
        output.write(pubspec)
    # A reviewed host lock makes fresh CI/PC resolution match the tested SDK.
    # The canonical ATLAS lock remains separate and unchanged.
    with (target / 'pubspec.lock').open('xb') as output:
        output.write(lock_bytes)
    return len(files) + 1
