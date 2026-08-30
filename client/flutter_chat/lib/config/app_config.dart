import 'package:shared_preferences/shared_preferences.dart';

/// Central runtime configuration. The API base MUST match the running
/// ASP.NET Core server (see server/ChatServer/Program.cs).
///
/// Defaults (dev):
///   - Flutter Web (chrome) : http://localhost:5298   (same machine, CORS-enabled)
///   - Windows desktop      : http://localhost:5298
///   - Android emulator     : http://10.0.2.2:5298    (10.0.2.2 == host loopback)
///   - iOS simulator        : http://localhost:5298
///   - Physical device      : your dev machine LAN IP, e.g. http://192.168.1.50:5298
///
/// The value can be overridden at runtime (Settings) and persists via SharedPreferences.
class AppConfig {
  static const String defaultApiBase = 'http://localhost:5298';
  static const String _prefKey = 'api_base';

  /// Resolved API base (no trailing slash).
  static String apiBase = defaultApiBase;

  /// Absolute SignalR hub URL.
  static String get hubUrl =>
      '${apiBase.replaceAll(RegExp(r'/\$'), '')}/hubs/chat';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null && saved.isNotEmpty) {
      apiBase = saved.trim();
    }
  }

  static Future<void> set(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.trim().isEmpty) {
      apiBase = defaultApiBase;
      await prefs.remove(_prefKey);
    } else {
      apiBase = value.trim();
      await prefs.setString(_prefKey, apiBase);
    }
  }
}
