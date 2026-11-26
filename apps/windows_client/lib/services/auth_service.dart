import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'config.dart';
import 'startup_clock.dart';

enum AuthStatus { unknown, signedOut, signedIn }

enum AuthOutcome { signedIn, confirmEmail, codeSent, failed }

class AuthSession {
  AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.email,
    this.userId,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String? email;
  final String? userId;

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'expires_at': expiresAt.millisecondsSinceEpoch ~/ 1000,
        'email': email,
        'user_id': userId,
      };

  static AuthSession? fromStored(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final access = j['access_token'] as String?;
      final refresh = j['refresh_token'] as String?;
      final exp = j['expires_at'];
      if (access == null || refresh == null || exp is! num) return null;
      return AuthSession(
        accessToken: access,
        refreshToken: refresh,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000),
        email: j['email'] as String?,
        userId: j['user_id'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Supabase Auth (email + password, or email one-time code) for the Windows app.
///
/// The session (access + refresh token) is kept in SharedPreferences for local
/// Windows builds (no ATL). Prefer flutter_secure_storage once VS ATL
/// (`atlstr.h`) is installed. The access token is a Supabase JWT that the
/// Orbita API verifies; there is no client-side tier or identity.
///
/// A `stub:<id>:<tier>` token is used only when [AppConfig.devStubAuthEnabled]
/// (non-release build + `--dart-define=ALLOW_DEV_STUB_AUTH=true`).
class AuthService extends ChangeNotifier {
  AuthService({
    http.Client? client,
    String? supabaseUrl,
    String? supabaseAnonKey,
    String? apiBaseUrl,
    bool? devStub,
    DateTime Function()? now,
  })  : _client = client ?? http.Client(),
        _supabaseUrl = _trimSlash(supabaseUrl ?? AppConfig.supabaseUrl),
        _anonKey = supabaseAnonKey ?? AppConfig.supabaseAnonKey,
        _apiBaseUrl = _trimSlash(apiBaseUrl ?? AppConfig.apiBaseUrl),
        _devStub = devStub ?? AppConfig.devStubAuthEnabled,
        _now = now ?? DateTime.now;

  final http.Client _client;
  final String _supabaseUrl;
  final String _anonKey;
  final String _apiBaseUrl;
  final bool _devStub;
  final DateTime Function() _now;

  static const _sessionKey = 'chatai_supabase_session';
  static const _legacyTokenKey = 'chatai_access_token';

  /// Keep /v1/me off the critical path — unreachable API must not stall UI.
  static const _meTimeout = Duration(seconds: 3);
  static const _authTimeout = Duration(seconds: 15);
  static const _refreshSkew = Duration(seconds: 60);

  ChatUser? user;
  String? accessToken;
  AuthSession? session;
  AuthStatus status = AuthStatus.unknown;
  bool loading = false;
  bool busy = false;
  String? error;

  /// Human-readable detail from the last failed sign-in attempt (server text).
  String? authMessage;
  bool _bootstrapping = false;
  Future<bool>? _refreshing;

  bool get isDevStub => _devStub;
  bool get configured => _supabaseUrl.isNotEmpty && _anonKey.isNotEmpty;
  String? get email => session?.email ?? user?.email;

  static String _trimSlash(String v) =>
      v.endsWith('/') ? v.substring(0, v.length - 1) : v;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// Sync hydrate for first paint. Only the dev stub signs in without a session.
  void hydrateLocalSync() {
    if (_devStub) {
      accessToken ??= AppConfig.stubAuthToken;
      status = AuthStatus.signedIn;
    }
    loading = false;
  }

  Future<void> bootstrap() async {
    if (_bootstrapping) return;
    _bootstrapping = true;
    StartupClock.mark('authBootstrapStart');
    try {
      final prefs = await _prefs.timeout(const Duration(seconds: 2));
      if (_devStub) {
        final stored = prefs.getString(_legacyTokenKey);
        accessToken = (stored != null && stored.isNotEmpty)
            ? stored
            : AppConfig.stubAuthToken;
        await prefs.setString(_legacyTokenKey, accessToken!);
        status = AuthStatus.signedIn;
        StartupClock.mark('authPrefs');
        await refreshMe();
        StartupClock.mark('authMe');
        return;
      }

      // A stub token left behind by an older build must never act as a login.
      await prefs.remove(_legacyTokenKey);
      final raw = prefs.getString(_sessionKey);
      session = raw == null ? null : AuthSession.fromStored(raw);
      StartupClock.mark('authPrefs');
      if (session == null) {
        _setSignedOut();
        return;
      }
      status = AuthStatus.signedIn;
      accessToken = session!.accessToken;
      if (_expiringSoon(session!)) {
        await _refresh();
      }
      if (status == AuthStatus.signedIn) {
        notifyListeners();
        await refreshMe();
      }
      StartupClock.mark('authMe');
    } on TimeoutException {
      error = 'auth_timeout';
      if (!_devStub && session == null) _setSignedOut();
    } catch (e) {
      error = e.toString();
      if (!_devStub && session == null) _setSignedOut();
    } finally {
      loading = false;
      _bootstrapping = false;
      notifyListeners();
      StartupClock.mark('authBootstrapDone');
    }
  }

  bool _expiringSoon(AuthSession s) =>
      !s.expiresAt.isAfter(_now().add(_refreshSkew));

  /// Token for API calls; refreshes the Supabase session shortly before expiry.
  Future<String?> freshAccessToken() async {
    final s = session;
    if (!_devStub && s != null && _expiringSoon(s)) {
      await _refresh();
    }
    return accessToken;
  }

  Future<void> refreshMe() async {
    var token = await freshAccessToken();
    if (token == null) {
      user = null;
      notifyListeners();
      return;
    }
    try {
      var res = await _getMe(token);
      if (res.statusCode == 401 && session != null && !_devStub) {
        if (await _refresh(force: true)) {
          token = accessToken;
          res = await _getMe(token!);
        }
      }
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        user = ChatUser.fromJson(body['user'] as Map<String, dynamic>);
        error = null;
      } else {
        error = 'auth_failed_${res.statusCode}';
      }
    } on TimeoutException {
      error = 'auth_timeout';
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<http.Response> _getMe(String token) => _client
      .get(
        Uri.parse('$_apiBaseUrl/v1/me'),
        headers: {'Authorization': 'Bearer $token'},
      )
      .timeout(_meTimeout);

  Future<AuthOutcome> signInWithPassword(String email, String password) async {
    return _guard(() async {
      final res = await _post(
        '/auth/v1/token?grant_type=password',
        {'email': email.trim(), 'password': password},
      );
      return _handleSessionResponse(res, email.trim());
    });
  }

  /// Creates the account. Supabase either signs in at once or requires the
  /// user to confirm their address first ([AuthOutcome.confirmEmail]).
  Future<AuthOutcome> signUpWithPassword(String email, String password) async {
    return _guard(() async {
      final res = await _post(
        '/auth/v1/signup',
        {'email': email.trim(), 'password': password},
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final body = _json(res);
        if (body['access_token'] == null) return AuthOutcome.confirmEmail;
      }
      return _handleSessionResponse(res, email.trim());
    });
  }

  Future<AuthOutcome> sendEmailCode(String email) async {
    return _guard(() async {
      final res = await _post(
        '/auth/v1/otp',
        {'email': email.trim(), 'create_user': true},
      );
      if (res.statusCode == 200) return AuthOutcome.codeSent;
      authMessage = _errorMessage(res);
      return AuthOutcome.failed;
    });
  }

  Future<AuthOutcome> verifyEmailCode(String email, String code) async {
    return _guard(() async {
      final res = await _post(
        '/auth/v1/verify',
        {'type': 'email', 'email': email.trim(), 'token': code.trim()},
      );
      return _handleSessionResponse(res, email.trim());
    });
  }

  Future<void> signOut() async {
    final token = accessToken;
    if (!_devStub && token != null && configured) {
      try {
        await _client.post(
          Uri.parse('$_supabaseUrl/auth/v1/logout'),
          headers: {'apikey': _anonKey, 'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 3));
      } catch (_) {
        // Local sign-out must succeed even when offline.
      }
    }
    final prefs = await _prefs;
    await prefs.remove(_sessionKey);
    await prefs.remove(_legacyTokenKey);
    session = null;
    _setSignedOut();
    notifyListeners();
  }

  /// Dev stub only: switch the fake tier against a local API.
  Future<void> switchStubTier(String tier) async {
    if (!_devStub) return;
    accessToken = 'stub:user_demo:$tier';
    await (await _prefs).setString(_legacyTokenKey, accessToken!);
    await refreshMe();
  }

  void _setSignedOut() {
    accessToken = null;
    user = null;
    status = AuthStatus.signedOut;
  }

  Future<AuthOutcome> _guard(Future<AuthOutcome> Function() body) async {
    if (!configured) {
      authMessage = null;
      error = 'auth_not_configured';
      notifyListeners();
      return AuthOutcome.failed;
    }
    busy = true;
    authMessage = null;
    notifyListeners();
    try {
      return await body();
    } on TimeoutException {
      authMessage = 'timeout';
      return AuthOutcome.failed;
    } catch (e) {
      authMessage = e.toString();
      return AuthOutcome.failed;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) {
    return _client
        .post(
          Uri.parse('$_supabaseUrl$path'),
          headers: {
            'apikey': _anonKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(_authTimeout);
  }

  Map<String, dynamic> _json(http.Response res) {
    try {
      final v = jsonDecode(res.body);
      return v is Map<String, dynamic> ? v : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String _errorMessage(http.Response res) {
    final b = _json(res);
    return (b['msg'] ??
            b['error_description'] ??
            b['message'] ??
            b['error'] ??
            'http_${res.statusCode}')
        .toString();
  }

  Future<AuthOutcome> _handleSessionResponse(
    http.Response res,
    String fallbackEmail,
  ) async {
    if (res.statusCode != 200) {
      authMessage = _errorMessage(res);
      return AuthOutcome.failed;
    }
    final next = _sessionFrom(_json(res), fallbackEmail);
    if (next == null) {
      authMessage = 'invalid_session_response';
      return AuthOutcome.failed;
    }
    await _adopt(next);
    unawaited(refreshMe());
    return AuthOutcome.signedIn;
  }

  AuthSession? _sessionFrom(Map<String, dynamic> j, String fallbackEmail) {
    final access = j['access_token'] as String?;
    final refresh = j['refresh_token'] as String?;
    if (access == null || refresh == null) return null;
    final expiresAt = j['expires_at'];
    final expiresIn = j['expires_in'];
    final DateTime exp;
    if (expiresAt is num) {
      exp = DateTime.fromMillisecondsSinceEpoch(expiresAt.toInt() * 1000);
    } else if (expiresIn is num) {
      exp = _now().add(Duration(seconds: expiresIn.toInt()));
    } else {
      exp = _now().add(const Duration(hours: 1));
    }
    final u = j['user'];
    return AuthSession(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: exp,
      email: (u is Map ? u['email'] as String? : null) ?? fallbackEmail,
      userId: u is Map ? u['id'] as String? : null,
    );
  }

  Future<void> _adopt(AuthSession next) async {
    session = next;
    accessToken = next.accessToken;
    status = AuthStatus.signedIn;
    error = null;
    final prefs = await _prefs;
    await prefs.setString(_sessionKey, jsonEncode(next.toJson()));
    notifyListeners();
  }

  /// Exchanges the refresh token. Returns false when the session is gone
  /// (rejected refresh token → signed out) or the network failed (session kept).
  Future<bool> _refresh({bool force = false}) {
    final s = session;
    if (s == null || !configured) return Future.value(false);
    if (!force && !_expiringSoon(s)) return Future.value(true);
    return _refreshing ??= _doRefresh(s).whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh(AuthSession s) async {
    try {
      final res = await _post(
        '/auth/v1/token?grant_type=refresh_token',
        {'refresh_token': s.refreshToken},
      );
      if (res.statusCode == 200) {
        final next = _sessionFrom(_json(res), s.email ?? '');
        if (next != null) {
          await _adopt(next);
          return true;
        }
      }
      if (res.statusCode == 400 || res.statusCode == 401 || res.statusCode == 403) {
        final prefs = await _prefs;
        await prefs.remove(_sessionKey);
        session = null;
        _setSignedOut();
        notifyListeners();
      }
      return false;
    } catch (_) {
      error = 'auth_network';
      return false;
    }
  }
}
