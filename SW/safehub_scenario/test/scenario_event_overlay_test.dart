import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safehub_app/core/house_scenario.dart';
import 'package:safehub_app/services/situation_service.dart';
import 'package:safehub_app/ui/widgets/scenario_event_overlay.dart';

Widget host(SituationService service) => MaterialApp(
        home: Scaffold(
            body: Stack(children: [
      const Center(child: Text('SafeHub 홈')),
      AnimatedBuilder(
          animation: service,
          builder: (_, __) => service.flow.active == null
              ? const SizedBox.shrink()
              : ScenarioEventOverlay(
                  key: ValueKey(service.flow.active),
                  service: service,
                  camera: const ColoredBox(
                      color: Colors.black,
                      child: Center(
                          child: Text('연결된 수어 카메라',
                              style: TextStyle(color: Colors.white)))),
                  onAcknowledge: service.acknowledge,
                  onSignal: () => service.flow.setDelivery('테스트 · 실제 명령 없음'))),
    ])));

SituationService createService() => SituationService(
    settings: SituationSettings(enabled: false, address: '테스트시 안심로 10, 101호'));

void main() {
  testWidgets('broadcast popup shows source and alert devices over the home',
      (tester) async {
    final service = createService();
    addTearDown(service.dispose);
    service.startScenarioTest(HouseScenario.broadcast, '화재가 발생했습니다. 대피하세요.');
    await tester.pumpWidget(host(service));
    await tester.pumpAndSettle();
    expect(find.text('SafeHub 홈'), findsOneWidget);
    expect(find.text('화재 안내방송이 감지됐어요'), findsOneWidget);
    expect(find.text('화재가 발생했습니다. 대피하세요.'), findsOneWidget);
    expect(find.text('LED 점멸 · 시연'), findsOneWidget);
    expect(find.text('베드셰이커 진동 · 시연'), findsOneWidget);
    await tester.tap(find.text('대피 안내 확인'));
    await tester.pumpAndSettle();
    expect(find.byType(ScenarioEventOverlay), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'disaster popup identifies earthquake from actual incident source',
      (tester) async {
    final service = createService();
    addTearDown(service.dispose);
    service.startScenarioTest(
        HouseScenario.disaster, '시연지역에 지진이 발생했습니다. 대피 안내를 확인하세요.');
    await tester.pumpWidget(host(service));
    await tester.pumpAndSettle();
    expect(find.text('지진 알림이 도착했어요'), findsOneWidget);
    expect(find.textContaining('지역: 시연지역'), findsOneWidget);
    expect(find.text('119 도움 요청'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'help is available with unknown response and never claims acceptance',
      (tester) async {
    final service = createService();
    addTearDown(service.dispose);
    service.startScenarioTest(HouseScenario.assistance, '침실 · 보호자 쓰러짐 의심');
    await tester.pumpWidget(host(service));
    await tester.pumpAndSettle();
    await tester.tap(find.text('119 도움 요청'));
    await tester.pumpAndSettle();
    expect(find.text('신고 내용을 준비했어요'), findsOneWidget);
    await tester.tap(find.text('준비한 신고 내용 보기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('사용자가 선택한 의식·반응: 미확인'), findsOneWidget);
    expect(find.textContaining('주소: 테스트시 안심로 10, 101호'), findsOneWidget);
    expect(find.textContaining('아직 전송하지 않음'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'confirmed sign enters help request and a new incident resets state',
      (tester) async {
    final service = createService();
    addTearDown(service.dispose);
    service.startScenarioTest(HouseScenario.assistance, '침실 · 첫 사건');
    await tester.pumpWidget(host(service));
    await tester.pumpAndSettle();
    await tester.tap(find.text('반응 없어요'));
    service.receiveSign('구조', simulated: true);
    await tester.pumpAndSettle();
    expect(find.text('119에 신고할까요?'), findsOneWidget);
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('119 도움 요청')));
    await tester.pumpAndSettle();
    expect(find.text('신고 내용을 준비했어요'), findsOneWidget);
    service.acknowledge();
    await tester.pumpAndSettle();
    service.startScenarioTest(HouseScenario.assistance, '화장실 · 다음 사건');
    await tester.pumpAndSettle();
    expect(find.text('119 도움 요청'), findsOneWidget);
    expect(find.text('신고 내용을 준비했어요'), findsNothing);
    expect(service.flow.active!.response, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('camera and touch remain visible without a sign start button',
      (tester) async {
    tester.view.physicalSize = const Size(1304, 884);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = createService();
    addTearDown(service.dispose);
    service.startScenarioTest(HouseScenario.assistance, '침실 · 보호자 쓰러짐 의심');
    await tester.pumpWidget(host(service));
    await tester.pumpAndSettle();
    final camera = tester.getRect(find.text('연결된 수어 카메라'));
    final touch =
        tester.getRect(find.widgetWithText(FilledButton, '119 도움 요청'));
    expect(camera.bottom, lessThan(884));
    expect(touch.bottom, lessThan(884));
    expect(camera.left, lessThan(touch.left));
    expect(find.byTooltip('구조 수어 입력 시연'), findsNothing);
    service.receiveSign('감사', simulated: true);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'collapse recognition opens confirmation automatically and repeated labels do not duplicate',
      (tester) async {
    final service = createService();
    addTearDown(service.dispose);
    service.startScenarioTest(HouseScenario.assistance, '침실 · 보호자 쓰러짐 의심');
    await tester.pumpWidget(host(service));
    await tester.pumpAndSettle();
    service.receiveSign('쓰러짐', simulated: true);
    await tester.pumpAndSettle();
    expect(find.text('119에 신고할까요?'), findsOneWidget);
    expect(find.text('“쓰러짐” 수어를 인식했어요.'), findsOneWidget);
    service.receiveSign('쓰러짐', simulated: true);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('다시 확인'));
    await tester.pumpAndSettle();
    service.receiveSign('쓰러짐', simulated: true);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    service.receiveSign('감사', simulated: true);
    service.receiveSign('도움', simulated: true);
    await tester.pumpAndSettle();
    expect(find.text('“도움” 수어를 인식했어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a confirmation from an ended incident is removed',
      (tester) async {
    final service = createService();
    addTearDown(service.dispose);
    service.startScenarioTest(HouseScenario.assistance, '첫 사건');
    await tester.pumpWidget(host(service));
    await tester.pumpAndSettle();
    service.receiveSign('구조', simulated: true);
    await tester.pumpAndSettle();
    expect(find.text('119에 신고할까요?'), findsOneWidget);
    service.acknowledge();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    service.startScenarioTest(HouseScenario.assistance, '다음 사건');
    await tester.pumpAndSettle();
    expect(find.text('119 도움 요청'), findsOneWidget);
    expect(find.text('신고 내용을 준비했어요'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every event popup has an X close button', (tester) async {
    final service = createService();
    addTearDown(service.dispose);
    await tester.pumpWidget(host(service));
    for (final kind in HouseScenario.values) {
      service.startScenarioTest(
          kind,
          kind == HouseScenario.broadcast
              ? '화재가 발생했습니다. 대피하세요.'
              : '지진 또는 보호자 도움 시연');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('알림 창 닫기'));
      await tester.pumpAndSettle();
      expect(find.byType(ScenarioEventOverlay), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'sign confirmation X returns to camera without preparing a report',
      (tester) async {
    final service = createService();
    addTearDown(service.dispose);
    service.startScenarioTest(HouseScenario.assistance, '보호자 쓰러짐 의심');
    await tester.pumpWidget(host(service));
    await tester.pumpAndSettle();
    service.receiveSign('구조', simulated: true);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('수어 신고 확인 창 닫기'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('연결된 수어 카메라'), findsOneWidget);
    expect(find.text('신고 내용을 준비했어요'), findsNothing);
  });

  testWidgets(
      'report has submit and X, while the existing return action remains',
      (tester) async {
    final service = createService();
    addTearDown(service.dispose);
    service.startScenarioTest(HouseScenario.assistance, '보호자 쓰러짐 의심');
    await tester.pumpWidget(host(service));
    await tester.pumpAndSettle();
    await tester.tap(find.text('119 도움 요청'));
    await tester.pumpAndSettle();
    expect(find.text('SafeHub로 돌아가기'), findsOneWidget);
    await tester.tap(find.text('준비한 신고 내용 보기'));
    await tester.pumpAndSettle();
    expect(find.text('내용 복사'), findsNothing);
    expect(find.text('신고하기'), findsOneWidget);
    await tester.tap(find.byTooltip('신고 내용 창 닫기'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('SafeHub로 돌아가기'), findsOneWidget);
    await tester.tap(find.text('준비한 신고 내용 보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('신고하기'));
    await tester.pumpAndSettle();
    expect(find.text('신고 요청 시연입니다. 실제 119 전송은 아직 연결되지 않았어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
