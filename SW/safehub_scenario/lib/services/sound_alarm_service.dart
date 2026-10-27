import 'dart:convert';
import 'package:http/http.dart' as http;

class SoundAlarmEvent {
  const SoundAlarmEvent(this.id, this.label);
  final String id, label;
}

class SoundAlarmState {
  const SoundAlarmState(this.status, [this.event]);
  final String status;
  final SoundAlarmEvent? event;
}

class SoundAlarmService {
  SoundAlarmService({required this.uri, http.Client? client})
      : _client = client ?? http.Client();
  final Uri uri;
  final http.Client _client;
  DateTime _notBefore = DateTime.now();
  bool _listening = false;
  bool _closed = false;

  Future<SoundAlarmState> poll({required bool listening}) async {
    if (_closed) return const SoundAlarmState('경보음 감지 종료');
    if (!listening) {
      _listening = false;
      return const SoundAlarmState('마이크 일시정지 · 경보음 감지도 중지');
    }
    if (!_listening) _notBefore = DateTime.now();
    _listening = true;
    try {
      final response =
          await _client.get(uri).timeout(const Duration(milliseconds: 800));
      if (_closed || response.statusCode != 200) throw const FormatException();
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final age = data['audio_age_seconds'];
      if (data['engine'] != 'yamnet' || data['ready'] != true)
        throw const FormatException();
      if (age is! num || !age.isFinite || age < 0 || age > 2) {
        return const SoundAlarmState('YAMNet 준비됨 · 마이크 소리 수신 대기');
      }
      final event = data['event'];
      final eventAge = data['event_age_seconds'];
      if (event is Map &&
          event['source'] == 'yamnet' &&
          event['id'] is String &&
          (event['id'] as String).startsWith('yamnet:') &&
          {
            'Fire alarm',
            'Smoke detector, smoke alarm',
            'Civil defense siren',
            'Siren',
            'Police car (siren)',
            'Ambulance (siren)',
            'Fire engine, fire truck (siren)',
          }.contains(event['label']) &&
          event['score'] is num &&
          (event['score'] as num).isFinite &&
          (event['score'] as num) >= 0 &&
          (event['score'] as num) <= 1 &&
          event['confirmations'] is int &&
          event['confirmations'] >= 2 &&
          event['stream_generation'] == data['stream_resets'] &&
          eventAge is num &&
          eventAge.isFinite &&
          eventAge >= 0 &&
          eventAge <= 4 &&
          event['timestamp'] is num) {
        final stamp = event['timestamp'] as num;
        if (stamp.isFinite &&
            stamp >= _notBefore.millisecondsSinceEpoch / 1000 &&
            stamp <= DateTime.now().millisecondsSinceEpoch / 1000 + 5) {
          return SoundAlarmState('경보음 감지 중 · YAMNet',
              SoundAlarmEvent(event['id'] as String, event['label'] as String));
        }
      }
      final top = data['top'];
      final label = top is List && top.isNotEmpty && top.first is Map
          ? (top.first as Map)['label'] : null;
      final observed = switch (label) {
        'Speech' || 'Conversation' || 'Narration, monologue' => '현재 음성으로 분류 중',
        'Music' => '현재 음악으로 분류 중',
        'Silence' => '마이크 소리 대기',
        _ => '주변 소리 분석 중',
      };
      return SoundAlarmState('YAMNet · $observed');
    } catch (_) {
      return const SoundAlarmState('경보음 서버 연결 확인 필요 · 음성자막은 계속 작동');
    }
  }

  void dispose() {
    _closed = true;
    _client.close();
  }
}
