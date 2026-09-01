using System;

namespace ChatServer.Entities;

// <summary>
/// 全系統功能開關（單例配置）。
///
/// 表由 AdminServer 負責建立，ChatServer 僅讀取，字段需與
/// AdminServer.Entities.SystemSettings 保持一致。
/// </summary>
public class SystemSettings
{
    /// 單例行的固定主鍵（必須與 AdminServer 端一致）。
    public static readonly Guid SingletonId =
        Guid.Parse("00000000-0000-0000-0000-000000000001");

    public Guid Id { get; set; } = SingletonId;

    /// 是否顯示好友在線狀態。
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
