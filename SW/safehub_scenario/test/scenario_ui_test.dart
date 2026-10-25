import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safehub_app/config/app_config.dart';
import 'package:safehub_app/services/live_caption_service.dart';
import 'package:safehub_app/services/situation_service.dart';
import 'package:safehub_app/ui/home_page.dart';
import 'package:safehub_app/ui/theme/app_theme.dart';
import 'package:safehub_app/ui/widgets/situation_panel.dart';
import 'local_preview_test.dart' show mockAudioPlugins;

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  final directory = Platform.environment['SCENARIO_SCREENSHOTS'];
  if (directory == null) return;
  await tester.runAsync(() async {
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
  testWidgets('sign, appliance and signal routes retain one light visual theme', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AppConfig.resetForTesting();
    mockAudioPlugins(tester);
    await tester.runAsync(() async {
      await (FontLoader('Pretendard')..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.otf'))).load();
      await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key,
      child: MaterialApp(theme: AppTheme.light, home: const SafeHubHomePage())));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('수어 대화'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('수어 인식 결과'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'unified-sign');
    await tester.tap(find.text('가전'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('가전 · 수어 단축키'), findsOneWidget);
    expect(Theme.of(tester.element(find.text('가전 · 수어 단축키'))).brightness, Brightness.light);
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'unified-appliance');
    await tester.tap(find.text('신호 관리'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('와이파이 센싱'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'unified-signal');
    await tester.tap(find.text('홈'));
    await tester.pump();
    expect(find.text('우리 집 상황'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('home keeps all functions and opens the new help workflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AppConfig.resetForTesting();
    mockAudioPlugins(tester);
    await tester.runAsync(() async {
      await (FontLoader('Pretendard')..addFont(
        rootBundle.load('assets/fonts/Pretendard-Regular.otf'),
      )).load();
    });
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const SafeHubHomePage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('우리 집 상황'), findsOneWidget);
    expect(find.byTooltip('신호 수집 · 모델 관리'), findsOneWidget);
    expect(find.text('거실'), findsNothing);
    expect(find.text('침실'), findsNothing);
    expect(find.text('AI에게 말하기'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsNothing);
    expect(find.text('수어로 이야기해요').hitTestable(), findsOneWidget);
    expect(find.text('도움이 필요해요').hitTestable(), findsOneWidget);
    expect(find.text('경보 · 재난').hitTestable(), findsOneWidget);
    expect(find.text('수어 인식 대기 중'), findsOneWidget);
    await capture(tester, key, 'scenario-home');
    await tester.tap(find.text('도움이 필요해요'));
    await tester.pump();
    expect(find.byType(SituationResponse), findsOneWidget);
    await tester.tap(find.text('가족이 쓰러졌어요'));
    await tester.pump();
    expect(find.textContaining('확인된 응답: 가족이 쓰러졌습니다.'), findsOneWidget);
    await capture(tester, key, 'scenario-response');
    await tester.tap(find.text('도움 요청 문안 만들기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('아직 전송하지 않음'), findsOneWidget);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('경보 확인'));
    await tester.tap(find.text('경보 확인'));
    await tester.pump();
    expect(find.byType(SituationResponse), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('touch response screen fits an 800 by 480 display', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    mockAudioPlugins(tester);
    final situation = SituationService()..openHelp();
    final captions = LiveCaptionService(transcribe: (_) async => '');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SituationResponse(
            service: situation,
            captions: captions,
            camera: const ColoredBox(color: Colors.black),
            incidentTitle: '재난 알림',
            incidentText: '화재 안내방송 내용을 확인해 주세요.',
            onAcknowledge: () {},
            onSignal: () {},
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('경보 확인'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    situation.dispose();
    captions.dispose();
    await tester.pump();
  });
}
