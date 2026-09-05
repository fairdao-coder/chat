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

  /// 是否啟用語音通話。
  bool get enableVoiceCall => _chatBool('EnableVoiceCall');

  /// 是否啟用視頻通話。
  bool get enableVideoCall => _chatBool('EnableVideoCall');

  /// 是否允許發送文件（含圖片）。
  bool get allowFile => _chatBool('AllowFile');

  /// 是否允許發送語音消息。
  bool get allowVoice => _chatBool('AllowVoice');

  /// 是否允許普通用戶自助註冊新帳號。
  bool get allowRegister => _chatBool('AllowRegister');

  /// 默認打開的欄目（底部固定 Tab）Id，null 表示未配置。
  String? get defaultColumnId {
    if (otherConfig == null) return null;
    final m = jsonDecode(otherConfig!) as Map<dynamic, dynamic>?;
    return m?['DefaultColumnId'] as String?;
  }

  /// WebRTC ICE 服務器列表（STUN/TURN）。
  ///
  /// 供 [flutter_webrtc] 的 [RTCConfiguration.iceServers] 使用，
  /// 每項形如 `{'urls': [...], 'username': ..., 'credential': ..., 'credentialType': ...}`。
  /// 後端未配置（null）或解析失敗時回落到兩個 Google 公共 STUN。
  List<Map<String, dynamic>> get iceServers {
    final src = rtConfig;
    if (src == null || src.trim().isEmpty) return _defaultIceServers();
    try {
      final m = jsonDecode(src) as Map<dynamic, dynamic>?;
      final list = m?['IceServers'] as List<dynamic>?;
      if (list == null || list.isEmpty) return _defaultIceServers();

      final result = <Map<String, dynamic>>[];
      for (final item in list) {
        final srv = item as Map<dynamic, dynamic>?;
        if (srv == null) continue;
        final urls = srv['Urls'];
        final urlList = urls is List
            ? urls.map((e) => e.toString()).toList()
            : urls is String
                ? [urls]
                : <String>[];
        if (urlList.isEmpty) continue;
        final entry = <String, dynamic>{
          'urls': urlList,
          if (srv['Username'] != null) 'username': srv['Username'].toString(),
          if (srv['Credential'] != null) 'credential': srv['Credential'].toString(),
          if (srv['CredentialType'] != null)
            'credentialType': srv['CredentialType'].toString(),
        };
        result.add(entry);
      }
      return result.isEmpty ? _defaultIceServers() : result;
    } catch (_) {
      return _defaultIceServers();
    }
  }

  /// 默認 ICE 服務器：空列表。
  ///
  /// 不依賴外網 STUN，讓 WebRTC 僅靠 host candidate（本地網卡 IP）完成區域網內直連，
  /// 解決純內網/無外網環境下因 STUN 不可達導致的通話失敗。
  /// 需要跨網段/跨 NAT 時，由管理後台在 [rtConfig] 下發 STUN/TURN。
  static List<Map<String, dynamic>> _defaultIceServers() => const [];

  /// 拉取失敗時回退到全開，避免接口異常導致所有功能不可用。
  factory FeatureSettings.allEnabled() => const FeatureSettings();

  factory FeatureSettings.fromJson(Map<String, dynamic> j) => FeatureSettings(
        chatConfig: j['chatConfig'] as String? ?? '{}',
        otherConfig: j['otherConfig'] as String?,
        rtConfig: j['rtConfig'] as String?,
      );
}
