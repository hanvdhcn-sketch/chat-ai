import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'config.dart';

class ApiClient {
  ApiClient({required this.getToken, http.Client? client})
      : _client = client ?? http.Client();

  final Future<String?> Function() getToken;
  final http.Client _client;

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

  /// Streaming-ready: parses SSE `data:` lines from the chat stream endpoint.
  Stream<Map<String, dynamic>> streamMessage({
    required String conversationId,
    required String content,
    String? model,
  }) async* {
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

    final response = await _client.send(request);
    if (response.statusCode != 200) {
      final err = await response.stream.bytesToString();
      throw Exception('stream_failed_${response.statusCode}: $err');
    }

    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (!line.startsWith('data: ')) continue;
      final raw = line.substring(6).trim();
      if (raw.isEmpty) continue;
      yield jsonDecode(raw) as Map<String, dynamic>;
    }
  }

  void _ensureOk(http.Response res, {int expected = 200}) {
    if (res.statusCode != expected &&
        !(expected == 200 && res.statusCode >= 200 && res.statusCode < 300)) {
      throw Exception('api_${res.statusCode}: ${res.body}');
    }
  }
}
