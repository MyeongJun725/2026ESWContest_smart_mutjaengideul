"""Run the actual scenario UI in a temporary, hardware-free browser host."""

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import shutil
import subprocess
import tempfile
import webbrowser


from host_support import host_pubspec, validate_target


SOURCE = Path(__file__).resolve().parents[1]


def replace_once(text, before, after):
    if text.count(before) != 1:
        raise ValueError(f"Preview adapter no longer matches: {before[:60]}")
    return text.replace(before, after, 1)


def prepare_host(output):
    """Copy app sources/assets, adapting only the disposable browser host."""
    output = output.expanduser().resolve()
    validate_target(output, SOURCE)
    output.mkdir(parents=True, exist_ok=True)
    for name in ("lib", "assets"):
        shutil.copytree(SOURCE / name, output / name)
    pubspec = host_pubspec((SOURCE / "pubspec.yaml").read_text(encoding="utf-8"))
    (output / "pubspec.yaml").write_text(pubspec, encoding="utf-8")
    shutil.copyfile(SOURCE / "pubspec.lock", output / "pubspec.lock")

    config = output / "lib/config/app_config.dart"
    text = "import 'package:flutter/foundation.dart';\n" + config.read_text(
        encoding="utf-8"
    )
    text = replace_once(
        text,
        "if (Platform.environment.containsKey('DISASTER_API_KEY'))",
        "if (!kIsWeb && Platform.environment.containsKey('DISASTER_API_KEY'))",
    )
    text = replace_once(
        text, "    _filePath = filePath;",
        "    if (kIsWeb) return;\n    _filePath = filePath;",
    )
    config.write_text(text, encoding="utf-8")

    service = output / "lib/services/situation_service.dart"
    text = replace_once(
        service.read_text(encoding="utf-8"),
        "    if (!await file.exists()) return SituationSettings();",
        "    if (kIsWeb) return SituationSettings(enabled: false);\n"
        "    if (!await file.exists()) return SituationSettings();",
    )
    service.write_text(text, encoding="utf-8")
    web = output / "web"
    web.mkdir()
    (web / "index.html").write_text(
        '<!DOCTYPE html><html lang="ko"><head>'
        '<base href="$FLUTTER_BASE_HREF"><meta charset="UTF-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '<title>SafeHub Scenario UI</title></head><body>'
        '<script src="flutter_bootstrap.js" async></script></body></html>',
        encoding="utf-8",
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--flutter-path", help="Flutter executable; defaults to PATH")
    parser.add_argument("--port", type=int, default=8766)
    parser.add_argument("--no-browser", action="store_true")
    parser.add_argument("--check-only", action="store_true",
                        help="Prepare and verify the host without running Flutter")
    args = parser.parse_args()
    if not 1 <= args.port <= 65535:
        parser.error("--port must be between 1 and 65535")
    flutter = args.flutter_path or shutil.which("flutter")
    if not args.check_only and not flutter:
        parser.error("Install Flutter SDK or specify --flutter-path")

    # Generated files never enter the checkout. Closing the server removes only
    # this script's own temporary directory, not any user's build or settings.
    with tempfile.TemporaryDirectory(prefix="safehub-ui-") as temporary:
        host = Path(temporary) / "app"
        prepare_host(host)
        if args.check_only:
            print("Preview host preparation passed; source files unchanged.")
            return
        subprocess.run([flutter, "pub", "get"], cwd=host, check=True)
        subprocess.run(
            [flutter, "build", "web", "--dart-define=APP_LOCAL_PREVIEW=true",
             "--no-web-resources-cdn"], cwd=host, check=True,
        )
        handler = partial(SimpleHTTPRequestHandler, directory=str(host / "build/web"))
        with ThreadingHTTPServer(("127.0.0.1", args.port), handler) as server:
            url = f"http://127.0.0.1:{args.port}/"
            print(f"SafeHub UI preview: {url}\nStop with Ctrl+C.")
            if not args.no_browser:
                webbrowser.open(url)
            try:
                server.serve_forever()
            except KeyboardInterrupt:
                pass


if __name__ == "__main__":
    main()
