import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/chapter.dart';
import '../services/book_service.dart';

class ChapterDetailScreen extends StatefulWidget {
  final int chapterNumber;
  const ChapterDetailScreen({super.key, required this.chapterNumber});

  @override
  State<ChapterDetailScreen> createState() => _ChapterDetailScreenState();
}

class _ChapterDetailScreenState extends State<ChapterDetailScreen> {
  Chapter? _chapter;
  Set<int> _checked = {};
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final chapter = await BookService.instance.getChapter(widget.chapterNumber);
    final checked = await DBHelper.instance.getCheckedItems(widget.chapterNumber);
    final completed =
        await DBHelper.instance.isChapterCompleted(widget.chapterNumber);
    if (!mounted) return;
    setState(() {
      _chapter = chapter;
      _checked = checked;
      _completed = completed;
    });
  }

  Future<void> _toggleItem(int index, bool value) async {
    await DBHelper.instance.setChecklistItem(widget.chapterNumber, index, value);
    await DBHelper.instance.recordDailyActivity();
    setState(() {
      if (value) {
        _checked.add(index);
      } else {
        _checked.remove(index);
      }
    });
  }

  Future<void> _completeChapter() async {
    final xp = await DBHelper.instance
        .completeChapter(widget.chapterNumber, _chapter!.checklist.length);
    if (!mounted) return;
    setState(() => _completed = true);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Chapter complete! 🎉'),
        content: Text(
            'You earned $xp XP.${widget.chapterNumber < 39 ? " Chapter ${widget.chapterNumber + 1} is now unlocked." : " You\'ve finished the whole course!"}'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Nice'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chapter = _chapter;
    if (chapter == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chapter')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final allChecked =
        chapter.checklist.isNotEmpty && _checked.length == chapter.checklist.length;

    return Scaffold(
      appBar: AppBar(title: Text('Chapter ${chapter.number}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(chapter.title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_completed)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Completed'),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Text('Drills',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...chapter.drills.map((d) => _DrillCard(drill: d)),
          if (chapter.mistakes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Mistakes to Avoid',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...chapter.mistakes.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.close, color: Colors.red, size: 18),
                      const SizedBox(width: 6),
                      Expanded(child: Text(m)),
                    ],
                  ),
                )),
          ],
          if (chapter.mission.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Real-World Mission',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(chapter.mission),
            ),
          ],
          if (chapter.checklist.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Completion Checklist',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Do the drills in real life, then check them off here.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            ...chapter.checklist.asMap().entries.map((entry) {
              final index = entry.key;
              final text = entry.value;
              return CheckboxListTile(
                value: _checked.contains(index),
                onChanged: _completed
                    ? null
                    : (v) => _toggleItem(index, v ?? false),
                title: Text(text),
                controlAffinity: ListTileControlAffinity.leading,
              );
            }),
            const SizedBox(height: 12),
            if (!_completed)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: allChecked ? _completeChapter : null,
                  child: Text(allChecked
                      ? 'Complete Chapter'
                      : 'Check off all items to complete'),
                ),
              ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _DrillCard extends StatelessWidget {
  final Drill drill;
  const _DrillCard({required this.drill});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text('${drill.id} — ${drill.title}'),
        subtitle: Text('Difficulty ${drill.difficulty}/5 · ${drill.time}'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(drill.body, style: const TextStyle(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
