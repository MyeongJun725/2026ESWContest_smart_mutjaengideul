import 'package:flutter/material.dart';
import '../../core/house_scenario.dart';
import '../../services/situation_service.dart';

/// Event-driven layer over the existing home. No call/SMS transport is assumed.
class ScenarioEventOverlay extends StatefulWidget {
  const ScenarioEventOverlay(
      {super.key,
      required this.service,
      required this.camera,
      required this.onAcknowledge,
      required this.onSignal});
  final SituationService service;
  final Widget camera;
  final VoidCallback onAcknowledge, onSignal;
  @override
  State<ScenarioEventOverlay> createState() => _ScenarioEventOverlayState();
}

class _ScenarioEventOverlayState extends State<ScenarioEventOverlay> {
  String consciousness = '미확인';
  bool reportPrepared = false;
  String? preparedReport;
  String? _lastPromptedSign;
  bool _confirmingSign = false;
  DialogRoute<bool>? _signDialog;
  static const ink = Color(0xFF242629);
  static const muted = Color(0xFF686C73);
  static const accent = Color(0xFFA32640);

  SituationService get service => widget.service;
  HouseIncident? get incident => service.flow.active;
  HouseScenario get kind => incident?.kind ?? HouseScenario.assistance;
  bool get assistance => kind == HouseScenario.assistance;
  bool get simulated => service.scenarioTestMode;

