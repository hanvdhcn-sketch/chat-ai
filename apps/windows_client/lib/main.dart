import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'screens/chat_screen.dart';
import 'screens/sign_in_screen.dart';
import 'services/auth_service.dart';
import 'services/locale_preference.dart';
import 'services/startup_clock.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  StartupClock.start();
  WidgetsFlutterBinding.ensureInitialized();
  StartupClock.mark('binding');

  final auth = AuthService();
  final localePreference = LocalePreference();
  // Dev stub signs in synchronously; real auth resolves after the first frame.
  auth.hydrateLocalSync();
  StartupClock.mark('hydrate');

  runApp(ChatAiApp(auth: auth, localePreference: localePreference));
  StartupClock.mark('runApp');

  // Prefs + /v1/me after the first frame so the shell is already up.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    StartupClock.mark('firstFrame');
    unawaited(localePreference.load());
    unawaited(auth.bootstrap());
  });
}

class ChatAiApp extends StatelessWidget {
  const ChatAiApp({
    super.key,
    required this.auth,
    required this.localePreference,
  });

  final AuthService auth;
  final LocalePreference localePreference;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: localePreference),
      ],
      child: Consumer<LocalePreference>(
        builder: (context, localePref, _) {
          return MaterialApp(
            title: AppTheme.brandName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            locale: localePref.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.select<AuthService, AuthStatus>((a) => a.status);
    switch (status) {
      case AuthStatus.signedIn:
        return const ChatScreen();
      case AuthStatus.signedOut:
        return const SignInScreen();
      case AuthStatus.unknown:
        return const Scaffold(
          backgroundColor: AppTheme.surface,
          body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
    }
  }
}
