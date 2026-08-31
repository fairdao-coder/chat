namespace ChatServer.Entities;

/// <summary>
/// 發現頁欄目。可由管理後臺維護，App 啟動時拉取並展示；
/// 點擊後在 WebView 中打開 Link。
/// </summary>
public class DiscoverColumn
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Title { get; set; } = default!;
    public string? Icon { get; set; }
    public string? Link { get; set; }
    public int Sort { get; set; } = 0;
    public bool Enabled { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
