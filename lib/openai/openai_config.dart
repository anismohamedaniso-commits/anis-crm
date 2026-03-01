import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// OpenAI runtime configuration
// Values are provided via --dart-define at runtime and resolved here.
// Do NOT append any paths to the endpoint. Use it directly as provided.
const String openAIApiKey = String.fromEnvironment('OPENAI_PROXY_API_KEY');
const String openAIEndpoint = String.fromEnvironment('OPENAI_PROXY_ENDPOINT');

class OpenAIClient {
  const OpenAIClient();

  bool get isConfigured => (openAIApiKey.isNotEmpty && openAIEndpoint.isNotEmpty);

  Uri get _endpointUri => Uri.parse(openAIEndpoint);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $openAIApiKey',
      };

  // Lightweight connectivity probe using gpt-4o-mini.
  // Expects a valid JSON object: {"connected": true}
  Future<bool> connectivityProbe({Duration timeout = const Duration(seconds: 8)}) async {
    if (!isConfigured) return false;
    try {
      final body = jsonEncode({
        'model': 'gpt-4o-mini',
        'temperature': 0,
        'response_format': {'type': 'json_object'},
        'messages': [
          {
            'role': 'system',
            'content': 'You are a healthcheck probe. Only output a JSON object with {"connected": true}.'
          },
          {
            'role': 'user',
            'content': 'Return {"connected": true} only.'
          }
        ],
      });
      final resp = await http.post(_endpointUri, headers: _headers, body: body).timeout(timeout);
      if (resp.statusCode != 200) {
        debugPrint('OpenAI probe HTTP ${resp.statusCode}: ${resp.body}');
        return false;
      }
      final data = jsonDecode(utf8.decode(resp.bodyBytes));
      final content = _firstMessageContent(data);
      if (content == null) return false;
      try {
        final obj = jsonDecode(content) as Map<String, dynamic>;
        return obj['connected'] == true;
      } catch (e) {
        debugPrint('OpenAI probe parse error: $e');
        return false;
      }
    } catch (e) {
      debugPrint('OpenAI probe error: $e');
      return false;
    }
  }

  // Generate dashboard priorities as a JSON array of items
  // Each item: {"title": string, "reason": string, "action": "Call"|"Message"|"Open Lead"}
  Future<List<Map<String, dynamic>>> generatePriorities(List<Map<String, dynamic>> leads, {Duration timeout = const Duration(seconds: 15)}) async {
    final body = jsonEncode({
      'model': 'gpt-4o',
      'temperature': 0.3,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': 'You are an assistant for a CRM dashboard. Output JSON only as an object with a field "items" which is an array.'
        },
        {
          'role': 'user',
          'content': 'Given these leads as JSON: ${jsonEncode(leads)}. Return {"items": [{"title": string, "reason": string, "action": "Call"|"Message"|"Open Lead"}] } limited to at most 3 items.'
        }
      ],
    });
    try {
      final resp = await http.post(_endpointUri, headers: _headers, body: body).timeout(timeout);
      if (resp.statusCode != 200) {
        throw Exception('OpenAI priorities HTTP ${resp.statusCode}: ${resp.body}');
      }
      final data = jsonDecode(utf8.decode(resp.bodyBytes));
      final content = _firstMessageContent(data);
      if (content == null) return [];
      final obj = jsonDecode(content) as Map<String, dynamic>;
      final items = (obj['items'] as List?)?.cast<dynamic>() ?? const [];
      return items.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (e) {
      debugPrint('OpenAI generatePriorities error: $e');
      rethrow;
    }
  }

  String? _firstMessageContent(dynamic data) {
    // OpenAI responses: { choices: [ { message: { content: '...' } } ] }
    try {
      final choices = (data['choices'] as List?) ?? const [];
      if (choices.isEmpty) return null;
      final msg = (choices.first as Map)['message'] as Map?;
      final content = msg?['content'] as String?;
      return content;
    } catch (_) {
      return null;
    }
  }
}
