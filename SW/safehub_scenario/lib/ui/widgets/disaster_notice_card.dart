import 'package:flutter/material.dart';

/// API records remain visible independently of conversations and other events.
class DisasterNoticeCard extends StatelessWidget {
  const DisasterNoticeCard({
    super.key,
    required this.disaster,
    required this.status,
    required this.onDisaster,
    required this.onEvents,
    this.latestEvent,
  });
  final Map<String, dynamic>? disaster;
  final String status;
  final String? latestEvent;
  final VoidCallback onDisaster, onEvents;

  @override
  Widget build(BuildContext context) {
    const muted = Color(0xFF625E5A), accent = Color(0xFF8D2345);
    final region = '${disaster?['RCPTN_RGN_NM'] ?? ''}'.trim();
    final issued = '${disaster?['CRT_DT'] ?? ''}'.trim();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        key: const ValueKey('disaster-notice-card'),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE9E8E5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  color: accent,
                  size: 24,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '재난·알림',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(onPressed: onEvents, child: const Text('전체 알림')),
              ],
            ),
            Expanded(
              child: InkWell(
                onTap: onDisaster,
                borderRadius: BorderRadius.circular(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      disaster == null ? status : '재난 문자 · $status',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, color: muted),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${disaster?['MSG_CN'] ?? '재난 문자를 수신하면 여기에 표시됩니다.'}',
                          key: const ValueKey('disaster-message'),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 22,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    if (region.isNotEmpty || issued.isNotEmpty)
                      Text(
                        [region, issued].where((s) => s.isNotEmpty).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, color: muted),
                      ),
                  ],
                ),
              ),
            ),
            if (latestEvent != null) ...[
              const SizedBox(height: 8),
              Text(
                '최근 활동 · $latestEvent',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
