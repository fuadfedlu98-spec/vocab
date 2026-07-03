import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../services/notification_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final hourStr = await DBHelper.instance.getSetting('reminder_hour');
    final minuteStr = await DBHelper.instance.getSetting('reminder_minute');
    final freqStr = await DBHelper.instance.getSetting('reminder_frequency');

    if (hourStr != null && minuteStr != null) {
      _time = TimeOfDay(hour: int.parse(hourStr), minute: int.parse(minuteStr));
    }
    if (freqStr == ReminderFrequency.twicePerDay.name) {
      _frequency = ReminderFrequency.twicePerDay;
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const SizedBox(height: 24),
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
          ],
        ),
      ),
    );
  }
}
