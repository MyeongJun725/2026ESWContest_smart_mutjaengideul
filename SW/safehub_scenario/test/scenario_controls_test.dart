import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safehub_app/core/house_scenario.dart';
import 'package:safehub_app/services/situation_service.dart';
import 'package:safehub_app/ui/theme/app_theme.dart';
import 'package:safehub_app/ui/widgets/house_status_card.dart';
import 'package:safehub_app/ui/widgets/scenario_event_overlay.dart';

void main() {
  for (final kind in HouseScenario.values) {
    testWidgets('${kind.name}: select, respond, draft, acknowledge, exit', (
      t,
    ) async {
      t.view.physicalSize = const Size(1280, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final service = SituationService(
        settings: SituationSettings(enabled: false),
      );
      addTearDown(service.dispose);
      var physicalCommands = 0;
      service.onScenarioAlert = () => physicalCommands++;
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AnimatedBuilder(
              animation: service,
              builder: (context, _) => Stack(
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      height: 160,
                      child: HouseStatusCard(
                        service: service,
                        onAcknowledge: service.acknowledge,
                      ),
                    ),
                  ),
                  if (service.flow.active != null)
                    ScenarioEventOverlay(
                      key: ValueKey(service.flow.active),
                      service: service,
                      camera: const ColoredBox(color: Colors.black),
                      onAcknowledge: service.acknowledge,
                      onSignal: () => physicalCommands++,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('시나리오 테스트'));
      await t.pumpAndSettle();
      await t.tap(find.byType(DropdownButtonFormField<HouseScenario>));
      await t.pumpAndSettle();
      final label = ['① 아파트 안내방송', '② 재난 API 알림', '③ 가족 쓰러짐·도움 요청'][kind.index];
      await t.tap(find.text(label).last);
      await t.pumpAndSettle();
      await t.enterText(
        find.byType(TextField),
        kind == HouseScenario.broadcast
            ? '화재가 발생했습니다. 안내방송을 확인해 주세요.'
            : '직접 입력한 상황을 확인해 주세요.',
      );
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      await t.tap(find.text('화면만 실행'));
      await t.pumpAndSettle();
      final incident = service.flow.active!;
      expect(incident.kind, kind);
      expect(incident.delivery, contains('실제 명령 없음'));
      expect(find.text('화면 테스트 · 실제 장치와 신고는 작동하지 않아요.'), findsOneWidget);
      if (kind != HouseScenario.assistance) {
        await t.tap(find.text('도움이 필요해요'));
        await t.pumpAndSettle();
      }
      service.receiveSign('아프다', simulated: true);
      await t.pumpAndSettle();
      expect(service.helpSign, '아프다');
      await t.ensureVisible(find.text('119 신고 내용 확인'));
      await t.tap(find.text('119 신고 내용 확인'));
      await t.pumpAndSettle();
      expect(find.textContaining('인식한 수어: 아프다'), findsOneWidget);
      expect(find.textContaining('실제 신고·연락 기능은 연결되어 있지 않아요.'), findsOneWidget);
      await t.tap(find.text('확인하고 돌아가기'));
      await t.pumpAndSettle();
      if (kind != HouseScenario.assistance) {
        expect(service.flow.active, same(incident));
        expect(incident.acknowledged, isFalse);
        await t.tap(
          find.text(kind == HouseScenario.broadcast ? '방송 확인했어요' : '알림 확인했어요'),
        );
        await t.pumpAndSettle();
      }
      expect(service.flow.active, isNull);
      expect(service.flow.lastAcknowledged!.acknowledged, isTrue);
      await t.tap(find.text('시연 종료'));
      await t.pumpAndSettle();
      expect(service.scenarioTestMode, isFalse);
      expect(service.liveFlow.active, isNull);
      expect(physicalCommands, 0);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
}
