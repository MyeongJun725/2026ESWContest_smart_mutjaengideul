import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safehub_app/services/camera_stream_service.dart';
import 'package:safehub_app/ui/home_page.dart';

import 'local_preview_test.dart' show mockAudioPlugins;

class _Camera extends CameraStreamService {
  late void Function(Uint8List) frame;
  late void Function(bool) connection;

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

ui.Image _image() {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
  final picture = recorder.endRecording();
  final image = picture.toImageSync(1, 1);
  picture.dispose();
  return image;
}

void main() {
  testWidgets(
    'slow decode retains only the newest pending frame and clears it on reconnect',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      mockAudioPlugins(tester);
      final camera = _Camera();
      final callbacks = <void Function(ui.Image)>[];
      final decoded = <Uint8List>[];
      await tester.pumpWidget(
        MaterialApp(
          home: SafeHubHomePage(
            cameraService: camera,
            cameraDecoder: (bytes, _, __, ___, callback) {
              decoded.add(bytes);
              callbacks.add(callback);
            },
          ),
        ),
      );
      camera.connection(true);
      final first = Uint8List(320 * 240 * 4)..[0] = 1;
      final middle = Uint8List(320 * 240 * 4)..[0] = 2;
      final latest = Uint8List(320 * 240 * 4)..[0] = 3;
      camera.frame(first);
      camera.frame(middle);
      camera.frame(latest);
      expect(decoded, [same(first)]);
      final firstImage = _image();
      callbacks.removeAt(0)(firstImage);
      expect(decoded, [same(first), same(latest)]);
      expect(decoded, isNot(contains(same(middle))));
      // A queued old-session frame must not start after reconnection.
      camera.frame(middle);
      camera.connection(false);
      camera.connection(true);
      final newSession = Uint8List(320 * 240 * 4)..[0] = 4;
      camera.frame(newSession);
      final stale = _image();
      callbacks.removeAt(0)(stale);
      expect(stale.debugDisposed, isTrue);
      expect(decoded, [same(first), same(latest), same(newSession)]);
      // Disposal also discards a pending frame and releases the in-flight image.
      camera.frame(middle);
      await tester.pumpWidget(const SizedBox());
      final afterDispose = _image();
      callbacks.removeAt(0)(afterDispose);
      expect(afterDispose.debugDisposed, isTrue);
      expect(firstImage.debugDisposed, isTrue);
      expect(decoded, hasLength(3));
      expect(tester.takeException(), isNull);
    },
  );

  for (final reconnect in [false, true]) {
    testWidgets(
      'late decode is discarded after disconnect (reconnect=$reconnect)',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        mockAudioPlugins(tester);
        final camera = _Camera();
        final callbacks = <void Function(ui.Image)>[];

        await tester.pumpWidget(
          MaterialApp(
            home: SafeHubHomePage(
              cameraService: camera,
              cameraDecoder: (_, __, ___, ____, callback) =>
                  callbacks.add(callback),
            ),
          ),
        );
        // The injected service uses the same callback path as a real connection.
        // No network address or physical camera is required for this test.
        camera.frame(Uint8List(320 * 240 * 4));
        expect(callbacks, isEmpty, reason: 'Frames require a connected stream');
        camera.connection(true);
        camera.frame(Uint8List(320 * 240 * 4));
        expect(callbacks, hasLength(1));
        camera.connection(false);
        if (reconnect) camera.connection(true);

        final stale = _image();
        callbacks.removeAt(0)(stale);
        await tester.pump();
        expect(stale.debugDisposed, isTrue);
        expect(find.byKey(const ValueKey('camera_preview')), findsNothing);

        if (!reconnect) camera.connection(true);
        camera.frame(Uint8List(320 * 240 * 4));
        final fresh = _image();
        callbacks.removeAt(0)(fresh);
        await tester.pump();
        expect(
          tester
              .widget<RawImage>(find.byKey(const ValueKey('camera_preview')))
              .image,
          same(fresh),
        );

        // A callback from the disposed page also releases its decoded image.
        camera.frame(Uint8List(320 * 240 * 4));
        await tester.pumpWidget(const SizedBox());
        final afterDispose = _image();
        callbacks.removeAt(0)(afterDispose);
        await tester.pump();
        expect(fresh.debugDisposed, isTrue);
        expect(afterDispose.debugDisposed, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
