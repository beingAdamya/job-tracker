import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile.dart';
import 'account.dart';

class ProfileService {
  static const String _key = 'profile';

  static Future<Profile> load() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final p = await Account.prefix();
    final text = prefs.getString('$p$_key');
    if (text == null) return Profile.empty();

    try {
      return Profile.fromJson(jsonDecode(text));
    } catch (_) {
      return Profile.empty(); // damaged data → start fresh
    }
  }

  static Future<void> save(Profile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final p = await Account.prefix();
    await prefs.setString('$p$_key', jsonEncode(profile.toJson()));
  }

  // The private CV folder of the signed-in account
  // (other apps, and other accounts, never see it)
  static Future<Directory> _cvDir({bool create = true}) async {
    final base = await getApplicationDocumentsDirectory();
    final uid = await Account.activeUid() ?? 'nobody';
    final dir = Directory('${base.path}/cv/$uid');
    if (create && !await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // Copies the picked file into the private folder (one CV at a time)
  // and returns the path of the copy
  static Future<String> storeCv(String sourcePath, String name) async {
    final dir = await _cvDir();

    // Remove the old CV, including one saved before accounts existed
    final current = (await load()).cvPath;
    if (current != null) {
      final old = File(current);
      if (await old.exists()) await old.delete();
    }
    await for (final entry in dir.list()) {
      if (entry is File) await entry.delete();
    }

    final safeName = name.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_');
    final copy = await File(sourcePath).copy('${dir.path}/$safeName');
    return copy.path;
  }

  // Deletes this account's CV file(s)
  static Future<void> deleteCvFiles() async {
    final current = (await load()).cvPath;
    if (current != null) {
      final old = File(current);
      if (await old.exists()) await old.delete();
    }
    final dir = await _cvDir(create: false);
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}