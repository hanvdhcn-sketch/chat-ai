import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'config.dart';

/// Auth hooks for Supabase (magic link + Google).
/// MVP scaffold: stores JWT/stub in Windows secure storage; `/v1/me` verifies.
class AuthService extends ChangeNotifier {
  AuthService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _storage;

  static const _tokenKey = 'chatai_access_token';

  ChatUser? user;
  String? accessToken;
  bool loading = true;
  String? error;

  Future<void> bootstrap() async {
    loading = true;
    notifyListeners();
    try {
      accessToken = await _storage.read(key: _tokenKey);
      accessToken ??= AppConfig.stubAuthToken;
      await _storage.write(key: _tokenKey, value: accessToken);
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
    await _storage.write(key: _tokenKey, value: accessToken);
    await refreshMe();
  }

  Future<void> switchStubTier(String tier) async {
    accessToken = 'stub:user_demo:$tier';
    await _storage.write(key: _tokenKey, value: accessToken);
    await refreshMe();
  }

  Future<void> signOut() async {
    await _storage.delete(key: _tokenKey);
    accessToken = null;
    user = null;
    notifyListeners();
  }
}
