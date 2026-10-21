import 'package:shared_preferences/shared_preferences.dart';

// Which account's data is in use. Everything saved is stored under a
// prefix made from the account, so two accounts on one phone never mix.
class Account {
  static const String _uidKey = 'session_uid';
  static const String _claimedKey = 'legacy_claimed';

  // Keys used before accounts existed. The first account adopts them.
  static const List<String> _perAccountKeys = [
    'companies',
    'jobs',
    'settings',
    'profile',
    'diagnostics',
    'notify_last_batch',
    'notify_pending',
  ];

  // The signed-in account (null = nobody)
  static Future<String?> activeUid() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // the background worker may have changed it
    final uid = prefs.getString(_uidKey);
    return (uid == null || uid.isEmpty) ? null : uid;
  }

  // "u_abc123." goes in front of every per-account key
  static Future<String> prefix() async {
    final uid = await activeUid();
    return uid == null ? 'nobody.' : 'u_$uid.';
  }

  // Called when someone signs in (uid) or out (null)
  static Future<void> activate(String? uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    if (uid == null) {
      await prefs.remove(_uidKey);
      return;
    }

    // The very first account adopts the data saved before accounts existed
    if (!(prefs.getBool(_claimedKey) ?? false)) {
      for (final key in _perAccountKeys) {
        final value = prefs.get(key);
        if (value == null) continue;

        final target = 'u_$uid.$key';
        if (value is String) {
          await prefs.setString(target, value);
        } else if (value is int) {
          await prefs.setInt(target, value);
        }
        await prefs.remove(key);
      }
      await prefs.setBool(_claimedKey, true);
    }

    await prefs.setString(_uidKey, uid);
  }

  // Deletes only the signed-in account's data (used by "Reset all")
  static Future<void> clearActiveData() async {
    final prefs = await SharedPreferences.getInstance();
    final p = await prefix();
    final mine = prefs.getKeys().where((k) => k.startsWith(p)).toList();
    for (final key in mine) {
      await prefs.remove(key);
    }
  }
}