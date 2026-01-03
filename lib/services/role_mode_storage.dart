import 'package:shared_preferences/shared_preferences.dart';

class RoleModeStorage {
  static const String _keyPrefix = 'role_mode_';

  static Future<String?> getSelectedRole(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_keyPrefix$uid');
  }

  static Future<void> setSelectedRole(String uid, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrefix$uid', role);
  }

  static Future<void> clearSelectedRole(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$uid');
  }
}
