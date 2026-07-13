import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import '../db/db_helper.dart';
import '../models/dictionary_entry.dart';

class DictionaryService {
  DictionaryService._internal();
  static final DictionaryService instance = DictionaryService._internal();

  /// Loads the bundled compact dictionary into SQLite the first time the
  /// app runs (subsequent launches skip this since the table is already
  /// populated). Safe to call on every startup.
  Future<void> ensureOfflineDictionaryLoaded() async {
    final alreadyLoaded = await DBHelper.instance.isDictionaryLoaded();
    if (alreadyLoaded) return;

    final raw =
        await rootBundle.loadString('assets/dictionary/dictionary_compact.json');
    final List<dynamic> data = json.decode(raw) as List<dynamic>;

    final rows = data.map((e) {
      final m = e as Map<String, dynamic>;
      return {
        'word': (m['word'] as String).toLowerCase().trim(),
        'part_of_speech': m['partOfSpeech'] as String? ?? '',
        'definition': m['definition'] as String? ?? '',
        'example': m['example'] as String? ?? '',
      };
    }).toList();

    await DBHelper.instance.bulkInsertDictionary(rows);
  }

  Future<List<DictionaryEntry>> searchOffline(String query) async {
    final rows = await DBHelper.instance.searchDictionary(query);
    return rows
        .map((r) => DictionaryEntry(
              word: r['word'] as String,
              partOfSpeech: (r['part_of_speech'] as String?) ?? '',
              definition: (r['definition'] as String?) ?? '',
              example: (r['example'] as String?) ?? '',
            ))
        .toList();
  }

  Future<DictionaryEntry?> lookupOffline(String word) async {
    final row = await DBHelper.instance.getDictionaryWord(word);
    if (row == null) return null;
    return DictionaryEntry(
      word: row['word'] as String,
      partOfSpeech: (row['part_of_speech'] as String?) ?? '',
      definition: (row['definition'] as String?) ?? '',
      example: (row['example'] as String?) ?? '',
    );
  }

  /// Optional online fallback (safe mode): only used when the word isn't
  /// found offline. Uses a free public API, no key required. Any failure
  /// (no internet, timeout, word not found) is caught and returns null
  /// rather than throwing, so it never breaks the offline app.
  Future<DictionaryEntry?> lookupOnline(String word) async {
    final w = word.trim().toLowerCase();
    if (w.isEmpty) return null;
    try {
      final uri = Uri.parse('https://api.dictionaryapi.dev/api/v2/entries/en/$w');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final List<dynamic> data = json.decode(response.body) as List<dynamic>;
      if (data.isEmpty) return null;

      final entry = data.first as Map<String, dynamic>;
      final meanings = entry['meanings'] as List<dynamic>?;
      if (meanings == null || meanings.isEmpty) return null;

      final firstMeaning = meanings.first as Map<String, dynamic>;
      final partOfSpeech = firstMeaning['partOfSpeech'] as String? ?? '';
      final definitions = firstMeaning['definitions'] as List<dynamic>?;
      if (definitions == null || definitions.isEmpty) return null;

      final firstDef = definitions.first as Map<String, dynamic>;
      final definition = firstDef['definition'] as String? ?? '';
      final example = firstDef['example'] as String? ?? '';

      if (definition.isEmpty) return null;

      return DictionaryEntry(
        word: (entry['word'] as String?) ?? w,
        partOfSpeech: partOfSpeech,
        definition: definition,
        example: example,
        fromOnline: true,
      );
    } catch (_) {
      // No internet, timeout, or malformed response - fail gracefully.
      return null;
    }
  }
}
