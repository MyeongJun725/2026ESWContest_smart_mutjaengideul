/// Keep the current AI interpretation as one item, alongside real events.
bool updateInterpretation(
  List<Map<String, dynamic>> events,
  String reply,
  bool sign, {
  DateTime? now,
  String input = '',
}) {
  final index = events.indexWhere(
    (event) =>
        event['event'] == 'llm_conversation' &&
        event['sign'] == sign &&
        ('${event['input'] ?? ''}'.isNotEmpty == input.isNotEmpty),
  );
  String normalized(Object? value) =>
      '$value'.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (index >= 0 &&
      normalized(events[index]['reply']) == normalized(reply) &&
      normalized(events[index]['input'] ?? '') == normalized(input))
    return false;
  final value = <String, dynamic>{
    'event': 'llm_conversation',
    'location': 'all',
    'reply': reply,
    if (input.isNotEmpty) 'input': input,
    'sign': sign,
    '_receivedAt': (now ?? DateTime.now()).toIso8601String(),
  };
  if (index >= 0) {
    events[index] = value;
  } else {
    events.insert(0, value);
  }
  while (events.length > 30) {
    events.removeLast();
  }
  return true;
}
