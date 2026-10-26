import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:safehub_app/services/situation_service.dart';

class CaptureClient extends http.BaseClient {
  final inner = http.Client();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await inner.send(request);
    final bytes = await response.stream.toBytes();
    final directory = Platform.environment['SAFEHUB_LIVE_RESULT_DIR'];
    if (directory != null) {
      await File('$directory/fasttext-live-response.json').writeAsBytes(bytes);
    }
    return http.StreamedResponse(
      Stream.value(bytes),
      response.statusCode,
      headers: response.headers,
      request: response.request,
    );
  }

  @override
  void close() => inner.close();
}

void main() {
  test(
    'real fastText service supplies a non-generative context reply',
    () async {
      final health = jsonDecode(
        (await http.get(Uri.parse('http://127.0.0.1:9380/health'))).body,
      );
      expect(health['engine'], 'fasttext');
      expect(health['llm'], isFalse);
      final service = SituationService(clientFactory: CaptureClient.new);
      addTearDown(service.dispose);
      service.addEvidence(
        '확정 음성자막',
        '관리사무소 안내입니다. 지금은 화재 대피 훈련 중이며 실제 화재는 발생하지 않았습니다.',
        analyze: false,
      );
      final timer = Stopwatch()..start();
      await service.analyze();
      final result = service.assessment;
      final directory = Platform.environment['SAFEHUB_LIVE_RESULT_DIR'];
      if (directory != null) {
        await File('$directory/fasttext-live-result.json').writeAsString(
          jsonEncode({
            'elapsed_ms': timer.elapsedMilliseconds,
            'status': service.status,
            'model': service.settings.model,
            'endpoint': service.settings.endpoint,
            'assessment_valid': result != null,
            'title': result?.title,
            'summary': result?.summary,
            'is_drill': result?.isDrill,
            'urgency': result?.urgency,
            'announcement_opened': service.announcement != null,
            'test_input_only': true,
          }),
        );
      }
      expect(result, isNotNull, reason: service.status);
      expect(result!.summary, isNotEmpty);
      expect(service.announcement, isNull);
    },
    skip: Platform.environment['SAFEHUB_LIVE_FASTTEXT_TEST'] != '1',
  );
}
