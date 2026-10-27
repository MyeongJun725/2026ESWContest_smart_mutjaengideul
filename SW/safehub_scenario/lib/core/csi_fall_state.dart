class CsiFallState {
  CsiFallState._(this.headline, this.detail, this.modelReady, this.fallScore, this.event);
  final String headline, detail;
  final bool modelReady;
  final double? fallScore;
  final Map<String, dynamic>? event;
  static const fallLabels = {'낙상', '쓰러짐', '쓰러지다'};
  static bool supportsFall(dynamic model) {
    final labels = model is Map ? model['labels'] : null;
    return labels is List && labels.any(fallLabels.contains) &&
        labels.any((label) => !fallLabels.contains(label));
  }

  factory CsiFallState.fromState(Map<String, dynamic>? state, {DateTime? now}) {
    final ready = supportsFall(state?['model']);
    CsiFallState waiting(String title, String detail) => CsiFallState._(title, detail, ready, null, null);
    if (state == null || state['connected'] != true || state['fresh'] != true) {
      return waiting('CSI 신호 대기', '수신기 연결과 새 신호를 확인해 주세요. 낙상 여부를 판단할 수 없습니다.');
    }
    if (state['mode'] != 'live' || state['dummy_allowed'] != false) {
      return waiting('실측 신호 연결 필요', '모의 신호에서는 낙상 경고를 발생시키지 않습니다.');
    }
    if (!ready) return waiting('낙상 모델 학습 필요', '낙상과 일상 동작으로 학습한 모델을 PC에서 가져오세요.');
    if ((state['recognition'] as Map?)?['running'] != true) {
      return waiting('낙상 감지 중지', '낙상 감지를 시작하면 평소에는 대기하고 의심 신호에만 경고합니다.');
    }
    final fall = state['fall_detection'];
    if (fall is! Map) return waiting('CSI 서비스 업데이트 필요', '낙상 경고 정책을 지원하는 수집 서비스를 사용하세요.');
    Map<String, dynamic>? event;
    final raw = fall['event'];
    if (fall['status'] == 'detected' && raw is Map<String, dynamic> &&
        raw['event'] == 'fall_detected' && raw['message_id'] is String &&
        (raw['message_id'] as String).isNotEmpty && raw['timestamp'] is num &&
        (raw['timestamp'] as num).isFinite && raw['confidence'] is num &&
        (raw['confidence'] as num).isFinite && raw['confidence'] >= 0 && raw['confidence'] <= 1) {
      final age = (now ?? DateTime.now()).millisecondsSinceEpoch / 1000 - raw['timestamp'];
      if (age >= -5 && age <= 30) event = Map<String, dynamic>.from(raw);
    }
    final result = (state['recognition'] as Map?)?['result'];
    final scores = result is Map ? result['scores'] : null;
    final positive = scores is Map ? [for (final label in fallLabels)
      if (scores[label] is num && (scores[label] as num).isFinite) (scores[label] as num).toDouble()] : <double>[];
    final score = positive.isEmpty ? null : positive.reduce((a, b) => a > b ? a : b);
    final headline = switch (fall['status']) {
      'detected' => '낙상 의심 감지',
      'confirming' => '낙상 의심 확인 중',
      'monitoring' => '낙상 의심 신호 없음',
      'warming' => '낙상 판단 신호 수집 중',
      'uncertain' => '낙상 판단 보류',
      _ => 'CSI 신호 대기',
    };
    return CsiFallState._(headline,
      fall['status'] == 'detected' ? '상태를 확인해 주세요. 음성·화면·빛·진동 알림으로 연결합니다.'
      : '평소에는 대기합니다. 낙상 결과가 0.5초 이상 유지되면 한 번 경고합니다.', ready, score, event);
  }
}
