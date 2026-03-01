import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:anis_crm/models/kpi_target.dart';
import 'package:anis_crm/models/lead.dart';
import 'package:anis_crm/models/activity.dart';
import 'package:anis_crm/services/auth_service.dart';
import 'package:anis_crm/services/lead_service.dart';
import 'package:anis_crm/services/activity_service.dart';

/// Manages KPI targets with automatic progress computation from live data.
/// Targets are persisted to Supabase via user_metadata (with SharedPreferences fallback).
class KpiService {
  static const _prefsKey = 'kpi_targets_v1';
  static final KpiService instance = KpiService._();
  KpiService._();

  final ValueNotifier<List<KpiTarget>> targets = ValueNotifier<List<KpiTarget>>([]);

  bool _loaded = false;

  /// Reset loaded state so data is re-fetched on next login.
  void reset() {
    _loaded = false;
    targets.value = [];
  }

  // ─── Lifecycle ──────────────────────────────────────────────────────────

  Future<void> load() async {
    if (_loaded) return;
    try {
      // Try loading from Supabase user_metadata first
      final cloudTargets = AuthService.instance.loadKpiTargets();
      if (cloudTargets.isNotEmpty) {
        targets.value = cloudTargets.map(KpiTarget.fromJson).toList();
        debugPrint('KpiService: loaded ${targets.value.length} targets from Supabase');
      } else {
        // Fallback: SharedPreferences (migrate from local-only to Supabase)
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_prefsKey);
        if (raw != null && raw.isNotEmpty) {
          final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
          targets.value = list.map(KpiTarget.fromJson).toList();
          debugPrint('KpiService: loaded ${targets.value.length} targets from local, migrating to Supabase');
          // Migrate to Supabase
          await _saveToSupabase();
        } else {
          targets.value = _defaultTargets();
          await _save();
        }
      }
    } catch (e) {
      debugPrint('KpiService.load failed: $e');
      targets.value = _defaultTargets();
    } finally {
      _loaded = true;
    }
    // Recalculate actuals whenever leads or activities change
    LeadService.instance.leads.addListener(_recalculate);
    ActivityService.instance.byLead.addListener(_recalculate);
    _recalculate();
  }

  // ─── CRUD ───────────────────────────────────────────────────────────────

  Future<void> addTarget(KpiTarget t) async {
    targets.value = [...targets.value, t];
    await _save();
    _recalculate();
  }

  Future<void> updateTarget(KpiTarget updated) async {
    targets.value = targets.value.map((t) => t.id == updated.id ? updated : t).toList();
    await _save();
    _recalculate();
  }

  Future<void> removeTarget(String id) async {
    targets.value = targets.value.where((t) => t.id != id).toList();
    await _save();
  }

  // ─── Calculation ────────────────────────────────────────────────────────

  void _recalculate() {
    final leads = LeadService.instance.leads.value;
    final allActivities = ActivityService.instance.byLead.value;
    final now = DateTime.now();

    targets.value = targets.value.map((kpi) {
      final range = _dateRange(kpi.period, now);
      final actual = _computeActual(kpi.metric, leads, allActivities, range);
      return kpi.copyWith(current: actual);
    }).toList();
  }

  int _computeActual(
    KpiMetric metric,
    List<LeadModel> leads,
    Map<String, List<ActivityModel>> allActivities,
    _DateRange range,
  ) {
    switch (metric) {
      case KpiMetric.leadsCreated:
        return leads.where((l) => _inRange(l.createdAt, range)).length;

      case KpiMetric.leadsConverted:
        return leads
            .where((l) => l.status == LeadStatus.converted && _inRange(l.updatedAt, range))
            .length;

      case KpiMetric.callsMade:
        return _countActivities(allActivities, ActivityType.call, range);

      case KpiMetric.followUpsDone:
        return _countActivities(allActivities, ActivityType.followup, range);

      case KpiMetric.emailsSent:
        return _countActivities(allActivities, ActivityType.message, range);

      case KpiMetric.responseRate:
        final total = leads.where((l) => _inRange(l.createdAt, range)).length;
        if (total == 0) return 0;
        final contacted = leads
            .where((l) => _inRange(l.createdAt, range) && l.lastContactedAt != null)
            .length;
        return ((contacted / total) * 100).round();
    }
  }

  int _countActivities(
    Map<String, List<ActivityModel>> byLead,
    ActivityType type,
    _DateRange range,
  ) {
    int count = 0;
    for (final list in byLead.values) {
      count += list.where((a) => a.type == type && _inRange(a.createdAt, range)).length;
    }
    return count;
  }

  bool _inRange(DateTime dt, _DateRange r) =>
      !dt.isBefore(r.start) && !dt.isAfter(r.end);

  _DateRange _dateRange(KpiPeriod period, DateTime now) {
    switch (period) {
      case KpiPeriod.daily:
        final start = DateTime(now.year, now.month, now.day);
        return _DateRange(start, now);
      case KpiPeriod.weekly:
        final weekday = now.weekday; // 1=Mon
        final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: weekday - 1));
        return _DateRange(start, now);
      case KpiPeriod.monthly:
        return _DateRange(DateTime(now.year, now.month, 1), now);
      case KpiPeriod.quarterly:
        final qMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        return _DateRange(DateTime(now.year, qMonth, 1), now);
    }
  }

  // ─── Persistence ────────────────────────────────────────────────────────

  Future<void> _save() async {
    // Save locally (fast, offline fallback)
    await _saveLocal();
    // Save to Supabase (persistent, cross-device)
    await _saveToSupabase();
  }

  Future<void> _saveLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = targets.value.map((t) => t.toJson()).toList();
      await prefs.setString(_prefsKey, jsonEncode(json));
    } catch (e) {
      debugPrint('KpiService._saveLocal failed: $e');
    }
  }

  Future<void> _saveToSupabase() async {
    try {
      if (!AuthService.instance.isLoggedIn) return;
      final json = targets.value.map((t) => t.toJson()).toList();
      await AuthService.instance.saveKpiTargets(json);
    } catch (e) {
      debugPrint('KpiService._saveToSupabase failed: $e');
    }
  }

  // ─── Defaults ───────────────────────────────────────────────────────────

  List<KpiTarget> _defaultTargets() {
    final now = DateTime.now();
    const uuid = Uuid();
    return [
      KpiTarget(
        id: uuid.v4(),
        label: 'New Leads This Month',
        metric: KpiMetric.leadsCreated,
        period: KpiPeriod.monthly,
        target: 50,
        createdAt: now,
      ),
      KpiTarget(
        id: uuid.v4(),
        label: 'Conversions This Month',
        metric: KpiMetric.leadsConverted,
        period: KpiPeriod.monthly,
        target: 10,
        createdAt: now,
      ),
      KpiTarget(
        id: uuid.v4(),
        label: 'Calls This Week',
        metric: KpiMetric.callsMade,
        period: KpiPeriod.weekly,
        target: 30,
        createdAt: now,
      ),
      KpiTarget(
        id: uuid.v4(),
        label: 'Follow-ups This Week',
        metric: KpiMetric.followUpsDone,
        period: KpiPeriod.weekly,
        target: 20,
        createdAt: now,
      ),
    ];
  }
}

class _DateRange {
  final DateTime start;
  final DateTime end;
  const _DateRange(this.start, this.end);
}
