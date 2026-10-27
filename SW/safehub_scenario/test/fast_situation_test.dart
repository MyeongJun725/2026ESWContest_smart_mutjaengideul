import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safehub_app/services/situation_service.dart';

http.Response answer(String text, {String caption = ''}) => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'choices': [
        {
          'message': {
            'content': jsonEncode({'reply': text, 'caption': caption}),
          },
        },
      ],
    }),
  ),
  200,
);

void main() {
  test(
    'fast server contract publishes actual source and interpretation without alarm',
    () async {
      late Map<String, dynamic> request;
      final events = <List<Object>>[];
      final service = SituationService(
        clientFactory: () => MockClient((r) async {
          expect(r.url.port, 9380);
          request = jsonDecode(jsonDecode(r.body)['messages'][1]['content']);
          return answer('화재가 발생했다는 안내입니다.', caption: '화재가 발생했습니다.');
        }),
      );
      addTearDown(service.dispose);
      service.onConversation = (source, reply, sign) =>
          events.add([source, reply, sign]);
      service.addEvidence('확정 음성자막', '화재가 발생했습니다.', analyze: false);
      await service.analyze();
      expect(request['task'], '집 안 화면 상태 분석');
      expect(request['selected_context'], contains('화재가 발생했습니다.'));
      expect(request['source'], isEmpty);
      expect(events.single[1], '화재가 발생했다는 안내입니다.');
      expect(events.single[0], isEmpty);
      expect(service.finalCaptions.single, '화재가 발생했습니다.');
      expect(service.announcement, isNull);
      expect(service.assessment!.urgency, 'review');
    },
  );

  test(
    'confirmed sign produces contextual question even without speech',
    () async {
      final service = SituationService(
        debounce: const Duration(days: 1),
        clientFactory: () => MockClient((r) async {
          final input = jsonDecode(
            jsonDecode(r.body)['messages'][1]['content'],
          );
          expect(input['task'], '선택한 문맥에 맞춰 수어에 응답');
          expect(input['source'], '감사');
          return answer('함께 있어 주셔서 고맙습니다.');
        }),
      );
      addTearDown(service.dispose);
      // Help/pain signs open the immediate safety UI; use a conversational sign here.
      service.receiveSign('감사');
      service.confirmSign();
      await service.analyze();
      expect(service.signQuestion, '함께 있어 주셔서 고맙습니다.');
    },
  );

  test('new sign discards a late question', () async {
    final result = Completer<http.Response>();
    final service = SituationService(
      clientFactory: () => MockClient((_) => result.future),
    );
    addTearDown(service.dispose);
    service.receiveSign('감사');
    service.confirmSign();
    final pending = service.analyze();
    service.receiveSign('괜찮아');
    result.complete(answer('어디가 아프신가요?'));
    await pending;
    expect(service.signQuestion, isEmpty);
  });

  test('invalid fast reply never enters conversation history', () async {
    final service = SituationService(
      clientFactory: () => MockClient((_) async => answer('')),
    );
    addTearDown(service.dispose);
    var count = 0;
    service.onConversation = (_, __, ___) => count++;
    service.addEvidence('확정 음성자막', '안녕하세요', analyze: false);
    await service.analyze();
    expect(count, 0);
    expect(service.status, contains('실패'));
  });
}
