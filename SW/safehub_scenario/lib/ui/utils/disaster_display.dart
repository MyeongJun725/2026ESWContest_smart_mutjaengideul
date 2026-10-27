enum DisasterSeverity { notice, emergency, critical }

DisasterSeverity getDisasterSeverity(Map<String, dynamic> disaster) {
  final step = disaster['EMRG_STEP_NM']?.toString().trim() ?? '';

  switch (step) {
    case '위급재난':
      return DisasterSeverity.critical;

    case '긴급재난':
      return DisasterSeverity.emergency;

    case '안전안내':
    default:
      return DisasterSeverity.notice;
  }
}
