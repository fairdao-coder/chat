namespace AdminServer.Entities;

/// <summary>
/// 發現頁欄目。表結構由 ChatServer 負責遷移維護，此處僅聲明鍵與讀寫，
/// 並通過 ExcludeFromMigrations 排除，避免 AdminServer 自行建表覆蓋 ChatServer 的定義。
/// 字段需與 ChatServer.Entities.DiscoverColumn 保持一致。
/// </summary>
public class DiscoverColumn
{
    public Guid Id { get; set; }
    public string Title { get; set; } = default!;
    public string? Icon { get; set; }
    public string? Link { get; set; }
    public int Sort { get; set; }
    public bool Enabled { get; set; }
    public DateTime CreatedAt { get; set; }
}
