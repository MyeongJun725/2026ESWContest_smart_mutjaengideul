import 'package:flutter_test/flutter_test.dart';
import 'package:safehub_app/core/house_scenario.dart';
import 'package:safehub_app/services/situation_service.dart';
void main() {
  test('broadcast clause scope preserves explicit danger without model input', () {
    for (final entry in {
      '훈련이 아닙니다. 실제 화재가 발생했습니다. 즉시 대피하세요.': true,
      '훈련은 취소되었습니다. 실제 화재가 발생했습니다.': true,
      '화재가 발생했습니다. 엘리베이터를 사용하지 마세요.': true,
      '화재가 발생하는 훈련입니다.': false,
      '화재가 발생하지 않았습니다.': false,
      '화재 예방 안내입니다.': false,
    }.entries) {
      final flow = HouseScenarioFlow();
      expect(flow.broadcast(entry.key), entry.value, reason: entry.key);
      flow.dispose();
    }
  });
  test('stale test termination cannot clear a preempting real event', () {
    final s = SituationService(settings: SituationSettings(enabled:false));
    s.startScenarioTest(HouseScenario.assistance, '시연', actuate:true);
    s.observeBroadcast('실제 화재가 발생했습니다.');
    final real = s.flow.active;
    var callbacks=0;
    s.onScenarioTestChanged=()=>callbacks++;
    s.endScenarioTest();
    expect(s.flow.active,same(real));
    expect(real!.acknowledged,isFalse);
    expect(callbacks,0);
    s.addEvidence('확정 음성자막','화재가 아닙니다.',analyze:false);
    expect(s.flow.active,same(real));
    s.dispose();
  });
}
