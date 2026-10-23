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

  Widget _detail(String label, String value) => Expanded(
    child: Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF686C73)),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: service,
    builder: (context, _) {
      final flow = service.flow;
      final incident = flow.active;
      final simulated = service.scenarioTestMode;
      return Container(
        height: 248,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: simulated ? const Color(0xFFFFF1D6) : const Color(0xFFEEECE8),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text(
                  '우리 집 상황',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                if (simulated)
                  const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Text(
                      '테스트 · 실제 장치 명령 없음',
                      style: TextStyle(
                        color: Color(0xFF8C5300),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const Spacer(),
                if (simulated)
                  TextButton(
                    onPressed: service.endScenarioTest,
                    child: const Text('테스트 종료'),
                  ),
                TextButton(
                  onPressed: () => showScenarioTest(context, service),
                  child: const Text('시나리오 테스트'),
                ),
              ],
            ),
            Text(
              incident?.title ??
                  (flow.lastAcknowledged != null
                      ? '알림 확인을 기록했어요. 위험 해제 여부는 별도 확인이 필요해요.'
                      : '방송·재난·센서 정보를 확인하며 새로운 알림을 기다려요.'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 9),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detail(
                  '판단 근거',
                  incident == null
                      ? flow.observation
                      : '${incident.relevance} · ${incident.evidence}',
                ),
                _detail(
                  '알림 전달',
                  incident?.delivery ?? '화면 수신 대기 · 장치 동작을 확인한 상태가 아닙니다.',
                ),
                _detail(
                  '사용자 응답',
                  incident == null
                      ? flow.lastAcknowledged?.response ?? '응답을 요청한 알림 없음'
                      : incident.response.isEmpty
                      ? '확인 대기 · 움직임만으로 확인 여부를 판단하지 않아요.'
                      : incident.response,
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    incident?.nextAction ?? service.sensorStatus,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                if (flow.pendingCount > 0) Text('대기 ${flow.pendingCount}건  '),
                if (incident != null) ...[
                  TextButton(
                    onPressed: onAcknowledge,
                    child: const Text('확인했어요'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: service.openHelp,
                    child: const Text('상황 응답 · 도움'),
                  ),
                ] else
                  TextButton(
                    onPressed: service.toggleVoiceChat,
                    child: Text(
                      service.voiceChatEnabled ? 'AI 대화 끄기' : 'AI에게 말하기',
                    ),
                  ),
              ],
            ),
            Text(
              service.voiceReply.isNotEmpty && incident == null
                  ? '질문: ${service.voiceQuestion} · ${service.voiceReply}'
                  : service.busy
                  ? 'AI가 근거를 정리하고 있어요. 경보·응답은 바로 사용할 수 있어요.'
                  : service.assessmentStale
                  ? 'AI 설명 대기 · 알림과 응답은 AI 연결 없이도 작동합니다.'
                  : 'AI 참고 안내: ${service.assessment!.summary}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Color(0xFF686C73)),
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
