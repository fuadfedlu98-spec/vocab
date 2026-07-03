class Word {
  final int? id;
  final String word;
  final String meaning;
  final String? example;
  final int correctCount;
  final int wrongCount;
  final DateTime? lastSeen;
  final DateTime nextReviewTime;

  Word({
    this.id,
    required this.word,
    required this.meaning,
    this.example,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.lastSeen,
    DateTime? nextReviewTime,
  }) : nextReviewTime = nextReviewTime ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word': word,
      'meaning': meaning,
      'example': example,
      'correct_count': correctCount,
      'wrong_count': wrongCount,
      'last_seen': lastSeen?.millisecondsSinceEpoch,
      'next_review_time': nextReviewTime.millisecondsSinceEpoch,
    };
  }

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'] as int?,
      word: map['word'] as String,
      meaning: map['meaning'] as String,
      example: map['example'] as String?,
      correctCount: map['correct_count'] as int? ?? 0,
      wrongCount: map['wrong_count'] as int? ?? 0,
      lastSeen: map['last_seen'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_seen'] as int)
          : null,
      nextReviewTime: DateTime.fromMillisecondsSinceEpoch(
          map['next_review_time'] as int),
    );
  }

  Word copyWith({
    int? id,
    String? word,
    String? meaning,
    String? example,
    int? correctCount,
    int? wrongCount,
    DateTime? lastSeen,
    DateTime? nextReviewTime,
  }) {
    return Word(
      id: id ?? this.id,
      word: word ?? this.word,
      meaning: meaning ?? this.meaning,
      example: example ?? this.example,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      lastSeen: lastSeen ?? this.lastSeen,
      nextReviewTime: nextReviewTime ?? this.nextReviewTime,
    );
  }
}
