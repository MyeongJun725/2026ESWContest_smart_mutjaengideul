import 'package:flutter_test/flutter_test.dart';
import 'package:safehub_app/core/recent_activity.dart';

void main() {
  test('repeated disaster interpretation keeps one row and its original timestamp', () {
    final events = <Map<String, dynamic>>[{'event': 'doorbell'}];
    final first = DateTime(2026, 10, 23, 12);
    expect(updateInterpretation(events, '수도 안내가 있습니다.', false, now: first), isTrue);
    expect(updateInterpretation(events, '수도 안내가 있습니다. ', false, now: first.add(const Duration(minutes: 1))), isFalse);
    expect(events.length, 2);
    expect(events.first['_receivedAt'], first.toIso8601String());
    updateInterpretation(events, '수도 안내를 확인하세요.', false);
    expect(events.length, 2);
    expect(events.first['reply'], '수도 안내를 확인하세요.');
    expect(events.last['event'], 'doorbell');
  });

  test('sign questions do not replace the household interpretation', () {
    final events = <Map<String, dynamic>>[];
    updateInterpretation(events, '가정 내 상태를 확인하세요.', false);
    updateInterpretation(events, '어디가 아프신가요?', true);
    updateInterpretation(events, '누구에게 도움이 필요한가요?', true);
    expect(events.length, 2);
    expect(events.where((e) => e['sign'] == false).single['reply'], '가정 내 상태를 확인하세요.');
  });
}
