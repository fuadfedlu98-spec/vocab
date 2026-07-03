import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/word.dart';

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
      version: 1,
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
      },
    );
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
}
