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
    /// 小應用欄目（Kind = "mini"，Content 為 `script:` 前綴的內聯 HTML）。
    ///
    /// 默認**不啟用**（Enabled = false）：僅入庫待用，管理員在後台確認內容後
    /// 再逐個啟用，避免佔位內容暴露給終端用戶。
    /// 排序接續發現頁默認欄目（0-3）之後。
    /// </summary>
    private static readonly SeedColumn[] MiniApps =
    {
        new("遊戲", "🎮", "mini", Placeholder("遊戲", "🎮"), 4, Pinned: false, Enabled: false,
            I18n("遊戲", "游戏", "Games", "Juegos")),
        new("直播", "📺", "mini", Placeholder("直播", "📺"), 5, Pinned: false, Enabled: false,
            I18n("直播", "直播", "Live", "En vivo")),
        new("商城", "🛍️", "mini", Placeholder("商城", "🛍️"), 6, Pinned: false, Enabled: false,
            I18n("商城", "商城", "Mall", "Tienda")),
        new("劇場", "🎭", "mini", Placeholder("劇場", "🎭"), 7, Pinned: false, Enabled: false,
            I18n("劇場", "剧场", "Theater", "Teatro")),
        new("賺錢", "💰", "mini", Placeholder("賺錢", "💰"), 8, Pinned: false, Enabled: false,
            I18n("賺錢", "赚钱", "Earn", "Ganar")),
        new("首頁", "🏠", "mini", Placeholder("首頁", "🏠"), 9, Pinned: false, Enabled: false,
            I18n("首頁", "首页", "Home", "Inicio")),
        new("視頻", "🎬", "mini", Placeholder("視頻", "🎬"), 10, Pinned: false, Enabled: false,
            I18n("視頻", "视频", "Videos", "Videos")),
        new("理財", "📈", "mini", Placeholder("理財", "📈"), 11, Pinned: false, Enabled: false,
            I18n("理財", "理财", "Finance", "Finanzas")),
        new("交易", "💱", "mini", Placeholder("交易", "💱"), 12, Pinned: false, Enabled: false,
            I18n("交易", "交易", "Trade", "Operar")),
        new("資產", "🏦", "mini", Placeholder("資產", "🏦"), 13, Pinned: false, Enabled: false,
            I18n("資產", "资产", "Assets", "Activos")),
        new("行情", "📊", "mini", Placeholder("行情", "📊"), 14, Pinned: false, Enabled: false,
            I18n("行情", "行情", "Market", "Mercado")),
    };

    /// <summary>
    /// 生成小程式佔位內容：`script:` 前綴 + 內聯 HTML（允許執行腳本）。
    ///
    /// 客戶端渲染約束（務必遵守，否則內容會被靜默剔除）：
    /// 1. 內聯 HTML 是**片段**（注入到既有 div），不可寫 &lt;html&gt;/&lt;head&gt;/&lt;body&gt;；
    /// 2. Web 端校驗器**不允許 &lt;style&gt; 元素**，故一律用 `style="..."` 行內樣式；
    /// 3. Web 端僅表單類元素放行 onclick 等事件屬性，故用 script 內 addEventListener 綁定；
    /// 4. 深色模式因此改用腳本監聽 prefers-color-scheme 並設置行內樣式。
    ///
    /// 演示 `window.ChatBridge.call()` 調用宿主能力（Promise）。
    /// </summary>
    private static string Placeholder(string title, string icon) => "script:" + $$"""
<div id="mini-app" style="font-family:system-ui,-apple-system,'Segoe UI',sans-serif;padding:28px 16px;text-align:center;box-sizing:border-box;min-height:100%;background:#f7f8fa;color:#1b1c1e">
  <div style="font-size:52px;line-height:1">{{icon}}</div>
  <div style="margin:14px 0 6px;font-size:20px;font-weight:600">{{title}}</div>
  <div style="font-size:13px;line-height:1.8;color:#8a8f98">
    小程式佔位內容（內聯 HTML，支援 script）。<br />
    在後台修改本欄目的「欄目內容」即可接入真實業務。
  </div>
  <button id="mini-cta" style="margin-top:20px;padding:10px 22px;font-size:14px;border:0;border-radius:999px;cursor:pointer;color:#fff;background:#1aad19">
    呼叫宿主 Toast
  </button>
  <div id="mini-out" style="margin-top:14px;font-size:12px;color:#8a8f98;min-height:18px"></div>
</div>
<script>
(function () {
  var root = document.getElementById('mini-app');
  var out = document.getElementById('mini-out');
  var cta = document.getElementById('mini-cta');

  // 深色模式：不能用 <style> 元素，改由腳本設置行內樣式。
  function applyTheme() {
    var dark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
    root.style.background = dark ? '#17181a' : '#f7f8fa';
    root.style.color = dark ? '#eceef1' : '#1b1c1e';
  }
  applyTheme();
  if (window.matchMedia) {
    var mq = window.matchMedia('(prefers-color-scheme: dark)');
    if (mq.addEventListener) { mq.addEventListener('change', applyTheme); }
  }

  cta.addEventListener('click', function () {
    var bridge = window.ChatBridge;
    if (!bridge || !bridge.call) {
      out.textContent = 'Bridge 不可用（非小程式容器）';
      return;
    }
    out.textContent = '呼叫中...';
    bridge.call('ui.toast', { message: '{{title}} 小程式已就緒' })
      .then(function () { out.textContent = 'Bridge 呼叫成功（ui.toast）'; })
      .catch(function (e) { out.textContent = 'Bridge 呼叫失敗：' + (e && e.message ? e.message : e); });
  });
})();
</script>
""";

    public static async Task SeedAsync(AdminDbContext db, ILogger logger)
    {
        var existing = await db.DiscoverColumns.ToListAsync();
        var byContent = existing
            .Where(c => !string.IsNullOrEmpty(c.Content))
            .GroupBy(c => c.Content!)
            .ToDictionary(g => g.Key, g => g.First());

        var changed = 0;

        foreach (var seed in PinnedTabs.Concat(DefaultColumns).Concat(MiniApps))
        {
            if (byContent.TryGetValue(seed.Content, out var found))
            {
                // 已存在：僅在從未配置譯文時補上內置譯文，不覆蓋管理員的定制。
                if (string.IsNullOrWhiteSpace(found.TitleI18n))
                {
                    found.TitleI18n = ToJson(seed.I18n);
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
