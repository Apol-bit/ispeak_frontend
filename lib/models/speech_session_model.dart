class SpeechSession {
  final String id;
  final String userId;
  final String audioPath;
  final double wpmScore;
  final int fillerWordCount;
  final double energyScore;
  final String transcription;
  final DateTime createdAt;

  SpeechSession({
    required this.id,
    required this.userId,
    required this.audioPath,
    required this.wpmScore,
    required this.fillerWordCount,
    required this.energyScore,
    required this.transcription,
    required this.createdAt,
  });

  // "Translator" that converts MongoDB JSON into Flutter Objects
  factory SpeechSession.fromJson(Map<String, dynamic> json) {
    return SpeechSession(
      id: json['_id'],
      userId: json['userId'],
      audioPath: json['audioPath'],
      wpmScore: (json['wpmScore'] ?? 0).toDouble(),
      fillerWordCount: json['fillerWordCount'] ?? 0,
      energyScore: (json['energyScore'] ?? 0).toDouble(),
      transcription: json['transcription'] ?? "",
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}