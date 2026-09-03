import 'dart:convert';

/// 系統功能開關（由管理後臺配置，客戶端啟動時拉取）。
///
/// 後端按分類存儲為 JSON：[chatConfig] 存聊天相關開關，
/// [otherConfig] 存其他雜項（如默認打開欄目）。
class FeatureSettings {
  /// 聊天功能開關 JSON 字符串。
  final String chatConfig;

  /// 其他配置 JSON 字符串，可能為 null。
  final String? otherConfig;

  const FeatureSettings({
    this.chatConfig = '{}',
    this.otherConfig,
  });

  Map<String, dynamic> get _chat => Map<String, dynamic>.from(
      (jsonDecode(chatConfig) as Map<dynamic, dynamic>?) ?? {});

  bool _chatBool(String key) => _chat[key] as bool? ?? true;

  /// 是否顯示好友在線狀態。
  bool get showOnlineStatus => _chatBool('ShowOnlineStatus');

  /// 是否啟用語音通話。
  bool get enableVoiceCall => _chatBool('EnableVoiceCall');

  /// 是否啟用視頻通話。
  bool get enableVideoCall => _chatBool('EnableVideoCall');

  /// 是否允許發送文件（含圖片）。
  bool get allowFile => _chatBool('AllowFile');

  /// 是否允許發送語音消息。
  bool get allowVoice => _chatBool('AllowVoice');

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
      );
}
