import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_colors.dart';
import 'config/app_config.dart';
import 'l10n/app_localizations.dart';
import 'providers/auth_provider.dart';
import 'providers/call_provider.dart';
import 'providers/conversations_provider.dart';
import 'providers/config_link_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_mode_provider.dart';
import 'providers/notification_provider.dart';
import 'bridges/chat_bridge.dart';
import 'widgets/message_banner_overlay.dart';
import 'router.dart';
import 'theme.dart';

/// Global key so the uncaught-error handler below can surface messages as a
/// snack bar even from outside a build context.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// 全局消息橫幅的 Overlay key：固定 key 避免 MaterialApp.builder 因導航/主題變化
/// 重建時丟失橫幅狀態；同時為橫幅內的 Tooltip 提供 Overlay 祖先。
final _bannerOverlayKey = GlobalKey<OverlayState>();

void _reportError(Object error, [StackTrace? stackTrace]) {
  final msg = error.toString();
  // 先把堆疊列印到控制台 / logcat，方便開發者定位真正的拋出位置；
  // SnackBar 只顯示簡短訊息，調試時請查看完整日誌。
  developer.log('Uncaught error: $msg', name: 'main', error: error, stackTrace: stackTrace);
  // [DEBUG] 把完整堆疊上報到本機日誌服務，便於無頭/web-server 模式下抓取報錯。
  // 上報失敗（例如服務未啟動）直接忽略，不影響主流程。
  try {
    Dio().post(
      'http://localhost:5300/log',
      data: {'error': msg, 'stack': stackTrace?.toString() ?? ''},
      options: Options(contentType: Headers.jsonContentType),
    );
  } catch (_) {}
  // ScaffoldMessenger.showSnackBar cannot be called during build; schedule it
  // for the next frame so the message is safe to display.
  SchedulerBinding.instance.addPostFrameCallback((_) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('發生錯誤: $msg'),
        duration: const Duration(seconds: 4),
        // 用 fixed 行為，避免 floating 在底部欄過高時觸發
        // "Floating SnackBar presented off screen" 而再次崩潰。
        behavior: SnackBarBehavior.fixed,
      ),
    );
  });
}

void main() async {
  // ensureInitialized() 必須與 runApp 處於同一 zone，否則會觸發 Zone mismatch
  // （Flutter bindings 在根 zone 初始化，runApp 卻在 runZonedGuarded 的子 zone）。
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await AppConfig.load();

      // Surface uncaught errors (e.g. from platform callbacks / async gaps) instead
      // of letting them become a silent "Uncaught Error" in the console.
      FlutterError.onError = (details) => _reportError(
            details.exception,
            details.stack,
          );
      // ignore: deprecated_member_use
      WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
        _reportError(error, stack);
        return true;
      };

      runApp(const ProviderScope(child: MyApp()));
    },
    (error, stack) => _reportError(error, stack),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // 小應用 JS Bridge 的 toast 走全局 snack bar。
    setBridgeToastHandler((m) => scaffoldMessengerKey.currentState
        ?.showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 2))));
    // Web 端：安裝 postMessage 橋監聽（僅 Web 生效，移動端走 WebView channel）。
    installWebBridge(ref);
    // Restore persisted session and (re)connect the SignalR hub.
    ref.read(authProvider.notifier).init();
    // 配置深鏈監聽（App 級別）：任何頁面收到配置鏈接都會彈確認框。
    ref.read(configLinkProvider);
    // 監聽好友請求推送：收到新邀請即時刷新好友請求列表與紅點（無需重啟 App）。
    ref.read(friendRequestPushProvider);
    // 訂閱全局消息推送：非當前會話收到消息時在屏幕頂部閃現橫幅（息屏再響鈴）。
    ref.read(messageNotificationControllerProvider);
    // 保持通話服務常駐，以便接收來電並導航到通話頁。
    ref.listen(callProvider, (_, __) {});
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    // 让系统状态栏图标颜色跟随主题：亮主题用深色图标（可见），暗主题用浅色图标。
    // 注意：此处不能依赖 MaterialApp 子树内的 MediaQuery（build 时尚未就绪，
    // 易导致 system 模式下误判亮度，使亮色背景下用了浅色图标而看不见时间/电量）。
    // 改用 platformDispatcher 直接读取系统真实亮度，最可靠。
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isDarkMode = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && platformBrightness == Brightness.dark);
    SystemChrome.setSystemUIOverlayStyle(
      isDarkMode
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
          // 亮色模式：深色图标 + 透明状态栏背景，让页面内容延伸至顶部，保证时间/电量清晰可见。
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: AppColors.lightSurface,
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
    );

    return MaterialApp.router(
      title: 'Flutter Chat',
      locale: locale,
      localizationsDelegates: const [
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L10n.supportedLocales,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      // 全局消息橫幅需 Overlay 上下文（內部 Tooltip 依賴 Overlay），但 MaterialApp.builder
      // 的 context 位於 Navigator/Overlay 之外；用顯式 Overlay + 固定 key 包裹，
      // 既讓 Tooltip 取得祖先 Overlay，又避免導航時橫幅狀態丟失。
      builder: (context, child) => Stack(
        children: [
          if (child != null) child,
          Overlay(
            key: _bannerOverlayKey,
            initialEntries: [
              OverlayEntry(builder: (_) => const MessageBannerOverlay()),
            ],
          ),
        ],
      ),
    );
  }
}
