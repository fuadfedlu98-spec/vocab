import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../services/notification_service.dart';
import '../services/ai_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  TimeOfDay _time = const TimeOfDay(hour: 19, minute: 0);
  ReminderFrequency _frequency = ReminderFrequency.daily;
  bool _loading = true;
  bool _saving = false;
  final _apiKeyController = TextEditingController();
  bool _obscureKey = true;
  bool _savingKey = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final hourStr = await DBHelper.instance.getSetting('reminder_hour');
    final minuteStr = await DBHelper.instance.getSetting('reminder_minute');
    final freqStr = await DBHelper.instance.getSetting('reminder_frequency');
    final apiKey = await AIService.instance.getApiKey();

    if (hourStr != null && minuteStr != null) {
      _time = TimeOfDay(hour: int.parse(hourStr), minute: int.parse(minuteStr));
    }
    if (freqStr == ReminderFrequency.twicePerDay.name) {
      _frequency = ReminderFrequency.twicePerDay;
    }
    if (apiKey != null) {
      _apiKeyController.text = apiKey;
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await NotificationService.instance.scheduleReminder(
      hour: _time.hour,
      minute: _time.minute,
      frequency: _frequency,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reminder saved')),
    );
  }

  Future<void> _saveApiKey() async {
    setState(() => _savingKey = true);
    await AIService.instance.setApiKey(_apiKeyController.text);
    if (!mounted) return;
    setState(() => _savingKey = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI API key saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            title: const Text('Reminder time'),
            subtitle: Text(_time.format(context)),
            trailing: const Icon(Icons.access_time),
            onTap: _pickTime,
          ),
          const SizedBox(height: 8),
          const Text('Frequency'),
          RadioListTile<ReminderFrequency>(
            title: const Text('Daily'),
            value: ReminderFrequency.daily,
            groupValue: _frequency,
            onChanged: (v) => setState(() => _frequency = v!),
          ),
          RadioListTile<ReminderFrequency>(
            title: const Text('Twice per day'),
            value: ReminderFrequency.twicePerDay,
            groupValue: _frequency,
            onChanged: (v) => setState(() => _frequency = v!),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Reminder'),
          ),
          const Divider(height: 48),
          Text('AI Tutor', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'The AI tutor and AI-generated chapter questions need your own '
            'API key from an AI provider (e.g. Anthropic). This is sent '
            'directly to that provider over the internet - it is not used '
            'anywhere else in the app, which otherwise works fully offline.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyController,
            obscureText: _obscureKey,
            decoration: InputDecoration(
              labelText: 'API Key',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscureKey ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _savingKey ? null : _saveApiKey,
            child: _savingKey
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save API Key'),
          ),
        ],
      ),
    );
  }
}
