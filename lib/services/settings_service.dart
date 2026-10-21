import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import 'account.dart';

class SettingsService {
  static const String _key = 'settings';

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final p = await Account.prefix();
    final text = prefs.getString('$p$_key');
    if (text == null) return AppSettings(); // nothing saved yet → defaults

    try {
      return AppSettings.fromJson(jsonDecode(text));
    } catch (_) {
      return AppSettings(); // damaged data → defaults
    }
  }

  static Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final p = await Account.prefix();
    await prefs.setString('$p$_key', jsonEncode(settings.toJson()));
  }
}