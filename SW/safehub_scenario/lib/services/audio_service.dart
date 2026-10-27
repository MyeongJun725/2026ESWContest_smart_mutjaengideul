import 'dart:typed_data';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'atlas_audio_output.dart';

class AudioService {
  AudioService({
    AudioPlayer? player,
    this.operationTimeout = const Duration(seconds: 5),
    bool? localFilePlayback,
  }) : assert(operationTimeout > Duration.zero),
       _localFilePlayback = localFilePlayback ?? (!kIsWeb && (Platform.isLinux || Platform.operatingSystem == 'atlas')),
       _player = player;

  AudioPlayer? _player;
  bool _disposed = false;
  final Duration operationTimeout;
  final bool _localFilePlayback;
  Directory? _audioDirectory;
  File? _audioFile;
  AtlasAudioOutput? _atlasOutput;
  bool get _useAtlasOutput => !kIsWeb && _player == null &&
      File('/data/share/safehub-tools/parecord').existsSync() &&
      File('/usr/bin/gst-launch-1.0').existsSync();

  Future<File> _writeAudioFile(Uint8List bytes, String mimeType) async {
    await _removeAudioFile();
    _audioDirectory ??= await Directory.systemTemp.createTemp('safehub-audio-');
    _audioFile = File('${_audioDirectory!.path}/speech.${mimeType == 'audio/wav' ? 'wav' : 'mp3'}');
    await _audioFile!.writeAsBytes(bytes, flush: true);
    return _audioFile!;
  }

  AudioPlayer get _activePlayer {
    if (_disposed) throw StateError('AudioService is disposed');
    return _player ??= AudioPlayer();
  }

  Future<void> playBytes(
    Uint8List bytes, {
    String mimeType = 'audio/mpeg',
  }) async {
    if (_disposed) throw StateError('AudioService is disposed');
    if (_useAtlasOutput) {
      final output = _atlasOutput ??= AtlasAudioOutput();
      await output.stop();
      final file = await _writeAudioFile(bytes, mimeType);
      if (_disposed) throw StateError('AudioService is disposed');
      await output.playFile(file.path);
      return;
    }
    final player = _activePlayer;
    await player.stop().timeout(operationTimeout);
    if (_disposed) throw StateError('AudioService is disposed');

    Source source = BytesSource(bytes, mimeType: mimeType);
    if (_localFilePlayback) {
      // ATLAS has no path_provider plugin. Supply a real file directly instead
      // of BytesSource's desktop getTemporaryDirectory() fallback.
      final file = await _writeAudioFile(bytes, mimeType);
      source = DeviceFileSource(file.path, mimeType: mimeType);
      if (_disposed) { await _removeAudioFile(); throw StateError('AudioService is disposed'); }
    }

    await player
        .play(source)
        .timeout(operationTimeout);
  }

  Future<void> playUrl(String url) async {
    if (url.trim().isEmpty) {
      return;
    }

    final player = _activePlayer;
    await player.stop().timeout(operationTimeout);
    if (_disposed) throw StateError('AudioService is disposed');
    await _removeAudioFile();
    await player.play(UrlSource(url)).timeout(operationTimeout);
  }

  Future<void> stop() async {
    await _atlasOutput?.stop();
    await _player?.stop().timeout(operationTimeout);
    await _removeAudioFile();
  }

  Future<void> _removeAudioFile() async {
    final file = _audioFile;
    _audioFile = null;
    if (file != null && await file.exists()) await file.delete();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final player = _player;
    _player = null;
    try {
      await _atlasOutput?.dispose();
      await player?.dispose().timeout(operationTimeout);
    } finally {
      await _removeAudioFile();
      final directory = _audioDirectory;
      _audioDirectory = null;
      if (directory != null && await directory.exists()) await directory.delete();
    }
  }
}
