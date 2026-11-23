import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session.dart';

/// Stores and retrieves session history from SharedPreferences.
class SessionStorage {
  static const _key = 'heart_rate_sessions';

  static Future<void> saveSession(Session session) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await getSessions();
    sessions.insert(0, session);
    final jsonList = sessions.map((s) => jsonEncode(s.toMap())).toList();
    await prefs.setStringList(_key, jsonList);
  }

  static Future<List<Session>> getSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_key) ?? [];
    return jsonList
        .map((json) => Session.fromMap(jsonDecode(json) as Map<String, dynamic>))
        .toList();
  }

  static Future<void> clearSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
