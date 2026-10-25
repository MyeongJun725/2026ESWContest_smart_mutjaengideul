import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safehub_app/core/house_scenario.dart';
import 'package:safehub_app/services/situation_service.dart';
import 'package:safehub_app/services/live_caption_service.dart';
import 'package:safehub_app/ui/theme/app_theme.dart';
import 'package:safehub_app/ui/widgets/house_status_card.dart';
import 'package:safehub_app/ui/widgets/situation_panel.dart';

void main() {
  for (final kind in HouseScenario.values) {
    testWidgets('${kind.name}: select, respond, draft, acknowledge, exit', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = SituationService(settings: SituationSettings(enabled: false));
      final captions = LiveCaptionService(transcribe: (_) async => '');
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: Scaffold(
        body: AnimatedBuilder(animation: service, builder: (context, _) => service.helpOpen
          ? SituationResponse(service: service, captions: captions, camera: const SizedBox(),
              onAcknowledge: service.acknowledge, onSignal: () {},
              incidentTitle: service.flow.active?.title, incidentText: service.flow.active?.evidence)
          : Align(alignment: Alignment.topCenter, child: HouseStatusCard(
              service: service, onAcknowledge: service.acknowledge))))));
      await tester.tap(find.text('시나리오 테스트'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<HouseScenario>));
      await tester.pumpAndSettle();
      final label = ['① 아파트 안내방송', '② 재난 API 알림', '③ 가족 쓰러짐·도움 요청'][kind.index];
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), kind == HouseScenario.broadcast
          ? '화재가 발생했습니다. 안내방송을 확인해 주세요.' : '직접 입력한 상황을 확인해 주세요.');
      await tester.tap(find.text('화면 테스트 실행'));
      await tester.pumpAndSettle();
      expect(service.flow.active!.kind, kind);
      expect(find.text('테스트 · 실제 장치 명령 없음'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('상황 응답 · 도움'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '아프다');
      await tester.tap(find.text('테스트 수어 넣기'));
      await tester.pump();
      await tester.tap(find.text('이 수어로 응답'));
      await tester.pump();
      expect(service.response, contains('아프다'));
      await tester.tap(find.text('도움 요청 문안 만들기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('[테스트] 도움 요청 문안'), findsOneWidget);
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('경보 확인'));
      await tester.tap(find.text('경보 확인'));
      await tester.pumpAndSettle();
      expect(service.flow.active, isNull);
      expect(service.flow.lastAcknowledged!.acknowledged, isTrue);
      await tester.tap(find.text('테스트 종료'));
      await tester.pumpAndSettle();
      expect(service.scenarioTestMode, isFalse);
      expect(service.liveFlow.active, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      service.dispose(); captions.dispose();
    });
  }
}
