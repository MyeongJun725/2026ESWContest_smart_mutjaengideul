import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:safehub_app/services/atlas_audio_output.dart';

class TestProcess extends Fake implements Process {
  final output = StreamController<List<int>>();
  final errors = StreamController<List<int>>();
  final exit = Completer<int>();
  int killed = 0;
  @override Stream<List<int>> get stdout => output.stream;
  @override Stream<List<int>> get stderr => errors.stream;
  @override Future<int> get exitCode => exit.future;
  @override bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed++;
    if (!exit.isCompleted) exit.complete(0);
    return true;
  }
}

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  test('starts the file as one literal argument and waits for playback', () async {
    final process = TestProcess();
    final player = AtlasAudioOutput(startProcess: (program, args) async {
      expect(program, '/usr/bin/gst-launch-1.0');
      expect(args, contains('location=/tmp/a file.mp3'));
      return process;
    });
    final ready = player.playFile('/tmp/a file.mp3');
    await tick();
    process.output.add('New clock: GstPulseSinkClock\n'.codeUnits);
    await ready;
    await player.stop();
    expect(process.killed, 1);
    await player.dispose();
  });

  test('an unavailable sink reports failure instead of success', () async {
    final process = TestProcess();
    final player = AtlasAudioOutput(startProcess: (_, __) async => process);
    final ready = player.playFile('/tmp/file.mp3');
    final expectation = expectLater(ready, throwsStateError);
    await tick();
    process.errors.add('sink unavailable'.codeUnits);
    process.exit.complete(1);
    await expectation;
    await player.dispose();
  });

  test('cancelling while process creation is pending kills the stale child', () async {
    final pending = Completer<Process>();
    final process = TestProcess();
    final player = AtlasAudioOutput(startProcess: (_, __) => pending.future);
    final ready = player.playFile('/tmp/file.mp3');
    await tick();
    await player.stop();
    pending.complete(process);
    await ready;
    expect(process.killed, 1);
    await player.dispose();
  });
}
