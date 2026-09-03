using System.Data;
using System.Data.Common;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace AdminServer.Data;

/// <summary>
/// 資料庫結構遷移輔助。
/// 本專案採用 EnsureCreated（Code First 僅建表、不會變更已存在表的 schema），
/// 因此舊庫會停留在舊欄位結構，需要手動遷移以相容新實體。所有步驟皆冪等可重複執行。
/// </summary>
public static class DatabaseMigrator
{
    /// 舊結構的布林功能開關欄位（遷移到 ChatConfig JSON）。
    private static readonly string[] LegacyBoolColumns =
    {
        "ShowOnlineStatus", "EnableVoiceCall", "EnableVideoCall", "AllowFile", "AllowVoice"
    };

    /// 舊結構的默認欄目欄位（遷移到 OtherConfig JSON）。
    /// 注意：此欄位為後來新增，部分舊庫可能從未建立過，需動態探測再讀取。
    private const string LegacyDefaultColumnId = "DefaultColumnId";

    /// <summary>
    /// 將 SystemSettings 舊欄位（布林功能開關 + DefaultColumnId）遷移到分類 JSON 存儲：
    /// ChatConfig（聊天功能開關 JSON）與 OtherConfig（其他雜項 JSON）。
    /// 只處理實際存在的舊欄位，缺失者按默認值（開關全開、默認欄目未配置）處理。
    /// </summary>
    public static async Task MigrateSystemSettingsAsync(AdminDbContext db, ILogger logger)
    {
        var conn = db.Database.GetDbConnection();
        if (conn.State != ConnectionState.Open)
            await conn.OpenAsync();

        // 1) 探測該表現有的欄位（表由 EnsureCreated 建立，理論上必存在）。
        var existing = await QueryColumnNamesAsync(conn);
        if (existing.Count == 0)
        {
            logger.LogInformation("SystemSettings 表尚不存在或無欄位，跳過遷移。");
            return;
        }

        // 2) 確保新欄位存在（新庫 EnsureCreated 已建好則自動跳過）。
        await ExecuteAsync(conn, """
            ALTER TABLE "SystemSettings" ADD COLUMN IF NOT EXISTS "ChatConfig" text NOT NULL DEFAULT '{}';
            ALTER TABLE "SystemSettings" ADD COLUMN IF NOT EXISTS "OtherConfig" text;
            """);

        // 3) 篩出仍殘留的舊欄位。
        var legacy = LegacyBoolColumns.Concat(new[] { LegacyDefaultColumnId })
            .Where(c => existing.Contains(c))
            .ToList();

        if (legacy.Count == 0)
        {
            logger.LogInformation("SystemSettings 已是新結構，跳過欄位遷移。");
            return;
        }

        logger.LogInformation(
            "偵測到 SystemSettings 舊結構欄位（{Columns}），開始遷移到分類 JSON 存儲...",
            string.Join(",", legacy));

        // 4) 讀取單例列（理論上僅一行）的舊值；僅 SELECT 實際存在的舊欄位。
        string chatConfig = "{}";
        string? otherConfig = null;

        var selectCols = string.Join(",", legacy.Select(c => $"\"{c}\""));
        await using (var cmd = conn.CreateCommand())
        {
            cmd.CommandText = $"SELECT {selectCols} FROM \"SystemSettings\" LIMIT 1";
            await using var reader = await cmd.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                var values = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                for (var i = 0; i < legacy.Count; i++)
                    values[legacy[i]] = reader.IsDBNull(i) ? null : reader.GetValue(i);

                // 缺失的舊欄位回退默認值 true（與實體默認值一致）。
                bool BoolOf(string col) =>
                    values.TryGetValue(col, out var v) && v is bool b ? b : true;

                var chat = new Dictionary<string, object>
                {
                    ["ShowOnlineStatus"] = BoolOf("ShowOnlineStatus"),
                    ["EnableVoiceCall"] = BoolOf("EnableVoiceCall"),
                    ["EnableVideoCall"] = BoolOf("EnableVideoCall"),
                    ["AllowFile"] = BoolOf("AllowFile"),
                    ["AllowVoice"] = BoolOf("AllowVoice"),
                };
                chatConfig = System.Text.Json.JsonSerializer.Serialize(chat);

                if (values.TryGetValue(LegacyDefaultColumnId, out var id) && id is string s && s.Length > 0)
                {
                    var other = new Dictionary<string, object> { ["DefaultColumnId"] = s };
                    otherConfig = System.Text.Json.JsonSerializer.Serialize(other);
                }
            }
        }

