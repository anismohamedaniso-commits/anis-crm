import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:anis_crm/models/lead.dart';
import 'package:anis_crm/env_config.dart';

class AiService {
  AiService._();
  static final AiService instance = AiService._();

  String get _base => '${EnvConfig.apiBaseUrl}/api/ai';

  Future<String> chat(List<Map<String, String>> messages, {String model = 'qwen2.5:7b'}) async {
    final body = jsonEncode({'model': model, 'messages': messages});
    final resp = await http.post(Uri.parse('$_base/chat'), headers: {'Content-Type': 'application/json'}, body: body).timeout(const Duration(seconds: 60));
    if (resp.statusCode >= 200 && resp.statusCode < 300) return resp.body;
    throw Exception('AI chat failed: ${resp.statusCode} ${resp.body}');
  }

  Future<String> summarize(String text) async {
    final prompt = 'Summarize the following text in a short bullet list:\n\n$text';
    final messages = [ {'role': 'user', 'content': prompt} ];
    return chat(messages);
  }

  Future<String> dailyInsights(List<LeadModel> leads) async {
    // Build a compact prompt with key lead fields
    final lines = leads.take(200).map((l) => '- ${l.name} | ${l.status.name} | ${l.phone ?? '-'} | ${l.email ?? '-'} | ${l.campaign ?? '-'}').join('\n');
    final prompt = 'You are a sales coach for Tick & Talk (presentation training, Shark Tank Egypt partner) and Speekr.ai (AI communication SaaS).\n'
        'Look at these leads and provide:\n'
        '1) 3 short insights about the pipeline (mention Masterclass, Corporate Accelerator, or Speekr where relevant)\n'
        '2) 3 concrete sales actions the user should take today to close more enrollments\n'
        '3) Flag up to 5 leads that need immediate follow-up with reason\n\nLeads:\n$lines\n\n'
        'Provide output in plain text, NOT as a tool call.';
    // Use the assistant structured endpoint (server includes CRM context)
    final out = await assistantStructured(prompt);
    if (out.containsKey('assistant')) return out['assistant'] as String;
    // fallback to chat
    return chat([{'role': 'user', 'content': prompt}]);
  }

  /// Non-streaming assistant call (uses server assistant endpoint that has access to CRM context)
  Future<String> assistant(String message, {String model = 'qwen2.5:7b', List<Map<String, String>>? history}) async {
    final payload = <String, dynamic>{'model': model, 'message': message};
    if (history != null && history.isNotEmpty) {
      payload['history'] = history;
    }
    final body = jsonEncode(payload);
    final resp = await http.post(Uri.parse('$_base/assistant'), headers: {'Content-Type': 'application/json'}, body: body).timeout(const Duration(seconds: 60));
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      // Server now returns JSON {"assistant": "..."} — extract the text
      try {
        final js = jsonDecode(resp.body) as Map<String, dynamic>;
        return (js['assistant'] as String?) ?? resp.body;
      } catch (_) {
        return resp.body;
      }
    }
    throw Exception('AI assistant failed: ${resp.statusCode} ${resp.body}');
  }

  /// Streaming assistant: returns a stream of text chunks as the model produces them.
  /// Parses NDJSON lines when possible and emits only message content fragments for cleaner UI updates.
  Stream<String> assistantStream(String message, {String model = 'qwen2.5:7b', List<Map<String, String>>? history}) {
    final uri = Uri.parse('$_base/assistant');
    final client = http.Client();
    final payload = <String, dynamic>{'model': model, 'message': message, 'stream': true};
    if (history != null && history.isNotEmpty) {
      payload['history'] = history;
    }
    final req = http.Request('POST', uri)
      ..headers.addAll({'Content-Type': 'application/json'})
      ..body = jsonEncode(payload);

    final controller = StreamController<String>();

    client.send(req).then((streamedResp) {
      if (streamedResp.statusCode < 200 || streamedResp.statusCode >= 300) {
        streamedResp.stream.toBytes().then((bytes) {
          final body = utf8.decode(bytes);
          controller.addError(Exception('Assistant stream failed: ${streamedResp.statusCode} $body'));
          controller.close();
          client.close();
        }).catchError((e) {
          controller.addError(e);
          controller.close();
          client.close();
        });
        return;
      }

      final decoded = streamedResp.stream.transform(utf8.decoder);
      String buffer = '';

      decoded.listen((data) {
        buffer += data;
        // Split on newline for NDJSON lines
        final parts = buffer.split('\n');
        // Keep last partial in buffer
        buffer = parts.removeLast();
        for (final p in parts) {
          final line = p.trim();
          if (line.isEmpty) continue;
          // Try to parse JSON line
          try {
            final js = jsonDecode(line);
            if (js is Map) {
              // Try common fields
              final text = js['response'] ?? js['content'] ?? js['token'] ?? js['text'];
              if (text != null) controller.add(text.toString());
              continue;
            }
            // Fallback: emit raw line
            controller.add(line);
          } catch (_) {
            // Not JSON, emit the raw piece
            controller.add(line);
          }
        }
      }, onDone: () {
        // Flush remaining buffer if any
        final rem = buffer.trim();
        if (rem.isNotEmpty) {
          try {
            final js = jsonDecode(rem);
            final text = js is Map ? (js['response'] ?? js['content'] ?? js['token'] ?? js['text']) : null;
            if (text != null) controller.add(text.toString()); else controller.add(rem);
          } catch (_) {
            controller.add(rem);
          }
        }
        controller.close();
        client.close();
      }, onError: (e) {
        controller.addError(e);
        controller.close();
        client.close();
      });
    }).catchError((e) {
      controller.addError(e);
      controller.close();
      client.close();
    });

    return controller.stream;
  }

  /// Structured assistant call: returns JSON with possible tool request
  Future<Map<String, dynamic>> assistantStructured(String message, {String model = 'qwen2.5:7b'}) async {
    final body = jsonEncode({'model': model, 'message': message});
    final resp = await http.post(Uri.parse('$_base/assistant'), headers: {'Content-Type': 'application/json'}, body: body).timeout(const Duration(seconds: 60));
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      try {
        final js = jsonDecode(resp.body) as Map<String, dynamic>;
        return js;
      } catch (_) {
        return {'assistant': resp.body};
      }
    }
    throw Exception('AI assistant failed: ${resp.statusCode} ${resp.body}');
  }

  /// Execute a server-side tool (confirmed by user). Returns tool result.
  Future<Map<String, dynamic>> executeTool(String tool, Map<String, dynamic> args, {String? apiKey}) async {
    final headers = {'Content-Type': 'application/json'};
    if (apiKey != null) headers['x-api-key'] = apiKey;
    final resp = await http.post(Uri.parse('$_base/tools/$tool'), headers: headers, body: jsonEncode(args)).timeout(const Duration(seconds: 30));
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Tool execution failed: ${resp.statusCode} ${resp.body}');
  }
}
