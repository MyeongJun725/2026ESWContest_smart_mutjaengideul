import 'package:flutter/material.dart';

/// The last recognized word stays adjacent to the camera, including on disconnect.
class SignResultStrip extends StatelessWidget {
  const SignResultStrip({
    super.key,
    required this.sign,
    required this.connected,
    required this.onConversation,
  });
  final String sign;
  final bool connected;
  final VoidCallback onConversation;

  @override
  Widget build(BuildContext context) {
    final waiting = sign.trim().isEmpty || sign == '수어 인식 대기 중';
    return Container(
      key: const ValueKey('sign-result-strip'),
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFFFAF4F5),
        border: Border(top: BorderSide(color: Color(0xFFE8D7DD))),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  !connected && !waiting ? '최근 인식 결과 · 카메라 연결 끊김' : '수어 인식 결과',
                  style: const TextStyle(
                    fontSize: 17,
                    color: Color(0xFF625E5A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  waiting ? '입력 대기' : sign.trim(),
                  key: const ValueKey('sign-result-text'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: waiting ? 32 : 40,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: waiting
                        ? const Color(0xFF625E5A)
                        : const Color(0xFF8D2345),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          TextButton.icon(
            onPressed: onConversation,
            icon: const Icon(Icons.chat_bubble_outline, size: 22),
            label: const Text('수어 대화', style: TextStyle(fontSize: 20)),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8D2345),
              minimumSize: const Size(120, 52),
            ),
          ),
        ],
      ),
    );
  }
}
