import 'package:flutter/material.dart';
import '../services/background_service.dart';
import '../services/battery_service.dart';
import '../services/notification_service.dart';
import 'companies_tab.dart';
import 'jobs_tab.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _resetCount = 0; // changes after a reset → tabs rebuild from scratch

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _firstRunPrompts());
  }

  // Notification permission first, then a friendly battery explanation (once)
  Future<void> _firstRunPrompts() async {
    await NotificationService.requestPermission();
    if (!mounted) return;
    if (await BatteryService.alreadyAsked()) return;
    if (await BatteryService.isUnrestricted()) return;

    await BatteryService.markAsked();
    if (!mounted) return;

    final allow = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.battery_charging_full),
        title: const Text('Keep checking for jobs?'),
        content: const Text(
          'To look for new jobs while the app is closed, Android needs to '
          'let Job Tracker run in the background. Next you will see an '
          'Android prompt. You can change this later in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (allow == true) await BatteryService.request();
  }

  Future<void> _openSettings() async {
    final didReset = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );

    if (didReset == true && mounted) {
      setState(() => _resetCount++);
      BackgroundService.ensureScheduled(); // reset wiped the saved schedule
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Everything was reset')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Job Tracker'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Settings',
              onPressed: _openSettings,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.work), text: 'Jobs'),
              Tab(icon: Icon(Icons.business), text: 'Companies'),
            ],
          ),
        ),
        body: TabBarView(
          key: ValueKey(_resetCount),
          children: const [
            JobsTab(),
            CompaniesTab(),
          ],
        ),
      ),
    );
  }
}