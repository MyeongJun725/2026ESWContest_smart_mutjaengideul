"""Read-only Dart import/asset audit. Does not build, connect or inspect devices.

Reachability is based on explicit import/export/part directives from lib/main.dart.
It does not prove runtime coverage or validate externally supplied models/SDKs.
"""
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "SW/safehub_scenario"
DIRECTIVE = re.compile(r"^\s*(?:import|export|part)\s+(['\"]).*?;", re.M | re.S)


def audit(source):
    source = Path(source).resolve()
    lib = source / "lib"
    files = {path.resolve() for path in lib.rglob("*.dart")}
    graph, missing = {}, []
    for path in sorted(files):
        if not path.is_relative_to(lib):
            raise ValueError("Dart source leaves lib directory")
        children = []
        for directive in DIRECTIVE.finditer(path.read_text(encoding="utf-8")):
            for uri in re.findall(r"['\"]([^'\"]+)['\"]", directive[0]):
                if uri.startswith("package:safehub_app/"):
                    target = lib / uri.split("/", 1)[1]
                elif ":" in uri:
                    continue
                else:
                    target = path.parent / uri
                target = target.resolve()
                children.append(target)
                if target not in files:
                    missing.append({"file": str(path.relative_to(source)), "uri": uri})
        graph[path] = children
    reached, pending = set(), [(lib / "main.dart").resolve()]
    while pending:
        path = pending.pop()
        if path in reached:
            continue
        reached.add(path)
        pending.extend(graph.get(path, []))
    if not (lib / "main.dart").is_file():
        missing.append({"file": "lib/main.dart", "uri": "entrypoint"})
    pubspec = (source / "pubspec.yaml").read_text(encoding="utf-8")
    assets = re.findall(r"^\s*-\s+(?:asset:\s*)?(assets/\S+)\s*$", pubspec, re.M)
    missing_assets = [
        name for name in assets
        if not ((source / name).is_dir() if name.endswith("/")
                else (source / name).is_file())
    ]
    return {
        "dart_files": len(files),
        "reachable_from_main": len(files & reached),
        "unreachable": [str(path.relative_to(source)) for path in sorted(files - reached)],
        "missing_local_imports": missing,
        "declared_assets": assets,
        "missing_assets": missing_assets,
    }


def main():
    report = audit(SOURCE)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return int(bool(report["missing_local_imports"] or report["missing_assets"] or report["unreachable"]))


if __name__ == "__main__":
    raise SystemExit(main())
