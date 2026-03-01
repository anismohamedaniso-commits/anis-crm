import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:anis_crm/models/lead.dart';
import 'package:anis_crm/engine/priorities_engine.dart';
import 'package:anis_crm/services/lead_service.dart';

/// Centralized placeholder for future AI calls.
/// No AI logic is executed now. Methods will early-return or throw
/// when AI is disabled. Wire all AI entrypoints here in the future.
class AiGateway {
  AiGateway._();
  static final instance = AiGateway._();

  /// Example placeholder method; not used yet.
  Future<T> notEnabled<T>(String feature) async {
    debugPrint('AiGateway: "$feature" requested but AI is disabled.');
    throw StateError('AI feature "$feature" is disabled.');
  }

  /// Attempts to generate priorities using a local AI provider (e.g., Ollama).
  /// Safe to call: on error/timeout, this throws so callers can fallback.
  Future<List<LeadPriority>> generatePrioritiesFromLocalAi(
    List<LeadModel> leads, {
    Duration timeout = const Duration(seconds: 15),
    String endpoint = 'http://localhost:11434/api/chat',
  }) async {
    final uri = Uri.parse(endpoint);
    final payload = {
      'model': 'qwen2.5:7b',
      'format': 'json',
      'stream': false,
      'messages': [
        {'role': 'user', 'content': _buildPrioritiesPrompt(leads)},
      ],
    };
    try {
      final resp = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload))
          .timeout(timeout);
      if (resp.statusCode != 200) {
        throw Exception('AI HTTP ${resp.statusCode}: ${resp.body}');
      }
      final body = jsonDecode(utf8.decode(resp.bodyBytes));
      // Ollama /api/chat returns {"message": {"role": "assistant", "content": "..."}}
      dynamic responseField;
      if (body is Map<String, dynamic>) {
        final msg = body['message'];
        if (msg is Map<String, dynamic>) {
          responseField = msg['content'];
        } else {
          responseField = body['response'];
        }
      }
      dynamic jsonContent;
      if (responseField is String) {
        // Some models include code fences; strip them crudely
        final cleaned = responseField.trim().replaceAll('```json', '').replaceAll('```', '');
        jsonContent = jsonDecode(cleaned);
      } else if (responseField is Map<String, dynamic> || responseField is List) {
        jsonContent = responseField;
      } else {
        throw Exception('Unrecognized AI response shape');
      }

      final list = (jsonContent as List).cast<dynamic>();
      return list.map((e) => _mapPriority(e)).whereType<LeadPriority>().toList();
    } catch (e) {
      debugPrint('AiGateway.generatePrioritiesFromLocalAi error: $e');
      rethrow;
    }
  }

  String _buildPrioritiesPrompt(List<LeadModel> leads) {
    final minimal = leads
        .map((l) => {
              'name': l.name,
              'status': l.status.name,
              'created_at': l.createdAt.toIso8601String(),
              'last_contacted_at': l.lastContactedAt?.toIso8601String(),
              'next_followup_at': l.nextFollowupAt?.toIso8601String(),
            })
        .toList();
    final contextJson = jsonEncode(minimal);
    return 'You are a CRM assistant. Given these leads as JSON: $contextJson. '
        'Return a JSON array (no text) of up to 3 objects with fields: '
        'title (string), reason (string), action (one of "Call" | "Message" | "Open Lead"). '
        'Keep titles short.';
  }

  LeadPriority? _mapPriority(dynamic e) {
    try {
      final m = (e as Map).cast<String, dynamic>();
      final String title = m['title']?.toString() ?? '';
      final String reason = m['reason']?.toString() ?? '';
      final String actionStr = m['action']?.toString().toLowerCase() ?? '';
      final action = switch (actionStr) {
        'call' => PriorityAction.call,
        'message' => PriorityAction.message,
        'open lead' || 'open_lead' || 'openlead' => PriorityAction.openLead,
        _ => PriorityAction.openLead,
      };
      if (title.isEmpty || reason.isEmpty) return null;
      // Try to resolve a lead from the title for contact info
      final leads = LeadService.instance.leads.value;
      LeadModel? matched;
      for (final l in leads) {
        if (title.toLowerCase().contains(l.name.toLowerCase())) {
          matched = l;
          break;
        }
      }
      return LeadPriority(title: title, reason: reason, action: action, leadId: matched?.id, phone: matched?.phone, email: matched?.email);
    } catch (_) {
      return null;
    }
  }
}
