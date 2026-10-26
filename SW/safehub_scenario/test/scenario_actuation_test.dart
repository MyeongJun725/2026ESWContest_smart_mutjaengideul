import 'package:flutter_test/flutter_test.dart';
import 'package:safehub_app/core/house_scenario.dart';
import 'package:safehub_app/services/situation_service.dart';

void main() {
  test('each scenario selection requests the actuator route and exit stops it', () {
    final service = SituationService(settings: SituationSettings(enabled: false));
    addTearDown(service.dispose);
    final modes = <bool>[];
    service.onScenarioTestChanged = () => modes.add(service.scenarioActuators);
    for (final kind in HouseScenario.values) {
      expect(service.startScenarioTest(kind, kind == HouseScenario.broadcast
          ? '화재가 발생했습니다. 대피하세요.' : '시연 상황', actuate: true), isTrue);
      expect(service.flow.active!.kind, kind);
      expect(service.scenarioActuators, isTrue);
      service.endScenarioTest();
    }
    expect(modes, [true, false, true, false, true, false]);
  });

  test('final speech creates a real alert without LLM and interrupts screen test', () {
    final service = SituationService(settings: SituationSettings(enabled: false));
    addTearDown(service.dispose);
    var alerts = 0;
    service.onScenarioAlert = () => alerts++;
    service.startScenarioTest(HouseScenario.disaster, '모의 재난');
    service.addEvidence('확정 음성자막', '화재가 발생했습니다. 신속히 대피하세요.', analyze: false);
    expect(service.scenarioTestMode, isFalse);
    expect(service.liveFlow.active!.kind, HouseScenario.broadcast);
    expect(alerts, 1);
    service.addEvidence('확정 음성자막', '화재가 발생했습니다. 신속히 대피하세요.', analyze: false);
    expect(alerts, 1);
  });

  test('negative or drill speech never invokes the actuator route', () {
    final service = SituationService(settings: SituationSettings(enabled: false));
    addTearDown(service.dispose);
    var alerts = 0;
    service.onScenarioAlert = () => alerts++;
    for (final text in ['화재가 발생하지 않았습니다.', '화재 대피 훈련입니다.']) {
      service.addEvidence('확정 음성자막', text, analyze: false);
    }
    expect(alerts, 0);
    expect(service.liveFlow.active, isNull);
  });
}
