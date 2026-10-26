part of 'home_page.dart';

const _paper = Color(0xFFF7F5F2);
const _charcoal = Color(0xFF242629);
const _secondary = Color(0xFF686C73);
const _accent = Color(0xFF8D2345);
const _line = Color(0xFFE9E8E5);

extension _HomeDashboard on _SafeHubHomePageState {
  Widget _label(
    String value, {
    double size = 18,
    Color color = _charcoal,
    int lines = 2,
    FontWeight weight = FontWeight.w500,
  }) => Text(
    value,
    maxLines: lines,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: size,
      height: 1.4,
      color: color,
      fontWeight: weight,
      letterSpacing: -.3,
    ),
  );

  Widget _card({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? action,
  }) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 23, color: _accent),
            const SizedBox(width: 10),
            Expanded(child: _label(title, size: 20, weight: FontWeight.w700)),
            if (action != null) action,
          ],
        ),
        const SizedBox(height: 16),
        Expanded(child: child),
      ],
    ),
  );

  Widget _pill(String text, {bool ok = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: ok ? const Color(0xFFEAF4EF) : _paper,
      borderRadius: BorderRadius.circular(30),
    ),
    child: _label(
      text,
      size: 18,
      color: ok ? const Color(0xFF287055) : _secondary,
    ),
  );

  Widget _nav(
    String text,
    IconData icon,
    VoidCallback action, {
    bool selected = false,
  }) => TextButton.icon(
    onPressed: action,
    icon: Icon(icon, size: 20),
    label: Text(text),
    style: TextButton.styleFrom(
      foregroundColor: selected ? _accent : _secondary,
      backgroundColor: selected ? const Color(0xFFF7EDEF) : Colors.transparent,
      minimumSize: const Size(80, 48),
      textStyle: const TextStyle(fontSize: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );

  Widget _modernHeader() => SizedBox(
    height: 64,
    child: Row(
      children: [
        const Icon(Icons.home_rounded, size: 34, color: _accent),
        const SizedBox(width: 10),
        _label('SafeHub', size: 29, weight: FontWeight.w800),
        const SizedBox(width: 28),
        _nav(
          '홈',
          Icons.dashboard_outlined,
          () => _navigate(_SafeHubPage.home),
          selected: _currentPage == _SafeHubPage.home,
        ),
        _nav(
          '수어 대화',
          Icons.sign_language_outlined,
          _openSignTranslation,
          selected: _currentPage == _SafeHubPage.signTranslation,
        ),
        _nav(
          '신호 관리',
          Icons.sensors,
          () => _navigate(_SafeHubPage.wifiSensing),
          selected: _currentPage == _SafeHubPage.wifiSensing,
        ),
        _nav(
          '가전',
          Icons.devices_other,
          () => _navigate(_SafeHubPage.appliances),
          selected: _currentPage == _SafeHubPage.appliances,
        ),
        const Spacer(),
        _pill(
          AppConfig.localPreview
              ? '미리보기'
              : _mqttConnected
              ? '홈 연결됨'
              : '홈 연결 확인',
          ok: _mqttConnected && !AppConfig.localPreview,
        ),
        const SizedBox(width: 12),
        IconButton(
          tooltip: 'AI·알림 설정',
          onPressed: () => showSituationSettings(context, _situation),
          icon: const Icon(Icons.auto_awesome_outlined, color: _secondary),
        ),
        IconButton(
          tooltip: '연결 설정',
          onPressed: _openConnectionSettings,
          icon: const Icon(Icons.settings_outlined, color: _secondary),
        ),
      ],
    ),
  );

  Widget _modernDashboard(SafeHubAlert? alert) => Column(
    children: [
      HouseStatusCard(
        service: _situation,
        onAcknowledge: _situation.acknowledge,
      ),
      const SizedBox(height: 18),
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 62, child: _modernCamera()),
            const SizedBox(width: 20),
            Expanded(
              flex: 38,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _modernCaptions()),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 62,
                    child: OutlinedButton.icon(
                      onPressed: _showEventDetails,
                      icon: const Icon(Icons.notifications_none),
                      label: Text(
                        _recentEvents.isEmpty
                            ? '받은 알림 · 기록 보기'
                            : '받은 알림 ${_recentEvents.length}건 · 기록 보기',
                      ),
                      style: OutlinedButton.styleFrom(
                        textStyle: const TextStyle(fontSize: 21),
                        foregroundColor: _charcoal,
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: _line),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 70,
                    child: FilledButton.icon(
                      onPressed: _situation.openHelp,
                      icon: const Icon(Icons.front_hand_outlined, size: 28),
                      label: const Text('도움이 필요해요'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _modernCamera() => _card(
    title: '수어로 이야기해요',
    icon: Icons.sign_language_outlined,
    action: _pill(_cameraConnected ? '연결됨' : '연결 대기', ok: _cameraConnected),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _cameraPlaceholder()),
        const SizedBox(height: 12),
        _label(
          _signText == '수어 인식 대기 중' ? '수어를 기다리고 있어요' : '인식한 수어  $_signText',
          size: 28,
          weight: FontWeight.w700,
        ),
        const SizedBox(height: 6),
        _label('인식한 수어가 여기에 표시돼요.', size: 20, color: _secondary),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _openSignTranslation,
          icon: const Icon(Icons.chat_bubble_outline, size: 18),
          label: const Text('수어 대화 열기'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _charcoal,
            minimumSize: const Size.fromHeight(56),
            textStyle: const TextStyle(fontSize: 20),
            side: const BorderSide(color: _line),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: _situation,
          builder:
              (context, _) => InkWell(
                onTap: () => _navigate(_SafeHubPage.wifiSensing),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.sensors, color: _accent, size: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _label(
                          _situation.sensorStatus.replaceFirst(
                            'CSI 분류:',
                            'CSI 활동:',
                          ),
                          size: 22,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const Icon(Icons.arrow_forward, color: _secondary),
                    ],
                  ),
                ),
              ),
        ),
      ],
    ),
  );

  Widget _modernPresence() => _card(
    title: '재실 · 활동',
    icon: Icons.sensors,
    action: IconButton(
      tooltip: '신호 수집 · 모델 관리',
      onPressed: () => _navigate(_SafeHubPage.wifiSensing),
      icon: const Icon(Icons.arrow_forward, color: _secondary, size: 20),
    ),
    child: AnimatedBuilder(
      animation: _situation,
      builder:
          (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _label(
                    _situation.sensorStatus,
                    size: 22,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              _label('움직임이 없다고 부재·수면으로 단정하지 않아요.', size: 18, color: _secondary),
            ],
          ),
    ),
  );

  Widget _modernCaptions() => _card(
    title: '음성 자막',
    icon: Icons.closed_caption_outlined,
    child: _FinalCaptionBody(
      situation: _situation,
      captions: _captions,
      available:
          !AppConfig.localPreview && AppConfig.sttServerUrl.trim().isNotEmpty,
    ),
  );

  Widget _modernEvents() {
    final events = _recentEvents.take(3).toList();
    return _card(
      title: '최근 이벤트',
      icon: Icons.history,
      action: IconButton(
        tooltip: '이벤트 전체 보기',
        onPressed: _showEventDetails,
        icon: const Icon(Icons.more_horiz, color: _secondary),
      ),
      child:
          events.isEmpty
              ? Center(
                child: _label(
                  '새 알림과 AI 상황 해석이 여기에 모여요.',
                  size: 16,
                  color: _secondary,
                ),
              )
              : Column(
                children: [
                  for (final event in events)
                    Expanded(
                      child: InkWell(
                        onTap:
                            () => _showDetails(
                              '최근 이벤트',
                              event['event'] == 'llm_conversation'
                                  ? _conversationText(event)
                                  : '${_getEventName(event)}\n${_formatEventDateTime(event)}',
                            ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: _line)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                event['event'] == 'llm_conversation'
                                    ? Icons.auto_awesome
                                    : Icons.notifications_none,
                                size: 18,
                                color: _accent,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _label(
                                  event['event'] == 'llm_conversation'
                                      ? event['reply'].toString()
                                      : _getEventName(event),
                                  size: 16,
                                  lines: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
    );
  }

  Widget _modernAlarms(SafeHubAlert? alert) => _card(
    title: '경보 · 재난',
    icon: Icons.shield_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pill(alert == null ? '새 경보 수신 대기' : '확인이 필요한 경보'),
        const SizedBox(height: 18),
        _label(
          _latestDisaster?['DST_SE_NM']?.toString() ?? '재난 정보',
          size: 22,
          weight: FontWeight.w700,
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _label(
            _latestDisaster?['MSG_CN']?.toString() ??
                (AppConfig.disasterConfigured
                    ? '수신된 재난 정보가 없습니다.'
                    : '재난 API 연결 설정이 필요합니다.'),
            size: 18,
            lines: 7,
          ),
        ),
        if (_latestDisaster != null) ...[
          _label(
            _latestDisaster?['CRT_DT']?.toString() ?? '',
            size: 12,
            color: _secondary,
          ),
          TextButton(
            onPressed: () => _showDisasterDetails(_latestDisaster!),
            child: const Text('재난 안내 자세히 보기'),
          ),
        ],
        const Divider(color: _line, height: 24),
        _label('초인종 · 가전 알림', size: 16, weight: FontWeight.w700),
        const SizedBox(height: 6),
        _label('연결된 기기에서 받은 알림은 최근 이벤트에 표시해요.', size: 14, color: _secondary),
      ],
    ),
  );

  Widget _modernHelp() => _card(
    title: '도움이 필요할 때',
    icon: Icons.front_hand_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _label('수어 또는 터치로 상황을 알려주세요.', size: 16, color: _secondary),
        ),
        FilledButton.icon(
          onPressed: _situation.openHelp,
          icon: const Icon(Icons.support_agent),
          label: const Text('도움이 필요해요'),
          style: FilledButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    ),
  );
}

/// Microphone level changes rebuild this card, never the camera or the dashboard.
class _FinalCaptionBody extends StatelessWidget {
  const _FinalCaptionBody({
    required this.situation,
    required this.captions,
    required this.available,
  });
  final SituationService situation;
  final LiveCaptionService captions;
  final bool available;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([situation, captions]),
    builder: (context, _) {
      final lines = [
        ...situation.finalCaptions,
        if (captions.listening &&
            !captions.serverError &&
            captions.draftText.isNotEmpty)
          captions.draftText,
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                captions.listening ? Icons.mic : Icons.mic_off_outlined,
                size: 17,
                color:
                    captions.listening ? const Color(0xFF287055) : _secondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  !available
                      ? '음성 서버 연결 필요'
                      : captions.serverError
                      ? captions.status
                      : situation.busy
                      ? '듣고 있어요 · 집 안 상황 분석 중'
                      : captions.listening
                      ? '듣고 있어요'
                      : '자막 일시정지',
                  style: const TextStyle(color: _secondary, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child:
                lines.isEmpty
                    ? Center(
                      child: Text(
                        situation.busy
                            ? '듣고 있어요\n인식한 문장을 바로 표시해요.'
                            : '말씀하시면\n여기에 바로 표시돼요.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _secondary,
                          fontSize: 24,
                          height: 1.6,
                        ),
                      ),
                    )
                    : ListView.builder(
                      reverse: true,
                      itemCount: lines.length,
                      itemBuilder:
                          (context, index) => Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: Text(
                              lines[lines.length - 1 - index],
                              key:
                                  index == 0
                                      ? const ValueKey('final-caption')
                                      : null,
                              style: TextStyle(
                                fontSize: index == 0 ? 27 : 20,
                                height: 1.5,
                                fontWeight:
                                    index == 0
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                color: index == 0 ? _charcoal : _secondary,
                              ),
                            ),
                          ),
                    ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  situation.clearCaptions();
                  captions.clear();
                },
                style: TextButton.styleFrom(foregroundColor: _secondary),
                child: const Text('지우기'),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed:
                    !available
                        ? null
                        : () {
                          if (captions.enabled) {
                            captions.pause();
                          } else {
                            captions.start();
                          }
                        },
                icon: Icon(
                  captions.enabled ? Icons.pause : Icons.mic_none,
                  size: 17,
                ),
                label: Text(captions.enabled ? '일시정지' : '시작'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _charcoal,
                  minimumSize: const Size(90, 44),
                  side: const BorderSide(color: _line),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}
