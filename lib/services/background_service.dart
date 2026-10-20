import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../models/app_settings.dart';
import '../models/job.dart';
import 'notification_service.dart';
import 'settings_service.dart';
import 'sync_service.dart';

// The entry point Android calls in the background.
// It must be a top-level function with this annotation.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    DartPluginRegistrant.ensureInitialized(); // make plugins available here
    try {
      await BackgroundService.runCheck();
    } catch (e) {
      print('Background check failed: $e');
    }
    return true; // always "done": a failing site must not cause retry storms
  });
}

class BackgroundService {
  static const String taskName = 'job_sync';
  static const String _uniqueName = 'job_sync_periodic';
  static const String _scheduledKey = 'scheduled_sync_hours';
  static const String _lastBatchKey = 'notify_last_batch';
  static const String _pendingKey = 'notify_pending';

  // ===== Scheduling =====
  static Future<void> init() async {
    await Workmanager().initialize(callbackDispatcher);
    await ensureScheduled();
  }

  // Make sure the repeating check matches the sync frequency in Settings
  static Future<void> ensureScheduled() async {
    final settings = await SettingsService.load();
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    // Already scheduled with this frequency? Leave it alone, so opening
    // the app doesn't keep restarting the countdown
    if (prefs.getInt(_scheduledKey) == settings.syncHours) return;

    await Workmanager().cancelByUniqueName(_uniqueName);
    await Workmanager().registerPeriodicTask(
      _uniqueName,
      taskName,
      frequency: Duration(hours: settings.syncHours),
      constraints: Constraints(
        networkType: NetworkType.connected, // needs internet
        requiresBatteryNotLow: true,        // not when the battery is low
      ),
    );
    await prefs.setInt(_scheduledKey, settings.syncHours);
  }

  // Run one check right now in the background (for testing)
  static Future<void> runNow() async {
    await Workmanager().registerOneOffTask(
      'job_sync_now_${DateTime.now().millisecondsSinceEpoch}',
      taskName,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  // ===== The check itself =====
  static Future<void> runCheck() async {
    final settings = await SettingsService.load();
    final result = await SyncService.syncAll();
    print('Background check: ${result.newJobs.length} new, '
        '${result.notifiable.length} worth a notification');

    await NotificationService.init();
    await _notify(result.notifiable, settings);
  }

  // The first keyword found in title, role, location or mode (or null)
  static String? _matchedKeyword(Job job, List<String> keywords) {
    final text =
        '${job.title} ${job.role} ${job.location} ${job.mode}'.toLowerCase();
    for (final k in keywords) {
      if (text.contains(k)) return k;
    }
    return null;
  }

  static Future<void> _notify(List<Job> jobs, AppSettings settings) async {
    final keywords = settings.keywordList;
    final matches = <Job>[];
    final others = <Job>[];

    for (final job in jobs) {
      if (_matchedKeyword(job, keywords) != null) {
        matches.add(job);
      } else {
        others.add(job);
      }
    }

    // 1. Keyword matches: right away, ignoring the notification frequency
    if (matches.length <= 3) {
      for (final job in matches) {
        await NotificationService.show(
          id: job.id.hashCode & 0x7fffffff, // a positive number from the job id
          title: job.title,
          body: '${job.companyName} · ${job.location} · ${job.mode}\n'
              'Matched keyword: ${_matchedKeyword(job, keywords)}',
        );
      }
    } else {
      final lines = matches
          .take(5)
          .map((j) => '• ${j.title} (${j.companyName})')
          .join('\n');
      await NotificationService.show(
        id: 1,
        title: '${matches.length} jobs match your keywords',
        body: lines,
      );
    }

    // 2. Everything else: one summary, at most once per notification frequency
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    var pending = (prefs.getInt(_pendingKey) ?? 0) + others.length;
    final lastBatch = prefs.getInt(_lastBatchKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final waitMs = settings.notifyHours * 60 * 60 * 1000;
    const toleranceMs = 5 * 60 * 1000; // Android runs checks a little early/late

    if (pending > 0 && now + toleranceMs >= lastBatch + waitMs) {
      await NotificationService.show(
        id: 2,
        title: '$pending new ${pending == 1 ? 'job' : 'jobs'}',
        body: 'Open Job Tracker to see what is new.',
      );
      pending = 0;
      await prefs.setInt(_lastBatchKey, now);
    }
    await prefs.setInt(_pendingKey, pending);
  }
}