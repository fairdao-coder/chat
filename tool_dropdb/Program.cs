// 臨時工具：刪除 chatdb 數據庫（WITH (FORCE) 強制斷開殘留連接），
// 由 AdminServer 啟動時 EnsureCreated 自動重建。
// 用法: dotnet run -- "<postgres maintenance 連接串>"
using Npgsql;

var cs = args.Length > 0
    ? args[0]
    : "User ID=hxb;Password=Db%^13FDb%^13FDb%^13F;Host=192.168.10.200;Database=postgres;Pooling=true;";

await using var conn = new NpgsqlConnection(cs);
await conn.OpenAsync();

var existsDb = "SELECT 1 FROM pg_database WHERE datname = 'chatdb'";
await using (var check = new NpgsqlCommand(existsDb, conn))
{
    var exists = await check.ExecuteScalarAsync();
    if (exists == null)
    {
        Console.WriteLine("DB_NOT_EXISTS");
        return;
    }
}

await using (var drop = new NpgsqlCommand("DROP DATABASE chatdb WITH (FORCE)", conn))
{
    await drop.ExecuteNonQueryAsync();
}
Console.WriteLine("DB_DROPPED");
