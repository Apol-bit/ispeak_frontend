String fillerFeedback(Map<String, dynamic> session) {
  final raw = session['fillerAnalysis'];
  final detail = raw is Map && raw['version'] == 1 ? raw : null;
  final available = detail != null
      ? detail['available'] == true
      : session['fillerAnalysisAvailable'] == true;
  if (!available) return 'Filler-word analysis unavailable.';
  final value = detail?['count'] ?? session['fillerWordCount'];
  if (value is! num || value < 0 || !value.isFinite) {
    return 'Filler-word analysis unavailable.';
  }
  final candidates = detail?['candidateCount'];
  final count = value.toInt();
  var message = count > 0
      ? '$count confirmed filler spans (grouped detections).'
      : candidates is num && candidates > 0
      ? 'No confirmed fillers; possible fillers need review.'
      : 'No accepted filler spans detected; this does not guarantee filler-free speech.';
  if (count > 0 && candidates is num && candidates > 0) {
    message += ' Other possible fillers need review.';
  }
  final words = detail?['words'];
  if (count > 0 && words is List) {
    final labels = words
        .whereType<Map>()
        .map((w) => w['word'])
        .whereType<String>()
        .take(5)
        .join(', ');
    if (labels.isNotEmpty) message += ' Detected: $labels.';
  }
  final review = detail?['candidates'];
  if (review is List) {
    final labels = review
        .whereType<Map>()
        .map((w) => w['word'])
        .whereType<String>()
        .take(5)
        .join(', ');
    if (labels.isNotEmpty) {
      message += ' Review matches (may be grammatical): $labels.';
    }
  }
  final coverage = detail?['coverage'];
  if (coverage is Map && coverage['status'] == 'mismatch') {
    message +=
        ' Transcript coverage differs; filler analysis may be incomplete.';
  } else if (detail == null ||
      coverage is! Map ||
      coverage['status'] != 'matched') {
    message += ' Transcript coverage was not verified.';
  }
  return message;
}
