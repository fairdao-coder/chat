import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_config.dart';
import 'l10n/app_localizations.dart';
import 'providers/auth_provider.dart';
import 'providers/call_provider.dart';
import 'providers/conversations_provider.dart';
import 'providers/config_link_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_mode_provider.dart';
import 'pages/call_overlay.dart';
import 'router.dart';
import 'theme.dart';

/// Global key so the uncaught-error handler below can surface messages as a
/// snack bar even from outside a build context.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void _reportError(Object error) {
  final msg = error.toString();
  // Some errors are noisy/no-op (e.g. platform gesture noise); keep it short.
  scaffoldMessengerKey.currentState?.showSnackBar(
    SnackBar(content: Text('發生錯誤: $msg'), duration: const Duration(seconds: 4)),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();

  // Surface uncaught errors (e.g. from platform callbacks / async gaps) instead
  // of letting them become a silent "Uncaught Error" in the console.
  FlutterError.onError = (details) => _reportError(details.exceptionAsString());
  // ignore: deprecated_member_use
  WidgetsBinding.instance.platformDispatcher.onError = (error, _) {
    _reportError(error);
    return true;
  };

  runZonedGuarded(
    () => runApp(const ProviderScope(child: MyApp())),
    (error, _) => _reportError(error),
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
    // Restore persisted session and (re)connect the SignalR hub.
    ref.read(authProvider.notifier).init();
    // 預實例化通話控制器，使其訂閱 SignalR 來電事件（否則來電期間 overlay 不顯示）。
    ref.read(callProvider);
    // 配置深鏈監聽（App 級別）：任何頁面收到配置鏈接都會彈確認框。
    ref.read(configLinkProvider);
    // 監聽好友請求推送：收到新邀請即時刷新好友請求列表與紅點（無需重啟 App）。
    ref.read(friendRequestPushProvider);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
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
      builder: (context, child) => Stack(
        children: [
          if (child != null) child,
          const CallOverlay(),
        ],
      ),
    );
  }
}
