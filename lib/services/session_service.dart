import 'package:shared_preferences/shared_preferences.dart';

import '../data/mock_database.dart';

class SessionService {
  static const _sessionUserIdKey = 'session_user_id';

  Future<void> saveSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionUserIdKey, user.id);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionUserIdKey);
  }

  Future<User?> loadSessionUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_sessionUserIdKey);
    if (userId == null || userId.isEmpty) return null;
    return DatabaseService().getUserById(userId);
  }
}
