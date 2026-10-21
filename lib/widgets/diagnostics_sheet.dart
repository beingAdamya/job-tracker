import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/company.dart';
import '../services/diagnostics_service.dart';
import 'app_snack.dart';
import 'bug_report.dart';

// Shows what the app did the last time it checked this company
Future<void> showDiagnostics(BuildContext context, Company company) async {
  final entry = await DiagnosticsService.load(company.id);
  if (!context.mounted) return;

  final text = entry == null
      ? 'No check has run yet. Tap refresh on the Jobs tab first.'
      : entry.lines.join('\n');
  final when = entry == null
      ? ''
      : 'Last check: ${entry.at.day}/${entry.at.month}/${entry.at.year} '
          '${entry.at.hour.toString().padLeft(2, '0')}:'
          '${entry.at.minute.toString().padLeft(2, '0')}';

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What happened for ${company.name}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            if (when.isNotEmpty)
              Text(when, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: SelectableText(
                  text,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (sheetContext.mounted) {
                      showAppSnack(sheetContext, 'Copied');
                    }
                  },
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.bug_report_outlined),
                  label: const Text('Report this page'),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    if (!context.mounted) return;
                    showBugReportSheet(
                      context,
                      details: 'Company: ${company.name}\n'
                          'Link: ${company.link}\n\n'
                          'What the app saw:\n$text',
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}