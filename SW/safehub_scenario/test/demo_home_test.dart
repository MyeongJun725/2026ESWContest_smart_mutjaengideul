import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safehub_app/config/app_config.dart';
import 'package:safehub_app/core/house_scenario.dart';
import 'package:safehub_app/services/situation_service.dart';
import 'package:safehub_app/ui/home_page.dart';
import 'package:safehub_app/ui/theme/app_theme.dart';
import 'package:safehub_app/ui/widgets/scenario_event_overlay.dart';
import 'local_preview_test.dart' show mockAudioPlugins;
import 'scenario_ui_test.dart' show capture;

void main() {
  testWidgets('home gives most width to camera and keeps help within screen', (
    t,
  ) async {
    t.view.physicalSize = const Size(1280, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    AppConfig.resetForTesting();
    mockAudioPlugins(t);
    await t.runAsync(() async {
      await (FontLoader('Pretendard')..addFont(
        rootBundle.load('assets/fonts/Pretendard-Regular.otf'),
      )).load();
      await (FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const SafeHubHomePage(),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 150));
    expect(find.text('도움이 필요해요').hitTestable(), findsOneWidget);
    expect(find.text('새로운 알림이 없어요'), findsOneWidget);
    expect(find.text('판단 근거'), findsNothing);
    expect(find.text('최근 이벤트'), findsNothing);
    expect(t.takeException(), isNull);
    await capture(t, key, 'demo-home');
    await t.pumpWidget(const SizedBox());
    await t.pump();
    final s = SituationService(settings: SituationSettings(enabled: false));
    for (final kind in HouseScenario.values) {
      s.startScenarioTest(
        kind,
        kind == HouseScenario.broadcast
            ? '아파트 안내방송입니다. 화재가 발생했습니다. 대피 방송을 확인해 주세요.'
            : kind == HouseScenario.disaster
            ? '시연지역에 지진이 발생했습니다. 재난 안내를 확인해 주세요.'
            : '가족 쓰러짐 의심 신호가 접수됐습니다.',
      );
      final overlayKey = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: overlayKey,
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: ScenarioEventOverlay(
                key: ValueKey(kind),
                service: s,
                camera: const ColoredBox(
                  color: Color(0xFFDFDCD7),
                  child: Center(child: Icon(Icons.sign_language, size: 70)),
                ),
                onAcknowledge: s.acknowledge,
                onSignal: () {},
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await capture(t, overlayKey, 'demo-${kind.name}');
      await t.pumpWidget(const SizedBox());
      s.endScenarioTest();
    }
    s.dispose();
  });
}
