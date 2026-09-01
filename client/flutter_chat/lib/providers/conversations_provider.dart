import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/contact_dto.dart';
import '../models/friend_request_dto.dart';
import '../models/user_dto.dart';
import 'core_providers.dart';

/// Recent conversations (friends + groups) with last-message preview & presence.
final conversationsProvider = FutureProvider<List<ContactDto>>((ref) {
  final api = ref.watch(apiProvider);
  return api.getConversations();
});

/// Incoming pending friend requests (for the badge / requests page).
final friendRequestsProvider = FutureProvider<List<FriendRequestDto>>((ref) {
  final api = ref.watch(apiProvider);
  return api.getFriendRequests();
});

/// 监听 SignalR 的 `ReceiveFriendRequest` 推送：收到新邀请时即时刷新
/// [friendRequestsProvider]，使好友请求页与通讯录红点实时更新，无需重启 App。
/// 该 provider 仅为副作用而存在，无状态输出；在应用入口处被 watch 一次即可。
/// hub 是单例、[ChatHubClient.onFriendRequest] 为 broadcast，这里只订阅一次，
/// 无论登录/登出切换都不会重复订阅。
///
/// 注意：此 provider 刻意【不】 watch/读取 [authProvider]，避免在 auth 状态变化
/// （依赖已失效、provider 尚未重建）的窗口里于流回调中调用 ref 函数，从而触发
/// Riverpod "Cannot use ref functions after the dependency of a provider changed"
/// 错误。是否真正登录由调用方 invalidate 的目标 provider 自行判断即可。
final friendRequestPushProvider = Provider<void>((ref) {
  final hub = ref.watch(hubProvider);
  final sub = hub.onFriendRequest.listen((_) {
    // 仅标记失效，让 friends/friendRequests 等 provider 在下次读取时自行
    // 携带最新登录态重新拉取；此处不做任何 ref 读取，规避生命周期竞态。
    ref.invalidate(friendRequestsProvider);
  });
  // 常驻：应用生命周期内只订阅一次，不被任何依赖变化反复重建/销毁。
  ref.keepAlive();
  ref.onDispose(sub.cancel);
});

/// 好友列表（通訊錄 tab）。
final friendsProvider = FutureProvider<List<UserDto>>((ref) async {
  final api = ref.watch(apiProvider);
  final list = await api.getFriends();
  list.sort((a, b) => a.nickName.compareTo(b.nickName));
  return list;
});
