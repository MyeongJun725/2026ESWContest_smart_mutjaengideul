import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safehub_app/core/house_scenario.dart';
import 'package:safehub_app/services/situation_service.dart';
import 'package:safehub_app/ui/widgets/house_status_card.dart';
import 'package:safehub_app/ui/widgets/hardware_test_dialog.dart';

void main() {
  testWidgets('scenario chooser defaults to actual actuator route', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = SituationService(settings: SituationSettings(enabled: false));
    addTearDown(service.dispose);
    var deliveries = 0;
    service.onScenarioTestChanged = () { if (service.scenarioActuators) deliveries++; };
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) =>
      TextButton(onPressed: () => showScenarioTest(context, service), child: const Text('열기'))))));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('화면·장치 함께 실행'));
    await tester.pumpAndSettle();
    expect(deliveries, 1);
    expect(service.flow.active!.kind, HouseScenario.broadcast);
    expect(service.scenarioActuators, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('curtain buttons submit direction and stop without changing fan', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final curtains = <String>[];
    final fans = <bool>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: HardwareTestDialog(
      connected: true, classifierUri: Uri.parse('http://127.0.0.1:9380/classify'),
      publishAlert: (_, __) => true,
      publishFan: (power) { fans.add(power); return true; },
      publishCurtain: (action) { curtains.add(action); return true; },
    ))));
    for (final label in ['커튼 올림', '커튼 내림', '커튼 정지']) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pump();
    }
    expect(curtains, ['up', 'down', 'stop']);
    expect(fans, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
