import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safehub_app/core/house_scenario.dart';
import 'package:safehub_app/services/sound_alarm_service.dart';
import 'package:safehub_app/services/situation_service.dart';

Map<String, dynamic> event({String label = 'Fire alarm', double? stamp}) => {
      'id': 'yamnet:test:1',
      'source': 'yamnet',
      'label': label,
      'score': .8,
      'confirmations': 2,
      'stream_generation': 1,
      'timestamp': stamp ?? DateTime.now().millisecondsSinceEpoch / 1000,
    };
http.Response response(Map<String, dynamic>? alarm) => http.Response(
    jsonEncode({
      'engine': 'yamnet',
      'ready': true,
      'audio_age_seconds': .1,
      'stream_resets': 1,
      'event_age_seconds': .1,
      'event': alarm,
    }),
    200);

void main() {
  test('fresh alarm creates an independent alert without any caption or LLM',
      () async {
    final sound = SoundAlarmService(
        uri: Uri.parse('http://127.0.0.1:9381/state'),
        client: MockClient((_) async => response(event())));
    final situation =
        SituationService(settings: SituationSettings(enabled: false));
    addTearDown(sound.dispose);
    addTearDown(situation.dispose);
    var calls = 0;
    situation.onScenarioAlert = () => calls++;
    final state = await sound.poll(listening: true);
    expect(state.event, isNotNull);
    situation.observeSoundAlarm(state.event!.id, state.event!.label);
    situation.observeSoundAlarm(state.event!.id, state.event!.label);
    expect(calls, 1);
    expect(situation.liveFlow.active!.origin, 'sound');
    expect(situation.finalCaptions, isEmpty);
  });

  test('past event and a ringtone never become fire alarms', () async {
    var old = true;
    final sound = SoundAlarmService(
        uri: Uri.parse('http://127.0.0.1:9381/state'),
        client: MockClient((_) async => response(old
            ? event(stamp: DateTime.now().millisecondsSinceEpoch / 1000 - 10)
            : event(label: 'Ringtone'))));
    addTearDown(sound.dispose);
    expect((await sound.poll(listening: true)).event, isNull);
    old = false;
    expect((await sound.poll(listening: true)).event, isNull);
    expect((await sound.poll(listening: false)).status, contains('감지도 중지'));
  });

  test('detector outage is a status, not an exception in the caption UI',
      () async {
    final sound = SoundAlarmService(
        uri: Uri.parse('http://127.0.0.1:9381/state'),
        client: MockClient((_) async => http.Response('offline', 503)));
    addTearDown(sound.dispose);
    expect((await sound.poll(listening: true)).status, contains('음성자막은 계속'));
  });

  test('sound and text reinforce one alert without a second popup or pulse',
      () {
    final situation =
        SituationService(settings: SituationSettings(enabled: false));
    addTearDown(situation.dispose);
    var calls = 0;
    situation.onScenarioAlert = () => calls++;
    situation.observeBroadcast('화재가 발생했습니다. 대피하세요.');
    situation.observeSoundAlarm('yamnet:test:1', 'Fire alarm');
    situation.observeSoundAlarm('yamnet:test:2', 'Fire alarm');
    expect(calls, 1);
    expect(situation.liveFlow.pendingCount, 0);
    expect(situation.liveFlow.active!.evidence, contains('YAMNet'));
    expect(situation.liveFlow.active!.evidence, contains('화재가 발생했습니다'));
  });
}
