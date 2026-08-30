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

/// 好友列表（通讯录 tab）。
final friendsProvider = FutureProvider<List<UserDto>>((ref) async {
  final api = ref.watch(apiProvider);
  final list = await api.getFriends();
  list.sort((a, b) => a.nickName.compareTo(b.nickName));
  return list;
});
