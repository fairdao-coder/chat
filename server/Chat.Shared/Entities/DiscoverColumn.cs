namespace Chat.Shared.Entities;

/// <summary>
/// 發現頁欄目。可由管理後臺維護，App 啟動時拉取並展示。
/// Kind 決定點擊後的行為，Content 為該行為所需的單一參數：
///   link  - 在 WebView 中打開 Content（外部連結）
///   route - 在 App 內跳轉到 Content（內部路由）
///   action- 執行內置動作，Content 為動作名（scan / addFriend / createGroup / friendRequests）
///   tab   - 客戶端底部固定 Tab，Content 為 tab 標識（chat / contacts / discover / me）
///   mini  - 打開小應用 / H5 本地包，Content 為包名（對應 /mini?name=xxx）
/// </summary>
public class DiscoverColumn
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>
    /// 欄目名稱（默認/回退標題）。管理後臺填寫，客戶端在找不到對應語言譯文時使用它。
    /// </summary>
    public string Title { get; set; } = default!;

    /// <summary>
    /// 欄目名稱的多語言譯文，存為 JSON：{"zh-TW":"遊戲中心","en":"Games"}。
    /// null 或未包含當前語言時，客戶端回退到 [Title]。
    /// 鍵為 BCP47 風格：zh-TW（繁中）/ zh-CN（簡中）/ en / es。
    /// </summary>
    public string? TitleI18n { get; set; }

    public string? Icon { get; set; }
    public string Kind { get; set; } = "link";
    public string? Content { get; set; }
    public int Sort { get; set; } = 0;
    public bool Enabled { get; set; } = true;
    /// <summary>
    /// 是否固定到客戶端底部導航。固定欄目將作為底部 Tab 顯示（如：信息、通訊錄、發現、我）。
    /// </summary>
    public bool Pinned { get; set; } = false;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
