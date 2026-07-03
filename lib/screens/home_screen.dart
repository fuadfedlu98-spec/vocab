import 'package:flutter/material.dart';
import 'add_word_screen.dart';
import 'word_list_screen.dart';
import 'quiz_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vocab')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _HomeTile(
              icon: Icons.add_circle_outline,
              label: 'Add Word',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AddWordScreen())),
            ),
            _HomeTile(
              icon: Icons.list_alt,
              label: 'Word List',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const WordListScreen())),
            ),
            _HomeTile(
              icon: Icons.quiz_outlined,
              label: 'Quiz',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const QuizScreen())),
            ),
            _HomeTile(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HomeTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(label, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
