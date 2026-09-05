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
    /// {"ShowOnlineStatus":true,"EnableVoiceCall":true,"EnableVideoCall":true,"AllowFile":true,"AllowVoice":true}
    /// 採用分類存儲，避免每新增一項配置就加一個字段。
    public string ChatConfig { get; set; } = "{}";

    /// 其他配置，存為 JSON，例如：{"DefaultColumnId":"xxx"}。
    /// 默認打開的欄目（底部固定 Tab）的 Id。
    /// 未配置（缺省/缺失）時客戶端回落到按 sort 排在最前的固定欄目；
    /// 默認欄目必須是已固定的欄目。
    public string? OtherConfig { get; set; }

    /// WebRTC 實時通信配置，存為 JSON：
    /// {"IceServers":[{"Urls":["stun:stun.l.google.com:19302"],"Username":null,"Credential":null,"CredentialType":null}]}
    /// null 表示未配置，客戶端回落到默認（空列表 = 區域網 host 直連）。
    public string? RtConfig { get; set; }

    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    /// 聊天功能開關的強類型視圖（從 [ChatConfig] 解析，缺失項回退默認值）。
    public ChatFeatureConfig Chat => ChatFeatureConfig.FromJson(ChatConfig);

    /// 其他配置的強類型視圖（從 [OtherConfig] 解析）。
    public OtherConfigView Other => OtherConfigView.FromJson(OtherConfig);

    /// 實時通信（WebRTC）配置的強類型視圖（從 [RtConfig] 解析）。
    public RtConfigView Rt => RtConfigView.FromJson(RtConfig);
}

/// <summary>
/// 聊天功能開關的強類型視圖，對應 <see cref="SystemSettings.ChatConfig"/> 的 JSON。
/// 缺失字段時回退默認值（全開），避免歷史數據缺項導致功能被誤關。
/// </summary>
public sealed class ChatFeatureConfig
{
    public bool ShowOnlineStatus { get; set; } = true;
    public bool EnableVoiceCall { get; set; } = true;
    public bool EnableVideoCall { get; set; } = true;
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
        if (r.TryGetProperty(nameof(EnableVoiceCall), out var v2) && (v2.ValueKind == System.Text.Json.JsonValueKind.True || v2.ValueKind == System.Text.Json.JsonValueKind.False))
            cfg.EnableVoiceCall = v2.GetBoolean();
        if (r.TryGetProperty(nameof(EnableVideoCall), out var v3) && (v3.ValueKind == System.Text.Json.JsonValueKind.True || v3.ValueKind == System.Text.Json.JsonValueKind.False))
            cfg.EnableVideoCall = v3.GetBoolean();
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

/// <summary>
/// WebRTC 實時通信配置視圖，對應 <see cref="SystemSettings.RtConfig"/> 的 JSON。
/// 承載 STUN/TURN 服務器列表；缺失項回退默認（兩個 Google 公共 STUN）。
/// </summary>
public sealed class RtConfigView
{
    /// ICE 服務器列表（STUN/TURN）。
    public List<IceServer> IceServers { get; set; } = new();

    /// 默認配置：空 ICE 服務器列表。
    ///
    /// 不依賴外網 STUN，讓客戶端僅靠 host candidate（本地網卡 IP）完成區域網內直連，
    /// 解決純內網/無外網環境下的通話失敗；需要跨網段/跨 NAT 時由管理後台下發 STUN/TURN。
    public static RtConfigView Default() => new()
    {
        IceServers = new List<IceServer>(),
    };

    public static RtConfigView FromJson(string? json)
    {
        if (string.IsNullOrWhiteSpace(json))
            return Default();

        try
        {
            using var doc = System.Text.Json.JsonDocument.Parse(json);
            var r = doc.RootElement;
            if (r.TryGetProperty(nameof(IceServers), out var arr) && arr.ValueKind == System.Text.Json.JsonValueKind.Array)
            {
                var cfg = new RtConfigView();
                foreach (var item in arr.EnumerateArray())
                {
                    var srv = new IceServer();
                    if (item.TryGetProperty(nameof(IceServer.Urls), out var urls))
                    {
                        if (urls.ValueKind == System.Text.Json.JsonValueKind.Array)
                        {
                            foreach (var u in urls.EnumerateArray())
                                if (u.ValueKind == System.Text.Json.JsonValueKind.String)
                                    srv.Urls.Add(u.GetString()!);
                        }
                        else if (urls.ValueKind == System.Text.Json.JsonValueKind.String)
                        {
                            srv.Urls.Add(urls.GetString()!);
                        }
                    }
                    if (item.TryGetProperty(nameof(IceServer.Username), out var un) && un.ValueKind == System.Text.Json.JsonValueKind.String)
                        srv.Username = un.GetString();
                    if (item.TryGetProperty(nameof(IceServer.Credential), out var cr) && cr.ValueKind == System.Text.Json.JsonValueKind.String)
                        srv.Credential = cr.GetString();
                    if (item.TryGetProperty(nameof(IceServer.CredentialType), out var ct) && ct.ValueKind == System.Text.Json.JsonValueKind.String)
                        srv.CredentialType = ct.GetString();
                    cfg.IceServers.Add(srv);
                }
                // 解析成功但為空列表時，回落默認，避免客戶端無可用服務器。
                return cfg.IceServers.Count == 0 ? Default() : cfg;
            }
        }
        catch
        {
            // 解析失敗回落默認，避免單條壞配置讓整個通話不可用。
        }
        return Default();
    }

    public string ToJson() =>
        System.Text.Json.JsonSerializer.Serialize(this);
}

/// <summary>
/// 單個 ICE 服務器（STUN/TURN）。
/// </summary>
public sealed class IceServer
{
    /// 服務器地址，支持多值（如多 host）；TURN 亦可包含 ?transport=udp 等查詢。
    public List<string> Urls { get; set; } = new();

    /// TURN 用戶名；STUN 可為 null。
    public string? Username { get; set; }

    /// TURN 憑證（密碼或 oauth token）；STUN 可為 null。
    public string? Credential { get; set; }

    /// 憑證類型："password" 或 "oauth"；為 null 時按 password 處理。
    public string? CredentialType { get; set; }
}
