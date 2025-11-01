import 'package:shared_preferences/shared_preferences.dart';

/// Minimal wrapper for SharedPreferences
/// Note: Authentication tokens (id_token, prof_id) are now stored in Hive via LocationStorageService
/// This class is kept for any temporary/non-critical data that needs SharedPreferences
class SharedPrefs {
  static Future<void> saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  static Future<String?> getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
