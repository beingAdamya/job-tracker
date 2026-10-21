import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_info.dart';
import 'app_snack.dart';

// Opens a sheet with the ways to report a bug. `details` is extra text
// (for example which company link failed) added to the report.
Future<void> showBugReportSheet(BuildContext context,
    {String details = ''}) async {
  final hasEmail = AppInfo.bugEmail.isNotEmpty;
  final hasGithub = AppInfo.hasRepo;

  if (!hasEmail && !hasGithub) {
    showAppSnack(context, 'Bug reporting is not set up yet (see app_info.dart)');
    return;
  }

  final report = await _buildReport(details);
  if (!context.mounted) return;

  final subject = '${AppInfo.appName} bug report';

  await showModalBottomSheet(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Report a bug',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (hasEmail)
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Send by email'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final ok = await launchUrl(Uri.parse(
                  'mailto:${AppInfo.bugEmail}'
                  '?subject=${Uri.encodeComponent(subject)}'
                  '&body=${Uri.encodeComponent(report)}',
                ));
                if (!ok && context.mounted) {
                  showAppSnack(context, 'No email app found');
                }
              },
            ),
          if (hasGithub)
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Open on GitHub'),
              subtitle: const Text('Needs a GitHub account'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await launchUrl(
                  Uri.parse(
                    'https://github.com/${AppInfo.githubOwner}/${AppInfo.githubRepo}'
                    '/issues/new?title=${Uri.encodeComponent(subject)}'
                    '&body=${Uri.encodeComponent(report)}',
                  ),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
        ],
      ),
    ),
  );
}

// A ready-made template with the app and phone details filled in
Future<String> _buildReport(String details) async {
  var app = 'unknown';
  var phone = 'unknown';

  try {
    final info = await PackageInfo.fromPlatform();
    app = '${info.version} (${info.buildNumber})';
  } catch (_) {}

  try {
    final android = await DeviceInfoPlugin().androidInfo;
    phone = '${android.manufacturer} ${android.model}, '
        'Android ${android.version.release}';
  } catch (_) {}

  return 'What happened?\n\n\n'
      'What did you expect?\n\n\n'
      'Steps to repeat it:\n1. \n\n'
      '---\n'
      'App version: $app\n'
      'Phone: $phone\n'
      '${details.isEmpty ? '' : '\n$details\n'}';
}