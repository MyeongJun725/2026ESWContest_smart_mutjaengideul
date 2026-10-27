import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:safehub_app/core/house_scenario.dart';
import 'package:safehub_app/services/situation_service.dart';

void main() {
  test('broadcast clause scope preserves explicit danger without model input',
      () {
    final cases = jsonDecode(
        File('test/fixtures/broadcast_cases.json').readAsStringSync()) as List;
    for (final entry in cases) {
      final flow = HouseScenarioFlow();
      expect(flow.broadcast(entry['text']), entry['hazard'],
          reason: entry['id']);
      flow.dispose();
    }
  });
  test('stale test termination cannot clear a preempting real event', () {
    final s = SituationService(settings: SituationSettings(enabled: false));
    s.startScenarioTest(HouseScenario.assistance, '시연', actuate: true);
    s.observeBroadcast('실제 화재가 발생했습니다.');
    final real = s.flow.active;
    var callbacks = 0;
    s.onScenarioTestChanged = () => callbacks++;
    s.endScenarioTest();
    expect(s.flow.active, same(real));
    expect(real!.acknowledged, isFalse);
    expect(callbacks, 0);
    s.addEvidence('확정 음성자막', '화재가 아닙니다.', analyze: false);
    expect(s.flow.active, same(real));
    s.dispose();
  });
}
