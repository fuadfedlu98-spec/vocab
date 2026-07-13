class Drill {
  final String id;
  final String title;
  final int difficulty;
  final String time;
  final String body;
  final String check;

  Drill({
    required this.id,
    required this.title,
    required this.difficulty,
    required this.time,
    required this.body,
    required this.check,
  });

  factory Drill.fromJson(Map<String, dynamic> json) {
    return Drill(
      id: json['id'] as String,
      title: json['title'] as String,
      difficulty: json['difficulty'] as int,
      time: json['time'] as String,
      body: json['body'] as String,
      check: json['check'] as String,
    );
  }
}

class Chapter {
  final int number;
  final String title;
  final String intro;
  final List<Drill> drills;
  final List<String> mistakes;
  final String mission;
  final List<String> checklist;

  Chapter({
    required this.number,
    required this.title,
    required this.intro,
    required this.drills,
    required this.mistakes,
    required this.mission,
    required this.checklist,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      number: json['number'] as int,
      title: json['title'] as String,
      intro: json['intro'] as String,
      drills: (json['drills'] as List)
          .map((d) => Drill.fromJson(d as Map<String, dynamic>))
          .toList(),
      mistakes: (json['mistakes'] as List).map((e) => e as String).toList(),
      mission: json['mission'] as String,
      checklist: (json['checklist'] as List).map((e) => e as String).toList(),
    );
  }
}
