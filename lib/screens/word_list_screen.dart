import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/word.dart';
import 'word_detail_screen.dart';

class WordListScreen extends StatefulWidget {
  const WordListScreen({super.key});

  @override
  State<WordListScreen> createState() => _WordListScreenState();
}

class _WordListScreenState extends State<WordListScreen> {
  List<Word> _words = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load([String query = '']) async {
    final words = query.isEmpty
        ? await DBHelper.instance.getAllWords()
        : await DBHelper.instance.searchWords(query);
    if (!mounted) return;
    setState(() => _words = words);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Word List')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search words or meanings',
                border: OutlineInputBorder(),
              ),
              onChanged: _load,
            ),
          ),
          Expanded(
            child: _words.isEmpty
                ? const Center(child: Text('No words yet'))
                : ListView.builder(
                    itemCount: _words.length,
                    itemBuilder: (context, index) {
                      final w = _words[index];
                      return ListTile(
                        title: Text(w.word),
                        subtitle: Text(
                          w.meaning,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WordDetailScreen(wordId: w.id!),
                            ),
                          );
                          _load(_searchController.text);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
