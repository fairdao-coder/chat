import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../data/signalr_client.dart';
import 'core_providers.dart';

/// 在線好友 ID 集合（單一數據源）。
///
/// SignalR 的 `UserOnline` / `UserOffline` 屬於"盡力而為"的推送：重連窗口期、
/// 頁面尚未訂閱之前發生的事件都會丟失，導致列表裡出現"殭屍在線/離線"。
/// 這裡用「實時事件 + 定時輪詢服務端快照」雙通道保證在線狀態最終一致：
/// - 事件即時生效，無需等待輪詢；
/// - 輪詢（每 10s）兜底，把丟失的事件糾正回來。
final presenceProvider =
    StateNotifierProvider<PresenceController, Set<String>>((ref) {
  return PresenceController(ref.read(apiProvider), ref.read(hubProvider));
});

class PresenceController extends StateNotifier<Set<String>> {
  final ApiClient _api;
  final ChatHubClient _hub;
  Timer? _timer;
  StreamSubscription<String>? _onlineSub;
  StreamSubscription<String>? _offlineSub;

  PresenceController(this._api, this._hub) : super(<String>{}) {
    _onlineSub = _hub.onUserOnline.listen((id) {
      state = {...state, id};
    });
    _offlineSub = _hub.onUserOffline.listen((id) {
      state = {...state}..remove(id);
    });
    unawaited(refresh());
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => refresh());
  }

  /// 拉取服務端在線快照。失敗時保留上一次狀態，等下個週期再校正。
  Future<void> refresh() async {
    try {
      state = await _api.getOnlineFriends();
    } catch (_) {
      // 未登錄 / 網絡抖動：靜默忽略。
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _onlineSub?.cancel();
    _offlineSub?.cancel();
    super.dispose();
  }
}
