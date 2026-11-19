/// Build-time / runtime config for the Windows client.
/// Pass secrets only via dart-define for public values (anon key, API URL).
/// Never embed XAI / Gemini / MS Store Azure AD secret keys in the client.
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

  /// Dev-only stub token until Supabase Auth (magic link / Google) is wired.
  /// Format accepted by API: stub:<userId>:<tier>
  static const stubAuthToken = String.fromEnvironment(
    'STUB_AUTH_TOKEN',
    defaultValue: 'stub:user_demo:free',
  );
}
