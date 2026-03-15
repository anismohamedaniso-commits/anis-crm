import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:anis_crm/env_config.dart';

/// Service to manage Facebook & WhatsApp integrations
/// Talks to the FastAPI backend for config and status.
class IntegrationService {
  IntegrationService._();
  static final IntegrationService instance = IntegrationService._();

  /// Base URL of the FastAPI server (from EnvConfig / --dart-define).
  static String get _baseUrl => EnvConfig.apiBaseUrl;

  // ── Cached status ──
  final ValueNotifier<IntegrationStatus> status = ValueNotifier(
    const IntegrationStatus(),
  );

  /// Fetch current integration status from the server.
  Future<void> refreshStatus() async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/api/integrations/status'),
        headers: {'Content-Type': 'application/json'},
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final fb = data['facebook'] as Map<String, dynamic>? ?? {};
        final wa = data['whatsapp'] as Map<String, dynamic>? ?? {};
        final zap = data['zapier'] as Map<String, dynamic>? ?? {};
        status.value = IntegrationStatus(
          facebookConnected: fb['connected'] == true,
          facebookLeadsCount: (fb['leads_count'] as int?) ?? 0,
          whatsappConnected: wa['connected'] == true,
          whatsappLeadsCount: (wa['leads_count'] as int?) ?? 0,
          zapierConnected: zap['connected'] == true,
          zapierLeadsCount: (zap['leads_count'] as int?) ?? 0,
        );
      }
    } catch (e) {
      debugPrint('IntegrationService.refreshStatus error: $e');
    }
  }

  /// Fetch current integration config (tokens masked).
  Future<Map<String, dynamic>?> getConfig() async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/api/integrations/config'),
        headers: {'Content-Type': 'application/json'},
      );
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('IntegrationService.getConfig error: $e');
    }
    return null;
  }

  /// Save Facebook integration config.
  Future<bool> saveFacebookConfig({
    String? verifyToken,
    String? pageAccessToken,
  }) async {
    try {
      final body = <String, dynamic>{
        'facebook': <String, dynamic>{
          if (verifyToken != null && verifyToken.isNotEmpty)
            'verify_token': verifyToken,
          if (pageAccessToken != null && pageAccessToken.isNotEmpty)
            'page_access_token': pageAccessToken,
        },
      };
      final resp = await http.post(
        Uri.parse('$_baseUrl/api/integrations/config'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (resp.statusCode == 200) {
        await refreshStatus();
        return true;
      }
    } catch (e) {
      debugPrint('IntegrationService.saveFacebookConfig error: $e');
    }
    return false;
  }

  /// Save WhatsApp integration config.
  Future<bool> saveWhatsAppConfig({
    String? verifyToken,
    String? phoneNumberId,
    String? accessToken,
  }) async {
    try {
      final body = <String, dynamic>{
        'whatsapp': <String, dynamic>{
          if (verifyToken != null && verifyToken.isNotEmpty)
            'verify_token': verifyToken,
          if (phoneNumberId != null && phoneNumberId.isNotEmpty)
            'phone_number_id': phoneNumberId,
          if (accessToken != null && accessToken.isNotEmpty)
            'access_token': accessToken,
        },
      };
      final resp = await http.post(
        Uri.parse('$_baseUrl/api/integrations/config'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (resp.statusCode == 200) {
        await refreshStatus();
        return true;
      }
    } catch (e) {
      debugPrint('IntegrationService.saveWhatsAppConfig error: $e');
    }
    return false;
  }

  /// Save Zapier integration config (API key).
  Future<bool> saveZapierConfig({String? apiKey}) async {
    try {
      final body = <String, dynamic>{
        'zapier': <String, dynamic>{
          if (apiKey != null && apiKey.isNotEmpty) 'api_key': apiKey,
        },
      };
      final resp = await http.post(
        Uri.parse('$_baseUrl/api/integrations/config'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (resp.statusCode == 200) {
        await refreshStatus();
        return true;
      }
    } catch (e) {
      debugPrint('IntegrationService.saveZapierConfig error: $e');
    }
    return false;
  }

  /// Send a WhatsApp message via the backend.
  Future<bool> sendWhatsAppMessage({
    required String to,
    required String message,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/api/whatsapp/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'to': to, 'message': message}),
      );
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('IntegrationService.sendWhatsAppMessage error: $e');
      return false;
    }
  }

  /// Fetch leads from the server (includes FB & WA auto-created leads).
  Future<List<Map<String, dynamic>>> fetchServerLeads() async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/api/leads'),
        headers: {'Content-Type': 'application/json'},
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return (data['leads'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      }
    } catch (e) {
      debugPrint('IntegrationService.fetchServerLeads error: $e');
    }
    return [];
  }
}

/// Immutable integration status snapshot.
class IntegrationStatus {
  final bool facebookConnected;
  final int facebookLeadsCount;
  final bool whatsappConnected;
  final int whatsappLeadsCount;
  final bool zapierConnected;
  final int zapierLeadsCount;

  const IntegrationStatus({
    this.facebookConnected = false,
    this.facebookLeadsCount = 0,
    this.whatsappConnected = false,
    this.whatsappLeadsCount = 0,
    this.zapierConnected = false,
    this.zapierLeadsCount = 0,
  });
}
