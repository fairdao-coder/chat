namespace Chat.Shared.Security;

/// <summary>限流策略名。兩個服務共用同一套命名，便於統一運維與配置。</summary>
public static class RateLimitPolicies
{
    /// <summary>認證類接口（登錄/註冊/改密），針對撞庫與暴力破解。</summary>
    public const string Auth = "auth";

    /// <summary>文件上傳，防止打滿磁盤與帶寬。</summary>
    public const string Upload = "upload";
}
