import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class HardwareTestDialog extends StatefulWidget {
  const HardwareTestDialog({super.key, required this.connected,
    required this.publishAlert, required this.publishFan, required this.classifierUri,
    this.client, this.publishCurtain});
  final bool connected;
  final bool Function(String device, String action) publishAlert;
  final bool Function(bool powerOn) publishFan;
  final bool Function(String action)? publishCurtain;
  final Uri classifierUri;
  final http.Client? client;
  @override State<HardwareTestDialog> createState() => _HardwareTestDialogState();
}

class _HardwareTestDialogState extends State<HardwareTestDialog> {
  final text = TextEditingController(text: '화재가 발생했습니다. 신속히 대피하세요.');
  String result = '실제 LED·진동·팬·커튼을 제어합니다.';
  bool busy = false;
  static const accent = Color(0xFF8D2345);

  void alarm(String name) {
    final led = widget.publishAlert('led', 'blink');
    final vibration = widget.publishAlert('bedshaker', 'on');
    setState(() => result = '$name 모의 입력 · LED ${led ? "명령 제출" : "전송 실패"}, '
        '진동 ${vibration ? "명령 제출" : "전송 실패"}. 브리지 실행 중 최대 10초 뒤 종료합니다. 실제 장치를 확인하세요.');
  }

  void stop({bool fan = false}) {
    final led = widget.publishAlert('led', 'off');
    final vibration = widget.publishAlert('bedshaker', 'off');
    final power = !fan || widget.publishFan(false);
    final curtain = !fan || widget.publishCurtain == null || widget.publishCurtain!.call('stop');
    setState(() => result = led && vibration && power && curtain
        ? '${fan ? "팬·LED·진동" : "LED·진동"} 끄기 명령 제출 · 실제 장치를 확인하세요.'
        : '일부 명령 전송 실패 · 연결을 확인하세요.');
  }

  Future<void> classify() async {
    if (text.text.trim().isEmpty || busy) return;
    setState(() { busy = true; result = '입력한 문장을 fastText와 문맥 규칙으로 확인 중'; });
    final client = widget.client ?? http.Client();
    try {
      final response = await client.post(widget.classifierUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text.text.trim()})).timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) throw const FormatException('분류 서버 응답 오류');
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (!mounted) return;
      if (data is! Map<String, dynamic> || data['hazard'] is! bool) throw const FormatException('잘못된 분류 응답');
      if (data['hazard'] == true) {
        alarm('화재 방송');
      } else {
        setState(() => result = '위험 작동 보류 · ${data["reason"] ?? "근거 부족"}. '
            'LED·진동을 새로 켜지 않습니다. 기존 경보를 해제하지는 않아요.');
      }
    } catch (_) {
      if (mounted) setState(() => result = 'fastText 서버 연결 실패 · 장치 명령은 보내지 않았어요.');
    } finally {
      if (widget.client == null) client.close();
      if (mounted) setState(() => busy = false);
    }
  }

  Widget button(String label, VoidCallback action, {bool primary = false}) => SizedBox(
    height: 56,
    child: primary ? FilledButton(onPressed: widget.connected && !busy ? action : null,
      style: FilledButton.styleFrom(backgroundColor: accent), child: Text(label, style: const TextStyle(fontSize: 18)))
      : OutlinedButton(onPressed: widget.connected && !busy ? action : null, child: Text(label, style: const TextStyle(fontSize: 18))));

  @override Widget build(BuildContext context) => Dialog(
    backgroundColor: const Color(0xFFFCFBFA),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: Container(width: 1000, padding: const EdgeInsets.all(28),
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height - 72),
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [const Icon(Icons.science_outlined, color: accent), const SizedBox(width: 12),
          const Expanded(child: Text('실제 장치 테스트', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800))),
          IconButton(tooltip: '장치 테스트 닫기', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]),
        const SizedBox(height: 8),
        Text(widget.connected ? '모의 상황으로 실제 장치가 작동합니다. 119 신고·실제 재난 접수·CSI 실측 시험은 아닙니다.'
            : 'MQTT 연결을 먼저 확인해 주세요.', style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 20),
        TextField(controller: text, minLines: 2, maxLines: 3, style: const TextStyle(fontSize: 22),
          decoration: const InputDecoration(labelText: '직접 입력할 방송 문장', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        button('문장 판별 후 LED·진동 시험', () => classify(), primary: true),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 12, children: [
          button('화재 경보 10초', () => alarm('화재')),
          button('재난 경보 10초', () => alarm('재난')),
          button('낙상 의심 경보 10초', () => alarm('낙상 의심')),
          button('팬 켜기', () { final sent=widget.publishFan(true); setState(() => result=sent?'팬 켜기 명령 제출':'팬 명령 전송 실패'); }),
          button('팬 끄기', () { final sent=widget.publishFan(false); setState(() => result=sent?'팬 끄기 명령 제출':'팬 명령 전송 실패'); }),
          button('LED·진동 끄기', () => stop()),
          button('팬·LED·진동 끄고 커튼 정지', () => stop(fan: true)),
          if (widget.publishCurtain != null)
            for (final entry in {'up': '커튼 올림', 'down': '커튼 내림', 'stop': '커튼 정지'}.entries)
              button(entry.value, () {
                final sent = widget.publishCurtain!(entry.key);
                setState(() => result = sent ? '${entry.value} 명령 제출 · 이동은 1.5초 제한' : '커튼 명령 전송 실패');
              }),
        ]),
        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(
          color: const Color(0xFFF4E8EC), borderRadius: BorderRadius.circular(14)),
          child: Text(result, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600))),
        const SizedBox(height: 12),
        const Text('창을 닫아도 팬은 유지됩니다. 브리지 실행 중 LED·진동은 최대 10초입니다. 커튼 제한은 펌웨어 확인이 필요합니다. 팬은 별도로 꺼주세요.',
          style: TextStyle(fontSize: 16, color: Color(0xFF686C73))),
      ]))),
  );

  @override void dispose() { text.dispose(); super.dispose(); }
}
