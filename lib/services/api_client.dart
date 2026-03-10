import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:anis_crm/services/auth_service.dart';
import 'package:anis_crm/env_config.dart';

/// Centralized HTTP client for the FastAPI server.
/// All CRUD operations go through here for persistence.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  /// Base URL of the FastAPI server (from EnvConfig / --dart-define).
  static String get baseUrl => EnvConfig.apiBaseUrl;

  /// Optional API key for auth (matches server's API_KEY env var).
  String? apiKey;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (apiKey != null) 'x-api-key': apiKey!,
        // Include Supabase auth token for user-scoped data access
        if (AuthService.instance.accessToken != null)
          'Authorization': 'Bearer ${AuthService.instance.accessToken}',
      };

  bool _serverAvailable = true;

  /// Whether the server was reachable on the last attempt.
  bool get isServerAvailable => _serverAvailable;

  /// Ping the server to check connectivity.
  Future<bool> checkServer() async {
    try {
      final resp = await http
          .get(Uri.parse(baseUrl), headers: _headers)
          .timeout(const Duration(seconds: 3));
      _serverAvailable = resp.statusCode == 200;
    } catch (_) {
      _serverAvailable = false;
    }
    return _serverAvailable;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LEADS
  // ══════════════════════════════════════════════════════════════════════════

  /// Fetch all leads from the server.
  /// Fetch leads with optional pagination.
  /// Returns {"leads": [...], "total": N} when successful.
  Future<Map<String, dynamic>?> getLeadsPaginated({
    int limit = 0,
    int offset = 0,
  }) async {
    try {
      final params = <String, String>{};
      if (limit > 0) params['limit'] = '$limit';
      if (offset > 0) params['offset'] = '$offset';
      final uri = Uri.parse('$baseUrl/api/leads').replace(queryParameters: params.isNotEmpty ? params : null);
      final resp = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        _serverAvailable = true;
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('ApiClient.getLeadsPaginated error: $e');
      _serverAvailable = false;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>?> getLeads() async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/api/leads'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final list = (data['leads'] as List).cast<Map<String, dynamic>>();
        _serverAvailable = true;
        return list;
      }
    } catch (e) {
      debugPrint('ApiClient.getLeads error: $e');
      _serverAvailable = false;
    }
    return null;
  }

  /// Create a lead on the server.
  Future<bool> createLead(Map<String, dynamic> lead) async {
    try {
      final resp = await http
          .post(Uri.parse('$baseUrl/api/leads'),
              headers: _headers, body: jsonEncode(lead))
          .timeout(const Duration(seconds: 10));
      _serverAvailable = resp.statusCode == 201;
      return _serverAvailable;
    } catch (e) {
      debugPrint('ApiClient.createLead error: $e');
      _serverAvailable = false;
      return false;
    }
  }

  /// Update a lead on the server.
  Future<bool> updateLead(String id, Map<String, dynamic> fields) async {
    try {
      final resp = await http
          .put(Uri.parse('$baseUrl/api/leads/$id'),
              headers: _headers, body: jsonEncode(fields))
          .timeout(const Duration(seconds: 10));
      _serverAvailable = resp.statusCode == 200;
      return _serverAvailable;
    } catch (e) {
      debugPrint('ApiClient.updateLead error: $e');
      _serverAvailable = false;
      return false;
    }
  }

  /// Delete a lead on the server.
  Future<bool> deleteLead(String id) async {
    try {
      final resp = await http
          .delete(Uri.parse('$baseUrl/api/leads/$id'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      _serverAvailable = resp.statusCode == 200;
      return _serverAvailable;
    } catch (e) {
      debugPrint('ApiClient.deleteLead error: $e');
      _serverAvailable = false;
      return false;
    }
  }

  /// Bulk import leads to server.
  Future<int> importLeads(List<Map<String, dynamic>> leads) async {
    try {
      final resp = await http
          .post(Uri.parse('$baseUrl/api/leads/import'),
              headers: _headers,
              body: jsonEncode({'leads': leads}))
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        _serverAvailable = true;
        return data['imported'] as int? ?? 0;
      }
    } catch (e) {
      debugPrint('ApiClient.importLeads error: $e');
      _serverAvailable = false;
    }
    return 0;
  }

  /// Bulk-update leads (change status, assign, etc.).
  Future<int> bulkUpdateLeads(List<String> ids, Map<String, dynamic> fields) async {
    try {
      final resp = await http
          .post(Uri.parse('$baseUrl/api/leads/bulk-update'),
              headers: _headers,
              body: jsonEncode({'ids': ids, 'fields': fields}))
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        _serverAvailable = true;
        return data['updated'] as int? ?? 0;
      }
    } catch (e) {
      debugPrint('ApiClient.bulkUpdateLeads error: $e');
      _serverAvailable = false;
    }
    return 0;
  }

  /// Bulk-delete leads.
  Future<int> bulkDeleteLeads(List<String> ids) async {
    try {
      final resp = await http
          .post(Uri.parse('$baseUrl/api/leads/bulk-delete'),
              headers: _headers,
              body: jsonEncode({'ids': ids}))
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        _serverAvailable = true;
        return data['deleted'] as int? ?? 0;
      }
    } catch (e) {
      debugPrint('ApiClient.bulkDeleteLeads error: $e');
      _serverAvailable = false;
    }
    return 0;
  }

  // ══════════════════════════════════════════════════════════════════════════

  /// Fetch activities for a specific lead.
  Future<List<Map<String, dynamic>>?> getActivities(String leadId) async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/api/activities/$leadId'),
              headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final list =
            (data['activities'] as List).cast<Map<String, dynamic>>();
        _serverAvailable = true;
        return list;
      }
    } catch (e) {
      debugPrint('ApiClient.getActivities error: $e');
      _serverAvailable = false;
    }
    return null;
  }

  /// Fetch all activities grouped by lead.
  Future<Map<String, List<Map<String, dynamic>>>?> getAllActivities() async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/api/activities'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final raw = data['activities'] as Map<String, dynamic>;
        final result = <String, List<Map<String, dynamic>>>{};
        raw.forEach((k, v) {
          result[k] = (v as List).cast<Map<String, dynamic>>();
        });
        _serverAvailable = true;
        return result;
      }
    } catch (e) {
      debugPrint('ApiClient.getAllActivities error: $e');
      _serverAvailable = false;
    }
    return null;
  }

  /// Create an activity on the server.
  Future<bool> createActivity(Map<String, dynamic> activity) async {
    try {
      final resp = await http
          .post(Uri.parse('$baseUrl/api/activities'),
              headers: _headers, body: jsonEncode(activity))
          .timeout(const Duration(seconds: 10));
      _serverAvailable = resp.statusCode == 201;
      return _serverAvailable;
    } catch (e) {
      debugPrint('ApiClient.createActivity error: $e');
      _serverAvailable = false;
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEAM ACTIVITY FEED
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>?> getTeamActivities({int limit = 50, int offset = 0}) async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/api/team-activities?limit=$limit&offset=$offset'),
              headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return (data['activities'] as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('ApiClient.getTeamActivities error: $e');
    }
    return null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NOTIFICATIONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> getNotifications({int limit = 50}) async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/api/notifications?limit=$limit'),
              headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('ApiClient.getNotifications error: $e');
    }
    return null;
  }

  Future<bool> markNotificationRead(String id) async {
    try {
      final resp = await http
          .put(Uri.parse('$baseUrl/api/notifications/$id/read'),
              headers: _headers)
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> markAllNotificationsRead() async {
    try {
      final resp = await http
          .put(Uri.parse('$baseUrl/api/notifications/read-all'),
              headers: _headers)
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LEAD ASSIGNMENT & TEAM NOTES
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> assignLead(String leadId, String assignedToId, String assignedToName) async {
    try {
      final resp = await http
          .put(Uri.parse('$baseUrl/api/leads/$leadId/assign'),
              headers: _headers,
              body: jsonEncode({
                'assigned_to_id': assignedToId,
                'assigned_to_name': assignedToName,
              }))
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('ApiClient.assignLead error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>?> getLeadTeamNotes(String leadId) async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/api/leads/$leadId/team-notes'),
              headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return (data['notes'] as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('ApiClient.getLeadTeamNotes error: $e');
    }
    return null;
  }

  Future<bool> addLeadTeamNote(String leadId, String content) async {
    try {
      final resp = await http
          .post(Uri.parse('$baseUrl/api/leads/$leadId/team-notes'),
              headers: _headers,
              body: jsonEncode({'content': content}))
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 201;
    } catch (e) {
      debugPrint('ApiClient.addLeadTeamNote error: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TASKS
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>?> getTasks({
    String? assignedTo,
    String? status,
    int limit = 0,
    int offset = 0,
  }) async {
    try {
      final params = <String, String>{};
      if (assignedTo != null) params['assigned_to'] = assignedTo;
      if (status != null) params['status'] = status;
      if (limit > 0) params['limit'] = '$limit';
      if (offset > 0) params['offset'] = '$offset';
      final uri = Uri.parse('$baseUrl/api/tasks').replace(
          queryParameters: params.isNotEmpty ? params : null);
      final resp = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return (data['tasks'] as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('ApiClient.getTasks error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> createTask(Map<String, dynamic> task) async {
    try {
      final resp = await http
          .post(Uri.parse('$baseUrl/api/tasks'),
              headers: _headers, body: jsonEncode(task))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 201) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('ApiClient.createTask error: $e');
    }
    return null;
  }

  Future<bool> updateTask(String id, Map<String, dynamic> fields) async {
    try {
      final resp = await http
          .put(Uri.parse('$baseUrl/api/tasks/$id'),
              headers: _headers, body: jsonEncode(fields))
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('ApiClient.updateTask error: $e');
      return false;
    }
  }

  Future<bool> deleteTask(String id) async {
    try {
      final resp = await http
          .delete(Uri.parse('$baseUrl/api/tasks/$id'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEAM CHAT
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>?> getChatChannels() async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/api/chat/channels'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return (data['channels'] as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('ApiClient.getChatChannels error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> createChatChannel(Map<String, dynamic> channel) async {
    try {
      final resp = await http
          .post(Uri.parse('$baseUrl/api/chat/channels'),
              headers: _headers, body: jsonEncode(channel))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('ApiClient.createChatChannel error: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>?> getChatMessages(String channelId) async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/api/chat/channels/$channelId/messages'),
              headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return (data['messages'] as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('ApiClient.getChatMessages error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> sendChatMessage(String channelId, String text) async {
    try {
      final resp = await http
          .post(Uri.parse('$baseUrl/api/chat/channels/$channelId/messages'),
              headers: _headers, body: jsonEncode({'text': text}))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 201) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('ApiClient.sendChatMessage error: $e');
    }
    return null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LEADERBOARD
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>?> getLeaderboard() async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/api/leaderboard'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return (data['leaderboard'] as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('ApiClient.getLeaderboard error: $e');
    }
    return null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GLOBAL SEARCH
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> globalSearch(String query) async {
    try {
      final uri = Uri.parse('$baseUrl/api/search')
          .replace(queryParameters: {'q': query});
      final resp = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('ApiClient.globalSearch error: $e');
    }
    return null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REPORTS / EXPORT
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> getReportData(String reportType) async {
    try {
      final uri = Uri.parse('$baseUrl/api/reports/$reportType');
      final resp = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('ApiClient.getReportData error: $e');
    }
    return null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AUTOMATION RULES
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>?> getAutomationRules() async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/api/automation/rules'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return (data['rules'] as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('ApiClient.getAutomationRules error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> createAutomationRule(Map<String, dynamic> rule) async {
    try {
      final resp = await http
          .post(Uri.parse('$baseUrl/api/automation/rules'),
              headers: _headers, body: jsonEncode(rule))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 201) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('ApiClient.createAutomationRule error: $e');
    }
    return null;
  }

  Future<bool> updateAutomationRule(String id, Map<String, dynamic> fields) async {
    try {
      final resp = await http
          .put(Uri.parse('$baseUrl/api/automation/rules/$id'),
              headers: _headers, body: jsonEncode(fields))
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('ApiClient.updateAutomationRule error: $e');
      return false;
    }
  }

  Future<bool> deleteAutomationRule(String id) async {
    try {
      final resp = await http
          .delete(Uri.parse('$baseUrl/api/automation/rules/$id'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> evaluateAutomation(String trigger, Map<String, dynamic> context) async {
    try {
      await http
          .post(Uri.parse('$baseUrl/api/automation/evaluate'),
              headers: _headers,
              body: jsonEncode({'trigger': trigger, 'context': context}))
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('ApiClient.evaluateAutomation error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CUSTOM FIELDS
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>?> getCustomFields() async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/api/custom-fields'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return (data['fields'] as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('ApiClient.getCustomFields error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> createCustomField(Map<String, dynamic> field) async {
    try {
      final resp = await http
          .post(Uri.parse('$baseUrl/api/custom-fields'),
              headers: _headers, body: jsonEncode(field))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 201) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('ApiClient.createCustomField error: $e');
    }
    return null;
  }

  Future<bool> deleteCustomField(String id) async {
    try {
      final resp = await http
          .delete(Uri.parse('$baseUrl/api/custom-fields/$id'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CAMPAIGNS
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>?> getCampaigns({String market = ''}) async {
    try {
      final params = <String, String>{};
      if (market.isNotEmpty) params['market'] = market;
      final uri = Uri.parse('$baseUrl/api/campaigns')
          .replace(queryParameters: params.isNotEmpty ? params : null);
      final resp = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        _serverAvailable = true;
        return (data['campaigns'] as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('ApiClient.getCampaigns error: $e');
      _serverAvailable = false;
    }
    return null;
  }

  Future<Map<String, dynamic>?> createCampaign(Map<String, dynamic> campaign) async {
    try {
      final resp = await http
          .post(Uri.parse('$baseUrl/api/campaigns'),
              headers: _headers, body: jsonEncode(campaign))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 201) {
        _serverAvailable = true;
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('ApiClient.createCampaign error: $e');
      _serverAvailable = false;
    }
    return null;
  }

  Future<bool> updateCampaign(String id, Map<String, dynamic> fields) async {
    try {
      final resp = await http
          .put(Uri.parse('$baseUrl/api/campaigns/$id'),
              headers: _headers, body: jsonEncode(fields))
          .timeout(const Duration(seconds: 10));
      _serverAvailable = resp.statusCode == 200;
      return _serverAvailable;
    } catch (e) {
      debugPrint('ApiClient.updateCampaign error: $e');
      _serverAvailable = false;
      return false;
    }
  }

  Future<bool> deleteCampaign(String id) async {
    try {
      final resp = await http
          .delete(Uri.parse('$baseUrl/api/campaigns/$id'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) return true;
      debugPrint('deleteCampaign failed: ${resp.statusCode} ${resp.body}');
      return false;
    } catch (e) {
      debugPrint('deleteCampaign error: $e');
      return false;
    }
  }
}
