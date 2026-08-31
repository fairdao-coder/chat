import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/contact_dto.dart';
import '../models/friend_request_dto.dart';
import '../models/user_dto.dart';
import 'auth_provider.dart';
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
final friendRequestPushProvider = Provider<void>((ref) {
  final hub = ref.watch(hubProvider);
  ref.watch(authProvider);
  hub.onFriendRequest.listen((_) {
    // 仅在已登录（token 存在）时刷新；登出后无好友请求上下文。
    if (ref.read(authProvider).token != null) {
      ref.invalidate(friendRequestsProvider);
    }
  });
});

/// 好友列表（通訊錄 tab）。
final friendsProvider = FutureProvider<List<UserDto>>((ref) async {
  final api = ref.watch(apiProvider);
  final list = await api.getFriends();
  list.sort((a, b) => a.nickName.compareTo(b.nickName));
  return list;
});
