import 'dart:async';
import 'package:flutter/material.dart';
import '../models/dictionary_entry.dart';
import '../services/dictionary_service.dart';
import 'dictionary_detail_screen.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final _controller = TextEditingController();
  List<DictionaryEntry> _results = [];
  bool _searchingOnline = false;
  bool _showOnlineOption = false;
  String _lastQuery = '';
  Timer? _debounce;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(query));
  }

  Future<void> _search(String query) async {
    _lastQuery = query;
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _showOnlineOption = false;
      });
      return;
    }
    final results = await DictionaryService.instance.searchOffline(query);
    if (!mounted || _lastQuery != query) return;
    setState(() {
      _results = results;
      // Offer online lookup only if nothing matched offline.
      _showOnlineOption = results.isEmpty;
    });
  }

  Future<void> _tryOnline() async {
    setState(() => _searchingOnline = true);
    final entry = await DictionaryService.instance.lookupOnline(_controller.text);
    if (!mounted) return;
    setState(() => _searchingOnline = false);

    if (entry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No result found (check spelling or your connection)')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DictionaryDetailScreen(entry: entry)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dictionary')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search a word (offline, 6,000+ words)',
                border: OutlineInputBorder(),
              ),
              onChanged: _onChanged,
            ),
          ),
          Expanded(
            child: _controller.text.trim().isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'Start typing to search the built-in offline dictionary.\nIf a word isn\'t found, you can look it up online too.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView(
                    children: [
                      ..._results.map((e) => ListTile(
                            title: Text(e.word),
                            subtitle: Text(
                              e.definition,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: e.partOfSpeech.isEmpty
                                ? null
                                : Text(e.partOfSpeech,
                                    style: Theme.of(context).textTheme.bodySmall),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => DictionaryDetailScreen(entry: e)),
                            ),
                          )),
                      if (_showOnlineOption)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              const Text(
                                'Not in the offline dictionary.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              _searchingOnline
                                  ? const CircularProgressIndicator()
                                  : OutlinedButton.icon(
                                      onPressed: _tryOnline,
                                      icon: const Icon(Icons.cloud_outlined),
                                      label: const Text('Look up online'),
                                    ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
