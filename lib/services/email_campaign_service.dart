import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:anis_crm/services/lead_service.dart';
import 'package:anis_crm/env_config.dart';

// =============================================================================
// MODELS
// =============================================================================

enum CampaignStatus { draft, scheduled, sent }

class EmailCampaign {
  final String id;
  final String name;
  final String subject;
  final String body;
  final CampaignStatus status;
  final int recipientCount;
  final List<String> recipientLeadIds;
  final String channel;
  final DateTime createdAt;
  final DateTime? sentAt;

  const EmailCampaign({
    required this.id,
    required this.name,
    required this.subject,
    this.body = '',
    this.status = CampaignStatus.draft,
    this.recipientCount = 0,
    this.recipientLeadIds = const [],
    this.channel = 'email',
    required this.createdAt,
    this.sentAt,
  });

  EmailCampaign copyWith({
    String? id,
    String? name,
    String? subject,
    String? body,
    CampaignStatus? status,
    int? recipientCount,
    List<String>? recipientLeadIds,
    String? channel,
    DateTime? createdAt,
    DateTime? sentAt,
  }) =>
      EmailCampaign(
        id: id ?? this.id,
        name: name ?? this.name,
        subject: subject ?? this.subject,
        body: body ?? this.body,
        status: status ?? this.status,
        recipientCount: recipientCount ?? this.recipientCount,
        recipientLeadIds: recipientLeadIds ?? this.recipientLeadIds,
        channel: channel ?? this.channel,
        createdAt: createdAt ?? this.createdAt,
        sentAt: sentAt ?? this.sentAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'subject': subject,
        'body': body,
        'status': status.name,
        'recipientCount': recipientCount,
        'recipientLeadIds': recipientLeadIds,
        'channel': channel,
        'createdAt': createdAt.toIso8601String(),
        'sentAt': sentAt?.toIso8601String(),
      };

  factory EmailCampaign.fromJson(Map<String, dynamic> m) => EmailCampaign(
        id: m['id'] as String,
        name: m['name'] as String,
        subject: m['subject'] as String? ?? '',
        body: m['body'] as String? ?? '',
        status: CampaignStatus.values.firstWhere(
          (e) => e.name == m['status'],
          orElse: () => CampaignStatus.draft,
        ),
        recipientCount: m['recipientCount'] as int? ?? 0,
        recipientLeadIds: (m['recipientLeadIds'] as List?)?.cast<String>() ?? [],
        channel: m['channel'] as String? ?? 'email',
        createdAt: DateTime.parse(m['createdAt'] as String),
        sentAt: m['sentAt'] != null ? DateTime.parse(m['sentAt'] as String) : null,
      );
}

class EmailTemplate {
  final String id;
  final String name;
  final String subject;
  final String body;

  const EmailTemplate({
    required this.id,
    required this.name,
    this.subject = '',
    this.body = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'subject': subject,
        'body': body,
      };

  factory EmailTemplate.fromJson(Map<String, dynamic> m) => EmailTemplate(
        id: m['id'] as String,
        name: m['name'] as String,
        subject: m['subject'] as String? ?? '',
        body: m['body'] as String? ?? '',
      );
}

// =============================================================================
// SERVICE
// =============================================================================

class EmailCampaignService {
  static const _campaignsKey = 'email_campaigns_v1';
  static const _templatesKey = 'email_templates_v1';
  static final EmailCampaignService instance = EmailCampaignService._();
  EmailCampaignService._();

  final ValueNotifier<List<EmailCampaign>> campaigns =
      ValueNotifier<List<EmailCampaign>>([]);
  final ValueNotifier<List<EmailTemplate>> templates =
      ValueNotifier<List<EmailTemplate>>([]);

  bool _loaded = false;

  static String get _apiBase => EnvConfig.apiBaseUrl;

