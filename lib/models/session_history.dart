List<Map<String, dynamic>> newestSessions(
  Iterable<dynamic> sessions, {
  int? limit,
}) {
  final sorted = sessions
      .map((session) => Map<String, dynamic>.from(session as Map))
      .toList();
  DateTime date(Map session) =>
      DateTime.tryParse(session['createdAt']?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);
  sorted.sort((a, b) => date(b).compareTo(date(a)));
  return limit == null ? sorted : sorted.take(limit).toList();
}
