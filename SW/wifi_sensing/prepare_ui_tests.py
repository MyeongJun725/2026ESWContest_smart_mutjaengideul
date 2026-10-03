"""Copy the actual UI additions into a non-ATLAS test harness, unchanged."""
from pathlib import Path
import argparse
import shutil

parser = argparse.ArgumentParser()
parser.add_argument('output', type=Path)
args = parser.parse_args()
source = Path(__file__).resolve().parents[1] / 'safehub_app'
target = args.output.resolve()
target.mkdir(parents=True, exist_ok=True)
files = [
    'lib/services/wifi_sensing_service.dart',
    'lib/ui/widgets/wifi_sensing_panel.dart',
    'test/wifi_sensing_panel_test.dart',
    'assets/fonts/Pretendard-Regular.otf',
]
for relative in files:
    destination = target / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source / relative, destination)
(target / 'pubspec.yaml').write_text('''name: safehub_app
environment:
  sdk: '>=3.6.2 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.2
dev_dependencies:
  flutter_test:
    sdk: flutter
flutter:
  uses-material-design: true
  assets:
    - assets/fonts/Pretendard-Regular.otf
''', encoding='utf-8')
print(target)
