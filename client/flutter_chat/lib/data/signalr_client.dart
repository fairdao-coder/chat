import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';

import '../config/app_config.dart';
import '../config/constants.dart';
import '../models/call_signal.dart';
import '../models/friend_request_dto.dart';
import '../models/message_dto.dart';

/// Singleton wrapper around the SignalR `/hubs/chat` connection.
///
/// - Authenticates with the JWT via [HttpConnectionOptions.accessTokenFactory]
///   (the hub reads it as the `access_token` query parameter on handshake).
/// - Exposes typed invoke methods matching ChatHub.cs.
/// - Surfaces server events (ReceiveMessage / UserOnline / UserOffline) as streams.
class ChatHubClient {
  HubConnection? _connection;
  String? _token;
  // 記錄當前連接指向的 hub 地址；登錄頁修改服務器地址後，
  // connect() 據此丟棄舊連接、按新地址重建，而無需更換本單例
  // （callProvider 等既有訂閱者因此自動跟隨新地址）。
  String? _connectedUrl;

  final _messageController = StreamController<MessageDto>.broadcast();
  final _onlineController = StreamController<String>.broadcast();
  final _offlineController = StreamController<String>.broadcast();
  final _stateController = StreamController<bool>.broadcast();
  final _friendRequestCtl = StreamController<FriendRequestDto>.broadcast();
  // 正在輸入狀態：(對方用戶 ID, 是否正在輸入)
  final _typingCtl = StreamController<(String, bool)>.broadcast();
  // 消息撤回：推送已撤回的完整 MessageDto（含 conversationId）。
  final _recalledCtl = StreamController<MessageDto>.broadcast();

  // 通話信令事件
  final _incomingCallCtl = StreamController<CallInvite>.broadcast();
  final _callAcceptedCtl = StreamController<String>.broadcast();
  final _callRejectedCtl = StreamController<(String, String)>.broadcast();
  final _offerCtl = StreamController<(String, String)>.broadcast();
  final _answerCtl = StreamController<(String, String)>.broadcast();
  final _iceCtl = StreamController<(String, String)>.broadcast();
  final _hangUpCtl = StreamController<String>.broadcast();

  Stream<MessageDto> get onMessage => _messageController.stream;
  Stream<String> get onUserOnline => _onlineController.stream;
  Stream<String> get onUserOffline => _offlineController.stream;
  Stream<bool> get onConnectionState => _stateController.stream;
  Stream<FriendRequestDto> get onFriendRequest => _friendRequestCtl.stream;
  Stream<(String, bool)> get onTyping => _typingCtl.stream;
  Stream<MessageDto> get onMessageRecalled => _recalledCtl.stream;

  Stream<CallInvite> get onIncomingCall => _incomingCallCtl.stream;
  Stream<String> get onCallAccepted => _callAcceptedCtl.stream;
  Stream<(String, String)> get onCallRejected => _callRejectedCtl.stream;
  Stream<(String, String)> get onOffer => _offerCtl.stream;
  Stream<(String, String)> get onAnswer => _answerCtl.stream;
  Stream<(String, String)> get onIceCandidate => _iceCtl.stream;
  Stream<String> get onHangUp => _hangUpCtl.stream;

  bool get isConnected => _connection?.state == HubConnectionState.Connected;

  Future<void> connect(String token) async {
    _token = token;
    // 服務器地址被修改後：丟棄指向舊地址的連接，按新地址重建。
    final url = AppConfig.hubUrl;
    if (_connection != null && _connectedUrl != url) {
      try {
        await _connection!.stop();
      } catch (_) {}
      _connection = null;
    }
    _connectedUrl = url;

    if (_connection != null) {
      if (_connection!.state == HubConnectionState.Disconnected) {
        await _connection!.start();
        _stateController.add(true);
      }
      return;
    }

    _connection = HubConnectionBuilder()
        .withUrl(AppConfig.hubUrl,
            options: HttpConnectionOptions(
              accessTokenFactory: () => Future.value(_token),
            ))
        .withAutomaticReconnect()
        .build();

    _connection!.on(HubEvents.receiveMessage, (args) {
      if (args != null && args.isNotEmpty) {
        try {
          _messageController.add(MessageDto.fromJson(args[0] as Map<String, dynamic>));
        } catch (_) {
          // ignore malformed payloads
        }
      }
    });
    _connection!.on(HubEvents.userOnline, (args) {
      if (args != null && args.isNotEmpty) _onlineController.add(args[0].toString());
    });
    _connection!.on(HubEvents.userOffline, (args) {
      if (args != null && args.isNotEmpty) _offlineController.add(args[0].toString());
    });
    _connection!.on(HubEvents.receiveFriendRequest, (args) {
      if (args != null && args.isNotEmpty) {
        try {
          _friendRequestCtl.add(FriendRequestDto.fromJson(args[0] as Map<String, dynamic>));
        } catch (_) {
          // ignore malformed payloads
        }
      }
    });

    _connection!.on(HubEvents.typing, (args) {
      if (args != null && args.length >= 2) {
        _typingCtl.add((args[0].toString(), args[1] == true));
      }
    });

    _connection!.on(HubEvents.messageRecalled, (args) {
      if (args != null && args.isNotEmpty) {
        try {
          _recalledCtl.add(MessageDto.fromJson(args[0] as Map<String, dynamic>));
        } catch (_) {
          // ignore malformed payloads
        }
      }
    });

    // 通話信令
    _connection!.on(HubEvents.incomingCall, (args) {
      if (args != null && args.length >= 4) {
        _incomingCallCtl.add(CallInvite(
          args[0] as String,
          args[1] as String,
          args[2]?.toString() ?? '',
          args[3] as String,
        ));
      }
    });
    _connection!.on(HubEvents.callAccepted, (args) {
      if (args != null && args.isNotEmpty) _callAcceptedCtl.add(args[0].toString());
    });
    _connection!.on(HubEvents.callRejected, (args) {
      if (args != null && args.length >= 2) {
        _callRejectedCtl.add((args[0].toString(), args[1].toString()));
      }
    });
    _connection!.on(HubEvents.offer, (args) {
      if (args != null && args.length >= 2) {
        _offerCtl.add((args[0].toString(), args[1].toString()));
      }
    });
    _connection!.on(HubEvents.answer, (args) {
      if (args != null && args.length >= 2) {
        _answerCtl.add((args[0].toString(), args[1].toString()));
      }
    });
    _connection!.on(HubEvents.iceCandidate, (args) {
      if (args != null && args.length >= 2) {
        _iceCtl.add((args[0].toString(), args[1].toString()));
      }
    });
    _connection!.on(HubEvents.hangUp, (args) {
      if (args != null && args.isNotEmpty) _hangUpCtl.add(args[0].toString());
    });

    _connection!.onclose(({Exception? error}) {
      _stateController.add(false);
    });

    await _connection!.start();
    _stateController.add(true);
  }

