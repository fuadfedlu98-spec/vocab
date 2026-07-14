import 'dart:convert';
import 'package:http/http.dart' as http;
import '../db/db_helper.dart';
import '../models/chapter.dart';

class AIService {
  AIService._internal();
  static final AIService instance = AIService._internal();

  static const _model = 'claude-haiku-4-5-20251001';
  static const _apiUrl = 'https://api.anthropic.com/v1/messages';

  Future<String?> getApiKey() => DBHelper.instance.getSetting('ai_api_key');

  Future<void> setApiKey(String key) =>
      DBHelper.instance.setSetting('ai_api_key', key.trim());

  /// Builds a short, honest summary of the learner's real local progress
  /// (completed chapters, weakest words) to give the tutor genuine context
  /// instead of pretending to "remember" things it was never told.
  Future<String> _buildLearnerContext() async {
    final weakWords = await DBHelper.instance.getWeakWords(limit: 10);
    final unlocked = await DBHelper.instance.getHighestUnlockedChapter();
    final xp = await DBHelper.instance.getTotalXp();

    final weakList = weakWords.isEmpty
        ? 'none tracked yet'
        : weakWords.map((w) => w.word).join(', ');

    return '''
Learner progress (from their local app data, use this to personalize):
- Currently up to chapter $unlocked of 39 in an English fluency course.
- Total XP earned: $xp.
- Words they get wrong most often in vocab quizzes: $weakList.
Use this to focus practice on their actual weak spots. Don't invent facts about them beyond what's given here.
''';
  }

  /// Sends a chat message to the AI tutor, with recent conversation history
  /// and real learner context. Returns the reply text, or an error message
  /// (never throws) so the UI can always show something sensible.
  Future<String> sendTutorMessage(String userMessage) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return '__NO_API_KEY__';
    }

    final context = await _buildLearnerContext();
    final history = await DBHelper.instance.getRecentAiMessages(limit: 20);

    final messages = <Map<String, String>>[];
    for (final m in history) {
      messages.add({'role': m['role'] as String, 'content': m['content'] as String});
    }
    messages.add({'role': 'user', 'content': userMessage});

    final systemPrompt = '''
You are a friendly, encouraging English speaking and writing tutor and conversation partner, for a learner working through a structured fluency course.
$context
Correct mistakes gently, explain briefly why, then keep the conversation going with a natural follow-up question. Keep replies conversational and not too long (a few sentences), like a real chat with a tutor, not an essay. This is a text chat (not audio), so you cannot hear pronunciation directly - if pronunciation comes up, describe the mouth/sound mechanics in words instead.
''';

    try {
      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
            },
            body: json.encode({
              'model': _model,
              'max_tokens': 500,
              'system': systemPrompt,
              'messages': messages,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 401) {
        return '__INVALID_API_KEY__';
      }
      if (response.statusCode != 200) {
        return "Sorry, I couldn't reach the AI tutor right now (error ${response.statusCode}). Check your internet connection and try again.";
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final content = data['content'] as List<dynamic>?;
      if (content == null || content.isEmpty) {
        return "Sorry, I didn't get a usable reply. Try again?";
      }
      final text = (content.first as Map<String, dynamic>)['text'] as String?;
      final reply = text?.trim() ?? "Sorry, I didn't get a usable reply. Try again?";

      await DBHelper.instance.insertAiMessage('user', userMessage);
      await DBHelper.instance.insertAiMessage('assistant', reply);

      return reply;
    } catch (_) {
      return "Couldn't reach the AI tutor - check your internet connection and try again.";
    }
  }

  /// Generates extra practice questions for a chapter from its real content.
  /// Returns a list of {question, answer} maps, or an empty list on failure.
  Future<List<Map<String, String>>> generateChapterQuestions(Chapter chapter) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) return [];

    final drillSummary = chapter.drills
        .map((d) => '${d.id} ${d.title}: ${d.check}')
        .join('\n');

    final prompt = '''
Based on this English-fluency course chapter, write 5 short practice questions that test understanding and application of its drills (not just recall of trivia). Mix question types: some should ask the learner to apply a technique, some should ask them to spot a mistake, some should be short open-ended prompts they'd answer in their own words.

Chapter ${chapter.number}: ${chapter.title}
${chapter.intro}

Drills:
$drillSummary

Mission: ${chapter.mission}

Respond ONLY with a JSON array, no other text, in this exact format:
[{"question": "...", "answer": "..."}, ...]
''';

    try {
      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
            },
            body: json.encode({
              'model': _model,
              'max_tokens': 1024,
              'messages': [
                {'role': 'user', 'content': prompt}
              ],
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) return [];

      final data = json.decode(response.body) as Map<String, dynamic>;
      final content = data['content'] as List<dynamic>?;
      if (content == null || content.isEmpty) return [];
      var text = (content.first as Map<String, dynamic>)['text'] as String? ?? '';
      text = text.trim();
      // Strip accidental markdown code fences.
      text = text.replaceAll(RegExp(r'^```json'), '').replaceAll(RegExp(r'```$'), '').trim();

      final List<dynamic> parsed = json.decode(text) as List<dynamic>;
      return parsed
          .map((e) => {
                'question': (e['question'] as String?) ?? '',
                'answer': (e['answer'] as String?) ?? '',
              })
          .where((e) => e['question']!.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
