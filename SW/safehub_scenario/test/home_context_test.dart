import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safehub_app/services/situation_service.dart';
import 'fast_situation_test.dart' show answer;

void main() {
  test(
    'AI interpretation never rewrites speech, even if a server supplies a caption',
    () async {
      final pending = Completer<http.Response>();
      final service = SituationService(
        clientFactory:
            () => MockClient((request) {
              final body = jsonDecode(request.body);
              expect(body['stream'], false);
              expect(
                jsonDecode(body['messages'][1]['content'])['task'],
                '집 안 화면 상태 분석',
              );
              return pending.future;
            }),
      );
      addTearDown(service.dispose);
      service.addEvidence('확정 음성자막', '안녕 하세요.', analyze: false);
      final request = service.analyze();
      expect(service.finalCaptions, ['안녕 하세요.']);
      pending.complete(answer('인사를 나누고 있습니다.', caption: '안녕하세요.'));
      await request;
      expect(service.finalCaptions, ['안녕 하세요.']);
      expect(service.assessment!.summary, '인사를 나누고 있습니다.');
    },
  );

  test(
    'automatic context contains camera, alarm, disaster and events without image bytes',
    () async {
      final done = Completer<void>();
      final service = SituationService(
        debounce: Duration.zero,
        clientFactory:
            () => MockClient((request) async {
              final data = jsonDecode(
                jsonDecode(request.body)['messages'][1]['content'],
              );
              final context = jsonDecode(data['selected_context']);
              expect(context['camera'], '연결 끊김');
              expect(context['active_alarm'], '재난 경보');
              expect(context['disaster']['issued_at'], '2026-10-23 10:00');
              expect(context['events'], isNotEmpty);
              expect(context['sensor'], '재실·활동 미확인');
              expect(data.containsKey('scene_image'), isFalse);
              done.complete();
              return answer('재난 알림 내용을 확인해 주세요.');
            }),
      );
      addTearDown(service.dispose);
      service.setHomeContext({
        'camera': '연결 끊김',
        'active_alarm': '재난 경보',
        'disaster': {'issued_at': '2026-10-23 10:00'},
        'events': ['초인종'],
      });
      await done.future;
    },
  );

  test(
    'clear during inference discards late caption and history callback',
    () async {
      final pending = Completer<http.Response>();
      var history = 0;
      final service = SituationService(
        clientFactory: () => MockClient((_) => pending.future),
      );
      addTearDown(service.dispose);
      service.onConversation = (_, __, ___) => history++;
      service.addEvidence('확정 음성자막', '삭제할 문장입니다.', analyze: false);
      final request = service.analyze();
      service.clearCaptions();
      pending.complete(answer('대화 중입니다.', caption: '삭제할 문장입니다.'));
      await request;
      expect(service.finalCaptions, isEmpty);
      expect(service.evidence, isEmpty);
      expect(history, 0);
    },
  );

  test(
    'failed AI analysis leaves the immediately displayed original readable',
    () async {
      final service = SituationService(
        clientFactory:
            () => MockClient((_) async => http.Response('offline', 503)),
      );
      addTearDown(service.dispose);
      service.addEvidence('확정 음성자막', '안녕 하세요.', analyze: false);
      expect(service.finalCaptionText, '안녕 하세요.');
      await service.analyze();
      expect(service.finalCaptionText, '안녕 하세요.');
    },
  );

  test(
    'speech arriving during analysis is processed next with no parallel request',
    () async {
      final first = Completer<http.Response>();
      var calls = 0;
      final service = SituationService(
        debounce: const Duration(days: 1),
        clientFactory:
            () => MockClient((r) async {
              calls++;
              final data = jsonDecode(
                jsonDecode(r.body)['messages'][1]['content'],
              );
              if (calls == 1) return first.future;
              expect(data['selected_context'], contains('두 번째 문장입니다.'));
              expect(data['source'], isEmpty);
              return answer('두 번째 대화입니다.', caption: '두 번째 문장입니다.');
            }),
      );
      addTearDown(service.dispose);
      service.addEvidence('확정 음성자막', '첫 번째 문장입니다.', analyze: false);
      final request = service.analyze();
      await Future<void>.delayed(Duration.zero);
      service.addEvidence('확정 음성자막', '두 번째 문장입니다.');
      expect(calls, 1);
      first.complete(answer('첫 대화입니다.', caption: '첫 번째 문장입니다.'));
      await request;
      await service.analyze();
      expect(calls, 2);
      expect(service.finalCaptions, ['첫 번째 문장입니다.', '두 번째 문장입니다.']);
    },
  );
}
