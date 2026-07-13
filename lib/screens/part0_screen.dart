import 'package:flutter/material.dart';
import '../services/book_service.dart';

class Part0Screen extends StatefulWidget {
  const Part0Screen({super.key});

  @override
  State<Part0Screen> createState() => _Part0ScreenState();
}

class _Part0ScreenState extends State<Part0Screen> {
  String? _text;

  @override
  void initState() {
    super.initState();
    BookService.instance.getPart0Text().then((t) {
      if (!mounted) return;
      setState(() => _text = t);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Part 0 — Assessment')),
      body: _text == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(_text!, style: const TextStyle(height: 1.5)),
            ),
    );
  }
}
