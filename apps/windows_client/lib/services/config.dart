import 'package:flutter/foundation.dart';

/// Build-time / runtime config for the Windows client.
/// Pass secrets only via dart-define for public values (anon key, API URL).
/// Never embed XAI / MS Store Azure AD secret keys in the client.
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3001',
  );

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get supabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static const _allowDevStubAuth = bool.fromEnvironment('ALLOW_DEV_STUB_AUTH');

  /// Dev-only fallback: `stub:<userId>:<tier>` token the local API accepts when
  /// it runs with ALLOW_DEV_STUB_AUTH=true. Impossible in release builds.
  static bool get devStubAuthEnabled => !kReleaseMode && _allowDevStubAuth;

  static const stubAuthToken = String.fromEnvironment(
    'STUB_AUTH_TOKEN',
    defaultValue: 'stub:user_demo:free',
  );
}