  Future<void> disconnect() async {
    if (_connection != null) {
      await _connection!.stop();
      _connection = null;
    }
    _stateController.add(false);
  }

  // ---- Client -> Server invokes (method names/order per ChatHub.cs) ----

  Future<void> sendPrivateMessage(
      String toUserId, String content, String type, String? mediaUrl,
      {String? replyToId}) async {
    await _ensureConnected();
    await _connection!.invoke(HubMethods.sendPrivateMessage,
        args: [toUserId, content, type, mediaUrl ?? '', replyToId ?? '']);
  }

  Future<void> sendGroupMessage(
      String groupId, String content, String type, String? mediaUrl,
      {String? replyToId}) async {
    await _ensureConnected();
    await _connection!.invoke(HubMethods.sendGroupMessage,
        args: [groupId, content, type, mediaUrl ?? '', replyToId ?? '']);
  }

  /// 撤回自己發出的消息（服務端限時 2 分鐘）。
  /// 撤回結果通過 [onMessageRecalled] 事件回流，本地無需自行改狀態。
  Future<void> recallMessage(String messageId) async {
    await _ensureConnected();
    await _connection!.invoke(HubMethods.recallMessage, args: [messageId]);
  }

  Future<void> joinGroup(String groupId) async {
    await _ensureConnected();
    await _connection!.invoke(HubMethods.joinGroup, args: [groupId]);
  }

  Future<void> leaveGroup(String groupId) async {
    await _ensureConnected();
    await _connection!.invoke(HubMethods.leaveGroup, args: [groupId]);
  }

  /// 上報"正在輸入"狀態。異常靜默忽略（輸入提示屬錦上添花，不應打斷輸入體驗）。
  Future<void> sendTyping(String toUserId, bool isTyping) async {
    try {
      await _ensureConnected();
      await _connection!.invoke(HubMethods.sendTyping, args: [toUserId, isTyping]);
    } catch (_) {
      // 忽略：連接中斷時自動重連後會由下一輪輸入重新上報。
    }
  }

  // ---- 通話信令 invokes（方法名/參數順序與 ChatHub.cs 保持一致） ----

  Future<void> inviteCall(String callId, String targetUserId, String callType) async {
    await _ensureConnected();
    await _connection!.invoke(HubMethods.inviteCall,
        args: [callId, targetUserId, callType]);
  }

  Future<void> acceptCall(String callId) async {
    await _ensureConnected();
    await _connection!.invoke(HubMethods.acceptCall, args: [callId]);
  }

  Future<void> rejectCall(String callId) async {
    await _ensureConnected();
    await _connection!.invoke(HubMethods.rejectCall, args: [callId]);
  }

  Future<void> sendOffer(String callId, String sdp) async {
    await _ensureConnected();
    await _connection!.invoke(HubMethods.sendOffer, args: [callId, sdp]);
  }

  Future<void> sendAnswer(String callId, String sdp) async {
    await _ensureConnected();
    await _connection!.invoke(HubMethods.sendAnswer, args: [callId, sdp]);
  }

  Future<void> sendIceCandidate(String callId, String candidate) async {
    await _ensureConnected();
    await _connection!.invoke(HubMethods.sendIceCandidate, args: [callId, candidate]);
  }

  Future<void> hangUpCall(String callId) async {
    await _ensureConnected();
    await _connection!.invoke(HubMethods.hangUp, args: [callId]);
  }

  /// Waits until the underlying connection is active before invoking, restarting
  /// it if it dropped (automatic reconnect does not trigger on a failed start).
  Future<void> _ensureConnected() async {
    if (_connection == null) {
      throw StateError('Hub is not connected. Call connect() first.');
    }
    if (_connection!.state == HubConnectionState.Connected) return;
    if (_connection!.state == HubConnectionState.Disconnected) {
      await _connection!.start();
      _stateController.add(true);
      return;
    }
    // Reconnecting: give it a moment, then attempt a start if still not active.
    for (var i = 0; i < 50; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (_connection!.state == HubConnectionState.Connected) return;
    }
    if (_connection!.state == HubConnectionState.Disconnected) {
      await _connection!.start();
      _stateController.add(true);
    }
  }
}
