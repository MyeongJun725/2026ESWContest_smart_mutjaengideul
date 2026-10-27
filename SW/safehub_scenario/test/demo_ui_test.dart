import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safehub_app/core/house_scenario.dart';
import 'package:safehub_app/services/situation_service.dart';
import 'package:safehub_app/ui/widgets/scenario_event_overlay.dart';
import 'package:safehub_app/ui/theme/app_theme.dart';

Widget host(SituationService s, {double scale = 1}) => MaterialApp(
  theme: AppTheme.light,
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(
      body: AnimatedBuilder(
        animation: s,
        builder:
            (context, _) =>
                s.flow.active == null
                    ? const SizedBox()
                    : ScenarioEventOverlay(
                      key: ValueKey(s.flow.active),
                      service: s,
                      camera: const ColoredBox(
                        color: Colors.black,
                        child: Center(child: Text('카메라')),
                      ),
                      onAcknowledge: s.acknowledge,
                      onSignal: () {},
                    ),
      ),
    ),
  ),
);
void main() {
  for (final dimensions in [const Size(1280, 900), const Size(800, 480)]) {
    testWidgets('notice actions and close remain accessible at $dimensions', (
      t,
    ) async {
      t.view.physicalSize = dimensions;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final s = SituationService(settings: SituationSettings(enabled: false));
      addTearDown(s.dispose);
      s.startScenarioTest(
        HouseScenario.broadcast,
        '화재가 발생했습니다. 안내방송을 확인해 주세요.',
      );
      await t.pumpWidget(host(s));
      await t.pumpAndSettle();
      expect(find.text('화재 관련 안내방송'), findsOneWidget);
      expect(find.text('방송 확인했어요').hitTestable(), findsOneWidget);
      expect(find.byTooltip('알림 창 닫기').hitTestable(), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      await t.tap(find.text('방송 확인했어요'));
      await t.pumpAndSettle();
      expect(s.flow.active, isNull);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
    'personal pain has large camera and does not ask about caregiver consciousness',
    (t) async {
      t.view.physicalSize = const Size(1280, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final s = SituationService(settings: SituationSettings(enabled: false));
      addTearDown(s.dispose);
      s.receiveSign('아프다');
      await t.pumpWidget(host(s));
      await t.pumpAndSettle();
      expect(find.text('도움 요청'), findsOneWidget);
      expect(find.text('불러도 반응이 있나요?'), findsNothing);
      expect(find.text('카메라'), findsOneWidget);
      await t.tap(find.text('119 신고 내용 확인'));
      await t.pumpAndSettle();
      expect(find.text('도움 요청 내용 확인'), findsOneWidget);
      expect(find.textContaining('사용자가 도움을 요청합니다.'), findsOneWidget);
      expect(find.textContaining('보호자가 쓰러'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('large text leaves both main actions visible', (t) async {
    t.view.physicalSize = const Size(1280, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final s = SituationService(settings: SituationSettings(enabled: false));
    addTearDown(s.dispose);
    s.startScenarioTest(HouseScenario.disaster, '지진이 발생했습니다. 공지 내용을 확인해 주세요.');
    await t.pumpWidget(host(s, scale: 1.35));
    await t.pumpAndSettle();
    expect(find.text('알림 확인했어요').hitTestable(), findsOneWidget);
    expect(find.text('도움이 필요합니다').hitTestable(), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
