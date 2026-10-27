import 'package:flutter_test/flutter_test.dart';
import 'package:safehub_app/core/house_scenario.dart';
import 'package:safehub_app/services/situation_service.dart';

void main() {
  test(
    'real fire captions preempt a test and an elevator prohibition is not a fire negation',
    () {
      final s = SituationService(settings: SituationSettings(enabled: false));
      addTearDown(s.dispose);
      s.startScenarioTest(HouseScenario.assistance, '시연 입력');
      s.addEvidence(
        '확정 음성자막',
        '화재가 발생했습니다. 엘리베이터를 이용하지 않고 안내를 확인하세요.',
        analyze: false,
      );
      expect(s.scenarioTestMode, isFalse);
      expect(s.liveFlow.active!.kind, HouseScenario.broadcast);
    },
  );
  test(
    'pain opens immediate help without LLM or a caregiver collapse claim',
    () {
      final s = SituationService(settings: SituationSettings(enabled: false));
      addTearDown(s.dispose);
      s.receiveSign('아프다');
      expect(s.helpOpen, isTrue);
      expect(s.helpSign, '아프다');
      expect(s.flow.active!.kind, HouseScenario.assistance);
      expect(s.flow.active!.evidence, isNot(contains('쓰러')));
      s.cancelHelp();
      s.receiveSign('아프다');
      expect(s.helpOpen, isFalse);
      s.receiveSign('감사');
      s.receiveSign('아프다');
      expect(s.helpOpen, isTrue);
    },
  );
  test(
    'help sign never covers a hazard; cancellation preserves its incident',
    () {
      final s = SituationService(settings: SituationSettings(enabled: false));
      addTearDown(s.dispose);
      s.observeBroadcast('화재가 발생했습니다.');
      final hazard = s.flow.active;
      s.receiveSign('구조');
      expect(s.helpOpen, isFalse);
      expect(s.deferredHelp, isTrue);
      expect(s.flow.active, same(hazard));
      s.openHelp();
      s.cancelHelp();
      expect(s.flow.active, same(hazard));
      expect(hazard!.acknowledged, isFalse);
    },
  );
  test(
    'simulated inputs and stale sign state do not leak back to the real mode',
    () {
      final s = SituationService(settings: SituationSettings(enabled: false));
      addTearDown(s.dispose);
      s.startScenarioTest(HouseScenario.assistance, '가족 도움');
      s.receiveSign('구조');
      expect(s.helpSign, isEmpty);
      s.receiveSign('아프다', simulated: true);
      expect(s.helpSign, '아프다');
      s.endScenarioTest();
      expect(s.pendingSign, isEmpty);
      expect(s.helpSign, isEmpty);
      expect(s.liveFlow.active, isNull);
    },
  );
}