  // ── Load ──────────────────────────────────────────────────────────────
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      // campaigns
      final rawC = prefs.getString(_campaignsKey);
      if (rawC != null && rawC.isNotEmpty) {
        campaigns.value = (jsonDecode(rawC) as List)
            .cast<Map<String, dynamic>>()
            .map(EmailCampaign.fromJson)
            .toList();
      } else {
        campaigns.value = _sampleCampaigns();
      }
      // templates
      final rawT = prefs.getString(_templatesKey);
      if (rawT != null && rawT.isNotEmpty) {
        templates.value = (jsonDecode(rawT) as List)
            .cast<Map<String, dynamic>>()
            .map(EmailTemplate.fromJson)
            .toList();
      } else {
        templates.value = _sampleTemplates();
      }
    } catch (e) {
      debugPrint('EmailCampaignService.load failed: $e');
      campaigns.value = _sampleCampaigns();
      templates.value = _sampleTemplates();
    } finally {
      _loaded = true;
    }
  }

  Future<void> _save() async {
    if (!_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _campaignsKey, jsonEncode(campaigns.value.map((e) => e.toJson()).toList()));
      await prefs.setString(
          _templatesKey, jsonEncode(templates.value.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('EmailCampaignService._save error: $e');
    }
  }

  // ── SMTP ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> checkSmtpConfig() async {
    try {
      final res = await http.get(
        Uri.parse('$_apiBase/api/email/config'),
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return {'configured': false, 'error': 'Server returned ${res.statusCode}'};
    } catch (e) {
      debugPrint('checkSmtpConfig error: $e');
      return {'configured': false, 'error': 'Cannot reach server'};
    }
  }

  Future<Map<String, dynamic>> sendTestEmail() async {
    try {
      final res = await http.post(
        Uri.parse('$_apiBase/api/email/test'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      final body = jsonDecode(res.body);
      return {'ok': false, 'detail': body['detail'] ?? 'Server error ${res.statusCode}'};
    } catch (e) {
      debugPrint('sendTestEmail error: $e');
      return {'ok': false, 'detail': 'Cannot reach server: $e'};
    }
  }

  // ── Campaign CRUD ────────────────────────────────────────────────────
  Future<void> createCampaign({
    required String name,
    required String subject,
    String body = '',
    List<String> recipientLeadIds = const [],
    String channel = 'email',
  }) async {
    final campaign = EmailCampaign(
      id: const Uuid().v4(),
      name: name,
      subject: subject,
      body: body,
      recipientLeadIds: recipientLeadIds,
      recipientCount: recipientLeadIds.length,
      channel: channel,
      createdAt: DateTime.now(),
    );
    campaigns.value = [...campaigns.value, campaign];
    await _save();
  }

  Future<void> updateCampaign(EmailCampaign updated) async {
    campaigns.value = campaigns.value
        .map((c) => c.id == updated.id
            ? updated.copyWith(recipientCount: updated.recipientLeadIds.length)
            : c)
        .toList();
    await _save();
  }

  Future<void> deleteCampaign(String id) async {
    campaigns.value = campaigns.value.where((c) => c.id != id).toList();
    await _save();
  }

  Future<void> duplicateCampaign(String id) async {
    final original = campaigns.value.firstWhere((c) => c.id == id);
    final copy = original.copyWith(
      id: const Uuid().v4(),
      name: '${original.name} (copy)',
      status: CampaignStatus.draft,
      createdAt: DateTime.now(),
      sentAt: null,
    );
    campaigns.value = [...campaigns.value, copy];
    await _save();
  }

  Future<Map<String, dynamic>> sendCampaign(String id) async {
    final idx = campaigns.value.indexWhere((c) => c.id == id);
    if (idx == -1) return {'sent': 0, 'failed': 1, 'errors': ['Campaign not found']};
    final campaign = campaigns.value[idx];

    // Build recipient list from lead IDs
    final allLeads = LeadService.instance.leads.value;
    final recipients = <Map<String, String>>[];
    for (final lid in campaign.recipientLeadIds) {
      final lead = allLeads.where((l) => l.id == lid).firstOrNull;
      if (lead != null && lead.email != null && lead.email!.isNotEmpty) {
        recipients.add({'name': lead.name, 'email': lead.email!});
      }
    }

    if (recipients.isEmpty) {
      return {'sent': 0, 'failed': 0, 'errors': ['No recipients with valid email addresses']};
    }

    try {
      final res = await http.post(
        Uri.parse('$_apiBase/api/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'subject': campaign.subject,
          'body': campaign.body,
          'recipients': recipients,
          'campaign_name': campaign.name,
        }),
      ).timeout(const Duration(seconds: 60));

      final result = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200) {
        // Mark campaign as sent
        final updated = campaign.copyWith(
          status: CampaignStatus.sent,
          sentAt: DateTime.now(),
        );
        final list = [...campaigns.value];
        list[idx] = updated;
        campaigns.value = list;
        await _save();
        return result;
      }
      return {
        'sent': 0,
        'failed': recipients.length,
        'errors': [result['detail'] ?? 'Server error ${res.statusCode}'],
      };
    } catch (e) {
      debugPrint('sendCampaign error: $e');
      return {
        'sent': 0,
        'failed': recipients.length,
        'errors': ['Cannot reach server: $e'],
      };
    }
  }

  // ── Template CRUD ────────────────────────────────────────────────────
  Future<void> createTemplate({
    required String name,
    String subject = '',
    String body = '',
  }) async {
    final template = EmailTemplate(
      id: const Uuid().v4(),
      name: name,
      subject: subject,
      body: body,
    );
    templates.value = [...templates.value, template];
    await _save();
  }

  Future<void> deleteTemplate(String id) async {
    templates.value = templates.value.where((t) => t.id != id).toList();
    await _save();
  }

  // ── Sample data ──────────────────────────────────────────────────────
  List<EmailCampaign> _sampleCampaigns() {
    final now = DateTime.now();
    return [
      EmailCampaign(
        id: const Uuid().v4(),
        name: 'Spring Promo Blast',
        subject: 'Exclusive Spring Deals Just For You!',
        body: 'Hi there! Check out our amazing spring collection...',
        status: CampaignStatus.sent,
        recipientCount: 120,
        recipientLeadIds: [],
        channel: 'email',
        createdAt: now.subtract(const Duration(days: 5)),
        sentAt: now.subtract(const Duration(days: 4)),
      ),
      EmailCampaign(
        id: const Uuid().v4(),
        name: 'Welcome Series',
        subject: 'Welcome to Our Community!',
        body: 'Welcome aboard! Here is what you can expect...',
        status: CampaignStatus.draft,
        recipientCount: 0,
        recipientLeadIds: [],
        channel: 'email',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ];
  }

  List<EmailTemplate> _sampleTemplates() => [
        EmailTemplate(
          id: const Uuid().v4(),
          name: 'Welcome Email',
          subject: 'Welcome to {{company}}!',
          body: 'Hi {{name}},\n\nThank you for joining us...',
        ),
        EmailTemplate(
          id: const Uuid().v4(),
          name: 'Follow-Up',
          subject: 'Just Checking In',
          body: 'Hi {{name}},\n\nWe wanted to follow up on...',
        ),
      ];
}
