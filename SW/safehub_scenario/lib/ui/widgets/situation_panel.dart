import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_config.dart';

import '../../services/live_caption_service.dart';
import '../../services/situation_service.dart';

const _panel = Color(0xFFFFFFFF);
const _ink = Color(0xFF242629);
const _muted = Color(0xFF686C73);
const _accent = Color(0xFFA32640);

Widget _label(
  String text, {
  double size = 17,
  Color color = _ink,
  bool bold = false,
}) => Text(
  text,
  style: TextStyle(
    fontSize: size,
    color: color,
    height: 1.4,
    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
  ),
);

Widget _button(String text, VoidCallback? action, {bool primary = false}) =>
    Padding(
      padding: const EdgeInsets.only(right: 10, bottom: 8),
      child: FilledButton(
        onPressed: action,
        style: FilledButton.styleFrom(
          backgroundColor: primary ? _accent : const Color(0xFFEEECE8),
          foregroundColor: primary ? const Color(0xFFFFFFFF) : _ink,
          disabledForegroundColor: const Color(0xFF777B82),
          disabledBackgroundColor: const Color(0xFFEEECE8),
          minimumSize: const Size(130, 56),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        child: Text(text, style: const TextStyle(fontSize: 18)),
      ),
    );

class SituationPanel extends StatelessWidget {
  const SituationPanel({super.key, required this.service});
  final SituationService service;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: service,
    builder: (context, _) => Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9E8E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 20,
            runSpacing: 8,
            children: [
              _label('지금 우리 집', size: 28, bold: true),
              _label('음성·재난 확인 → 알림 → 수어·터치 응답', color: _accent),
            ],
          ),
          const SizedBox(height: 10),
          _label(
            service.assessmentStale
                ? '최근 정보를 확인하고 있어요'
                : service.assessment!.title,
            size: 22,
            bold: true,
          ),
          if (!service.assessmentStale) ...[
            const SizedBox(height: 6),
            _label(service.assessment!.summary),
            _label('AI 상황 해석 · 원문과 함께 확인하세요', size: 14, color: _muted),
          ],
          const SizedBox(height: 10),
          _label(
            service.settings.enabled ? service.status : '문맥 설명 꺼짐',
            color: _muted,
            size: 15,
          ),
          _label(
            '${service.sensorStatus} · 움직임만으로 부재·의식 상태를 판단하지 않습니다.',
            color: _muted,
            size: 15,
          ),
          if (service.evidence.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _label(
                '최근 원문 | ${service.evidence.last.source}: ${service.evidence.last.text}',
                size: 16,
              ),
            ),
          if (service.signQuestion.isNotEmpty)
            _label('AI 확인 질문: ${service.signQuestion}', color: _accent),
          if (service.pendingSign.isNotEmpty)
            _button('수어로 질문: ${service.pendingSign}', service.confirmSign),
          const SizedBox(height: 12),
          Wrap(
            children: [
              _button('도움 요청', service.openHelp, primary: true),
              _button(
                '지금 상황 다시 확인',
                service.busy || !service.settings.enabled
                    ? null
                    : () => service.requestAssessment(immediate: true),
              ),
              _button(
                'AI·알림 설정',
                () => showSituationSettings(context, service),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Future<void> showSituationSettings(
  BuildContext context,
  SituationService service,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _SituationSettingsDialog(service: service),
  );
}

class _SituationSettingsDialog extends StatefulWidget {
  const _SituationSettingsDialog({required this.service});
  final SituationService service;
  @override
  State<_SituationSettingsDialog> createState() =>
      _SituationSettingsDialogState();
}

class _SituationSettingsDialogState extends State<_SituationSettingsDialog> {
  late final endpoint = TextEditingController(
    text: widget.service.settings.endpoint,
  );
  late final homeRegion = TextEditingController(
    text: widget.service.settings.homeRegion,
  );
  late final address = TextEditingController(
    text: widget.service.settings.address,
  );
  late final ledOn = TextEditingController(
    text: widget.service.settings.ledOnAction,
  );
  late final ledOff = TextEditingController(
    text: widget.service.settings.ledOffAction,
  );
  late bool enabled = widget.service.settings.enabled;
  late bool monitoring = widget.service.settings.monitorAnnouncements;
  late bool actuators = widget.service.settings.actuatorsEnabled;
  bool saving = false;
  String error = '';

  Future<void> save() async {
    setState(() {
      saving = true;
      error = '';
    });
    try {
      final settings = SituationSettings(
        endpoint: endpoint.text.trim(),
        model: SituationSettings.contextModel,
        fastProtocol: true,
        enabled: enabled,
        monitorAnnouncements: monitoring,
        address: address.text.trim(),
        homeRegion: homeRegion.text.trim(),
        actuatorsEnabled: actuators,
        ledOnAction: ledOn.text.trim(),
        ledOffAction: ledOff.text.trim(),
      );
      await settings.save();
      widget.service.configure(settings);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        setState(() {
          error = e is FormatException ? e.message : '설정 저장에 실패했습니다.';
          saving = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('AI 상황 해석·알림 설정'),
    content: SizedBox(
      width: 600,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'fastText 기반 문맥 설명 · 생성형 LLM을 사용하지 않습니다.\n127.0.0.1은 이 화면을 실행하는 기기입니다. 실제 모델과 서버 준비 상태를 확인하세요.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: endpoint,
              decoration: const InputDecoration(
                labelText: 'fastText 문맥 서비스 API 주소',
              ),
            ),
            const Text('모델: fasttext-fire-screen · 실제 모델 파일은 별도 준비'),
            SwitchListTile(
              title: const Text('상황 해석 사용'),
              value: enabled,
              onChanged: (v) => setState(() => enabled = v),
            ),
            const Text(
              '확정 자막과 사건 문맥을 규칙·fastText로 설명합니다. 점수는 실제 위험 확률이 아니며 즉시 경보는 설명 서버를 기다리지 않습니다. 영상과 원본 음성은 보내지 않습니다. 이전 생성형 설정은 자동 호출하지 않고 설명을 꺼 둡니다. 주소·실제 모델을 확인한 뒤 켜세요.',
            ),
            SwitchListTile(
              title: const Text('긴급 안내방송 확인 화면 자동 표시'),
              subtitle: const Text(
                '실제 방송 여부는 원문으로 확인하세요. 훈련·일반 대화는 경보로 확정하지 않습니다.',
              ),
              value: monitoring,
              onChanged: (v) => setState(() => monitoring = v),
            ),
            if (widget.service.settings.fastProtocol)
              const Text(
                '최적화 서버의 대화 해석은 최근 이벤트에 표시됩니다. 재난·센서 경보는 별도로 동작하며 AI 요약만으로 장치를 작동시키지 않습니다.',
              ),
            TextField(
              controller: homeRegion,
              decoration: const InputDecoration(
                labelText: '재난 적용 지역 (예: 경산시 · 비우면 적용 여부 미확인)',
              ),
            ),
            TextField(
              controller: address,
              decoration: const InputDecoration(
                labelText: '도움 요청 문안에 넣을 주소 (선택)',
              ),
            ),
            SwitchListTile(
              title: const Text('경보 시 LED·베드셰이커 명령 전송'),
              subtitle: const Text(
                '기존 MQTT 규격을 사용합니다. 수신기 펌웨어와 실제 동작 확인 후 켜세요. 진동은 10초 요청입니다.',
              ),
              value: actuators,
              onChanged: (v) => setState(() => actuators = v),
            ),
            TextField(
              controller: ledOn,
              decoration: const InputDecoration(
                labelText: 'LED 켜기 action · 펌웨어 값 확인 후 입력',
              ),
            ),
            TextField(
              controller: ledOff,
              decoration: const InputDecoration(
                labelText: 'LED 끄기 action · 빈 값이면 LED 제어 안 함',
              ),
            ),
            if (error.isNotEmpty)
              Text(error, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        onPressed: saving ? null : save,
        child: Text(saving ? '저장 중' : '저장'),
      ),
    ],
  );

  @override
  void dispose() {
    for (final controller in [endpoint, address, homeRegion, ledOn, ledOff]) {
      controller.dispose();
    }
    super.dispose();
  }
}

/// One response screen for a received alarm, a broadcast or a manual help request.
class SituationResponse extends StatelessWidget {
  const SituationResponse({
    super.key,
    required this.service,
    required this.captions,
    required this.camera,
    required this.onAcknowledge,
    required this.onSignal,
    this.incidentTitle,
    this.incidentText,
  });
  final SituationService service;
  final LiveCaptionService captions;
  final Widget camera;
  final VoidCallback onAcknowledge, onSignal;
  final String? incidentTitle, incidentText;

  Future<void> _draft(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) {
      final text = service.reportDraft(incident: incidentText ?? '');
      return AlertDialog(
        title: const Text('도움 요청 문안 확인'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(child: SelectableText(text)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          FilledButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('문안을 복사했습니다. 실제 신고·전송은 아직 하지 않았습니다.'),
                  ),
                );
            },
            child: const Text('문안 복사'),
          ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) => BlockSemantics(
    child: Material(
      color: const Color(0xFFF6F5F3),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _label('SafeHub · 상황 확인과 응답', color: _accent),
              if (service.scenarioTestMode)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        service.scenarioActuators
                            ? '시연 입력 · 실제 LED·진동 작동 / 신고 전송 없음'
                            : '테스트 · 실제 장치 명령과 신고 전송 없음',
                        style: TextStyle(
                          color: Color(0xFF8C5300),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: service.endScenarioTest,
                      child: const Text('테스트 종료'),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              _label(
                incidentTitle ??
                    (service.announcement != null
                        ? '안내방송을 확인해 주세요'
                        : '어떤 도움이 필요한가요?'),
                size: 30,
                bold: true,
              ),
              const SizedBox(height: 10),
              _label(
                incidentText ??
                    service.announcement ??
                    '수어 또는 아래 버튼으로 상황을 알려주세요.',
                size: 23,
              ),
              if (!service.assessmentStale &&
                  (incidentText == null ||
                      service.assessment!.evidence.any(
                        (e) =>
                            e.text.contains(incidentText!) ||
                            incidentText!.contains(e.text),
                      ))) ...[
                const SizedBox(height: 12),
                _label(
                  'AI 참고 해석: ${service.assessment!.summary}',
                  color: _muted,
                ),
              ],
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cameraBlock = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: 210, child: camera),
                      const SizedBox(height: 8),
                      _label(
                        '수어 인식: ${service.pendingSign.isEmpty ? '새 응답 대기' : service.pendingSign}',
                        bold: true,
                      ),
                      _button(
                        '이 수어로 응답',
                        service.pendingSign.isEmpty
                            ? null
                            : service.confirmSign,
                      ),
                      _label('수어 인식 결과를 확인한 뒤 응답합니다.', size: 14, color: _muted),
                      if (AppConfig.developerTools && service.scenarioTestMode)
                        _TestSignInput(service: service),
                    ],
                  );
                  final responses = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label('터치로도 같은 응답을 할 수 있어요', size: 20, bold: true),
                      const SizedBox(height: 10),
                      Wrap(
                        children: [
                          _button(
                            '도움 요청',
                            () => service.respond('도움이 필요합니다.'),
                            primary: true,
                          ),
                          _button(
                            '가족이 쓰러졌어요',
                            () => service.respond('가족이 쓰러졌습니다.'),
                          ),
                          _button('아파요', () => service.respond('아픕니다.')),
                          _button('대피 중이에요', () => service.respond('대피 중입니다.')),
                        ],
                      ),
                      _label(
                        '확인된 응답: ${service.response.isEmpty ? '아직 없음' : service.response}\n${service.signQuestion.isEmpty ? '' : 'AI 확인 질문: ${service.signQuestion}'}',
                        color: _accent,
                      ),
                      const SizedBox(height: 10),
                      _button('도움 요청 문안 만들기', () => _draft(context)),
                      _label(
                        '119 자동 신고·보호자 전송은 연결되어 있지 않습니다.',
                        size: 14,
                        color: _muted,
                      ),
                    ],
                  );
                  if (constraints.maxWidth < 800)
                    return Column(
                      children: [
                        cameraBlock,
                        const SizedBox(height: 18),
                        responses,
                      ],
                    );
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: cameraBlock),
                      const SizedBox(width: 24),
                      Expanded(flex: 3, child: responses),
                    ],
                  );
                },
              ),
              const Divider(height: 30, color: Color(0xFFE9E8E5)),
              _label(
                service.scenarioTestMode
                    ? '테스트 입력 · 실제 센서 측정 아님'
                    : service.sensorStatus,
                color: _muted,
              ),
              _label(
                '센서 분류는 참고 정보입니다. 정지·수면·부재·의식 상태는 별도 확인이 필요합니다.',
                size: 14,
                color: _muted,
              ),
              const SizedBox(height: 10),
              if (!service.scenarioTestMode)
                AnimatedBuilder(
                  animation: Listenable.merge([captions, service]),
                  builder: (context, child) => _label(
                    '계속 듣는 음성자막\n${[service.finalCaptionText, if (captions.listening && !captions.serverError) captions.draftText].where((s) => s.isNotEmpty).join('\n')}',
                    size: 19,
                  ),
                ),
              const SizedBox(height: 16),
              _label(
                service.flow.active?.delivery ?? service.actuatorStatus,
                color: _muted,
                size: 15,
              ),
              Wrap(
                children: [
                  _button(
                    'LED·진동 다시 알림',
                    service.scenarioTestMode ||
                            service.settings.actuatorsEnabled
                        ? onSignal
                        : null,
                  ),
                  _button('경보 확인', onAcknowledge, primary: true),
                ],
              ),
              _label(
                '경보 확인은 화면을 확인했다는 뜻이며, 위험 해제나 신고 완료를 의미하지 않습니다.',
                size: 14,
                color: _muted,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _TestSignInput extends StatefulWidget {
  const _TestSignInput({required this.service});
  final SituationService service;
  @override
  State<_TestSignInput> createState() => _TestSignInputState();
}

class _TestSignInputState extends State<_TestSignInput> {
  final text = TextEditingController(text: '도와주세요');
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextField(
        controller: text,
        maxLength: 60,
        decoration: const InputDecoration(labelText: '테스트 수어 · 인식 결과 대신 입력'),
      ),
      TextButton(
        onPressed: () =>
            widget.service.receiveSign(text.text.trim(), simulated: true),
        child: const Text('테스트 수어 넣기'),
      ),
    ],
  );
}
