import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_result.dart';
import '../models/user_dto.dart';

/// Persists the JWT and current user in SharedPreferences.
class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  Future<void> save(AuthResult r) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_tokenKey, r.token);
    await p.setString(_userKey, jsonEncode(r.user.toJson()));
  }

  Future<String?> getToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_tokenKey);
  }

  Future<UserDto?> getUser() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_userKey);
    if (s == null) return null;
    try {
      return UserDto.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_tokenKey);
    await p.remove(_userKey);
  }
}
