using Chat.Shared.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace AdminServer.Data;

/// <summary>
/// 系統自帶欄目（內置底部導航 + 發現頁默認入口）的種子數據。
///
/// 每個欄目都內置四語譯文（繁中 / 簡中 / 英文 / 西語），建庫時一併寫入，
/// 客戶端即可隨界面語言切換，管理員無需逐個配置。
///
/// 冪等：按 Content（功能標識，比 Title 穩定）匹配。
/// - 欄目不存在 → 連同譯文一起插入；
/// - 欄目已存在但從未配置譯文 → 只補譯文，不覆蓋管理員的定制。
/// </summary>
public static class DiscoverColumnSeeder
{
    /// 譯文語言鍵（BCP47 風格），與客戶端 AppLocalizations 支持的四種語言一致。
    private const string ZhTW = "zh-TW";
    private const string ZhCN = "zh-CN";
    private const string En = "en";
    private const string Es = "es";

    private sealed record SeedColumn(
        string Title, string Icon, string Kind, string Content, int Sort,
        bool Pinned, bool Enabled, Dictionary<string, string> I18n);

    private static Dictionary<string, string> I18n(
        string zhTW, string zhCN, string en, string es) => new()
        {
            [ZhTW] = zhTW,
            [ZhCN] = zhCN,
            [En] = en,
            [Es] = es,
        };

    /// <summary>
    /// 內置底部導航欄目（Pinned=true）。
    /// Kind 用 "link"：底部 Tab 由 Pinned 決定，Kind 僅描述打開方式；
    /// Content 為內置標識（chat/contacts/discover/me），客戶端據此對應內置頁。
    /// 排序沿用微信習慣：信息/通訊錄置頂（大負值），發現/我置底（大正值）。
    /// </summary>
    private static readonly SeedColumn[] PinnedTabs =
    {
        new("信息", "💬", "link", "chat", -9999, Pinned: true, Enabled: true,
            I18n("信息", "信息", "Chats", "Mensajes")),
        new("通訊錄", "👤", "link", "contacts", -8888, Pinned: true, Enabled: true,
            I18n("通訊錄", "通讯录", "Contacts", "Contactos")),
        new("發現", "🧭", "link", "discover", 8888, Pinned: true, Enabled: true,
            I18n("發現", "发现", "Discover", "Descubrir")),
        new("我", "🙂", "link", "me", 9999, Pinned: true, Enabled: true,
            I18n("我", "我", "Me", "Yo")),
    };

    /// <summary>
    /// 發現頁默認欄目（內置動作，不固定到底部導航）。
    /// 動作類標題不屬於客戶端內置譯文範疇，故必須在此提供譯文。
    /// </summary>
    private static readonly SeedColumn[] DefaultColumns =
    {
        new("新增好友", "🤝", "action", "addFriend", 0, Pinned: false, Enabled: true,
            I18n("新增好友", "添加好友", "Add Friend", "Agregar amigo")),
        new("好友邀請", "📩", "action", "friendRequests", 1, Pinned: false, Enabled: true,
            I18n("好友邀請", "好友邀请", "Friend Requests", "Solicitudes")),
        new("建立群組", "👥", "action", "createGroup", 2, Pinned: false, Enabled: true,
            I18n("建立群組", "创建群聊", "Create Group", "Crear grupo")),
        new("掃一掃", "📷", "action", "scan", 3, Pinned: false, Enabled: true,
            I18n("掃一掃", "扫一扫", "Scan", "Escanear")),
    };

