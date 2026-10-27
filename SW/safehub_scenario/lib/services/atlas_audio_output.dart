import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// ATLAS's bundled GStreamer/PulseAudio path avoids blocking native plugin RPCs.
class AtlasAudioOutput {
  AtlasAudioOutput({this.startProcess = Process.start});
  final Future<Process> Function(String, List<String>) startProcess;
  Process? _process;
  int _generation = 0;
  bool _disposed = false;

  Future<void> playFile(String path) async {
    if (_disposed) throw StateError('Audio output disposed');
    await stop();
    final generation = _generation;
    final process = await startProcess('/usr/bin/gst-launch-1.0', [
      '-m', 'filesrc', 'location=$path', '!', 'decodebin', '!',
      'audioconvert', '!', 'audioresample', '!', 'pulsesink',
      'client-name=SafeHub speech',
    ]);
    if (_disposed || generation != _generation) {
      process.kill();
      return;
    }
    _process = process;
    final ready = Completer<void>();
    final errors = StringBuffer();
    final output = process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      if (!ready.isCompleted &&
          (line.contains('New clock:') || line.contains('new-state=(GstState)playing'))) ready.complete();
    });
    final errorOutput = process.stderr.transform(utf8.decoder).listen((text) {
      if (errors.length < 1500) errors.write(text);
    });
    unawaited(process.exitCode.then((code) {
      if (identical(_process, process)) _process = null;
      if (!ready.isCompleted) {
        ready.completeError(StateError('Audio pipeline exited before playback ($code): $errors'));
      }
      unawaited(output.cancel());
      unawaited(errorOutput.cancel());
    }));
    try {
      await ready.future.timeout(const Duration(seconds: 3));
    } catch (_) {
      if (identical(_process, process)) {
        process.kill();
        _process = null;
      }
      rethrow;
    }
  }

  Future<void> stop() async {
    _generation++;
    final process = _process;
    _process = null;
    if (process == null) return;
    process.kill();
    try { await process.exitCode.timeout(const Duration(seconds: 1)); }
    on TimeoutException { process.kill(ProcessSignal.sigkill); }
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
  }
}
