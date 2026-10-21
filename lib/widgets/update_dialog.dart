import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';

Future<void> showUpdateDialog(BuildContext context, UpdateInfo update) async {
  final notes = update.notes.length > 600
      ? '${update.notes.substring(0, 600)}…'
      : update.notes;

  final download = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.system_update),
      title: Text('Version ${update.version} is available'),
      content: SingleChildScrollView(
        child: Text(
          notes.isEmpty ? 'A new version is ready to download.' : notes,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Download'),
        ),
      ],
    ),
  );

  if (download != true) return;

  // The APK itself if the release has one, otherwise the release page
  final target = update.apkUrl ?? update.pageUrl;
  await launchUrl(Uri.parse(target), mode: LaunchMode.externalApplication);
}