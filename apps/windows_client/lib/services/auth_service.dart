import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'config.dart';

/// Auth hooks for Supabase (magic link + Google).
///
/// Token storage uses SharedPreferences for local Windows builds (no ATL).
/// Prefer flutter_secure_storage once VS ATL (`atlstr.h`) is installed.
class AuthService extends ChangeNotifier {
  AuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _tokenKey = 'chatai_access_token';

  ChatUser? user;
  String? accessToken;
  bool loading = true;
  String? error;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<void> bootstrap() async {
    loading = true;
    notifyListeners();
    try {
      final prefs = await _prefs;
      accessToken = prefs.getString(_tokenKey);
      accessToken ??= AppConfig.stubAuthToken;
      await prefs.setString(_tokenKey, accessToken!);
      await refreshMe();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshMe() async {
    final token = accessToken;
    if (token == null) {
      user = null;
      notifyListeners();
      return;
    }
    final res = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/v1/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      user = ChatUser.fromJson(body['user'] as Map<String, dynamic>);
      error = null;
    } else {
      error = 'auth_failed_${res.statusCode}';
      user = null;
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
