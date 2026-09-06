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

    /// 聊天相關功能開關，存為 JSON：
    /// {"ShowOnlineStatus":true,"AllowFile":true,"AllowVoice":true}
    /// 採用分類存儲，避免每新增一項配置就加一個字段。
    public string ChatConfig { get; set; } = "{}";

    /// 其他配置，存為 JSON，例如：{"DefaultColumnId":"xxx"}。
    /// 默認打開的欄目（底部固定 Tab）的 Id。
    /// 未配置（缺省/缺失）時客戶端回落到按 sort 排在最前的固定欄目；
    /// 默認欄目必須是已固定的欄目。
    public string? OtherConfig { get; set; }

    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    /// 聊天功能開關的強類型視圖（從 [ChatConfig] 解析，缺失項回退默認值）。
    public ChatFeatureConfig Chat => ChatFeatureConfig.FromJson(ChatConfig);

    /// 其他配置的強類型視圖（從 [OtherConfig] 解析）。
    public OtherConfigView Other => OtherConfigView.FromJson(OtherConfig);
}

/// <summary>
/// 聊天功能開關的強類型視圖，對應 <see cref="SystemSettings.ChatConfig"/> 的 JSON。
/// 缺失字段時回退默認值（全開），避免歷史數據缺項導致功能被誤關。
/// </summary>
public sealed class ChatFeatureConfig
{
    public bool ShowOnlineStatus { get; set; } = true;
    public bool AllowFile { get; set; } = true;
    public bool AllowVoice { get; set; } = true;
    /// <summary>是否允許普通用戶自助註冊新帳號；關閉後僅後台可建立帳號。</summary>
    public bool AllowRegister { get; set; } = true;

    public static ChatFeatureConfig FromJson(string? json)
    {
        var cfg = new ChatFeatureConfig();
        if (string.IsNullOrWhiteSpace(json) || json == "{}")
            return cfg;

        using var doc = System.Text.Json.JsonDocument.Parse(json);
        var r = doc.RootElement;
        if (r.TryGetProperty(nameof(ShowOnlineStatus), out var v1) && (v1.ValueKind == System.Text.Json.JsonValueKind.True || v1.ValueKind == System.Text.Json.JsonValueKind.False))
            cfg.ShowOnlineStatus = v1.GetBoolean();
        if (r.TryGetProperty(nameof(AllowFile), out var v4) && (v4.ValueKind == System.Text.Json.JsonValueKind.True || v4.ValueKind == System.Text.Json.JsonValueKind.False))
            cfg.AllowFile = v4.GetBoolean();
        if (r.TryGetProperty(nameof(AllowVoice), out var v5) && (v5.ValueKind == System.Text.Json.JsonValueKind.True || v5.ValueKind == System.Text.Json.JsonValueKind.False))
            cfg.AllowVoice = v5.GetBoolean();
        if (r.TryGetProperty(nameof(AllowRegister), out var v6) && (v6.ValueKind == System.Text.Json.JsonValueKind.True || v6.ValueKind == System.Text.Json.JsonValueKind.False))
            cfg.AllowRegister = v6.GetBoolean();
        return cfg;
    }

    public string ToJson() =>
        System.Text.Json.JsonSerializer.Serialize(this);
}

/// <summary>
/// 其他配置的強類型視圖，對應 <see cref="SystemSettings.OtherConfig"/> 的 JSON。
/// 當前承載「默認打開欄目」等雜項。
/// </summary>
public sealed class OtherConfigView
{
    /// 默認打開的欄目（底部固定 Tab）Id；null 表示未配置。
    public string? DefaultColumnId { get; set; }

    public static OtherConfigView FromJson(string? json)
    {
        var cfg = new OtherConfigView();
        if (string.IsNullOrWhiteSpace(json))
            return cfg;

        using var doc = System.Text.Json.JsonDocument.Parse(json);
        var r = doc.RootElement;
        if (r.TryGetProperty(nameof(DefaultColumnId), out var v) && v.ValueKind == System.Text.Json.JsonValueKind.String)
            cfg.DefaultColumnId = v.GetString();
        return cfg;
    }

    public string ToJson() =>
        System.Text.Json.JsonSerializer.Serialize(this);
}


