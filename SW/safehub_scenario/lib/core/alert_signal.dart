import 'dart:math';

/// Existing config/topics.json payloads; no new device protocol is introduced.
class AlertSignal {
  static final _random = Random.secure();
  static String _uuid() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static Map<String, dynamic> payload(
    String device,
    String action, {
    int duration = 10,
  }) {
    if (!['led', 'bedshaker'].contains(device) ||
        action.isEmpty ||
        (device == 'bedshaker' && !['on', 'off'].contains(action))) {
      throw ArgumentError('Unsupported actuator command');
    }
    return {
      'message_id': _uuid(),
      'device': 'rpi5_hub',
      'event': '${device}_command',
      'action': action,
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      if (device == 'bedshaker')
        'duration_sec': action == 'off' ? 0 : duration.clamp(1, 10),
    };
  }
}
