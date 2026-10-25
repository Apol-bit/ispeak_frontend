num? performanceAverage(Map stats) {
  final score = stats['avgScore'];
  return eligibleSessionCount(stats) > 0 &&
          score is num &&
          score.isFinite &&
          score >= 0 &&
          score <= 100
      ? score
      : null;
}

int eligibleSessionCount(Map stats) {
  final value = stats['eligibleScoredSessions'];
  return value is num &&
          value.isFinite &&
          value >= 0 &&
          value == value.roundToDouble()
      ? value.toInt()
      : 0;
}

/// Older compact responses lack enough evidence to certify chart eligibility.
List<dynamic> performanceSessions(Map data) {
  if (data['statisticsVersion'] != 1 || data['sessions'] is! List) return [];
  return (data['sessions'] as List)
      .where(
        (row) =>
            row is Map &&
            ['overallScore', 'paceScore', 'clarityScore', 'energyScore'].every((
              key,
            ) {
              final value = row[key];
              return value is num &&
                  value.isFinite &&
                  value >= 0 &&
                  value <= 100;
            }),
      )
      .toList();
}
