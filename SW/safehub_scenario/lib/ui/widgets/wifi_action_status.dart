import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/wifi_sensing_service.dart';
import '../../core/csi_fall_state.dart';

/// The home screen observes the same recognition session as the collection UI.
class WifiActionStatus extends StatefulWidget {
  const WifiActionStatus({
    super.key,
    required this.service,
    this.allowDummy = false,
    this.compact = false,
    this.allowModelSelection = false,
  });

  final WifiSensingService service;
  final bool allowDummy;
  final bool compact;
  final bool allowModelSelection;

  @override
  State<WifiActionStatus> createState() => _WifiActionStatusState();
}

class _WifiActionStatusState extends State<WifiActionStatus> {
  Timer? _timer;
  int _silentTicks = 0;
  Map<String, dynamic>? _state;
  bool _polling = false, _busy = false;
  int _generation = 0;
  String _error = '';
  String _commandError = '';

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      // A stalled request must not leave a previous action on the home screen.
      if (_state != null && ++_silentTicks >= 3) {
        setState(() => _state = null);
      }
      _poll();
    });
  }

  @override
  void didUpdateWidget(covariant WifiActionStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service ||
        oldWidget.allowDummy != widget.allowDummy) {
      _generation++;
      _state = null;
      _error = '';
      _commandError = '';
      _polling = false;
      _busy = false;
      _poll();
    }
  }

  Future<void> _poll() async {
    if (!mounted || _polling || _busy) return;
    _polling = true;
    final generation = _generation;
    try {
      final state = await widget.service.state({'view': 'summary'});
      if (!mounted || generation != _generation) return;
      if (!widget.allowDummy &&
          (state['dummy_allowed'] != false || state['mode'] != 'live')) {
        throw const FormatException('실제 수신 전용 CSI 서비스를 연결하세요.');
      }
      _silentTicks = 0;
      setState(() {
        _state = state;
        _error = '';
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _state = null;
          _error =
              error is FormatException ? error.message : 'CSI 서비스 연결을 확인하세요.';
        });
      }
    } finally {
      if (generation == _generation) _polling = false;
    }
  }

  Future<void> _toggleRecognition() async {
    if (_busy || _state == null) return;
    final running = _state!['recognition']['running'] == true;
    await _runControl(running ? 'stop_recognition' : 'recognize');
  }

  Future<void> _runControl(
    String action, [
    Map<String, dynamic> payload = const {},
  ]) async {
    if (_busy || _state == null) return;
    final generation = ++_generation;
    _polling = false;
    setState(() {
      _busy = true;
      _state = null;
      _error = '';
      _commandError = '';
    });
    try {
      await widget.service.command(action, payload);
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(
          () => _commandError = '$error'.replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
        await _poll();
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final fresh = state?['connected'] == true && state?['fresh'] == true;
    final running = state?['recognition']['running'] == true;
    final model = state?['model'];
    final fall = CsiFallState.fromState(state);
    final label = fall.headline;
    final score = fall.fallScore;
    final status = state == null
        ? '서비스 연결 대기'
        : fresh
            ? '실시간 신호 수신 중'
            : '수신기 신호 대기';
    final reason = _commandError.isNotEmpty
        ? _commandError
        : _error.isNotEmpty
            ? _error
            : fall.detail;
    const ink = Color(0xFFF1F3F6);
    const muted = Color(0xFFC5CAD1);
    const blue = Color(0xFFBBD5FC);

    if (widget.compact) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF202D36),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '낙상 감지',
              style: TextStyle(color: ink, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              key: const Key('alert-action-label'),
              style: const TextStyle(color: blue, fontSize: 22),
            ),
            Text(
              reason,
              style: const TextStyle(color: muted),
            ),
            const SizedBox(height: 6),
            const Text(
              '평소에는 대기하고 낙상 의심 신호에만 경고합니다.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'CSI 낙상 감지',
          style: TextStyle(
            color: blue,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Text(
          '낙상과 일상 동작으로 학습한 모델이 필요합니다.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              Icons.sensors,
              size: 18,
              color: fresh ? const Color(0xFFA6DFB2) : muted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                status,
                style: const TextStyle(color: muted, fontSize: 14),
              ),
            ),
            if (state?['mode'] == 'dummy')
              const Text('모의 신호', style: TextStyle(color: muted)),
          ],
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '낙상 감지 상태',
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
                  Text(
                    label,
                    key: const Key('home-action-label'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: blue,
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (score != null)
                    Text(
                      '낙상 모델 점수 ${(score * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: ink, fontSize: 18),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    reason,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: muted, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (widget.allowModelSelection &&
            state != null &&
            (state['models'] as List).isNotEmpty)
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: '기존 CSI 모델 선택 · 추론용'),
            value: model?['model_id'] as String?,
            items: [
              for (final item in (state['models'] as List))
                DropdownMenuItem(
                  value: item['model_id'] as String,
                  child: Text(item['model_id'] as String),
                ),
            ],
            onChanged: _busy
                ? null
                : (id) {
                    if (id != null) _runControl('select_model', {'id': id});
                  },
          ),
        if (model != null)
          Text(
            '${(model['labels'] as List).join(' · ')}  /  ${model['window_seconds'] ?? 4}초 신호',
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, fontSize: 13),
          ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed:
              !_busy && state != null && fall.modelReady && (running || fresh)
                  ? _toggleRecognition
                  : null,
          icon: Icon(running ? Icons.pause : Icons.play_arrow),
          label: Text(
            _busy
                ? '적용 중…'
                : running
                    ? '낙상 감지 중지'
                    : '낙상 감지 시작',
          ),
          style: TextButton.styleFrom(
            foregroundColor: blue,
            disabledForegroundColor: muted,
            minimumSize: const Size(48, 44),
          ),
        ),
        const Text(
          '의식·부상 여부를 확정하지 않습니다. 감지 시 상태를 확인하세요.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ],
    );
  }
}
