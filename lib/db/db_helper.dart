import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/word.dart';
import '../models/note.dart';

class DBHelper {
  DBHelper._internal();
  static final DBHelper instance = DBHelper._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'vocab_app.db');

    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE words (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word TEXT NOT NULL,
            meaning TEXT NOT NULL,
            example TEXT,
            correct_count INTEGER NOT NULL DEFAULT 0,
            wrong_count INTEGER NOT NULL DEFAULT 0,
            last_seen INTEGER,
            next_review_time INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await _createV2Tables(db);
        await _createV3Tables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createV2Tables(db);
        }
        if (oldVersion < 3) {
          await _createV3Tables(db);
        }
      },
    );
  }

  Future<void> _createV3Tables(Database db) async {
    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE ai_chat_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createV2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE chapter_progress (
        chapter_number INTEGER PRIMARY KEY,
        checked_items TEXT NOT NULL DEFAULT '',
        completed INTEGER NOT NULL DEFAULT 0,
        completed_at INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE dictionary (
        word TEXT PRIMARY KEY,
        part_of_speech TEXT,
        definition TEXT NOT NULL,
        example TEXT
      )
    ''');
  }

  // ---- Settings (reminder time / frequency) ----

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final maps = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (maps.isEmpty) return null;
    return maps.first['value'] as String;
  }

  Future<int> insertWord(Word word) async {
    final db = await database;
    return db.insert('words', word.toMap()..remove('id'));
  }

  Future<List<Word>> getAllWords() async {
    final db = await database;
    final maps = await db.query('words', orderBy: 'word ASC');
    return maps.map((m) => Word.fromMap(m)).toList();
  }

  Future<List<Word>> searchWords(String query) async {
    final db = await database;
    final maps = await db.query(
      'words',
      where: 'word LIKE ? OR meaning LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'word ASC',
    );
    return maps.map((m) => Word.fromMap(m)).toList();
  }

  Future<Word?> getWordById(int id) async {
    final db = await database;
    final maps = await db.query('words', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Word.fromMap(maps.first);
  }

  Future<int> updateWord(Word word) async {
    final db = await database;
    return db.update(
      'words',
      word.toMap(),
      where: 'id = ?',
      whereArgs: [word.id],
    );
  }

  Future<int> deleteWord(int id) async {
    final db = await database;
    return db.delete('words', where: 'id = ?', whereArgs: [id]);
  }

  /// Words due for review now (next_review_time <= now)
  Future<List<Word>> getDueWords() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final maps = await db.query(
      'words',
      where: 'next_review_time <= ?',
      whereArgs: [now],
    );
    return maps.map((m) => Word.fromMap(m)).toList();
  }

  // ---- Book / gamification ----

  Future<Set<int>> getCheckedItems(int chapterNumber) async {
    final db = await database;
    final maps = await db.query('chapter_progress',
        where: 'chapter_number = ?', whereArgs: [chapterNumber]);
    if (maps.isEmpty) return {};
    final raw = maps.first['checked_items'] as String;
    if (raw.isEmpty) return {};
    return raw.split(',').map(int.parse).toSet();
  }

  Future<bool> isChapterCompleted(int chapterNumber) async {
    final db = await database;
    final maps = await db.query('chapter_progress',
        where: 'chapter_number = ?', whereArgs: [chapterNumber]);
    if (maps.isEmpty) return false;
    return (maps.first['completed'] as int) == 1;
  }

  Future<void> setChecklistItem(
      int chapterNumber, int itemIndex, bool checked) async {
    final current = await getCheckedItems(chapterNumber);
    if (checked) {
      current.add(itemIndex);
    } else {
      current.remove(itemIndex);
    }
    final db = await database;
    await db.insert(
      'chapter_progress',
      {
        'chapter_number': chapterNumber,
        'checked_items': current.join(','),
        'completed': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Marks a chapter complete, awards XP, unlocks the next chapter,
  /// and updates the daily streak. Returns the XP awarded.
  Future<int> completeChapter(int chapterNumber, int checklistLength) async {
    final db = await database;
    final xpAward = 50 + (checklistLength * 5);

    final checked = await getCheckedItems(chapterNumber);
    await db.insert(
      'chapter_progress',
      {
        'chapter_number': chapterNumber,
        'checked_items': checked.join(','),
        'completed': 1,
        'completed_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final currentUnlocked = await getHighestUnlockedChapter();
    if (chapterNumber >= currentUnlocked) {
      await setSetting('highest_unlocked_chapter', (chapterNumber + 1).toString());
    }

    await _addXp(xpAward);
    await _recordActivityForStreak();

    return xpAward;
  }

  Future<int> getHighestUnlockedChapter() async {
    final v = await getSetting('highest_unlocked_chapter');
    return v == null ? 1 : int.parse(v);
  }

  Future<int> getTotalXp() async {
    final v = await getSetting('total_xp');
    return v == null ? 0 : int.parse(v);
  }

  Future<void> _addXp(int amount) async {
    final current = await getTotalXp();
    await setSetting('total_xp', (current + amount).toString());
  }

  Future<int> getStreak() async {
    final v = await getSetting('streak_count');
    return v == null ? 0 : int.parse(v);
  }

  String _todayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Call whenever the user does something meaningful (checks an item,
  /// completes a chapter) to keep the daily streak accurate.
  Future<void> _recordActivityForStreak() async {
    final today = DateTime.now();
    final todayKey = _todayKey(today);
    final lastKey = await getSetting('streak_last_date');

    if (lastKey == todayKey) {
      return; // already counted today
    }

    int streak = await getStreak();
    if (lastKey == null) {
      streak = 1;
    } else {
      final yesterday = today.subtract(const Duration(days: 1));
      if (lastKey == _todayKey(yesterday)) {
        streak += 1;
      } else {
        streak = 1; // streak broken
      }
    }

    await setSetting('streak_count', streak.toString());
    await setSetting('streak_last_date', todayKey);
  }

  /// Public wrapper so checklist taps (not just full chapter completion)
  /// also count toward the daily streak.
  Future<void> recordDailyActivity() => _recordActivityForStreak();

  // ---- Dictionary ----

  Future<bool> isDictionaryLoaded() async {
    final db = await database;
    final result = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM dictionary'));
    return (result ?? 0) > 0;
  }

  Future<void> bulkInsertDictionary(List<Map<String, dynamic>> entries) async {
    final db = await database;
    final batch = db.batch();
    for (final e in entries) {
      batch.insert(
        'dictionary',
        e,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<Map<String, dynamic>?> getDictionaryWord(String word) async {
    final db = await database;
    final maps = await db.query('dictionary',
        where: 'word = ?', whereArgs: [word.toLowerCase().trim()]);
    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<List<Map<String, dynamic>>> searchDictionary(String query) async {
    final db = await database;
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return [];
    return db.query(
      'dictionary',
      where: 'word LIKE ?',
      whereArgs: ['$q%'],
      orderBy: 'word ASC',
      limit: 50,
    );
  }

  // ---- Notes ----

  Future<int> insertNote(Note note) async {
    final db = await database;
    return db.insert('notes', note.toMap()..remove('id'));
  }

  Future<int> updateNote(Note note) async {
    final db = await database;
    return db.update('notes', note.toMap(), where: 'id = ?', whereArgs: [note.id]);
  }

  Future<int> deleteNote(int id) async {
    final db = await database;
    return db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Note>> getAllNotes() async {
    final db = await database;
    final maps = await db.query('notes', orderBy: 'updated_at DESC');
    return maps.map((m) => Note.fromMap(m)).toList();
  }

  // ---- AI chat history ----

  Future<void> insertAiMessage(String role, String content) async {
    final db = await database;
    await db.insert('ai_chat_messages', {
      'role': role,
      'content': content,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Returns the most recent [limit] messages, oldest first, so they can be
  /// fed back to the API as conversation history.
  Future<List<Map<String, dynamic>>> getRecentAiMessages({int limit = 20}) async {
    final db = await database;
    final rows = await db.query('ai_chat_messages',
        orderBy: 'id DESC', limit: limit);
    return rows.reversed.toList();
  }

  Future<void> clearAiChat() async {
    final db = await database;
    await db.delete('ai_chat_messages');
  }

  /// Words the learner struggles with most (wrong_count > correct_count),
  /// used to give the AI tutor real context about the learner's weaknesses.
  Future<List<Word>> getWeakWords({int limit = 15}) async {
    final db = await database;
    final maps = await db.query(
      'words',
      where: 'wrong_count > 0',
      orderBy: '(wrong_count - correct_count) DESC',
      limit: limit,
    );
    return maps.map((m) => Word.fromMap(m)).toList();
  }
}
