import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile.dart';

class ProfileService {
  static const String _key = 'profile';

  static Future<Profile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(_key);
    if (text == null) return Profile.empty();

    try {
      return Profile.fromJson(jsonDecode(text));
    } catch (_) {
      return Profile.empty(); // damaged data → start fresh
    }
  }

  static Future<void> save(Profile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(profile.toJson()));
  }

  // The app's private "cv" folder (other apps cannot read it)
  static Future<Directory> _cvDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/cv');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // Copies the picked file into the private folder (one CV at a time)
  // and returns the path of the copy
  static Future<String> storeCv(String sourcePath, String name) async {
    final dir = await _cvDir();
    await for (final entry in dir.list()) {
      if (entry is File) await entry.delete(); // remove the old CV
    }
    final safeName = name.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_');
    final copy = await File(sourcePath).copy('${dir.path}/$safeName');
    return copy.path;
  }

  static Future<void> deleteCvFiles() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/cv');
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}