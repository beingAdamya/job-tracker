import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;
import '../models/app_settings.dart';
import '../services/background_service.dart';
import '../services/battery_service.dart';
import '../services/job_fetcher.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  // ===== PART 1: State =====
  AppSettings _settings = AppSettings();
  bool _isLoading = true;
  bool _batteryOk = false;
  final _keywordsController = TextEditingController();

  // ===== PART 2: Start-up, loading and saving =====
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keywordsController.dispose();
    super.dispose();
  }

  // Coming back from Android's settings screen → check the battery again
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkBattery();
  }

  Future<void> _load() async {
    final saved = await SettingsService.load();
    if (!mounted) return;
    setState(() {
      _settings = saved;
      _keywordsController.text = saved.keywords;
      _isLoading = false;
    });
    _checkBattery();
  }

  Future<void> _save() async {
    JobFetcher.maxJobsPerCompany = _settings.maxJobs; // used by the next sync
    await SettingsService.save(_settings);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ===== PART 3: Battery =====
  Future<void> _checkBattery() async {
    final ok = await BatteryService.isUnrestricted();
    if (!mounted) return;
    setState(() => _batteryOk = ok);
  }

  Future<void> _allowBackground() async {
    final ok = await BatteryService.request();
    if (!mounted) return;
    setState(() => _batteryOk = ok);
    if (!ok) {
      _snack('Not allowed. You can also open the app info screen below.');
    }
  }

  // ===== PART 4: Testing helpers =====
  Future<void> _testNotification() async {
    final allowed = await NotificationService.requestPermission();
    if (!allowed) {
      _snack('Notifications are blocked. Allow them in the phone settings.');
      return;
    }
    await NotificationService.show(
      id: 99,
      title: 'Test notification',
      body: 'If you can read this, notifications work.',
    );
  }

  // Makes the app "forget" its 3 newest jobs, so the next check finds them
  // again as NEW jobs
  Future<void> _forgetNewestJobs() async {
    final jobs = await StorageService.loadJobs();
    if (jobs.length < 4) {
      _snack('Add a company with at least 4 jobs first.');
      return;
    }
    jobs.sort((a, b) => b.postedDate.compareTo(a.postedDate));
    final forgotten = jobs.take(3).map((j) => j.id).toSet();
    jobs.removeWhere((j) => forgotten.contains(j.id));
    await StorageService.saveJobs(jobs);
    _snack('Forgot the 3 newest jobs. Now run the background check.');
  }

  Future<void> _runBackgroundNow() async {
    await BackgroundService.runNow();
    _snack('Started. A notification should appear within a minute.');
  }

  // ===== PART 5: Reset all =====
  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
        title: const Text('Reset everything?'),
        content: const Text(
          'This permanently deletes all your companies, jobs, favourites '
          'and settings. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (confirmed != true) return; // Cancel, or tapped outside

    await StorageService.clearAll();
    JobFetcher.maxJobsPerCompany = 100; // back to the default
    if (!mounted) return;
    Navigator.pop(context, true); // tell the home screen a reset happened
  }

  // ===== PART 6: Small building blocks =====
  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _intDropdown(String title, String subtitle, int value,
      Map<int, String> options, void Function(int) onChanged) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: DropdownButton<int>(
        value: value,
        underline: const SizedBox(), // hides the line under the dropdown
        items: options.entries
            .map((e) => DropdownMenuItem<int>(
                  value: e.key,
                  child: Text(e.value),
                ))
            .toList(),
        onChanged: (picked) {
          if (picked != null) onChanged(picked);
        },
      ),
    );
  }

  // ===== PART 7: Drawing the screen =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionTitle('SYNCING'),
                _intDropdown(
                  'Sync frequency',
                  'How often the app checks your companies',
                  _settings.syncHours,
                  frequencyOptions,
                  (value) {
                    setState(() => _settings.syncHours = value);
                    _save();
                    BackgroundService.ensureScheduled();
                  },
                ),
                _intDropdown(
                  'Jobs per company',
                  'Newest jobs kept for each company. Applies at the next refresh',
                  _settings.maxJobs,
                  {for (final n in jobLimitOptions) n: '$n jobs'},
                  (value) {
                    setState(() => _settings.maxJobs = value);
                    _save();
                  },
                ),

                _sectionTitle('NOTIFICATIONS'),
                _intDropdown(
                  'Notification frequency',
                  'How often you are told about new jobs',
                  _settings.notifyHours,
                  frequencyOptions,
                  (value) {
                    setState(() => _settings.notifyHours = value);
                    _save();
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _keywordsController,
                  decoration: const InputDecoration(
                    labelText: 'Notification keywords',
                    hintText: 'e.g. python, remote, animator',
                    helperText: 'Separate words with commas. A job whose title, '
                        'role, location or mode contains one of them notifies '
                        'you right away.',
                    helperMaxLines: 3,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (text) {
                    setState(() => _settings.keywords = text);
                    _save();
                  },
                ),
                if (_settings.keywordList.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _settings.keywordList
                        .map((k) => Chip(
                              label: Text(k),
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
                ],

                _sectionTitle('BACKGROUND'),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _batteryOk ? Icons.check_circle : Icons.battery_alert,
                    color: _batteryOk ? Colors.green : Colors.orange,
                  ),
                  title: const Text('Run in background'),
                  subtitle: Text(
                    _batteryOk
                        ? 'Allowed. Checks can run on time'
                        : 'Battery-optimised: checks may be delayed',
                  ),
                  trailing: _batteryOk
                      ? null
                      : FilledButton.tonal(
                          onPressed: _allowBackground,
                          child: const Text('Allow'),
                        ),
                ),
                TextButton(
                  onPressed: openAppSettings,
                  child: const Text('Open app info (battery and other limits)'),
                ),

                _sectionTitle('DATA'),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Reset all'),
                  onPressed: _confirmReset,
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Deletes all companies, jobs, favourites and settings.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),

                _sectionTitle('TESTING'),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.notifications_active),
                  label: const Text('Send test notification'),
                  onPressed: _testNotification,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.history),
                  label: const Text('Forget 3 newest jobs'),
                  onPressed: _forgetNewestJobs,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.sync),
                  label: const Text('Run background check now'),
                  onPressed: _runBackgroundNow,
                ),
              ],
            ),
    );
  }
}