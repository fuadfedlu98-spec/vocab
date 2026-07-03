import 'dart:math';
import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/word.dart';

enum QuestionType { wordToMeaning, meaningToWord }

class _QuizQuestion {
  final Word target;
  final QuestionType type;
  final List<String> options;
  final String correctOption;

  _QuizQuestion({
    required this.target,
    required this.type,
    required this.options,
    required this.correctOption,
  });
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final _rand = Random();

  bool _loading = true;
  List<_QuizQuestion> _questions = [];
  int _index = 0;
  int _score = 0;
  String? _selected;
  bool _answered = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _buildSession();
  }

  Future<void> _buildSession() async {
    final allWords = await DBHelper.instance.getAllWords();

    if (allWords.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    final dueWords = await DBHelper.instance.getDueWords();

    // Session size: 5-10 questions, capped by available words.
    final sessionSize = min(
      allWords.length,
      5 + _rand.nextInt(6), // 5..10
    );

    // Prioritize due words, then fill with random words from full set.
    final selected = <Word>[];
    final dueShuffled = List<Word>.from(dueWords)..shuffle(_rand);
    selected.addAll(dueShuffled.take(sessionSize));

    if (selected.length < sessionSize) {
      final remaining = allWords
          .where((w) => !selected.any((s) => s.id == w.id))
          .toList()
        ..shuffle(_rand);
      selected.addAll(remaining.take(sessionSize - selected.length));
    }

    selected.shuffle(_rand);

    final questions = selected.map((w) => _buildQuestion(w, allWords)).toList();

    setState(() {
      _questions = questions;
      _loading = false;
    });
  }

  _QuizQuestion _buildQuestion(Word target, List<Word> allWords) {
    final type = _rand.nextBool()
        ? QuestionType.wordToMeaning
        : QuestionType.meaningToWord;

    final distractPool = allWords.where((w) => w.id != target.id).toList()
      ..shuffle(_rand);

    if (type == QuestionType.wordToMeaning) {
      final correct = target.meaning;
      final options = <String>{correct};
      for (final w in distractPool) {
        if (options.length >= 4) break;
        options.add(w.meaning);
      }
      final optionList = options.toList()..shuffle(_rand);
      return _QuizQuestion(
        target: target,
        type: type,
        options: optionList,
        correctOption: correct,
      );
    } else {
      final correct = target.word;
      final options = <String>{correct};
      for (final w in distractPool) {
        if (options.length >= 4) break;
        options.add(w.word);
      }
      final optionList = options.toList()..shuffle(_rand);
      return _QuizQuestion(
        target: target,
        type: type,
        options: optionList,
        correctOption: correct,
      );
    }
  }

  Future<void> _answer(String choice) async {
    if (_answered) return;
    setState(() {
      _selected = choice;
      _answered = true;
    });

    final q = _questions[_index];
    final isCorrect = choice == q.correctOption;
    final now = DateTime.now();

    Word updated;
    if (isCorrect) {
      _score++;
      // Longer interval as correct_count grows (simple spaced repetition).
      final newCorrect = q.target.correctCount + 1;
      final days = min(30, pow(2, newCorrect).toInt()); // 2,4,8,...capped at 30
      updated = q.target.copyWith(
        correctCount: newCorrect,
        lastSeen: now,
        nextReviewTime: now.add(Duration(days: days)),
      );
    } else {
      updated = q.target.copyWith(
        wrongCount: q.target.wrongCount + 1,
        lastSeen: now,
        nextReviewTime: now.add(const Duration(minutes: 10)),
      );
    }

    await DBHelper.instance.updateWord(updated);
  }

  void _next() {
    if (_index + 1 >= _questions.length) {
      setState(() => _finished = true);
    } else {
      setState(() {
        _index++;
        _selected = null;
        _answered = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz')),
        body: const Center(child: Text('Add some words first')),
      );
    }

    if (_finished) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz Complete')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Score: $_score / ${_questions.length}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      );
    }

    final q = _questions[_index];
    final prompt =
        q.type == QuestionType.wordToMeaning ? q.target.word : q.target.meaning;
    final promptLabel = q.type == QuestionType.wordToMeaning
        ? 'What does this word mean?'
        : 'Which word matches this meaning?';

    return Scaffold(
      appBar: AppBar(title: Text('Question ${_index + 1} / ${_questions.length}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(promptLabel, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(prompt, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            ...q.options.map((opt) {
              Color? color;
              if (_answered) {
                if (opt == q.correctOption) {
                  color = Colors.green.shade200;
                } else if (opt == _selected) {
                  color = Colors.red.shade200;
                }
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FilledButton.tonal(
                  style: color != null
                      ? FilledButton.styleFrom(backgroundColor: color)
                      : null,
                  onPressed: _answered ? null : () => _answer(opt),
                  child: Text(opt, textAlign: TextAlign.center),
                ),
              );
            }),
            const Spacer(),
            if (_answered)
              FilledButton(
                onPressed: _next,
                child: Text(
                  _index + 1 >= _questions.length ? 'Finish' : 'Next',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
