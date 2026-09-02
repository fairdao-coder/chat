namespace Chat.Shared.Entities;

/// <summary>
/// 全系統功能開關（單例配置）。
///
/// 由管理後臺維護，聊天客戶端啟動時讀取，據此控制功能可用性。
/// 採用固定主鍵的單行記錄，便於各端直接查找，無需「先查列表再取首條」。
/// </summary>
public class SystemSettings
{
    /// 單例行的固定主鍵（ChatServer 與 AdminServer 必須一致）。
    public static readonly Guid SingletonId =
        Guid.Parse("00000000-0000-0000-0000-000000000001");

    public Guid Id { get; set; } = SingletonId;

    /// 是否顯示好友在線狀態（關閉後聊天頁不再展示在線/離線）。
    public bool ShowOnlineStatus { get; set; } = true;

    /// 是否啟用語音通話。
    public bool EnableVoiceCall { get; set; } = true;

    /// 是否啟用視頻通話。
    public bool EnableVideoCall { get; set; } = true;

    /// 是否允許發送文件（含圖片）。
    public bool AllowFile { get; set; } = true;

    /// 是否允許發送語音消息。
    public bool AllowVoice { get; set; } = true;

    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
