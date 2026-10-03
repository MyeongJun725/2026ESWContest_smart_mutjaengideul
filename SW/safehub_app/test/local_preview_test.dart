import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safehub_app/config/app_config.dart';
import 'package:safehub_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only an explicit preview build skips required service settings', () {
    if (AppConfig.localPreview) {
      expect(AppConfig.validate, returnsNormally);
    } else if (AppConfig.mqttBroker.isEmpty) {
      expect(AppConfig.validate, throwsStateError);
    }
  });

  testWidgets(
    'preview opens without devices and disposes an unconnected MQTT receiver',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Native audio plugins are outside this device-free UI test.
      final messenger = tester.binding.defaultBinaryMessenger;
      final channels = <String>{};
      void mockChannel(
        String name, [
        Future<Object?> Function(MethodCall)? call,
      ]) {
        channels.add(name);
        messenger.setMockMethodCallHandler(
          MethodChannel(name),
          call ?? (_) async => null,
        );
      }

      mockChannel('xyz.luan/audioplayers.global');
      mockChannel('xyz.luan/audioplayers.global/events');
      mockChannel('xyz.luan/audioplayers', (call) async {
        if (call.method == 'create') {
          mockChannel(
            'xyz.luan/audioplayers/events/${call.arguments['playerId']}',
          );
        }
        return null;
      });
      mockChannel('com.llfbandit.record/messages', (call) async {
        if (call.method == 'create') {
          mockChannel(
            'com.llfbandit.record/events/${call.arguments['recorderId']}',
          );
        }
        return null;
      });
      addTearDown(() {
        for (final name in channels) {
          messenger.setMockMethodCallHandler(MethodChannel(name), null);
        }
      });

      await tester.pumpWidget(const SafeHubApp());
      await tester.pump();
      expect(find.textContaining('장비 연결 전 체험 ·'), findsOneWidget);
      expect(find.text('수어 인식 대기 중'), findsOneWidget);
      expect(find.text('와이파이 센싱'), findsOneWidget);
      expect(find.text('연결 중'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('와이파이 센싱'));
      await tester.pump();
      expect(find.text('1. 신호 수집'), findsOneWidget);
      expect(find.text('2. 기록 · 학습'), findsOneWidget);
      expect(find.text('3. 현재 행동'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
    skip: !AppConfig.localPreview,
  );
}
