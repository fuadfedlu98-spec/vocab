import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/chapter.dart';
import '../services/book_service.dart';
import 'chapter_detail_screen.dart';
import 'part0_screen.dart';

class BookHomeScreen extends StatefulWidget {
  const BookHomeScreen({super.key});

  @override
  State<BookHomeScreen> createState() => _BookHomeScreenState();
}

class _BookHomeScreenState extends State<BookHomeScreen> {
  bool _loading = true;
  List<Chapter> _chapters = [];
  int _highestUnlocked = 1;
  int _xp = 0;
  int _streak = 0;
  Set<int> _completed = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final chapters = await BookService.instance.getChapters();
    final unlocked = await DBHelper.instance.getHighestUnlockedChapter();
    final xp = await DBHelper.instance.getTotalXp();
    final streak = await DBHelper.instance.getStreak();

    final completed = <int>{};
    for (final c in chapters) {
      if (await DBHelper.instance.isChapterCompleted(c.number)) {
        completed.add(c.number);
      }
    }

    if (!mounted) return;
    setState(() {
      _chapters = chapters;
      _highestUnlocked = unlocked;
      _xp = xp;
      _streak = streak;
      _completed = completed;
      _loading = false;
    });
  }

  int get _level => (_xp ~/ 100) + 1;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('English Course')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('English Course')),
      body: Column(
        children: [
          _StatsBar(xp: _xp, level: _level, streak: _streak),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.assessment_outlined),
                    title: const Text('Part 0 — Initial Fluency Assessment'),
                    subtitle: const Text('Start here, before Chapter 1'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const Part0Screen())),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('39 Chapters',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                ..._chapters.map((c) {
                  final unlocked = c.number <= _highestUnlocked;
                  final completed = _completed.contains(c.number);
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: completed
                            ? Colors.green
                            : unlocked
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade400,
                        child: Icon(
                          completed
                              ? Icons.check
                              : unlocked
                                  ? Icons.menu_book
                                  : Icons.lock,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      title: Text('Ch. ${c.number}: ${c.title}',
                          style: TextStyle(
                              color: unlocked ? null : Colors.grey)),
                      subtitle: Text('${c.drills.length} drills',
                          style: TextStyle(
                              color: unlocked ? null : Colors.grey.shade400)),
                      onTap: unlocked
                          ? () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ChapterDetailScreen(chapterNumber: c.number),
                                ),
                              );
                              _load();
                            }
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Complete the previous chapter to unlock this one'),
                                ),
                              );
                            },
                    ),
                  );
                }),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  final int xp;
  final int level;
  final int streak;

  const _StatsBar({required this.xp, required this.level, required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(icon: Icons.star, label: 'Level $level', value: '$xp XP'),
          _StatItem(
              icon: Icons.local_fire_department,
              label: 'Streak',
              value: '$streak day${streak == 1 ? '' : 's'}'),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(value, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ],
    );
  }
}
