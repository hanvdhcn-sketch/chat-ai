import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'screens/chat_screen.dart';
import 'services/auth_service.dart';
import 'services/startup_clock.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  StartupClock.start();
  WidgetsFlutterBinding.ensureInitialized();
  StartupClock.mark('binding');

  final auth = AuthService();
  // Optimistic local token — never block first paint on prefs or /v1/me.
  auth.hydrateLocalSync();
  StartupClock.mark('hydrate');

  runApp(ChatAiApp(auth: auth));
  StartupClock.mark('runApp');

  // Prefs + /v1/me after the first frame so the shell is already up.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    StartupClock.mark('firstFrame');
    unawaited(auth.bootstrap());
  });
}

class ChatAiApp extends StatelessWidget {
  const ChatAiApp({super.key, required this.auth});

  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: auth,
      child: MaterialApp(
        title: AppTheme.brandName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Paint chat shell immediately — do not gate on network auth.
        home: const ChatScreen(),
      ),
    );
  }
}
