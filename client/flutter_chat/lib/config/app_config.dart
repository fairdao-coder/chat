import 'package:shared_preferences/shared_preferences.dart';

/// Central runtime configuration. The API base MUST match the running
/// ASP.NET Core server (see server/ChatServer/Program.cs).
///
/// Defaults (dev):
///   - Flutter Web (chrome) : http://localhost:5298   (same machine, CORS-enabled)
///   - Windows desktop      : http://localhost:5298
///   - Android emulator     : http://10.0.2.2:5298    (10.0.2.2 == host loopback)
///   - iOS simulator        : http://localhost:5298
///   - Physical device      : your dev machine LAN IP, e.g. http://192.168.1.50:5298
///
/// The value can be overridden at runtime (login page / Settings) and
/// persists via SharedPreferences.
///
/// Configuration links: opening a link carrying `name` / `api` query params
/// (e.g. fairchat://config?name=MyChat&api=https://api.example.com) lets the
/// user apply both settings at once — see [parseLink] / [applyLink].
class AppConfig {
  /// Compile-time default, overridable at build time:
  ///   flutter build web --dart-define=API_BASE=https://api.example.com
  ///
  /// This is what CI uses to point the published site at a real server;
  /// without it a deployed build would still talk to http://localhost:5298.
  static const String defaultApiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://localhost:5298',
  );
  static const String _prefKey = 'api_base';
  static const String _brandKey = 'brand_name';
  static const String _logoKey = 'brand_logo';
  static const String _apiFromLinkKey = 'api_from_link';

  /// Resolved API base (no trailing slash).
  static String apiBase = defaultApiBase;

  /// api 地址是否由配置鏈接設置。為 true 時登錄頁隱藏服務器地址輸入框
  /// （受控分發場景，避免誤改）；在設置頁手動修改會重置為 false。
  static bool apiFromLink = false;

  /// App display name shown inside the app (login page etc.).
  ///
  /// NOTE: this is the *runtime* brand name. The launcher icon label
  /// (Android `android:label`, iOS `CFBundleDisplayName`) is compile-time
  /// and cannot be changed from a link; native side stays "My Chat".
  static String brandName = 'FairChat';

  /// In-app logo image URL (login page brand mark). Empty = use built-in.
  ///
  /// Image loading needs the host to allow cross-origin reads when the app
  /// runs as Flutter Web with CanvasKit; on mobile any https URL works.
  /// The BrandMark widget falls back to the built-in mark on load failure.
  static String logoUrl = '';

  /// Absolute SignalR hub URL.
  static String get hubUrl =>
      '${apiBase.replaceAll(RegExp(r'/\$'), '')}/hubs/chat';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null && saved.isNotEmpty) {
      apiBase = saved.trim();
    }
    final brand = prefs.getString(_brandKey);
    if (brand != null && brand.isNotEmpty) {
      brandName = brand.trim();
    }
    final logo = prefs.getString(_logoKey);
    if (logo != null) {
      logoUrl = logo;
    }
    apiFromLink = prefs.getBool(_apiFromLinkKey) ?? false;
  }

  /// 手動修改地址（設置頁）。視為放棄鏈接托管，登錄頁地址框恢復顯示。
  static Future<void> set(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    apiFromLink = false;
    await prefs.setBool(_apiFromLinkKey, false);
    if (value == null || value.trim().isEmpty) {
      apiBase = defaultApiBase;
      await prefs.remove(_prefKey);
    } else {
      apiBase = value.trim();
      await prefs.setString(_prefKey, apiBase);
    }
  }

  /// 解析配置链接。链接 query 参数：
  ///   `name` 品牌名、`api` 服務器地址、`logo` 應用內 Logo 圖片 URL。
  /// 只提取「與當前配置不同」的項。
  ///
  /// `logo` 支持三態：
  ///   非空 URL -> 設置為該圖片（僅接受 http/https）；
  ///   空值     -> 恢復內置默認 Logo；
  ///   缺省     -> 不變。
  ///
  /// 返回 null 表示链接里没有需要应用的变更。
  static ({String? name, String? api, String? logo})? parseLink(Uri uri) {
    final p = uri.queryParameters;
    final name = p['name']?.trim();
    final api = p['api']?.trim();
    final hasName = name != null && name.isNotEmpty && name != brandName;
    final hasApi = api != null && api.isNotEmpty && api != apiBase;

    String? logo;
    final logoRaw = p['logo'];
    if (logoRaw != null) {
      final t = logoRaw.trim();
      if (t.isEmpty) {
        // 空值 = 顯式重置；已是默認狀態則無需變更。
        if (logoUrl.isNotEmpty) logo = '';
      } else if ((t.startsWith('http://') || t.startsWith('https://')) &&
          t != logoUrl) {
        logo = t; // 非法 scheme 的值直接忽略（不應用也不報錯）。
      }
    }

    if (!hasName && !hasApi && logo == null) return null;
    return (
      name: hasName ? name : null,
      api: hasApi ? api : null,
      logo: logo,
    );
  }

  /// 应用 [parseLink] 的解析结果并持久化。
  /// 返回 api 地址是否变化（变化时调用方需要 invalidate 依赖旧地址的 provider）。
  static Future<bool> applyLink(
      ({String? name, String? api, String? logo}) cfg) async {
    final prefs = await SharedPreferences.getInstance();
    var apiChanged = false;
    if (cfg.name != null && cfg.name!.isNotEmpty) {
      brandName = cfg.name!;
      await prefs.setString(_brandKey, brandName);
    }
    if (cfg.api != null && cfg.api!.isNotEmpty) {
      apiBase = cfg.api!;
      apiFromLink = true; // 鏈接托管的地址：登錄頁隱藏地址框。
      await prefs.setString(_prefKey, apiBase);
      await prefs.setBool(_apiFromLinkKey, true);
      apiChanged = true;
    }
    if (cfg.logo != null) {
      if (cfg.logo!.isEmpty) {
        logoUrl = '';
        await prefs.remove(_logoKey);
      } else {
        logoUrl = cfg.logo!;
        await prefs.setString(_logoKey, logoUrl);
      }
    }
    return apiChanged;
  }
}
