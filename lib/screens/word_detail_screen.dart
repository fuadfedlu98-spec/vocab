import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/word.dart';
import '../services/tts_service.dart';

class WordDetailScreen extends StatefulWidget {
  final int wordId;
  const WordDetailScreen({super.key, required this.wordId});

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  Word? _word;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final w = await DBHelper.instance.getWordById(widget.wordId);
    if (!mounted) return;
    setState(() => _word = w);
  }

  Future<void> _delete() async {
    await DBHelper.instance.deleteWord(widget.wordId);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final w = _word;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Word Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: w == null ? null : _delete,
          ),
        ],
      ),
      body: w == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(w.word, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(w.meaning, style: Theme.of(context).textTheme.titleMedium),
                  if (w.example != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      w.example!,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => TtsService.instance.speak(w.word),
                    icon: const Icon(Icons.volume_up),
                    label: const Text('Speak word'),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Correct: ${w.correctCount}   Wrong: ${w.wrongCount}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
    );
  }
}
