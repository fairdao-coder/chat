import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/signalr_client.dart';
import 'core_providers.dart';

/// 正在輸入的對方用戶 ID 集合。
///
/// 事件為「盡力而為」：對方強制退出 / 網絡中斷時可能收不到 isTyping=false，
/// 因此每條 true 都帶 4 秒過期，超時自動清除，
/// 避免「正在輸入...」永久卡在界面上。
final typingProvider =
    StateNotifierProvider<TypingController, Set<String>>((ref) {
  return TypingController(ref.read(hubProvider));
});

class TypingController extends StateNotifier<Set<String>> {
  final ChatHubClient _hub;
  StreamSubscription<(String, bool)>? _sub;
  final Map<String, Timer> _timers = {};

  /// 超過該時長未收到新事件則視為已停止輸入。
  static const Duration _timeout = Duration(seconds: 4);

  TypingController(this._hub) : super(<String>{}) {
    _sub = _hub.onTyping.listen((e) {
      final userId = e.$1;
      final isTyping = e.$2;
      if (isTyping) {
        _timers[userId]?.cancel();
        _timers[userId] = Timer(_timeout, () => _clear(userId));
        if (!state.contains(userId)) {
          state = {...state, userId};
        }
      } else {
        _clear(userId);
      }
    });
  }

  void _clear(String userId) {
    _timers.remove(userId)?.cancel();
    if (state.contains(userId)) {
      state = {...state}..remove(userId);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    super.dispose();
  }
}
