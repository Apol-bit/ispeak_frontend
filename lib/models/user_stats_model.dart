class UserStats {
  final int totalSessions;
  final double avgWPM;
  final double avgEnergy;
  final int totalFillers;

  UserStats({
    required this.totalSessions,
    required this.avgWPM,
    required this.avgEnergy,
    required this.totalFillers,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      totalSessions: json['totalSessions'] ?? 0,
      avgWPM: (json['avgWPM'] ?? 0).toDouble(),
      avgEnergy: (json['avgEnergy'] ?? 0).toDouble(),
      totalFillers: json['totalFillers'] ?? 0,
    );
  }
}