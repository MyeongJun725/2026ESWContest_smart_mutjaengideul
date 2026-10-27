import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safehub_app/config/app_config.dart';
import 'package:safehub_app/services/disaster_service.dart';
import 'package:safehub_app/ui/home_page.dart';
import 'package:safehub_app/ui/theme/app_theme.dart';
import 'package:safehub_app/ui/widgets/disaster_notice_card.dart';
import 'package:safehub_app/ui/widgets/sign_result_strip.dart';
import 'local_preview_test.dart' show mockAudioPlugins;

Future<void> capture(WidgetTester t, GlobalKey key, String name) async {
  final directory = Platform.environment['FHD_SCREENSHOTS'];
  if (directory == null) return;
  await t.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File(
      '$directory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets(
    'FHD home displays fetched disaster record outside alarm eligibility',
    (t) async {
      t.view.physicalSize = const Size(1920, 1080);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      mockAudioPlugins(t);
      late Directory directory;
      await t.runAsync(() async {
        directory = await Directory.systemTemp.createTemp('safehub-fhd-');
        final config = File('${directory.path}/settings.json');
        await config.writeAsString(
          jsonEncode({
            'DISASTER_API_URL': 'https://example.invalid/disaster',
            'DISASTER_API_KEY': 'fake-test-key',
          }),
        );
        await AppConfig.load(filePath: config.path);
        final fonts = FontLoader('Pretendard');
        for (final name in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
          fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$name.otf'));
        }
        await fonts.load();
      await (FontLoader('MaterialIcons')..addFont(
        rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
      addTearDown(() async {
        AppConfig.resetForTesting();
        await directory.delete(recursive: true);
      });
      var fail = false;
      final client = MockClient((_) async {
        if (fail) throw const SocketException('fake outage');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'header': {'resultCode': '00'},
              'totalCount': 1,
              'body': [
                {
                  'SN': 501,
                  'CRT_DT': '2026-10-26 09:00:00',
                  'DST_SE_NM': '안전안내',
                  'EMRG_STEP_NM': '안전안내',
                  'RCPTN_RGN_NM': '시연 지역',
                  'MSG_CN': '화면 예시 · 강풍이 예상됩니다. 외출 시 안전에 유의하세요.',
                },
              ],
            }),
          ),
          200,
        );
      });
      addTearDown(client.close);
      final service = DisasterService(client: client);
      final key = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: SafeHubHomePage(disasterService: service),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('화면 예시 · 강풍'), findsOneWidget);
      expect(find.text('재난·알림'), findsOneWidget);
      expect(find.byKey(const ValueKey('sign-result-strip')), findsOneWidget);
      final camera = t.getRect(find.byKey(const ValueKey('sign-result-strip')));
      expect(camera.bottom, lessThan(1080));
      expect(find.text('도움 요청').hitTestable(), findsOneWidget);
      expect(t.takeException(), isNull);
      await capture(t, key, 'home-fhd');
      // Failure must retain the last received message and show its stale state.
      fail = true;
      await t.pump(const Duration(minutes: 2));
      await t.pump();
      expect(find.textContaining('화면 예시 · 강풍'), findsOneWidget);
      expect(find.textContaining('조회 실패'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'recent activity never masks disaster text or its details action',
    (t) async {
      var details = 0;
      await t.pumpWidget(
        MaterialApp(
            debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: SizedBox(
              width: 680,
              height: 250,
              child: DisasterNoticeCard(
                disaster: const {'MSG_CN': '재난 원문', 'RCPTN_RGN_NM': '서울'},
                status: '최근 수신 기록',
                latestEvent: '대화 내용',
                onDisaster: () => details++,
                onEvents: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('재난 원문'), findsOneWidget);
      expect(find.text('최근 활동 · 대화 내용'), findsOneWidget);
      await t.tap(find.text('재난 원문'));
      expect(details, 1);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'recognized sign is large and retained as historical on disconnect',
    (t) async {
      final key = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 1050,
                  child: SignResultStrip(
                    sign: '아프다',
                    connected: false,
                    onConversation: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final text = t.widget<Text>(
        find.byKey(const ValueKey('sign-result-text')),
      );
      expect(text.data, '아프다');
      expect(text.style!.fontSize, 40);
      expect(find.textContaining('최근 인식 결과'), findsOneWidget);
      expect(t.takeException(), isNull);
      await capture(t, key, 'sign-result');
    },
  );
}
