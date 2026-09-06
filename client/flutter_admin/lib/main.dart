import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'l10n/app_strings.dart';
import 'providers/auth_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_skin_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..loadFromStorage()),
        ChangeNotifierProvider(create: (_) => ThemeSkinProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, loc, _) => Consumer<ThemeSkinProvider>(
          builder: (context, skin, _) => MaterialApp(
            title: 'Chat Admin Console',
            locale: loc.flutterLocale,
            supportedLocales: AppLocale.supported,
            theme: AppTheme.active,
            home: const RootDecider(),
            debugShowCheckedModeBanner: false,
          ),
        ),
      ),
    );
  }
}

class RootDecider extends StatelessWidget {
  const RootDecider({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.busy) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return auth.isAuthenticated ? const HomeScreen() : const LoginScreen();
  }
}
