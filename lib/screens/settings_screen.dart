import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;
import '../models/app_settings.dart';
import '../services/background_service.dart';
import '../services/battery_service.dart';
import '../services/job_fetcher.dart';
import '../services/profile_service.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/app_snack.dart';
import '../widgets/color_picker_sheet.dart';
import '../widgets/layout.dart';
import 'profile_screen.dart';
import '../app_info.dart';
import '../services/update_service.dart';
import '../widgets/bug_report.dart';
import '../widgets/update_dialog.dart';

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
  String _version = '';              
  bool _checkingUpdate = false;    
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
    _loadVersion(); 
  }

  Future<void> _save() async {
    JobFetcher.maxJobsPerCompany = _settings.maxJobs; // used by the next sync
    await SettingsService.save(_settings);
  }

  void _snack(String text) {
    if (!mounted) return;
    showAppSnack(context, text);
  }

  Future<void> _loadVersion() async {
    try {
      final v = await UpdateService.installedVersion();
      if (!mounted) return;
      setState(() => _version = v);
    } catch (_) {}
  }

  Future<void> _checkForUpdate() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);

    try {
      final update = await UpdateService.checkForUpdate(); // null = up to date
      if (!mounted) return;
      if (update == null) {
        _snack('You are up to date (version $_version)');
      } else {
        await showUpdateDialog(context, update);
      }
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  // Restyle the whole app now, and remember the choice
  void _applyTheme() {
    ThemeController.instance.apply(_settings);
    _save();
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

  // ===== PART 4: Reset all =====
  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
        title: const Text('Reset everything?'),
        content: const Text(
          'This permanently deletes all your companies, jobs, favourites, '
          'settings, profile and CV. This cannot be undone.',
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

    await ProfileService.deleteCvFiles(); // the CV copy
    await StorageService.clearAll();
    ThemeController.instance.apply(AppSettings()); // back to the default look
    JobFetcher.maxJobsPerCompany = 100; // back to the default
    if (!mounted) return;
    Navigator.pop(context, true); // tell the home screen a reset happened
  }

  // ===== PART 5: Small building blocks =====
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

  Widget _colorTile(String label, Color current, void Function(int) assign) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: current,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey),
        ),
      ),
      title: Text(label),
      trailing: const Icon(Icons.edit_outlined, size: 20),
      onTap: () async {
        final picked = await pickColor(context, title: label);
        if (picked == null) return;
        setState(() => assign(picked.toARGB32()));
        _applyTheme();
      },
    );
  }

  // ===== PART 6: Drawing the screen =====
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.symmetric(
                horizontal: sidePadding(context, 600),
                vertical: 16,
              ),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Profile and CV'),
                  subtitle: const Text(
                      'Your details and CV, ready to copy into applications'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ),
                ),

                _sectionTitle('APPEARANCE'),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'system',
                      icon: Icon(Icons.brightness_auto),
                      label: Text('System'),
                    ),
                    ButtonSegment(
                      value: 'light',
                      icon: Icon(Icons.light_mode),
                      label: Text('Light'),
                    ),
                    ButtonSegment(
                      value: 'dark',
                      icon: Icon(Icons.dark_mode),
                      label: Text('Dark'),
                    ),
                  ],
                  selected: {_settings.themeMode},
                  onSelectionChanged: (choice) {
                    setState(() => _settings.themeMode = choice.first);
                    _applyTheme();
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Custom colours'),
                  subtitle: const Text(
                      'Change background, text and accent colours on top of the theme above'),
                  value: _settings.customEnabled,
                  onChanged: (on) {
                    setState(() => _settings.customEnabled = on);
                    _applyTheme();
                  },
                ),
                if (_settings.customEnabled) ...[
                  _colorTile('Background', scheme.surface,
                      (c) => _settings.customBg = c),
                  _colorTile('Text', scheme.onSurface,
                      (c) => _settings.customText = c),
                  _colorTile('Accent', scheme.primary,
                      (c) => _settings.customAccent = c),
                  if (contrastRatio(scheme.surface, scheme.onSurface) < 4.5)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'These colours are hard to read together. Choose a background and text colour that differ more.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _settings.customBg = null;
                          _settings.customText = null;
                          _settings.customAccent = null;
                        });
                        _applyTheme();
                      },
                      child: const Text('Reset colours'),
                    ),
                  ),
                ],

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
                _intDropdown(
                  'Show jobs posted within',
                  'Older jobs are hidden. Choose a longer time, then refresh, to load older ones',
                  _settings.maxAgeDays,
                  jobAgeOptions,
                  (value) {
                    setState(() => _settings.maxAgeDays = value);
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
                    'Deletes all companies, jobs, favourites, settings, profile and CV.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),

                _sectionTitle('ABOUT'),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.system_update_outlined),
                  title: const Text('Check for update'),
                  subtitle: Text(_version.isEmpty
                      ? 'Version unknown'
                      : 'Installed version $_version'),
                  trailing: _checkingUpdate
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _checkForUpdate,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.bug_report_outlined),
                  title: const Text('Report a bug'),
                  subtitle: const Text('Tell us what went wrong'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showBugReportSheet(context),
                ),

                const SizedBox(height: 32),
                const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Made with '),
                      Icon(Icons.favorite, color: Colors.red, size: 18),
                      Text(' from ${AppInfo.developer}'),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'If you find this app useful, support the developer building such amazing apps.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                SizedBox(height: 24 + MediaQuery.of(context).padding.bottom),

              ],
            ),
    );
  }
}