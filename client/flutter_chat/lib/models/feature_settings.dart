/// 系統功能開關（由管理後臺配置，客戶端啟動時拉取）。
///
/// 字段與後端 `FeatureSettingsDto` / `SystemSettings` 一一對應。
class FeatureSettings {
  /// 是否顯示好友在線狀態。
  final bool showOnlineStatus;

  /// 是否啟用語音通話。
  final bool enableVoiceCall;

  /// 是否啟用視頻通話。
  final bool enableVideoCall;

  /// 是否允許發送文件（含圖片）。
  final bool allowFile;

  /// 是否允許發送語音消息。
  final bool allowVoice;

  const FeatureSettings({
    this.showOnlineStatus = true,
    this.enableVoiceCall = true,
    this.enableVideoCall = true,
    this.allowFile = true,
    this.allowVoice = true,
  });

  /// 拉取失敗時回退到全開，避免接口異常導致所有功能不可用。
  factory FeatureSettings.allEnabled() => const FeatureSettings();

  factory FeatureSettings.fromJson(Map<String, dynamic> j) => FeatureSettings(
        showOnlineStatus: j['showOnlineStatus'] ?? true,
        enableVoiceCall: j['enableVoiceCall'] ?? true,
        enableVideoCall: j['enableVideoCall'] ?? true,
        allowFile: j['allowFile'] ?? true,
        allowVoice: j['allowVoice'] ?? true,
      );
}
