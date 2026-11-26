import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chatai/services/auth_service.dart';

const _supabase = 'https://proj.supabase.co';
const _api = 'https://api.example.com';

Map<String, dynamic> _sessionBody({
  String access = 'access-1',
  String refresh = 'refresh-1',
  int expiresIn = 3600,
}) =>
    {
      'access_token': access,
      'refresh_token': refresh,
      'expires_in': expiresIn,
      'user': {'id': '11111111-1111-1111-1111-111111111111', 'email': 'a@b.co'},
    };

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

AuthService _service(MockClient client, {DateTime Function()? now}) =>
    AuthService(
      client: client,
      supabaseUrl: _supabase,
      supabaseAnonKey: 'anon',
      apiBaseUrl: _api,
      devStub: false,
      now: now,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('without a session the user is signed out and stubs are ignored',
      () async {
    SharedPreferences.setMockInitialValues({
      'chatai_access_token': 'stub:user_demo:pro',
    });
    final auth = _service(MockClient((_) async => _json({}, 500)));
    auth.hydrateLocalSync();
    expect(auth.status, AuthStatus.unknown);
    expect(auth.accessToken, isNull);

    await auth.bootstrap();
    expect(auth.status, AuthStatus.signedOut);
    expect(auth.accessToken, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('chatai_access_token'), isNull);
  });

  test('password sign-in stores the session and loads /v1/me', () async {
    final seen = <String>[];
    final client = MockClient((req) async {
      seen.add('${req.method} ${req.url.path}?${req.url.query}');
      if (req.url.path == '/auth/v1/token') {
        expect(req.headers['apikey'], 'anon');
        expect(jsonDecode(req.body), {'email': 'a@b.co', 'password': 'pw'});
        return _json(_sessionBody());
      }
      if (req.url.path == '/v1/me') {
        expect(req.headers['Authorization'], 'Bearer access-1');
        return _json({
          'user': {
            'id': '11111111-1111-1111-1111-111111111111',
            'email': 'a@b.co',
            'planTier': 'pro',
          },
        });
      }
      return _json({}, 404);
    });
    final auth = _service(client);

    final outcome = await auth.signInWithPassword(' a@b.co ', 'pw');
    expect(outcome, AuthOutcome.signedIn);
    await auth.refreshMe();
    expect(auth.status, AuthStatus.signedIn);
    expect(auth.accessToken, 'access-1');
    expect(auth.user?.isPro, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('chatai_supabase_session'), contains('refresh-1'));

    final restored = _service(client);
    await restored.bootstrap();
    expect(restored.status, AuthStatus.signedIn);
    expect(restored.accessToken, 'access-1');
  });

  test('bad credentials fail without a session', () async {
    final auth = _service(MockClient((_) async => _json(
          {'error_code': 'invalid_credentials', 'msg': 'Invalid login'},
          400,
        )));
    final outcome = await auth.signInWithPassword('a@b.co', 'nope');
    expect(outcome, AuthOutcome.failed);
    expect(auth.authMessage, 'Invalid login');
    expect(auth.session, isNull);
  });

  test('sign-up without a session asks for email confirmation', () async {
    final auth = _service(MockClient((_) async => _json({
          'id': '11111111-1111-1111-1111-111111111111',
          'email': 'a@b.co',
        })));
    expect(await auth.signUpWithPassword('a@b.co', 'pw'), AuthOutcome.confirmEmail);
    expect(auth.status, isNot(AuthStatus.signedIn));
  });

  test('email code flow sends then verifies', () async {
    final auth = _service(MockClient((req) async {
      if (req.url.path == '/auth/v1/otp') return _json({});
      if (req.url.path == '/auth/v1/verify') {
        expect(jsonDecode(req.body), containsPair('type', 'email'));
        return _json(_sessionBody());
      }
      return _json({}, 404);
    }));
    expect(await auth.sendEmailCode('a@b.co'), AuthOutcome.codeSent);
    expect(await auth.verifyEmailCode('a@b.co', '123456'), AuthOutcome.signedIn);
    expect(auth.status, AuthStatus.signedIn);
  });

  test('expired session is refreshed with the refresh token', () async {
    var clock = DateTime(2030, 1, 1);
    final client = MockClient((req) async {
      if (req.url.path == '/auth/v1/token') {
        expect(req.url.queryParameters['grant_type'], 'refresh_token');
        expect(jsonDecode(req.body), {'refresh_token': 'refresh-1'});
        return _json(_sessionBody(access: 'access-2', refresh: 'refresh-2'));
      }
      return _json({}, 404);
    });
    final auth = _service(client, now: () => clock);
    SharedPreferences.setMockInitialValues({
      'chatai_supabase_session': jsonEncode(AuthSession(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
        expiresAt: clock.add(const Duration(seconds: 10)),
        email: 'a@b.co',
      ).toJson()),
    });
    await auth.bootstrap();
    expect(auth.accessToken, 'access-2');
    expect(auth.session?.refreshToken, 'refresh-2');

    clock = clock.add(const Duration(hours: 2));
    expect(await auth.freshAccessToken(), 'access-2');
  });

  test('rejected refresh token signs the user out', () async {
    final now = DateTime(2030, 1, 1);
    SharedPreferences.setMockInitialValues({
      'chatai_supabase_session': jsonEncode(AuthSession(
        accessToken: 'old',
        refreshToken: 'revoked',
        expiresAt: now.subtract(const Duration(minutes: 1)),
      ).toJson()),
    });
    final auth = _service(
      MockClient((_) async => _json({'error': 'invalid_grant'}, 400)),
      now: () => now,
    );
    await auth.bootstrap();
    expect(auth.status, AuthStatus.signedOut);
    expect(auth.accessToken, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('chatai_supabase_session'), isNull);
  });

  test('sign-out clears the stored session', () async {
    final auth = _service(MockClient((req) async {
      if (req.url.path == '/auth/v1/token') return _json(_sessionBody());
      return _json({}, 204);
    }));
    await auth.signInWithPassword('a@b.co', 'pw');
    await auth.signOut();
    expect(auth.status, AuthStatus.signedOut);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('chatai_supabase_session'), isNull);
  });

  test('unconfigured build cannot sign in', () async {
    final auth = AuthService(
      client: MockClient((_) async => _json({})),
      supabaseUrl: '',
      supabaseAnonKey: '',
      apiBaseUrl: _api,
      devStub: false,
    );
    expect(await auth.signInWithPassword('a@b.co', 'pw'), AuthOutcome.failed);
    expect(auth.error, 'auth_not_configured');
  });

  test('dev stub signs in with the stub token', () async {
    final auth = AuthService(
      client: MockClient((_) async => _json({}, 500)),
      supabaseUrl: '',
      supabaseAnonKey: '',
      apiBaseUrl: _api,
      devStub: true,
    );
    auth.hydrateLocalSync();
    expect(auth.status, AuthStatus.signedIn);
    expect(auth.accessToken, startsWith('stub:'));
  });
}