        // 5) 寫回新欄位（僅當新欄位仍為預設空值時，避免覆蓋已遷移資料）。
        await using (var cmd = conn.CreateCommand())
        {
            cmd.CommandText = """
                UPDATE "SystemSettings"
                SET "ChatConfig" = @chat, "OtherConfig" = @other
                WHERE "ChatConfig" = '{}' OR "ChatConfig" IS NULL
                """;
            AddParam(cmd, "@chat", chatConfig);
            AddParam(cmd, "@other", (object?)otherConfig ?? DBNull.Value);
            await cmd.ExecuteNonQueryAsync();
        }

        // 6) 逐條刪除實際存在的舊欄位。
        foreach (var col in legacy)
        {
            await ExecuteAsync(conn, $"ALTER TABLE \"SystemSettings\" DROP COLUMN IF EXISTS \"{col}\";");
        }

        logger.LogInformation("SystemSettings 欄位遷移完成。");
    }

    /// <summary>
    /// 為 Messages 補上撤回與引用欄位。冪等，新庫自動跳過。
    /// 新表（MessageHides / ConversationStates）由 EnsureCreated 自動建立，無需處理。
    /// </summary>
    public static async Task MigrateMessagesAsync(AdminDbContext db, ILogger logger)
    {
        var conn = db.Database.GetDbConnection();
        if (conn.State != ConnectionState.Open)
            await conn.OpenAsync();

        await ExecuteAsync(conn, """
            ALTER TABLE "Messages" ADD COLUMN IF NOT EXISTS "Recalled" boolean NOT NULL DEFAULT false;
            ALTER TABLE "Messages" ADD COLUMN IF NOT EXISTS "RecalledAt" timestamp with time zone;
            ALTER TABLE "Messages" ADD COLUMN IF NOT EXISTS "ReplyToId" uuid;
            """);

        logger.LogInformation("Messages 撤回/引用欄位已就緒。");
    }

    /// <summary>
    /// 為 DiscoverColumns 補上多語言標題欄位 TitleI18n。冪等，新庫自動跳過。
    /// Title 保持為「默認/回退標題」，舊數據無需改動即可正常工作。
    /// </summary>
    public static async Task MigrateDiscoverColumnsAsync(AdminDbContext db, ILogger logger)
    {
        var conn = db.Database.GetDbConnection();
        if (conn.State != ConnectionState.Open)
            await conn.OpenAsync();

        await ExecuteAsync(conn,
            """ALTER TABLE "DiscoverColumns" ADD COLUMN IF NOT EXISTS "TitleI18n" text;""");

        logger.LogInformation("DiscoverColumns 多語言標題欄位已就緒。");
    }

    /// 讀取 SystemSettings 表的現有欄位名（大小寫不敏感集合）。
    private static async Task<HashSet<string>> QueryColumnNamesAsync(DbConnection conn)
    {
        var set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        await using var cmd = conn.CreateCommand();
        cmd.CommandText =
            "SELECT column_name FROM information_schema.columns WHERE table_name ILIKE 'systemsettings'";
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            set.Add(reader.GetString(0));
        return set;
    }

    private static async Task ExecuteAsync(DbConnection conn, string sql)
    {
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = sql;
        await cmd.ExecuteNonQueryAsync();
    }

    private static void AddParam(DbCommand cmd, string name, object value)
    {
        var p = cmd.CreateParameter();
        p.ParameterName = name;
        p.Value = value;
        cmd.Parameters.Add(p);
    }
}
