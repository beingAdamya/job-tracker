import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_info.dart';

class UpdateInfo {
  final String version; // "1.1.0"
  final String notes; // the release description
  final String pageUrl; // the release page
  final String? apkUrl; // direct APK download, if the release has one

  UpdateInfo({
    required this.version,
    required this.notes,
    required this.pageUrl,
    this.apkUrl,
  });
}

class UpdateService {
  static const String _lastCheckKey = 'update_last_check';
  static const String _lastPromptedKey = 'update_last_prompted';

  static Future<String> installedVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  // Is `latest` newer than `current`?   "v1.2.0" vs "1.1.9" → true
  static bool isNewer(String latest, String current) {
    List<int> parts(String v) {
      final clean = v
          .trim()
          .replaceFirst(RegExp(r'^[vV]'), '')
          .split(RegExp(r'[-+]')) // drop "+3" or "-beta"
          .first;
      return clean.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    }

    final a = parts(latest);
    final b = parts(current);
    final length = a.length > b.length ? a.length : b.length;

    for (var i = 0; i < length; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false; // identical
  }

  // Asks GitHub for the newest release. Throws a readable Exception on failure.
  static Future<UpdateInfo> fetchLatest() async {
    if (!AppInfo.hasRepo) {
      throw Exception('Update check is not set up yet (see app_info.dart)');
    }

    final url = 'https://api.github.com/repos/'
        '${AppInfo.githubOwner}/${AppInfo.githubRepo}/releases/latest';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'JobTrackerApp',
      },
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 404) {
      throw Exception(
          'No release found. Is the repository public, and does it have a release?');
    }
    if (response.statusCode != 200) {
      throw Exception('GitHub replied ${response.statusCode}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));

    String? apk;
    for (final asset in (data['assets'] as List? ?? [])) {
      final name = (asset['name'] ?? '').toString().toLowerCase();
      if (name.endsWith('.apk')) {
        apk = asset['browser_download_url']?.toString();
        break;
      }
    }

    return UpdateInfo(
      version: (data['tag_name'] ?? '').toString().replaceFirst(RegExp(r'^[vV]'), ''),
      notes: (data['body'] ?? '').toString().trim(),
      pageUrl: (data['html_url'] ?? '').toString(),
      apkUrl: apk,
    );
  }

  // The newer release, or null if you are up to date. Throws on failure.
  static Future<UpdateInfo?> checkForUpdate() async {
    final latest = await fetchLatest();
    final current = await installedVersion();
    return isNewer(latest.version, current) ? latest : null;
  }

  // For automatic checks: at most once a day, and only for a version the
  // user has not been told about yet. Never throws.
  static Future<UpdateInfo?> checkQuietly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final now = DateTime.now().millisecondsSinceEpoch;
      final last = prefs.getInt(_lastCheckKey) ?? 0;
      if (now - last < 24 * 60 * 60 * 1000) return null;
      await prefs.setInt(_lastCheckKey, now);

      final update = await checkForUpdate();
      if (update == null) return null;
      if (prefs.getString(_lastPromptedKey) == update.version) return null;
      return update;
    } catch (_) {
      return null;
    }
  }

  static Future<void> markPrompted(UpdateInfo update) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastPromptedKey, update.version);
  }
}