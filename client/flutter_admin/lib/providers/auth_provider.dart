import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../api/models.dart';
import '../core/constants.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient api = ApiClient();

  bool busy = true;
  bool isAuthenticated = false;
  AdminUserDto? admin;
  List<String> permissions = [];

  bool hasPerm(String p) => permissions.contains('*') || permissions.contains(p);

  Future<void> loadFromStorage() async {
    await api.loadToken();
    if (api.token != null) {
      try {
        final me = await api.get('/api/admin/auth/me');
        _applyMe(me);
      } catch (_) {
        await logout();
      }
    }
    busy = false;
    notifyListeners();
  }

  void _applyMe(Map<String, dynamic> me) {
    admin = AdminUserDto.fromJson(me['admin']);
    permissions = List<String>.from(me['permissions'] ?? []);
    isAuthenticated = true;
  }

  Future<void> login(String user, String pass) async {
    final res = await api.post('/api/admin/auth/login', {
      'userName': user,
      'password': pass,
    });
    api.setToken(res['token']);
    final sp = await SharedPreferences.getInstance();
    await sp.setString(Constants.tokenKey, res['token']);
    _applyMe(res);
    notifyListeners();
  }

  Future<void> logout() async {
    api.setToken(null);
    final sp = await SharedPreferences.getInstance();
    await sp.remove(Constants.tokenKey);
    admin = null;
    permissions = [];
    isAuthenticated = false;
    notifyListeners();
  }
}
