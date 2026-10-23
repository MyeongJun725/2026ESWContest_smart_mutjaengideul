import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safehub_app/services/situation_service.dart';
import 'fast_situation_test.dart' show answer;

void main() {
  test(
    'ongoing speech never discards the in-flight answer or erases it while waiting',
    () async {
      final first = Completer<http.Response>();
      var calls = 0;
      final service = SituationService(
        debounce: const Duration(days: 1),
        clientFactory:
            () => MockClient((request) {
              calls++;
              if (calls == 1) return first.future;
              final input = jsonDecode(
                jsonDecode(request.body)['messages'][1]['content'],
              );
              expect(input['source'], '내일은 어때? 비가 오나?');
              return Future.value(answer('내일 날씨 정보는 아직 없어요.'));
            }),
      );
      addTearDown(service.dispose);
      service.toggleVoiceChat();
      service.addEvidence('확정 음성자막', '지금 무슨 상황이야?', analyze: false);
      final request = service.analyze();
      await Future<void>.delayed(Duration.zero);
      service.addEvidence('확정 음성자막', '내일은 어때?');
      service.addEvidence('확정 음성자막', '비가 오나?');
      first.complete(answer('현재 접수된 경보는 없어요.'));
      await request;
      expect(service.voiceReply, '현재 접수된 경보는 없어요.');
      expect(service.voiceQuestion, '지금 무슨 상황이야?');
      expect(calls, 1);
      await service.analyze();
      expect(service.voiceReply, '내일 날씨 정보는 아직 없어요.');
      expect(calls, 2);
    },
  );
  test(
    'wake word routes a question with context and preserves raw subtitles',
    () async {
      final service = SituationService(
        debounce: const Duration(days: 1),
        clientFactory:
            () => MockClient((request) async {
              final input = jsonDecode(
                jsonDecode(request.body)['messages'][1]['content'],
              );
              expect(input['task'], '집 안 정보로 음성 질문에 답변');
              expect(input['source'], '지금 무슨 상황이야?');
              expect(input['selected_context'], contains('초인종'));
              return answer('초인종이 울렸어요. 방문자를 확인하시겠어요?');
            }),
      );
      addTearDown(service.dispose);
      service.setHomeContext({'active_alarm': '초인종'});
      service.addEvidence('확정 음성자막', '세이프 허브, 지금 무슨 상황이야?', analyze: false);
      await service.analyze();
      expect(service.voiceChatEnabled, isTrue);
      expect(service.voiceReply, contains('초인종'));
      expect(service.finalCaptions.single, '세이프 허브, 지금 무슨 상황이야?');
    },
  );

  test(
    'follow-up uses bounded conversation and off ignores delayed answers',
    () async {
      final pending = Completer<http.Response>();
      var calls = 0;
      final service = SituationService(
        debounce: const Duration(days: 1),
        clientFactory:
            () => MockClient((request) async {
              calls++;
              if (calls == 1) return answer('방문자를 확인하시겠어요?');
              final input = jsonDecode(
                jsonDecode(request.body)['messages'][1]['content'],
              );
              expect(input['source'], '어떻게 확인해?');
              expect(input['selected_context'], contains('방문자를 확인하시겠어요?'));
              return pending.future;
            }),
      );
      addTearDown(service.dispose);
      service.toggleVoiceChat();
      service.addEvidence('확정 음성자막', '무슨 소식이야?', analyze: false);
      await service.analyze();
      service.addEvidence('확정 음성자막', '어떻게 확인해?', analyze: false);
      final request = service.analyze();
      await Future<void>.delayed(Duration.zero);
      service.toggleVoiceChat();
      pending.complete(answer('인터폰을 확인해 주세요.'));
      await request;
      expect(service.voiceReply, isEmpty);
      expect(service.voiceChatEnabled, isFalse);
      expect(service.finalCaptions.length, 2);
    },
  );

  test(
    'ordinary speech remains a household observation, not an AI question',
    () async {
      final service = SituationService(
        clientFactory:
            () => MockClient((request) async {
              final input = jsonDecode(
                jsonDecode(request.body)['messages'][1]['content'],
              );
              expect(input['task'], '집 안 화면 상태 분석');
              return answer('가족과 대화하고 있어요.');
            }),
      );
      addTearDown(service.dispose);
      service.addEvidence('확정 음성자막', '오늘 저녁에 방문할게.', analyze: false);
      await service.analyze();
      expect(service.voiceQuestion, isEmpty);
      expect(service.voiceChatEnabled, isFalse);
    },
  );
}
