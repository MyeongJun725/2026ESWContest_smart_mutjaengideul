import 'package:flutter/material.dart';
import '../../core/house_scenario.dart';
import '../../services/situation_service.dart';

class HouseStatusCard extends StatelessWidget {
  const HouseStatusCard({
    super.key,
    required this.service,
    required this.onAcknowledge,
  });
  final SituationService service;
  final VoidCallback onAcknowledge;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: service,
    builder: (context, _) {
      final incident = service.flow.active;
      final previous = service.flow.lastAcknowledged;
      final title =
          incident != null
              ? (incident.kind == HouseScenario.assistance
                  ? '도움 요청을 확인해 주세요'
                  : '새 알림이 도착했어요')
              : previous != null
              ? '알림을 확인했어요'
              : '새로운 알림이 없어요';
      final detail =
          incident?.evidence ??
          (previous != null
              ? '필요하면 내용을 다시 볼 수 있어요.'
              : '필요하면 수어 또는 터치로 도움을 요청하세요.');
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color:
              incident != null || service.scenarioTestMode
                  ? const Color(0xFFFFF3D6)
                  : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE5DFD8)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    service.scenarioTestMode
                        ? '시연 모드 · 실제 장치는 작동하지 않아요.'
                      : detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
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
                child: const Text('시연 종료', style: TextStyle(fontSize: 20)),
              ),
            TextButton(
              onPressed: () => showScenarioTest(context, service),
              child: const Text('시나리오 테스트', style: TextStyle(fontSize: 20)),
            ),
            if (incident != null)
              TextButton(
                onPressed: service.openHelp,
                child: const Text('상황 응답 · 도움', style: TextStyle(fontSize: 20)),
              ),
            IconButton(
              tooltip: '상황 상세 보기',
              icon: const Icon(Icons.expand_more),
              onPressed:
                  () => showDialog<void>(
                    context: context,
                    builder:
                        (context) => AlertDialog(
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
                                  if (previous != null)
                                    '알림 확인은 위험 해제를 의미하지 않아요.',
                                ].join('\n\n'),
                                style: const TextStyle(fontSize: 22),
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
              '화면·응답 흐름만 시험합니다. MQTT 전송, 실제 재난 등록, CSI 기록·학습은 하지 않습니다.',
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
              Text(error, style: const TextStyle(color: Colors.red)),
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
          if (!widget.service.startScenarioTest(kind, text.text.trim())) {
            setState(() => error = '실제 알림이 있습니다. 먼저 확인한 뒤 테스트를 시작하세요.');
            return;
          }
          Navigator.pop(context);
        },
        child: const Text('화면 테스트 실행'),
      ),
    ],
  );
}
