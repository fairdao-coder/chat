import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../data/signalr_client.dart';
import '../models/enums.dart';
import '../models/message_dto.dart';
import '../utils/conversation_keys.dart';
import 'auth_provider.dart';
import 'core_providers.dart';

/// Identifies which conversation a [ChatPage] is showing.
class ChatTarget {
  final String id; // group id, or friend (peer) id
  final bool isGroup;
  /// 是否為客服會話（客服帳號免好友關係，UI 隱藏「加好友」並顯示客服標識）。
  final bool isService;
  const ChatTarget(
      {required this.id, required this.isGroup, this.isService = false});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatTarget &&
          other.id == id &&
          other.isGroup == isGroup &&
          other.isService == isService;

  @override
  int get hashCode =>
      id.hashCode ^ (isGroup ? 1 : 0) ^ (isService ? 2 : 0);
}

final chatProvider =
    StateNotifierProvider.family<ChatController, ChatState, ChatTarget>(
        (ref, target) {
  return ChatController(
      ref.read(apiProvider), ref.read(hubProvider), ref, target);
});

class ChatState {
  final List<MessageDto> messages;
  final bool loading;
  final String? error;
  const ChatState({this.messages = const [], this.loading = false, this.error});
  ChatState copyWith({List<MessageDto>? messages, bool? loading, String? error}) =>
      ChatState(
        messages: messages ?? this.messages,
        loading: loading ?? this.loading,
        error: error,
      );
}

class ChatController extends StateNotifier<ChatState> {
  final ApiClient _api;
  final ChatHubClient _hub;
  final Ref _ref;
  final ChatTarget _target;
  StreamSubscription<MessageDto>? _sub;
  StreamSubscription<MessageDto>? _recallSub;
  String? _convId;

  ChatController(this._api, this._hub, this._ref, this._target)
      : super(const ChatState(loading: true)) {
    _init();
  }

  String? get _myId => _ref.read(authProvider).user?.id;

