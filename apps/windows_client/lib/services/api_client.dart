import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'config.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.body, {this.code});

  final int statusCode;
  final String body;
  final String? code;

  bool get isQuota => statusCode == 402;
  bool get isRateLimit => statusCode == 429;

  @override
  String toString() => 'ApiException($statusCode, $code): $body';
}

class ApiClient {
  ApiClient({required this.getToken, http.Client? client})
      : _client = client ?? http.Client();

  final Future<String?> Function() getToken;
  final http.Client _client;

  http.Client get httpClient => _client;

  Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Conversation>> listConversations() async {
    final res = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/v1/conversations'),
      headers: await _headers(),
    );
    _ensureOk(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = body['conversations'] as List<dynamic>? ?? [];
    return list
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Conversation> createConversation({String? title}) async {
    final res = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/v1/conversations'),
      headers: await _headers(),
      body: jsonEncode({if (title != null) 'title': title}),
    );
    _ensureOk(res, expected: 201);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return Conversation.fromJson(body['conversation'] as Map<String, dynamic>);
  }

  Future<List<ChatMessage>> listMessages(String conversationId) async {
    final res = await _client.get(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/v1/conversations/$conversationId/messages',
      ),
      headers: await _headers(),
    );
    _ensureOk(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = body['messages'] as List<dynamic>? ?? [];
    return list
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<UsageSnapshot> getUsage() async {
    final res = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/v1/usage'),
      headers: await _headers(),
    );
    _ensureOk(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return UsageSnapshot.fromJson(body['usage'] as Map<String, dynamic>);
  }

  /// Sync Microsoft Store entitlement with the BFF (Collections / stub verify).
  Future<StoreVerifyResult> verifyStoreEntitlement({
    required String storeProductId,
    String? userStoreId,
    bool clientLicenseActive = false,
    bool stubGrantPro = false,
  }) async {
    final res = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/v1/billing/store/verify'),
      headers: await _headers(),
      body: jsonEncode({
        'storeProductId': storeProductId,
        if (userStoreId != null) 'userStoreId': userStoreId,
        'clientLicenseActive': clientLicenseActive,
        'stubGrantPro': stubGrantPro,
      }),
    );
    _ensureOk(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return StoreVerifyResult.fromJson(body);
  }

  Future<List<StoreProduct>> listStoreProducts() async {
    final res = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/v1/billing/store/products'),
      headers: await _headers(),
    );
    _ensureOk(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = body['products'] as List<dynamic>? ?? [];
    return list
        .map((e) => StoreProduct.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Streams SSE `data:` frames. Cancel via [cancel] Completer / abort the client.
  /// Returns a record of (eventStream, cancelFn).
  ({Stream<Map<String, dynamic>> events, Future<void> Function() cancel})
      streamMessage({
    required String conversationId,
    required String content,
    String? model,
  }) {
    final controller = StreamController<Map<String, dynamic>>();
    http.Client? streamClient;
    var cancelled = false;

    Future<void> cancel() async {
      cancelled = true;
      streamClient?.close();
      if (!controller.isClosed) {
        await controller.close();
      }
    }

    () async {
      try {
        streamClient = http.Client();
        final request = http.Request(
          'POST',
          Uri.parse(
            '${AppConfig.apiBaseUrl}/v1/conversations/$conversationId/messages/stream',
          ),
        );
        request.headers.addAll(await _headers());
        request.body = jsonEncode({
          'content': content,
          if (model != null) 'model': model,
        });

        final response = await streamClient!.send(request);
        if (response.statusCode != 200) {
          final err = await response.stream.bytesToString();
          String? code;
          try {
            code = (jsonDecode(err) as Map<String, dynamic>)['error'] as String?;
          } catch (_) {}
          throw ApiException(response.statusCode, err, code: code);
        }

        final lines = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter());

        await for (final line in lines) {
          if (cancelled) break;
          if (!line.startsWith('data: ')) continue;
          final raw = line.substring(6).trim();
          if (raw.isEmpty) continue;
          controller.add(jsonDecode(raw) as Map<String, dynamic>);
        }
      } catch (e, st) {
        if (!cancelled && !controller.isClosed) {
          controller.addError(e, st);
        }
      } finally {
        streamClient?.close();
        if (!controller.isClosed) {
          await controller.close();
        }
      }
    }();

    return (events: controller.stream, cancel: cancel);
  }

  void _ensureOk(http.Response res, {int expected = 200}) {
    if (res.statusCode != expected &&
        !(expected == 200 && res.statusCode >= 200 && res.statusCode < 300)) {
      String? code;
      try {
        code =
            (jsonDecode(res.body) as Map<String, dynamic>)['error'] as String?;
      } catch (_) {}
      throw ApiException(res.statusCode, res.body, code: code);
    }
  }
}
