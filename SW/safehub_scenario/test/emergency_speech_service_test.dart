import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safehub_app/core/house_scenario.dart';
import 'package:safehub_app/services/emergency_speech_service.dart';
import 'package:safehub_app/services/situation_service.dart';

Future<void> settle() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

HouseIncident incident(HouseScenario kind,
        {String origin = 'text', int time = 1}) =>
    HouseIncident(
        'case', kind, 'evidence', DateTime.fromMillisecondsSinceEpoch(time),
        origin: origin);

void main() {
  late EmergencySpeechService speech;
  late List<EmergencyVoice> loads;
  late List<int> plays;
  late List<String> status;
  late int stops;
  setUp(() {
    loads = [];
    plays = [];
    status = [];
    stops = 0;
    speech = EmergencySpeechService(
      load: (voice) async {
        loads.add(voice);
        return Uint8List.fromList([voice.index]);
      },
      play: (bytes) async => plays.add(bytes.single),
      stop: () async {
        stops++;
      },
      onStatus: status.add,
    );
  });
  tearDown(() => speech.dispose());

  test('four alert sources select separate bundled prompts', () async {
    for (final item in [
      incident(HouseScenario.broadcast),
      incident(HouseScenario.broadcast, origin: 'sound', time: 2),
      incident(HouseScenario.disaster),
      incident(HouseScenario.assistance)
    ]) {
      speech.update(item, enabled: true);
      await settle();
    }
    expect(loads, EmergencyVoice.values.take(4));
    expect(plays, [0, 1, 2, 3]);
    expect(stops, 4);
  });

  test('ordinary status and evidence updates do not replay the same alert',
      () async {
    final item = incident(HouseScenario.broadcast);
    for (var i = 0; i < 50; i++) speech.update(item, enabled: true);
    await settle();
    expect(plays, [0]);
  });

  test('screen-only test produces no physical sound', () async {
    speech.update(incident(HouseScenario.broadcast), enabled: false);
    await settle();
    expect(loads, isEmpty);
    expect(plays, isEmpty);
    expect(stops, 0);
  });

  test('acknowledgement cancels a pending load before playback', () async {
    final pending = Completer<Uint8List>();
    speech.dispose();
    speech = EmergencySpeechService(
        load: (_) => pending.future,
        play: (bytes) async => plays.add(bytes.single),
        stop: () async {
          stops++;
        },
        onStatus: status.add);
    speech.update(incident(HouseScenario.broadcast), enabled: true);
    await settle();
    speech.update(null, enabled: true);
    pending.complete(Uint8List.fromList([7]));
    await settle();
    expect(plays, isEmpty);
    expect(stops, 2);
  });

  test(
      'higher priority incident discards old audio and returning does not repeat it',
      () async {
    final pending = Completer<Uint8List>();
    speech.dispose();
    speech = EmergencySpeechService(
        load: (voice) => voice == EmergencyVoice.broadcast
            ? pending.future
            : Future.value(Uint8List.fromList([3])),
        play: (bytes) async => plays.add(bytes.single),
        stop: () async {},
        onStatus: status.add);
    final first = incident(HouseScenario.broadcast);
    speech.update(first, enabled: true);
    await settle();
    speech.update(incident(HouseScenario.assistance), enabled: true);
    await settle();
    pending.complete(Uint8List.fromList([0]));
    await settle();
    speech.update(first, enabled: true);
    await settle();
    expect(plays, [3]);
  });

  test('manual replay uses cache and a new test run is announced', () async {
    final item = incident(HouseScenario.broadcast);
    speech.update(item, enabled: true);
    await settle();
    speech.repeat(item);
    await settle();
    speech.update(incident(HouseScenario.broadcast, time: 2), enabled: true);
    await settle();
    expect(plays, [0, 0, 0]);
    expect(loads, [EmergencyVoice.broadcast]);
  });

  test('audio failure is reported as failure and the next alert still plays',
      () async {
    speech.dispose();
    speech = EmergencySpeechService(
        load: (voice) async => Uint8List.fromList([voice.index]),
        play: (bytes) async {
          if (bytes.single == 0) throw StateError('player');
          plays.add(bytes.single);
        },
        stop: () async {},
        onStatus: status.add);
    speech.update(incident(HouseScenario.broadcast), enabled: true);
    await settle();
    expect(status.last, contains('실패'));
    speech.update(incident(HouseScenario.disaster), enabled: true);
    await settle();
    expect(plays, [2]);
  });

  test('dispose discards an unfinished request', () async {
    final pending = Completer<Uint8List>();
    speech.dispose();
    speech = EmergencySpeechService(
        load: (_) => pending.future,
        play: (bytes) async => plays.add(1),
        stop: () async {},
        onStatus: status.add);
    speech.update(incident(HouseScenario.broadcast), enabled: true);
    await settle();
    speech.dispose();
    pending.complete(Uint8List.fromList([1]));
    await settle();
    expect(plays, isEmpty);
  });

  test(
      'live STT, sound, API and CSI events reach speech; screen test is silent',
      () async {
    final service =
        SituationService(settings: SituationSettings(enabled: false));
    void sync() => speech.update(service.flow.active,
        enabled: !service.scenarioTestMode || service.scenarioActuators);
    service.addListener(sync);
    addTearDown(service.dispose);
    service.startScenarioTest(HouseScenario.broadcast, '화재가 발생했습니다.',
        actuate: false);
    await settle();
    expect(plays, isEmpty);
    service.endScenarioTest();
    service.addEvidence('확정 음성자막', '화재가 발생했습니다. 대피하세요.', analyze: false);
    await settle();
    service.acknowledge();
    service.observeSoundAlarm('siren', 'Siren');
    await settle();
    service.acknowledge();
    service.observeDisaster(
        id: 'api', text: '지진', region: '전국', issuedAt: DateTime.now());
    await settle();
    service.acknowledge();
    service.observeFall('csi', '낙상 의심');
    await settle();
    service.acknowledge();
    expect(plays, [0, 1, 2, 4]);
  });

  test('spoken prompts cannot trigger the fire text rule themselves', () {
    for (final voice in EmergencyVoice.values) {
      final flow = HouseScenarioFlow();
      expect(flow.broadcast(EmergencySpeechService.textFor(voice)), isFalse);
      flow.dispose();
    }
  });
}
