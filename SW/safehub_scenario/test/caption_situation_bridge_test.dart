import 'package:flutter_test/flutter_test.dart';
import 'package:safehub_app/services/caption_connection.dart';
import 'package:safehub_app/services/live_caption_service.dart';
import 'caption_stream_test.dart' show FakeConnection;
import 'live_caption_service_test.dart' show FakeMicrophone;

void main() {
  test('only one finalized utterance reaches situation analysis, not partials or obsolete epochs', () async {
    final connection = FakeConnection();
    final finals = <String>[];
    final service = LiveCaptionService(
      microphone: FakeMicrophone(), connectStream: () async => connection,
      transcribe: (_) async => '', onFinalText: finals.add,
    );
    await service.start();
    connection.controller.add(const CaptionResult(0, '화', false, 0));
    expect(finals, isEmpty);
    expect(service.draftText, '화');
    connection.controller.add(const CaptionResult(0, '화재 안내', true, 0));
    connection.controller.add(const CaptionResult(0, '화재 안내', true, 0));
    expect(finals, ['화재 안내']);
    expect(service.draftText, isEmpty);
    service.clear();
    connection.controller.add(const CaptionResult(1, '이전 자막', true, 0));
    expect(finals, ['화재 안내']);
    connection.controller.add(CaptionResult(1, '새 안내', true, connection.epoch));
    expect(finals, ['화재 안내', '새 안내']);
    await service.close();
  });
}
