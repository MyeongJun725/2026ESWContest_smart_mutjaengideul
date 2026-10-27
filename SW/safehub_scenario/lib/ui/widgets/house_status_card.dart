import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../core/house_scenario.dart';
import '../../services/situation_service.dart';

class HouseStatusCard extends StatelessWidget {
  const HouseStatusCard({
    super.key,
    required this.service,
    required this.onAcknowledge,
    this.developerTools = AppConfig.developerTools,
  });
  final bool developerTools;
  final SituationService service;
  final VoidCallback onAcknowledge;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: service,
    builder: (context, _) {
      final incident = service.flow.active;
      final previous = service.flow.lastAcknowledged;
      final title = incident != null
          ? (incident.kind == HouseScenario.assistance
                ? '도움 요청을 확인해 주세요'
                : '새 알림이 도착했어요')
          : previous != null
          ? '알림을 확인했어요'
          : '새 알림 없음';
      final detail =
          incident?.evidence ??
          (previous != null
              ? '필요하면 내용을 다시 볼 수 있어요.'
              : '수어 인식 · 음성 자막 · 재난 알림');
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: incident != null || service.scenarioTestMode
              ? const Color(0xFFFFF3D6)
              : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE5DFD8)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x063E2830),
              blurRadius: 20,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: incident == null
                    ? const Color(0xFFF6ECEF)
                    : const Color(0xFFFFE7AE),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                incident == null
                    ? Icons.home_outlined
                    : Icons.notifications_active_outlined,
                color: const Color(0xFF8D2345),
                size: 28,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '우리 집',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF625E5A),
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    service.scenarioTestMode
                        ? (service.scenarioActuators
                              ? '시연 입력 · 실제 LED·진동 연동'
                              : '화면 테스트 · 실제 장치 작동 없음')
                        : detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 20,
                      color: Color(0xFF625E5A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            if (service.scenarioTestMode)
              TextButton(
                onPressed: service.endScenarioTest,
                child: const Text(
                  '시연 종료',
                  style: TextStyle(fontFamily: 'Pretendard', fontSize: 20),
                ),
              ),
            if (developerTools)
              TextButton(
                onPressed: () => showScenarioTest(context, service),
                child: const Text(
                  '시나리오 테스트',
                  style: TextStyle(fontFamily: 'Pretendard', fontSize: 20),
                ),
              ),
            if (incident != null)
              TextButton(
                onPressed: service.openHelp,
                child: const Text(
                  '상황 응답 · 도움',
                  style: TextStyle(fontFamily: 'Pretendard', fontSize: 20),
                ),
              ),
            IconButton(
              tooltip: '상황 상세 보기',
              icon: const Icon(Icons.expand_more),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('확인한 내용'),
                  content: SizedBox(
                    width: 650,
                    child: SingleChildScrollView(
                      child: Text(
                        [
                          detail,
                          service.sensorStatus,
                          if (incident != null) incident.delivery,
                          if (!service.assessmentStale)
                            service.assessment!.summary,
                          if (previous != null) '알림 확인은 위험 해제를 의미하지 않아요.',
                        ].join('\n\n'),
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 22,
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('닫기'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> showScenarioTest(BuildContext context, SituationService service) =>
    showDialog<void>(
      context: context,
      builder: (_) => _ScenarioTestDialog(service: service),
    );

class _ScenarioTestDialog extends StatefulWidget {
  const _ScenarioTestDialog({required this.service});
  final SituationService service;
  @override
  State<_ScenarioTestDialog> createState() => _ScenarioTestDialogState();
}

class _ScenarioTestDialogState extends State<_ScenarioTestDialog> {
  static const presets = {
    HouseScenario.broadcast: '아파트 안내방송입니다. 화재가 발생했습니다. 대피 방송을 확인해 주세요.',
    HouseScenario.disaster: '시연지역에 지진 관련 재난 알림이 발행됐습니다. 안내 내용을 확인해 주세요.',
    HouseScenario.assistance: '가족 쓰러짐 의심 신호가 접수되었습니다. 실제 상태는 아직 확인되지 않았습니다.',
  };
  HouseScenario kind = HouseScenario.broadcast;
  late final text = TextEditingController(text: presets[kind]);
  String error = '';
  bool actuate = true;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('세 가지 시나리오 테스트'),
    content: SizedBox(
      width: 600,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '선택한 상황으로 경고 화면과 LED·진동을 함께 시험합니다. 실제 재난 접수·CSI 검출·119 신고는 아닙니다.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<HouseScenario>(
              value: kind,
              decoration: const InputDecoration(labelText: '시나리오 선택'),
              items: const [
                DropdownMenuItem(
                  value: HouseScenario.broadcast,
                  child: Text('① 아파트 안내방송'),
                ),
                DropdownMenuItem(
                  value: HouseScenario.disaster,
                  child: Text('② 재난 API 알림'),
                ),
                DropdownMenuItem(
                  value: HouseScenario.assistance,
                  child: Text('③ 가족 쓰러짐·도움 요청'),
                ),
              ],
              onChanged: (value) {
                if (value != null)
                  setState(() {
                    kind = value;
                    text.text = presets[value]!;
                  });
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('실제 LED·진동 연동'),
              subtitle: const Text('켜면 선택 즉시 장치 작동 · 끄면 화면만 시험'),
              value: actuate,
              onChanged: (value) => setState(() => actuate = value),
            ),
            TextField(
              controller: text,
              maxLines: 4,
              maxLength: 600,
              decoration: const InputDecoration(labelText: '테스트 입력 · 직접 수정 가능'),
            ),
            const Text(
              '진행: 화면 알림 → 상황 응답 · 도움 → 터치 또는 테스트 수어 → 도움 요청 문안 → 확인했어요',
            ),
            if (error.isNotEmpty)
              Text(
                error,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  color: Colors.red,
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('닫기'),
      ),
      FilledButton(
        onPressed: () {
          if (text.text.trim().isEmpty) {
            setState(() => error = '입력 문장을 적어주세요.');
            return;
          }
          if (!widget.service.startScenarioTest(
            kind,
            text.text.trim(),
            actuate: actuate,
          )) {
            setState(() => error = '실제 알림이 있습니다. 먼저 확인한 뒤 테스트를 시작하세요.');
            return;
          }
          Navigator.pop(context);
        },
        child: Text(actuate ? '화면·장치 함께 실행' : '화면만 실행'),
      ),
    ],
  );
}
