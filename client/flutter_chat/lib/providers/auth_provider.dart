import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../data/signalr_client.dart';
import '../models/user_dto.dart';
import '../services/auth_service.dart';
import 'core_providers.dart';

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(apiProvider), ref.read(hubProvider));
});

class AuthState {
  final bool isLoading;
  final String? token;
  final UserDto? user;
  final String? error;

  const AuthState({this.isLoading = false, this.token, this.user, this.error});

  AuthState copyWith({
    bool? isLoading,
    String? token,
    UserDto? user,
    String? error,
    bool clearUser = false,
  }) =>
      AuthState(
        isLoading: isLoading ?? this.isLoading,
        token: token ?? this.token,
        user: clearUser ? null : (user ?? this.user),
        error: error,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _api;
  final ChatHubClient _hub;

  AuthNotifier(this._api, this._hub) : super(const AuthState());

  /// Restore persisted session (called once at startup).
  Future<void> init() async {
    final svc = AuthService();
    final token = await svc.getToken();
    final user = await svc.getUser();
    if (token != null && token.isNotEmpty && user != null) {
      state = state.copyWith(token: token, user: user);
      try {
        await _hub.connect(token);
      } catch (_) {
        // offline / server down — stay "logged in" locally, hub reconnects later
      }
    }
  }

  Future<bool> login(String userName, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final r = await _api.login(userName, password);
      await AuthService().save(r);
      try {
        await _hub.connect(r.token);
      } catch (_) {}
      state = state.copyWith(isLoading: false, token: r.token, user: r.user);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> register(String userName, String password, String nickName) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final r = await _api.register(userName, password, nickName);
      await AuthService().save(r);
      try {
        await _hub.connect(r.token);
      } catch (_) {}
      state = state.copyWith(isLoading: false, token: r.token, user: r.user);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await _hub.disconnect();
    await AuthService().clear();
    state = const AuthState();
  }
}
