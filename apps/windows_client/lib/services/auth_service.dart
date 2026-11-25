import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'config.dart';
import 'startup_clock.dart';

/// Auth hooks for Supabase (magic link + Google).
///
/// Token storage uses SharedPreferences for local Windows builds (no ATL).
/// Prefer flutter_secure_storage once VS ATL (`atlstr.h`) is installed.
class AuthService extends ChangeNotifier {
  AuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _tokenKey = 'chatai_access_token';

  /// Keep /v1/me off the critical path — unreachable API must not stall UI.
  static const _meTimeout = Duration(seconds: 3);

  ChatUser? user;
  String? accessToken;
  bool loading = false;
  String? error;
  bool _bootstrapping = false;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// Sync hydrate for first paint: use compile-time stub until prefs load.
  void hydrateLocalSync() {
    accessToken ??= AppConfig.stubAuthToken;
    loading = false;
  }

  Future<void> bootstrap() async {
    if (_bootstrapping) return;
    _bootstrapping = true;
    StartupClock.mark('authBootstrapStart');
    try {
      final prefs = await _prefs.timeout(const Duration(seconds: 2));
      final stored = prefs.getString(_tokenKey);
      accessToken = (stored != null && stored.isNotEmpty)
          ? stored
          : AppConfig.stubAuthToken;
      // Persist stub so later launches skip inventing a token.
      await prefs.setString(_tokenKey, accessToken!);
      StartupClock.mark('authPrefs');
      await refreshMe();
      StartupClock.mark('authMe');
    } on TimeoutException {
      error = 'auth_timeout';
      accessToken ??= AppConfig.stubAuthToken;
    } catch (e) {
      error = e.toString();
      accessToken ??= AppConfig.stubAuthToken;
    } finally {
      loading = false;
      _bootstrapping = false;
      notifyListeners();
      StartupClock.mark('authBootstrapDone');
    }
  }

  Future<void> refreshMe() async {
    final token = accessToken;
    if (token == null) {
      user = null;
      notifyListeners();
      return;
    }
    try {
      final res = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/v1/me'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_meTimeout);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        user = ChatUser.fromJson(body['user'] as Map<String, dynamic>);
        error = null;
      } else {
        error = 'auth_failed_${res.statusCode}';
        // Keep token so chat can still attempt API calls; shell stays up.
      }
    } on TimeoutException {
      error = 'auth_timeout';
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  /// Placeholder: open system browser for Supabase magic link / Google OAuth.
  Future<void> signInWithSupabasePlaceholder() async {
    // Wire supabase_flutter or custom OAuth PKCE + deep link `chatai://auth/callback`.
    // Until then, keep stub token for local API smoke tests.
    accessToken = AppConfig.stubAuthToken;
    await (await _prefs).setString(_tokenKey, accessToken!);
    await refreshMe();
  }

  Future<void> switchStubTier(String tier) async {
    accessToken = 'stub:user_demo:$tier';
    await (await _prefs).setString(_tokenKey, accessToken!);
    await refreshMe();
  }

  Future<void> signOut() async {
    await (await _prefs).remove(_tokenKey);
    accessToken = null;
    user = null;
    notifyListeners();
  }
}
