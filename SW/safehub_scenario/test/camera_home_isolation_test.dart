import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safehub_app/config/app_config.dart';
import 'package:safehub_app/services/camera_stream_service.dart';
import 'package:safehub_app/ui/home_page.dart';

import 'local_preview_test.dart' show mockAudioPlugins;

class TestCamera extends CameraStreamService {
  void Function(Uint8List)? frame;
  void Function(bool)? connection;

  @override
  Future<void> connect({
    required String host,
    required int port,
    required void Function(Uint8List) onFrame,
    required void Function(bool) onConnectionChanged,
  }) async {
    frame = onFrame;
    connection = onConnectionChanged;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('camera frames update pixels without rebuilding the home', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    mockAudioPlugins(tester);
    late Directory temporary;
    await tester.runAsync(() async {
      temporary = await Directory.systemTemp.createTemp('safehub-camera-test-');
      await AppConfig.load(filePath: '${temporary.path}/settings.json');
      await AppConfig.save({...AppConfig.settings, 'CAMERA_HOST': '127.0.0.1'});
    });
    addTearDown(() async {
      debugOnRebuildDirtyWidget = null;
      AppConfig.resetForTesting();
      await temporary.delete(recursive: true);
    });
    final camera = TestCamera();
    await tester.pumpWidget(
      MaterialApp(home: SafeHubHomePage(cameraService: camera)),
    );
    camera.connection!(true);
    await tester.pump();
    var homeRebuilds = 0;
    final cameraImage = find.byWidgetPredicate(
      (widget) =>
          widget is RawImage &&
          widget.image?.width == 320 &&
          widget.image?.height == 240,
    );
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      if (element.widget is SafeHubHomePage) homeRebuilds++;
    };
    for (var index = 1; index <= 12; index++) {
      final bytes = Uint8List(320 * 240 * 4);
      for (var offset = 0; offset < bytes.length; offset += 4) {
        bytes[offset] = index;
        bytes[offset + 3] = 255;
      }
      await tester.runAsync(() async {
        camera.frame!(bytes);
        await Future<void>.delayed(const Duration(milliseconds: 40));
      });
      await tester.pump();
      final image = tester.widget<RawImage>(cameraImage).image!;
      await tester.runAsync(() async {
        final actual = await image.toByteData();
        expect(actual!.getUint8(0), index);
      });
    }
    expect(
      homeRebuilds,
      0,
      reason: 'Camera frames must not rebuild sign, CSI and caption cards.',
    );
    camera.connection!(false);
    await tester.pump();
    expect(cameraImage, findsNothing);
    expect(find.text('RPi4 카메라 연결 대기 중'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