  @override
  void initState() {
    super.initState();
    service.addListener(_checkSign);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSign());
  }

  @override
  void didUpdateWidget(covariant ScenarioEventOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != service) {
      oldWidget.service.removeListener(_checkSign);
      service.addListener(_checkSign);
    }
  }

  @override
  void dispose() {
    service.removeListener(_checkSign);
    final route = _signDialog;
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isActive) route.navigator?.removeRoute(route);
      });
    }
    super.dispose();
  }

  String? _emergencySign(String text) {
    final value = text.replaceAll(RegExp(r'[\s.!?,·]'), '');
    if (const {'구조', '도움', '도와주세요', '도와줘', '도움요청'}.contains(value)) return '도움';
    if (const {'쓰러짐', '쓰러지다', '쓰러졌어요', '넘어짐', '낙상'}.contains(value))
      return '쓰러짐';
    return null;
  }

  void _checkSign() {
    if (!mounted || !assistance || reportPrepared || _confirmingSign) return;
    final label = _emergencySign(service.pendingSign);
    if (label == null) {
      _lastPromptedSign = null;
      return;
    }
    if (_lastPromptedSign == service.pendingSign) return;
    final recognized = service.pendingSign;
    final active = incident;
    _lastPromptedSign = recognized;
    _confirmingSign = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || incident != active || reportPrepared) {
        _confirmingSign = false;
        return;
      }
      final route = DialogRoute<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
                title: _dialogTitle('119에 신고할까요?', '수어 신고 확인 창 닫기',
                    () => Navigator.pop(dialogContext, false)),
                content: SizedBox(
                    width: 460,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _text('“$label” 수어를 인식했어요.', size: 23, bold: true),
                          const SizedBox(height: 12),
                          _text('등록 주소와 확인한 상태를 담아 도움 요청을 준비할게요.',
                              size: 16, color: muted),
                          const SizedBox(height: 12),
                          _text('119 연동 전 · 실제 신고는 전송되지 않습니다.',
                              size: 12, color: muted),
                        ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('다시 확인')),
                  FilledButton.icon(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      icon: const Icon(Icons.emergency_outlined),
                      label: const Text('119 도움 요청'),
                      style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          minimumSize: const Size(180, 58)))
                ],
              ));
      _signDialog = route;
      final accepted = await Navigator.of(context).push<bool>(route);
      _signDialog = null;
      _confirmingSign = false;
      if (!mounted || incident != active || accepted != true) return;
      // Record the recognized result that was actually confirmed, even if the
      // recognizer emitted another label while the confirmation was visible.
      service.respond('수어 확인: $recognized');
      _requestHelp();
    });
  }

  String get disasterName {
    final text = incident?.evidence ?? '';
    final found = RegExp('지진|산불|태풍|호우|홍수|침수|해일|폭염|한파|대설|강풍').firstMatch(text);
    return found?.group(0) ?? '재난';
  }

  String get title => reportPrepared
      ? '신고 내용을 준비했어요'
      : switch (kind) {
          HouseScenario.broadcast =>
            (incident?.evidence.contains('화재') == true ||
                    incident?.evidence.contains('불이') == true)
                ? '화재 안내방송이 감지됐어요'
                : '위험 안내방송이 감지됐어요',
          HouseScenario.disaster => '$disasterName 알림이 도착했어요',
          HouseScenario.assistance => '보호자에게 도움이 필요한가요?',
        };
  String get subtitle => reportPrepared
      ? '현재 실제 119 접수·통화는 연결되지 않았어요.'
      : switch (kind) {
          HouseScenario.broadcast => '방송에서 안내하는 대피 행동을 따라주세요.',
          HouseScenario.disaster => '원문에 안내된 대피 장소와 안전 행동을 확인하세요.',
          HouseScenario.assistance => '말하기 어려워도 터치나 수어로 도움을 요청할 수 있어요.',
        };

  void _respond(String value) {
    setState(() {
      consciousness = value;
      reportPrepared = false;
      preparedReport = null;
    });
    service.respond('보호자 의식·반응: $value');
  }

  void _requestHelp() {
    final address = service.settings.address.trim();
    // Snapshot this incident's facts. Never label a local draft as accepted.
    setState(() {
      preparedReport = [
        '[SafeHub ${simulated ? '신고 시연' : '신고 문안'} · 아직 전송하지 않음]',
        '보호자가 쓰러진 것으로 의심되어 구급 도움이 필요합니다.',
        '주소: ${address.isEmpty ? '미등록 · 주소 확인 필요' : address}',
        '상황 원문: ${incident?.evidence ?? '사용자가 도움을 요청했습니다.'}',
        '사용자가 선택한 의식·반응: $consciousness',
        if (incident?.response.isNotEmpty ?? false)
          '확인한 응답: ${incident!.response}',
        '수어·문자 소통이 필요합니다. 수어통역을 요청합니다.',
      ].join('\n');
      reportPrepared = true;
    });
  }

  @override
  Widget build(BuildContext context) => BlockSemantics(
          child: Stack(children: [
        const Positioned.fill(
            child: ModalBarrier(dismissible: false, color: Color(0x8A25232A))),
        Positioned.fill(
            child: SafeArea(child: LayoutBuilder(builder: (context, bounds) {
          final compact = bounds.maxHeight < 740;
          return Center(
              child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: assistance ? 1000 : 780,
                      maxHeight: bounds.maxHeight - 20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Material(
                      color: const Color(0xFFFEFDFC),
                      borderRadius: BorderRadius.circular(24),
                      clipBehavior: Clip.antiAlias,
                      child: SingleChildScrollView(
                          child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                  24, compact ? 18 : 26, 24, 12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(children: [
                                    Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                            color: const Color(0xFFF9E9ED),
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        child: Icon(
                                            assistance
                                                ? Icons.front_hand_outlined
                                                : kind ==
                                                        HouseScenario.broadcast
                                                    ? Icons
                                                        .local_fire_department_outlined
                                                    : Icons.campaign_outlined,
                                            color: accent,
                                            size: 27)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: _text(
                                            switch (kind) {
                                              HouseScenario.broadcast =>
                                                '아파트 안내방송',
                                              HouseScenario.disaster =>
                                                '재난 API 알림',
                                              HouseScenario.assistance =>
                                                '긴급 도움 요청'
                                            },
                                            size: 15,
                                            bold: true,
                                            color: accent)),
                                    _text(
                                        simulated ? '시연 · 실제 작동 없음' : '수신된 알림',
                                        size: 11,
                                        color: muted),
                                    const SizedBox(width: 8),
                                    IconButton(
                                        tooltip: '알림 창 닫기',
                                        onPressed: widget.onAcknowledge,
                                        icon: const Icon(Icons.close_rounded,
                                            color: muted)),
                                  ]),
                                  SizedBox(height: compact ? 14 : 22),
                                  Semantics(
                                      liveRegion: true,
                                      child: _text(title,
                                          size: compact ? 26 : 30, bold: true)),
                                  const SizedBox(height: 7),
                                  _text(subtitle, size: 16, color: muted),
                                  SizedBox(height: compact ? 14 : 20),
                                  if (!assistance) ...[
                                    Container(
                                        padding: const EdgeInsets.all(17),
                                        decoration: BoxDecoration(
                                            color: const Color(0xFFF4F1ED),
                                            borderRadius:
                                                BorderRadius.circular(13)),
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _text(
                                                  kind ==
                                                          HouseScenario
                                                              .broadcast
                                                      ? '음성자막 원문'
                                                      : '재난 알림 원문 · 지역·발행 시각',
                                                  size: 12,
                                                  color: muted),
                                              const SizedBox(height: 7),
                                              _text(
                                                  incident?.evidence ??
                                                      '수신 원문 확인 필요',
                                                  size: 18,
                                                  bold: true),
                                            ])),
                                    const SizedBox(height: 15),
                                    _delivery(),
                                    const SizedBox(height: 18),
                                    _primary('대피 안내 확인', Icons.check_rounded,
                                        widget.onAcknowledge),
                                    const SizedBox(height: 8),
                                    Center(
                                        child: _text(
                                            '확인은 알림을 읽었다는 뜻이며 위험 해제를 뜻하지 않아요.',
                                            size: 12,
                                            color: muted)),
                                    TextButton(
                                        onPressed: widget.onSignal,
                                        child: const Text('LED·베드셰이커 다시 알림')),
                                  ] else ...[
                                    _address(),
                                    const SizedBox(height: 14),
                                    if (!reportPrepared)
                                      _cameraAndTouch(compact)
                                    else ...[
                                      _text('주소·의식 상태·수어통역 요청을 함께 담았어요.',
                                          size: 15, color: muted),
                                      const SizedBox(height: 14),
                                      _primary(
                                          '준비한 신고 내용 보기',
                                          Icons.description_outlined,
                                          _showReport),
                                    ],
                                    const SizedBox(height: 7),
                                    Center(
                                        child: _text(
                                            '119 연동 전 · 실제 신고는 전송되지 않습니다.',
                                            size: 12,
                                            color: muted)),
                                    TextButton(
                                        onPressed: widget.onAcknowledge,
                                        child: Text(reportPrepared
                                            ? 'SafeHub로 돌아가기'
                                            : '도움이 필요하지 않아요')),
                                  ],
                                ],
                              ))),
                    ),
                  )));
        }))),
      ]));

  Widget _address() => Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: const Color(0xFFF4F1ED),
          borderRadius: BorderRadius.circular(13)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.location_on_outlined, color: accent, size: 24),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _text(simulated ? '등록 주소 · 시연 예시' : '등록 주소', size: 12, color: muted),
          const SizedBox(height: 4),
          _text(
              service.settings.address.trim().isEmpty
                  ? '주소 미등록 · 신고 시 확인 필요'
                  : service.settings.address,
              size: 19,
              bold: true),
          const SizedBox(height: 6),
          _text(incident?.evidence ?? '사용자가 도움을 요청했습니다.',
              size: 13, color: muted),
        ])),
      ]));
  Widget _delivery() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.lightbulb_outline, color: accent, size: 21),
          const SizedBox(width: 8),
          _text(simulated ? 'LED 점멸 · 시연' : 'LED 알림', size: 14),
          const SizedBox(width: 24),
          const Icon(Icons.vibration, color: accent, size: 21),
          const SizedBox(width: 8),
          Expanded(
              child: _text(simulated ? '베드셰이커 진동 · 시연' : '베드셰이커 알림', size: 14))
        ]),
        const SizedBox(height: 7),
        _text(incident?.delivery ?? service.actuatorStatus,
            size: 12, color: muted),
      ]);
  Widget _primary(String title, IconData icon, VoidCallback callback) =>
      SizedBox(
          height: 68,
          child: FilledButton.icon(
              onPressed: callback,
              icon: Icon(icon, size: 27),
              label: Text(title,
                  style: const TextStyle(
                      fontSize: 23, fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13)))));
  Widget _text(String value,
          {double size = 16, bool bold = false, Color color = ink}) =>
      Text(value,
          style: TextStyle(
              color: color,
              fontSize: size,
              height: 1.4,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400));
  Widget _dialogTitle(String title, String closeLabel, VoidCallback onClose) =>
      Row(children: [
        Expanded(child: Text(title)),
        const SizedBox(width: 8),
        IconButton(
            tooltip: closeLabel,
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded)),
      ]);
  Future<void> _showReport() => showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
            title: _dialogTitle('119 신고 내용 · 미전송', '신고 내용 창 닫기',
                () => Navigator.pop(dialogContext)),
            content: SizedBox(
                width: 540,
                child: SingleChildScrollView(
                    child: SelectableText(preparedReport ?? ''))),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('닫기')),
              FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content:
                            Text('신고 요청 시연입니다. 실제 119 전송은 아직 연결되지 않았어요.')));
                  },
                  icon: const Icon(Icons.emergency_outlined),
                  label: const Text('신고하기'),
                  style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      minimumSize: const Size(160, 56))),
            ],
          ));
  Widget _cameraAndTouch(bool compact) =>
      LayoutBuilder(builder: (context, size) {
        final camera =
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.sign_language_outlined, color: accent, size: 21),
            const SizedBox(width: 8),
            _text('카메라에 수어로 표현하세요', size: 17, bold: true)
          ]),
          const SizedBox(height: 10),
          SizedBox(height: compact ? 170 : 220, child: widget.camera),
          const SizedBox(height: 8),
          _text('도움 · 쓰러짐 수어가 인식되면 신고 확인 창이 떠요.', size: 13, color: muted),
        ]);
        final touch =
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _text('터치로도 바로 요청할 수 있어요', size: 17, bold: true),
          const SizedBox(height: 10),
          _text('불러도 반응이 있나요?', size: 14, color: muted),
          const SizedBox(height: 8),
          Wrap(
              spacing: 7,
              runSpacing: 7,
              children: ['반응 있어요', '반응 없어요', '미확인']
                  .map((value) => ChoiceChip(
                        label: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Text(value)),
                        selected: consciousness == value,
                        onSelected: (_) => _respond(value),
                        selectedColor: const Color(0xFFF7EDEF),
                        checkmarkColor: accent,
                        labelStyle: TextStyle(
                            color: consciousness == value ? accent : muted,
                            fontSize: 14),
                        side: BorderSide(
                            color: consciousness == value
                                ? accent
                                : const Color(0xFFE2DEDB)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ))
                  .toList()),
          const SizedBox(height: 8),
          _text('상태를 몰라도 도움을 요청할 수 있어요.', size: 12, color: muted),
          const SizedBox(height: 16),
          _primary('119 도움 요청', Icons.emergency_outlined, _requestHelp),
        ]);
        if (size.maxWidth >= 540)
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: camera),
            const SizedBox(width: 22),
            Expanded(child: touch)
          ]);
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [camera, const SizedBox(height: 18), touch]);
      });
}
