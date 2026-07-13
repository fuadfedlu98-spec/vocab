import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/dictionary_entry.dart';
import '../models/word.dart';
import '../services/tts_service.dart';

class DictionaryDetailScreen extends StatelessWidget {
  final DictionaryEntry entry;
  const DictionaryDetailScreen({super.key, required this.entry});

  Future<void> _addToMyWords(BuildContext context) async {
    final word = Word(
      word: entry.word,
      meaning: entry.definition,
      example: entry.example.isEmpty ? null : entry.example,
      nextReviewTime: DateTime.now(),
    );
    await DBHelper.instance.insertWord(word);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${entry.word}" added to your word list')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dictionary')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(entry.word,
                      style: Theme.of(context).textTheme.headlineMedium),
                ),
                if (entry.fromOnline)
                  Chip(
                    label: const Text('Online'),
                    backgroundColor:
                        Theme.of(context).colorScheme.secondaryContainer,
                  ),
              ],
            ),
            if (entry.partOfSpeech.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(entry.partOfSpeech,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 16),
            Text(entry.definition, style: Theme.of(context).textTheme.titleMedium),
            if (entry.example.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '"${entry.example}"',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => TtsService.instance.speak(entry.word),
              icon: const Icon(Icons.volume_up),
              label: const Text('Speak word'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _addToMyWords(context),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('Add to My Words'),
            ),
          ],
        ),
      ),
    );
  }
}