  Future<void> _init() async {
    final myId = _myId;
    if (myId == null) {
      // 從通知橫幅點擊進入會話時，若登入狀態尚未載入完成，避免 null check 崩潰。
      state = state.copyWith(
          loading: false, error: '未登錄或登入狀態尚未載入，請稍後重試');
      return;
    }
    _convId = _target.isGroup
        ? groupConversationId(_target.id)
        : privateConversationId(myId, _target.id);

    try {
      final history = _target.isGroup
          ? await _api.getGroupHistory(_target.id)
          : await _api.getPrivateHistory(_target.id);
      state = state.copyWith(messages: history, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }

    if (_target.isGroup) {
      try {
        await _hub.joinGroup(_target.id);
      } catch (_) {}
    }

    _sub = _hub.onMessage.listen((m) {
      if (m.conversationId != _convId) {
        // 兜底：如果 client 計算的 convId 與 server 發回的不同（舊版/排序規則不一致），
        // 仍按 (senderId, mediaUrl) 視為同會話，避免樂觀氣泡一直留著不被替換。
        final lookupOk = state.messages.any((x) =>
            x.id.startsWith('optimistic_') &&
            x.senderId == m.senderId &&
            (x.mediaUrl != null && x.mediaUrl == m.mediaUrl));
        if (!lookupOk) return;
        developer.log('onMessage convId mismatch (mine=$_convId theirs=${m.conversationId})'
            ' but matched by optimistic+mediaUrl', name: 'chat');
      }
      // 用服務端回發的真實消息替換本地樂觀消息（按發送者+媒體 URL 匹配）。
      final idx = state.messages.indexWhere((x) =>
          x.id.startsWith('optimistic_') &&
          x.senderId == m.senderId &&
          x.mediaUrl == m.mediaUrl);
      if (idx >= 0) {
        final list = [...state.messages];
        list[idx] = m;
        state = state.copyWith(messages: list);
        return;
      }
      final exists = state.messages.any((x) => x.id == m.id);
      if (!exists) state = state.copyWith(messages: [...state.messages, m]);
    });

    // 撤回事件：把對應氣泡替換為「已撤回」佔位（保留位置，供引用它的消息顯示原摘要狀態）。
    _recallSub = _hub.onMessageRecalled.listen((m) {
      if (m.conversationId != _convId) return;
      final idx = state.messages.indexWhere((x) => x.id == m.id);
      if (idx < 0) return;
      final list = [...state.messages];
      // 服務端下發的已撤回 DTO 已不含正文；保險起見本地也清空。
      list[idx] = m.copyWith(recalled: true, replyPreview: () => null);
      state = state.copyWith(messages: list);
    });
  }

  Future<String?> sendText(String text, {MessageDto? replyTo}) async {
    final content = text.trim();
    if (content.isEmpty) return null;
    return _send(content, 'Text', null, replyToId: replyTo?.id);
  }

  /// 撤回一條自己發出的消息（服務端限時 2 分鐘）。
  /// 返回錯誤碼消息；成功後等服務端 MessageRecalled 事件刷新本地狀態。
  Future<String?> recall(MessageDto m) async {
    try {
      await _hub.recallMessage(m.id);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// 刪除一條消息（僅自己不再顯示）：先落庫再本地移除。
  Future<String?> hide(MessageDto m) async {
    if (m.id.startsWith('optimistic_')) return '該消息尚未發送成功';
    try {
      await _api.hideMessage(m.id);
      state = state.copyWith(
        messages: state.messages.where((x) => x.id != m.id).toList(),
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// 清空當前會話的聊天記錄（僅自己的視角）。
  Future<String?> clearHistory() async {
    final convId = _convId;
    if (convId == null) return '未登錄';
    try {
      await _api.clearConversation(convId);
      state = state.copyWith(messages: []);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// 轉發消息到目標會話：以自己身份重新發送相同內容（不含引用關係）。
  Future<String?> forwardTo(ChatTarget target, MessageDto m) async {
    try {
      if (target.isGroup) {
        await _hub.sendGroupMessage(
            target.id, m.content, messageTypeToJson(m.type), m.mediaUrl);
      } else {
        await _hub.sendPrivateMessage(
            target.id, m.content, messageTypeToJson(m.type), m.mediaUrl);
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> sendMedia(String mediaUrl, String kind) async {
    final myId = _myId;
    if (myId == null) return '未登錄';
    developer.log('sendMedia target=${_target.id} isGroup=${_target.isGroup} '
        'url=$mediaUrl kind=$kind', name: 'chat');
    // 樂觀插入：發送後立刻在本地顯示氣泡，不等服務端回發，避免"點了沒反應"。
    final optimistic = MessageDto(
      id: 'optimistic_${DateTime.now().microsecondsSinceEpoch}',
      conversationId: _convId!,
      senderId: myId,
      senderName: _ref.read(authProvider).user?.nickName ?? '',
      chatType: _target.isGroup ? ChatType.group : ChatType.private,
      content: '',
      type: messageTypeFromJson(kind),
      mediaUrl: mediaUrl,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(messages: [...state.messages, optimistic]);
    developer.log('optimistic message inserted id=${optimistic.id} '
        'convId=$_convId', name: 'chat');
    final err = await _send('', kind, mediaUrl);
    if (err != null) {
      developer.log('sendMedia _send returned err=$err — removing optimistic '
          'id=${optimistic.id}', name: 'chat');
      // 發送失敗：移除樂觀消息，讓用戶看到狀態正確。
      state = state.copyWith(
        messages: state.messages.where((x) => x.id != optimistic.id).toList(),
      );
    } else {
      developer.log('sendMedia _send ok — keeping optimistic until '
          'server echoes ReceiveMessage', name: 'chat');
    }
    return err;
  }

  /// 發送語音消息。[seconds] 為錄音時長，編碼進 content（服務端按字符串存儲，
  /// 零 schema 改動），氣泡再解析為時長顯示。
  Future<String?> sendVoice(String mediaUrl, int seconds) async {
    final myId = _myId;
    if (myId == null) return '未登錄';
    developer.log('sendVoice target=${_target.id} isGroup=${_target.isGroup} '
        'url=$mediaUrl seconds=$seconds', name: 'chat');
    final optimistic = MessageDto(
      id: 'optimistic_${DateTime.now().microsecondsSinceEpoch}',
      conversationId: _convId!,
      senderId: myId,
      senderName: _ref.read(authProvider).user?.nickName ?? '',
      chatType: _target.isGroup ? ChatType.group : ChatType.private,
      content: seconds.toString(),
      type: MessageType.voice,
      mediaUrl: mediaUrl,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(messages: [...state.messages, optimistic]);
    final err = await _send(seconds.toString(), 'Voice', mediaUrl);
    if (err != null) {
      state = state.copyWith(
        messages: state.messages.where((x) => x.id != optimistic.id).toList(),
      );
    }
    return err;
  }

  /// Returns an error message if the send failed, otherwise null.
  Future<String?> _send(String content, String kind, String? mediaUrl,
      {String? replyToId}) async {
    try {
      if (_target.isGroup) {
        await _hub.sendGroupMessage(_target.id, content, kind, mediaUrl,
            replyToId: replyToId);
      } else {
        await _hub.sendPrivateMessage(_target.id, content, kind, mediaUrl,
            replyToId: replyToId);
      }
      return null;
    } catch (e, st) {
      final msg = e.toString();
      developer.log('hub _send exception',
          name: 'chat', error: e, stackTrace: st);
      state = state.copyWith(error: msg);
      return msg;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _recallSub?.cancel();
    if (_target.isGroup) {
      _hub.leaveGroup(_target.id).catchError((_) {});
    }
    super.dispose();
  }
}
