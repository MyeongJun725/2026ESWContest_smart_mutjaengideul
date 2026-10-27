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
  }) =>
      Text(
        value,
        maxLines: lines,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Pretendard',
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
  }) =>
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x073E2830),
              blurRadius: 20,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 23, color: _accent),
                const SizedBox(width: 10),
                Expanded(
                    child: _label(title, size: 20, weight: FontWeight.w700)),
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
  }) =>
      TextButton.icon(
        key: ValueKey('navigation-$text'),
        onPressed: action,
        icon: Icon(icon, size: 20),
        label: Text(text),
        style: TextButton.styleFrom(
          foregroundColor: selected ? _accent : _secondary,
          backgroundColor:
              selected ? const Color(0xFFF7EDEF) : Colors.transparent,
          minimumSize: const Size(80, 48),
          textStyle: const TextStyle(fontFamily: 'Pretendard', fontSize: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );

  Widget _modernHeader() => Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: const Color(0xF2FFFFFF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFEAE5DF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x073E2830),
              blurRadius: 18,
              offset: Offset(0, 5),
            ),
          ],
        ),
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
              widget.developerTools ? '신호 관리' : '활동 상태',
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
            if (widget.developerTools)
              OutlinedButton.icon(
                onPressed: _openHardwareTest,
                icon: const Icon(Icons.science_outlined, size: 21),
                label: const Text('장치 테스트'),
              ),
            IconButton(
              tooltip: '화면 배치 편집',
              onPressed: _toggleLayoutEditing,
              icon: Icon(
                Icons.dashboard_customize_outlined,
                color: _layoutEditing ? _accent : _secondary,
              ),
            ),
            IconButton(
              tooltip: '문맥·알림 설정',
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

  Widget _modernDashboard(SafeHubAlert? alert) => EditableDashboard(
        editing: _layoutEditing,
        onEditingChanged: _setLayoutEditing,
        tiles: {
          'status': HouseStatusCard(
            developerTools: widget.developerTools,
            service: _situation,
            onAcknowledge: _situation.acknowledge,
          ),
          'camera': _modernCamera(),
          'captions': _modernCaptions(),
          'notices': _notificationSummary(),
          'help': _helpSummary(),
          'csi': _csiSummary(),
        },
      );
  Widget _helpSummary() => Material(
        color: _accent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: _situation.openHelp,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.front_hand_outlined,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label(
                        '도움 요청',
                        size: 24,
                        color: Colors.white,
                        weight: FontWeight.w700,
                      ),
                      _label(
                        '수어·터치로 선택',
                        size: 18,
                        color: const Color(0xFFF7E9ED),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      );
  Widget _csiSummary() => AnimatedBuilder(
        animation: _situation,
        builder: (context, _) => Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: () => _navigate(_SafeHubPage.wifiSensing),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              decoration: BoxDecoration(
                border: Border.all(color: _line),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sensors, color: _accent, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _label(
                      _situation.sensorStatus
                          .replaceFirst('CSI 분류:', 'CSI 활동:'),
                      size: 22,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, color: _secondary),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _notificationSummary() {
    final event = _recentEvents.isEmpty ? null : _recentEvents.first;
    final activity = event == null ? null : event['event'] == 'llm_conversation'
        ? '${event['reply']}' : _getEventName(event);
    return DisasterNoticeCard(
      disaster: _latestDisaster,
      status: _disasterStatus,
      latestEvent: activity,
      onDisaster: () {
        if (_latestDisaster != null) {
          _showDisasterDetails(_latestDisaster!);
        } else if (AppConfig.disasterConfigured) {
          unawaited(_fetchLatestDisaster());
        } else {
          _openConnectionSettings();
        }
      },
      onEvents: _showEventDetails,
    );
  }

  Widget _modernCamera() => _card(
        title: '수어 인식',
        icon: Icons.sign_language_outlined,
        action: _pill(_cameraConnected ? '연결됨' : '연결 대기', ok: _cameraConnected),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _cameraPlaceholder()),
            SignResultStrip(sign: _signText, connected: _cameraConnected,
              onConversation: _openSignTranslation),
          ],
        ),
      );

  Widget _modernCaptions() => _card(
        title: '음성 자막',
        icon: Icons.closed_caption_outlined,
        child: _FinalCaptionBody(
          situation: _situation,
          captions: _captions,
          available: !AppConfig.localPreview &&
              AppConfig.sttServerUrl.trim().isNotEmpty,
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
                    color: captions.listening
                        ? const Color(0xFF287055)
                        : _secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      !available
                          ? '음성 서버 연결 필요'
                          : captions.serverError
                              ? captions.status
                              : situation.busy
                                  ? '음성 수신 중 · 문맥 확인 중'
                                  : captions.listening
                                      ? '음성 수신 중'
                                      : '자막 일시정지',
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        color: _secondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: lines.isEmpty
                    ? Center(
                        child: Text(
                          situation.busy
                              ? '음성 인식 중'
                              : '음성 자막 대기',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            color: _secondary,
                            fontSize: 24,
                            height: 1.6,
                          ),
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        itemCount: lines.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Text(
                            lines[lines.length - 1 - index],
                            key: index == 0
                                ? const ValueKey('final-caption')
                                : null,
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: index == 0 ? 27 : 20,
                              height: 1.5,
                              fontWeight: index == 0
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
                    onPressed: !available
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
