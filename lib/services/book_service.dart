import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/chapter.dart';

class BookService {
  BookService._internal();
  static final BookService instance = BookService._internal();

  List<Chapter>? _chapters;
  String? _part0Text;

  Future<List<Chapter>> getChapters() async {
    if (_chapters != null) return _chapters!;
    final raw = await rootBundle.loadString('assets/book/book_chapters.json');
    final List<dynamic> data = json.decode(raw) as List<dynamic>;
    _chapters = data
        .map((e) => Chapter.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    return _chapters!;
  }

  Future<Chapter> getChapter(int number) async {
    final chapters = await getChapters();
    return chapters.firstWhere((c) => c.number == number);
  }

  Future<String> getPart0Text() async {
    if (_part0Text != null) return _part0Text!;
    _part0Text = await rootBundle.loadString('assets/book/part0.md');
    return _part0Text!;
  }
}
