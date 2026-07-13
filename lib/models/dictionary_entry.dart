class DictionaryEntry {
  final String word;
  final String partOfSpeech;
  final String definition;
  final String example;
  final bool fromOnline;

  DictionaryEntry({
    required this.word,
    required this.partOfSpeech,
    required this.definition,
    required this.example,
    this.fromOnline = false,
  });

  factory DictionaryEntry.fromJson(Map<String, dynamic> json,
      {bool fromOnline = false}) {
    return DictionaryEntry(
      word: json['word'] as String,
      partOfSpeech: (json['partOfSpeech'] as String?) ?? '',
      definition: (json['definition'] as String?) ?? '',
      example: (json['example'] as String?) ?? '',
      fromOnline: fromOnline,
    );
  }
}
