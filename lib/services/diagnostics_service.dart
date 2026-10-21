import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/company.dart';
import 'fetch_log.dart';

class DiagnosticsEntry {
  final DateTime at;
  final List<String> lines;
  DiagnosticsEntry(this.at, this.lines);
}

class DiagnosticsService {
  static const String _key = 'diagnostics';

  static Future<Map<String, dynamic>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final text = prefs.getString(_key);
    if (text == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(text));
    } catch (_) {
      return {};
    }
  }

  static Future<void> save(Company company, FetchLog log) async {
    try {
      final all = await _loadAll();
      all[company.id] = {
        'at': DateTime.now().toIso8601String(),
        'lines': log.lines,
      };
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(all));
    } catch (_) {
      // diagnostics must never break a sync
    }
  }

  static Future<DiagnosticsEntry?> load(String companyId) async {
    final all = await _loadAll();
    final entry = all[companyId];
    if (entry is! Map) return null;
    return DiagnosticsEntry(
      DateTime.tryParse((entry['at'] ?? '').toString()) ?? DateTime.now(),
      List<String>.from(entry['lines'] ?? []),
    );
  }
}