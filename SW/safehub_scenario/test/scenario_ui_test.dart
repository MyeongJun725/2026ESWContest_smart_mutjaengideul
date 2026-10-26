import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safehub_app/config/app_config.dart';
import 'package:safehub_app/services/situation_service.dart';
import 'package:safehub_app/ui/home_page.dart';
import 'package:safehub_app/ui/theme/app_theme.dart';
import 'package:safehub_app/ui/widgets/scenario_event_overlay.dart';
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
  testWidgets(
    'sign, appliance and signal routes retain one light visual theme',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AppConfig.resetForTesting();
      mockAudioPlugins(tester);
      await tester.runAsync(() async {
        await (FontLoader('Pretendard')
              ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.otf')))
            .load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
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
      await tester.tap(find.byKey(const ValueKey('navigation-수어 대화')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('수어 인식 결과'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'unified-sign');
      await tester.tap(find.byKey(const ValueKey('navigation-가전')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('가전 · 수어 단축키'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.text('가전 · 수어 단축키'))).brightness,
        Brightness.light,
      );
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'unified-appliance');
      await tester.tap(find.byKey(const ValueKey('navigation-신호 관리')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('와이파이 센싱'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'unified-signal');
      await tester.tap(find.byKey(const ValueKey('navigation-홈')));
      await tester.pump();
      expect(find.text('우리 집'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

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
      await (FontLoader('Pretendard')
            ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.otf')))
          .load();
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
    expect(find.text('우리 집'), findsOneWidget);
    for (final id in [
      'status',
      'camera',
      'captions',
      'notices',
      'help',
      'csi',
    ]) {
      expect(find.byKey(ValueKey('tile-$id')), findsOneWidget);
    }
    expect(find.byTooltip('AI·알림 설정'), findsOneWidget);
    expect(find.text('수어로 이야기해요').hitTestable(), findsOneWidget);
    expect(find.text('도움이 필요해요').hitTestable(), findsOneWidget);
    expect(find.text('최근 알림'), findsOneWidget);
    expect(find.text('수어를 기다리고 있어요'), findsOneWidget);
    await capture(tester, key, 'scenario-home');
    await tester.tap(find.text('도움이 필요해요'));
    await tester.pump();
    expect(find.byType(ScenarioEventOverlay), findsOneWidget);
    await tester.tap(find.text('다른 사람이 아파요'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('반응 없어요'));
    await tester.pump();
    await tester.tap(find.text('119 신고 내용 확인'));
    await tester.pumpAndSettle();
    expect(find.textContaining('불러도 반응이 있는지: 반응 없어요'), findsOneWidget);
    expect(
      find.textContaining('미전송 · 실제 신고·연락 기능은 연결되어 있지 않아요.'),
      findsOneWidget,
    );
    await capture(tester, key, 'scenario-response');
    await tester.tap(find.text('확인하고 돌아가기'));
    await tester.pumpAndSettle();
    expect(find.byType(ScenarioEventOverlay), findsNothing);
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
    final situation = SituationService(
      settings: SituationSettings(enabled: false),
    )..receiveSign('아프다');
    addTearDown(situation.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScenarioEventOverlay(
            service: situation,
            camera: const ColoredBox(color: Colors.black),
            onAcknowledge: situation.acknowledge,
            onSignal: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('괜찮아요').hitTestable(), findsOneWidget);
    await tester.ensureVisible(find.text('119 신고 내용 확인'));
    await tester.tap(find.text('119 신고 내용 확인'));
    await tester.pumpAndSettle();
    expect(find.text('확인하고 돌아가기').hitTestable(), findsOneWidget);
    expect(find.textContaining('실제 신고·연락 기능은 연결되어 있지 않아요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
