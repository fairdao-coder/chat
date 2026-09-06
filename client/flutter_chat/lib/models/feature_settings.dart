import 'dart:convert';

/// 系統功能開關（由管理後臺配置，客戶端啟動時拉取）。
///
/// 後端按分類存儲為 JSON：[chatConfig] 存聊天相關開關，
/// [otherConfig] 存其他雜項（如默認打開欄目），
/// [rtConfig] 存 WebRTC 實時通信配置（STUN/TURN 列表）。
class FeatureSettings {
  /// 聊天功能開關 JSON 字符串。
  final String chatConfig;

  /// 其他配置 JSON 字符串，可能為 null。
  final String? otherConfig;

  /// WebRTC 實時通信配置 JSON 字符串（STUN/TURN），可能為 null。
  final String? rtConfig;

  const FeatureSettings({
    this.chatConfig = '{}',
    this.otherConfig,
    this.rtConfig,
  });

  Map<String, dynamic> get _chat => Map<String, dynamic>.from(
      (jsonDecode(chatConfig) as Map<dynamic, dynamic>?) ?? {});

  bool _chatBool(String key) => _chat[key] as bool? ?? true;

  /// 是否顯示好友在線狀態。
  bool get showOnlineStatus => _chatBool('ShowOnlineStatus');

  /// 是否允許發送文件（含圖片）。
  bool get allowFile => _chatBool('AllowFile');

  /// 是否允許發送語音消息。
  bool get allowVoice => _chatBool('AllowVoice');

  /// 是否允許普通用戶自助註冊新帳號。
  bool get allowRegister => _chatBool('AllowRegister');

  /// 是否允許發起語音通話。
  bool get allowVoiceCall => _chatBool('AllowVoiceCall');

  /// 是否允許發起視頻通話。
  bool get allowVideoCall => _chatBool('AllowVideoCall');

  /// 默認打開的欄目（底部固定 Tab）Id，null 表示未配置。
  String? get defaultColumnId {
    if (otherConfig == null) return null;
    final m = jsonDecode(otherConfig!) as Map<dynamic, dynamic>?;
    return m?['DefaultColumnId'] as String?;
  }


  /// 拉取失敗時回退到全開，避免接口異常導致所有功能不可用。
  factory FeatureSettings.allEnabled() => const FeatureSettings();

  factory FeatureSettings.fromJson(Map<String, dynamic> j) => FeatureSettings(
        chatConfig: j['chatConfig'] as String? ?? '{}',
        otherConfig: j['otherConfig'] as String?,
        rtConfig: j['rtConfig'] as String?,
      );
}
