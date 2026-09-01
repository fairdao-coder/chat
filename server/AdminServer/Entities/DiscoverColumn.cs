namespace AdminServer.Entities;

/// <summary>
/// 發現頁欄目。表結構由 AdminServer 負責建表，
/// 字段需與 ChatServer.Entities.DiscoverColumn 保持一致。
/// Kind 決定點擊後的行為，Content 為單一參數。
/// </summary>
public class DiscoverColumn
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Title { get; set; } = default!;
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