    /// <summary>
    /// 小應用欄目（Kind = "mini"）。
    ///
    /// Content **默認為空**：客戶端檢測到空內容時展示內置默認模板
    /// （含當前登錄用戶、Token、欄目名與 Bridge 調用示例），
    /// 管理員在後台填入 `script:` / `html:` / `https://` 內容即可切換為真實業務。
    ///
    /// 默認**不啟用**（Enabled = false）：僅入庫待用，避免佔位內容暴露給終端用戶。
    /// 排序接續發現頁默認欄目（0-3）之後。
    /// </summary>
    private static readonly SeedColumn[] MiniApps =
    {
        new("遊戲", "🎮", "mini", "", 4, Pinned: false, Enabled: false,
            I18n("遊戲", "游戏", "Games", "Juegos")),
        new("直播", "📺", "mini", "", 5, Pinned: false, Enabled: false,
            I18n("直播", "直播", "Live", "En vivo")),
        new("商城", "🛍️", "mini", "", 6, Pinned: false, Enabled: false,
            I18n("商城", "商城", "Mall", "Tienda")),
        new("劇場", "🎭", "mini", "", 7, Pinned: false, Enabled: false,
            I18n("劇場", "剧场", "Theater", "Teatro")),
        new("賺錢", "💰", "mini", "", 8, Pinned: false, Enabled: false,
            I18n("賺錢", "赚钱", "Earn", "Ganar")),
        new("首頁", "🏠", "mini", "", 9, Pinned: false, Enabled: false,
            I18n("首頁", "首页", "Home", "Inicio")),
        new("視頻", "🎬", "mini", "", 10, Pinned: false, Enabled: false,
            I18n("視頻", "视频", "Videos", "Videos")),
        new("理財", "📈", "mini", "", 11, Pinned: false, Enabled: false,
            I18n("理財", "理财", "Finance", "Finanzas")),
        new("交易", "💱", "mini", "", 12, Pinned: false, Enabled: false,
            I18n("交易", "交易", "Trade", "Operar")),
        new("資產", "🏦", "mini", "", 13, Pinned: false, Enabled: false,
            I18n("資產", "资产", "Assets", "Activos")),
        new("行情", "📊", "mini", "", 14, Pinned: false, Enabled: false,
            I18n("行情", "行情", "Market", "Mercado")),
    };

    public static async Task SeedAsync(AdminDbContext db, ILogger logger)
    {
        var existing = await db.DiscoverColumns.ToListAsync();
        // 匹配策略：優先按 Content（功能標識最穩定，管理員改標題也能命中）；
        // Content 為空（小程式默認不帶內容）時退回按 Title 匹配。
        var byContent = existing
            .Where(c => !string.IsNullOrEmpty(c.Content))
            .GroupBy(c => c.Content!)
            .ToDictionary(g => g.Key, g => g.First());
        var byTitle = existing
            .GroupBy(c => c.Title)
            .ToDictionary(g => g.Key, g => g.First());

        var changed = 0;

        foreach (var seed in PinnedTabs.Concat(DefaultColumns).Concat(MiniApps))
        {
            // 空 Content 不進 byContent（無法區分多條），按 Title 匹配。
            var found = (seed.Content.Length > 0 &&
                         byContent.TryGetValue(seed.Content, out var byC))
                ? byC
                : byTitle.GetValueOrDefault(seed.Title);

            if (found is not null)
            {
                // 已存在：僅在從未配置譯文時補上內置譯文，不覆蓋管理員的定制。
                if (string.IsNullOrWhiteSpace(found.TitleI18n))
                {
                    found.TitleI18n = ToJson(seed.I18n);
                    changed++;
                }

                // 舊版種子曾為小程式寫入佔位內聯 HTML；改用「空內容 + 客戶端默認模板」
                // 後，若內容仍是我們種下的佔位頁（標記 id="mini-app"），自動清空。
                // 管理員自定義的其他內容一律不動。
                if (seed.Content.Length == 0 &&
                    found.Content is not null &&
                    found.Content.StartsWith("script:", StringComparison.Ordinal) &&
                    found.Content.Contains("id=\"mini-app\"", StringComparison.Ordinal))
                {
                    found.Content = null;
                    changed++;
                }

                continue;
            }

            db.DiscoverColumns.Add(new DiscoverColumn
            {
                Title = seed.Title,
                TitleI18n = ToJson(seed.I18n),
                Icon = seed.Icon,
                Kind = seed.Kind,
                Content = seed.Content,
                Sort = seed.Sort,
                Enabled = seed.Enabled,
                Pinned = seed.Pinned,
                CreatedAt = DateTime.UtcNow,
            });
            changed++;
        }

        if (changed > 0)
        {
            await db.SaveChangesAsync();
            logger.LogInformation("已同步 {Count} 條系統自帶欄目（含四語譯文）。", changed);
        }
    }

    private static string ToJson(Dictionary<string, string> map) =>
        System.Text.Json.JsonSerializer.Serialize(map);
}
