import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:anis_crm/models/lead.dart';
import 'package:anis_crm/services/api_client.dart';
import 'package:anis_crm/services/auth_service.dart';

/// Manages Lead CRUD with server-first persistence and local fallback.
class LeadService {
  static const _prefsKey = 'leads_v1';
  static final LeadService instance = LeadService._();
  LeadService._();

  final ValueNotifier<List<LeadModel>> leads = ValueNotifier<List<LeadModel>>(<LeadModel>[]);

  bool _loaded = false;
  bool _hasMore = true;
  int _totalLeads = 0;
  static const int pageSize = 50;
  final _api = ApiClient.instance;

  /// Reset loaded state so data is re-fetched on next login.
  void reset() {
    _loaded = false;
    _hasMore = true;
    _totalLeads = 0;
    leads.value = [];
  }

  /// Whether more leads are available to fetch from the server.
  bool get hasMore => _hasMore;

  /// Total server-side lead count (from last fetch).
  int get totalLeads => _totalLeads;

  Future<void> load() async {
    // Always hit the server when authenticated — never serve stale cache.
    // Only skip if already loaded AND there is no auth token (unauthenticated / offline).
    final hasToken = AuthService.instance.accessToken != null;
    if (_loaded && !hasToken) return;
    try {
      // Server-first: fetch all leads directly from the API
      final serverLeads = await _api.getLeads();
      if (serverLeads != null) {
        final parsed = <LeadModel>[];
        for (final m in serverLeads) {
          try {
            parsed.add(_fromServerJson(m));
          } catch (e) {
            debugPrint('Skipping invalid server lead: $e');
          }
        }
        leads.value = parsed;
        _hasMore = false; // all leads loaded at once
        _totalLeads = parsed.length;
        debugPrint('LeadService: loaded ${parsed.length} leads from server');
        _loaded = true;
        return;
      }
    } catch (e) {
      debugPrint('LeadService: server fetch failed ($e)');
    }

    // Only fall back to local cache if we have no in-memory data yet
    if (leads.value.isNotEmpty) {
      _loaded = true;
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        final parsed = <LeadModel>[];
        for (final m in list) {
          try {
            parsed.add(LeadModel.fromJson(m));
          } catch (e) {
            debugPrint('Skipping invalid lead entry: $e');
          }
        }
        leads.value = parsed;
      } else {
        leads.value = [];
      }
    } catch (e) {
      debugPrint('LeadService.load: local storage failed ($e)');
      leads.value = [];
    } finally {
      _loaded = true;
    }
  }

  /// Load more leads from the server (infinite scroll pagination).
  Future<void> loadMore() async {
    if (!_hasMore) return;
    try {
      final result = await _api.getLeadsPaginated(
        limit: pageSize,
        offset: leads.value.length,
      );
      if (result != null) {
        _totalLeads = result['total'] as int? ?? _totalLeads;
        final serverLeads = (result['leads'] as List).cast<Map<String, dynamic>>();
        if (serverLeads.isEmpty || serverLeads.length < pageSize) {
          _hasMore = false;
        }
        final existing = leads.value.map((l) => l.id).toSet();
        final newLeads = <LeadModel>[];
        for (final m in serverLeads) {
          try {
            final lead = _fromServerJson(m);
            if (!existing.contains(lead.id)) newLeads.add(lead);
          } catch (e) {
            debugPrint('Skipping invalid server lead: $e');
          }
        }
        if (newLeads.isNotEmpty) {
          leads.value = [...leads.value, ...newLeads];
        }
      }
    } catch (e) {
      debugPrint('LeadService.loadMore error: $e');
    }
  }

  /// Convert server JSON (snake_case) to LeadModel.
  LeadModel _fromServerJson(Map<String, dynamic> m) {
    return LeadModel(
      id: m['id'] as String? ?? const Uuid().v4(),
      name: m['name'] as String? ?? '',
      status: _parseStatus(m['status'] as String?),
      phone: m['phone'] as String?,
      email: m['email'] as String?,
      source: _parseSource(m['source'] as String?),
      campaign: m['campaign'] as String?,
      createdAt: _parseDate(m['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(m['updated_at']) ?? DateTime.now(),
      lastContactedAt: _parseDate(m['last_contacted_at']),
      nextFollowupAt: _parseDate(m['next_followup_at']),
      dealValue: (m['deal_value'] as num?)?.toDouble(),
      country: m['country'] as String? ?? 'egypt',
    );
  }

  /// Convert LeadModel to server JSON (snake_case).
  Map<String, dynamic> _toServerJson(LeadModel lead) {
    return {
      'id': lead.id,
      'name': lead.name,
      'phone': lead.phone ?? '',
      'email': lead.email ?? '',
      'status': lead.status.name,
      'source': lead.source.name,
      'campaign': lead.campaign ?? '',
      'created_at': lead.createdAt.toUtc().toIso8601String(),
      'updated_at': lead.updatedAt.toUtc().toIso8601String(),
      'last_contacted_at': lead.lastContactedAt?.toUtc().toIso8601String(),
      'next_followup_at': lead.nextFollowupAt?.toUtc().toIso8601String(),
      'deal_value': lead.dealValue,
      'country': lead.country,
    };
  }

  LeadStatus _parseStatus(String? s) {
    if (s == null) return LeadStatus.fresh;
    for (final v in LeadStatus.values) {
      if (v.name == s) return v;
    }
    // Map server status names to enum
    switch (s) {
      case 'prospect':
      case 'fresh':
        return LeadStatus.fresh;
      case 'interested':
        return LeadStatus.interested;
      case 'followUp':
      case 'follow_up':
        return LeadStatus.followUp;
      case 'noAnswer':
      case 'no_answer':
        return LeadStatus.noAnswer;
      case 'closed':
        return LeadStatus.closed;
      case 'lost':
      case 'notInterested':
      case 'not_interested':
        return LeadStatus.notInterested;
      default:
        return LeadStatus.fresh;
    }
  }

  LeadSource _parseSource(String? s) {
    if (s == null) return LeadSource.whatsapp;
    for (final v in LeadSource.values) {
      if (v.name == s) return v;
    }
    switch (s) {
      case 'whatsapp':
        return LeadSource.whatsapp;
      case 'facebook':
        return LeadSource.facebook;
      case 'instagram':
        return LeadSource.instagram;
      default:
        return LeadSource.whatsapp;
    }
  }

  DateTime? _parseDate(dynamic d) {
    if (d == null) return null;
    if (d is String && d.isNotEmpty) {
      return DateTime.tryParse(d);
    }
    return null;
  }

  Future<void> _saveLocal() async {
    if (!_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = leads.value.map((e) => e.toJson()).toList();
      await prefs.setString(_prefsKey, jsonEncode(data));
    } catch (e) {
      // Silently skip
    }
  }

  Future<void> _syncToServer(LeadModel lead) async {
    try {
      await _api.updateLead(lead.id, _toServerJson(lead));
    } catch (e) {
      debugPrint('LeadService: server sync failed for ${lead.id}: $e');
    }
  }

  Future<LeadModel> create({
    required String name,
    LeadStatus status = LeadStatus.fresh,
    String? phone,
    String? email,
    LeadSource source = LeadSource.whatsapp,
    String? campaign,
    DateTime? createdAt,
    double? dealValue,
    String country = 'egypt',
  }) async {
    final now = DateTime.now();
    final lead = LeadModel(
      id: const Uuid().v4(),
      name: name,
      status: status,
      phone: phone,
      email: email,
      source: source,
      campaign: campaign,
      createdAt: createdAt ?? now,
      updatedAt: now,
      dealValue: dealValue,
      country: country,
    );
    debugPrint('LeadService.create name="$name" status=${status.name}');
    final list = [...leads.value, lead];
    leads.value = list;
    await _saveLocal();
    // Persist to server (fire-and-forget for offline support)
    try {
      await _api.createLead(_toServerJson(lead));
    } catch (e) {
      debugPrint('LeadService: server create failed for ${lead.id}: $e');
    }
    return lead;
  }

  Future<void> update(LeadModel updated) async {
    debugPrint('LeadService.update id=${updated.id}');
    final list = leads.value.map((e) => e.id == updated.id ? updated.copyWith(updatedAt: DateTime.now()) : e).toList();
    leads.value = list;
    await _saveLocal();
    await _syncToServer(updated.copyWith(updatedAt: DateTime.now()));
  }

  Future<void> delete(String id) async {
    debugPrint('LeadService.delete id=$id');
    leads.value = leads.value.where((e) => e.id != id).toList();
    await _saveLocal();
    try {
      await _api.deleteLead(id);
    } catch (e) {
      debugPrint('LeadService: server delete failed for $id: $e');
    }
  }

  /// Bulk update status for multiple leads.
  Future<int> bulkSetStatus(List<String> ids, LeadStatus status) async {
    final updated = leads.value.map((l) {
      if (ids.contains(l.id)) return l.copyWith(status: status, updatedAt: DateTime.now());
      return l;
    }).toList();
    leads.value = updated;
    await _saveLocal();
    try {
      return await _api.bulkUpdateLeads(ids, {'status': status.name});
    } catch (e) {
      debugPrint('LeadService.bulkSetStatus server error: $e');
      return ids.length; // applied locally
    }
  }

  /// Bulk assign leads to a campaign.
  Future<int> bulkSetCampaign(List<String> ids, String? campaignId) async {
    final updated = leads.value.map((l) {
      if (ids.contains(l.id)) return l.copyWith(campaign: campaignId ?? '', updatedAt: DateTime.now());
      return l;
    }).toList();
    leads.value = updated;
    await _saveLocal();
    try {
      return await _api.bulkUpdateLeads(ids, {'campaign': campaignId ?? ''});
    } catch (e) {
      debugPrint('LeadService.bulkSetCampaign server error: $e');
      return ids.length;
    }
  }

  /// Bulk assign leads to a team member.
  Future<int> bulkAssign(List<String> ids, String assignedToId, String assignedToName) async {
    final updated = leads.value.map((l) {
      if (ids.contains(l.id)) {
        return l.copyWith(
          assignedTo: assignedToId,
          assignedToName: assignedToName,
          updatedAt: DateTime.now(),
        );
      }
      return l;
    }).toList();
    leads.value = updated;
    await _saveLocal();
    try {
      return await _api.bulkUpdateLeads(ids, {
        'assigned_to': assignedToId,
        'assigned_to_name': assignedToName,
      });
    } catch (e) {
      debugPrint('LeadService.bulkAssign server error: $e');
      return ids.length;
    }
  }

  /// Bulk delete multiple leads.
  Future<int> bulkDelete(List<String> ids) async {
    leads.value = leads.value.where((l) => !ids.contains(l.id)).toList();
    await _saveLocal();
    try {
      return await _api.bulkDeleteLeads(ids);
    } catch (e) {
      debugPrint('LeadService.bulkDelete server error: $e');
      return ids.length;
    }
  }

  LeadModel? byId(String id) {
    try {
      return leads.value.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> setStatus(String id, LeadStatus status) async {
    final existing = byId(id);
    if (existing == null) return;
    await update(existing.copyWith(status: status));
  }

  Future<void> setLastContacted(String id, DateTime when) async {
    final existing = byId(id);
    if (existing == null) return;
    await update(existing.copyWith(lastContactedAt: when));
  }

  Future<void> setNextFollowup(String id, DateTime? when) async {
    final existing = byId(id);
    if (existing == null) return;
    await update(existing.copyWith(nextFollowupAt: when));
  }

  /// Import a batch of leads (CSV/Excel import).
  /// Saves locally AND pushes to server.
  Future<int> importBatch(List<LeadModel> batch) async {
    final existing = {...leads.value.map((e) => e.id)};
    final toAdd = batch.where((l) => !existing.contains(l.id)).toList();
    if (toAdd.isEmpty) return 0;

    final list = [...leads.value, ...toAdd];
    leads.value = list;
    await _saveLocal();

    // Push to server (fire-and-forget for offline support)
    try {
      final serverData = toAdd.map(_toServerJson).toList();
      await _api.importLeads(serverData);
    } catch (e) {
      debugPrint('LeadService: server import failed: $e');
    }
    return toAdd.length;
  }

  Map<LeadStatus, int> countsByStatus() {
    final map = <LeadStatus, int>{
      for (final s in LeadStatus.values) s: 0,
    };
    for (final l in leads.value) {
      map[l.status] = (map[l.status] ?? 0) + 1;
    }
    return map;
  }

  List<LeadModel> dueTodayFollowups() {
    final today = DateTime.now();
    bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
    return leads.value.where((l) {
      if (l.nextFollowupAt == null) return false;
      final d = l.nextFollowupAt!;
      return d.isBefore(DateTime(today.year, today.month, today.day).add(const Duration(days: 1))) &&
          (isSameDay(d, today) || d.isBefore(today));
    }).toList();
  }

  List<LeadModel> _sampleLeads() {
    final now = DateTime.now();
    return [
      LeadModel(
        id: const Uuid().v4(),
        name: 'Alex Johnson',
        status: LeadStatus.interested,
        phone: '+1 555 123 4567',
        email: 'alex@example.com',
        source: LeadSource.whatsapp,
        campaign: 'Spring Promo',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 3)),
      ),
      LeadModel(
        id: const Uuid().v4(),
        name: 'Maya Singh',
        status: LeadStatus.followUp,
        source: LeadSource.instagram,
        campaign: 'IG Stories',
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(hours: 2)),
        nextFollowupAt: now.subtract(const Duration(hours: 1)),
      ),
      LeadModel(
        id: const Uuid().v4(),
        name: 'Chen Wei',
        status: LeadStatus.noAnswer,
        source: LeadSource.facebook,
        campaign: 'FB Reach',
        createdAt: now.subtract(const Duration(days: 4)),
        updatedAt: now.subtract(const Duration(hours: 6)),
        lastContactedAt: now.subtract(const Duration(days: 2, hours: 3)),
      ),
    ];
  }
}
