// ATLAS device entry for kernel builds using the existing native runner.
// The stock Windows Flutter frontend does not generate ATLAS plugin registrants.
import 'dart:io';

import 'package:record_atlas/record_atlas.dart';

import '../lib/main.dart' as app;

Future<void> main() async {
  if ((Platform.isLinux || Platform.operatingSystem == 'atlas') &&
      File('/data/share/safehub-tools/parecord').existsSync()) {
    RecordAtlas.registerWith();
  }
  await app.main();
}
