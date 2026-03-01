import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:anis_crm/models/activity.dart';
import 'package:anis_crm/services/api_client.dart';

/// Stores activities per-lead with server-first persistence and local fallback.
class ActivityService {
  static const _prefsKey = 'activities_v1';
  static final ActivityService instance = ActivityService._();
  ActivityService._();

  final ValueNotifier<Map<String, List<ActivityModel>>> byLead =
      ValueNotifier<Map<String, List<ActivityModel>>>({});

  bool _loaded = false;
  final _api = ApiClient.instance;

  Future<void> load() async {
    if (_loaded) return;

    // Try loading from server first
    try {
      final serverData = await _api.getAllActivities();
      if (serverData != null) {
        final result = <String, List<ActivityModel>>{};
        serverData.forEach((leadId, list) {
          result[leadId] = list.map((m) => _fromServerJson(m)).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        });
        byLead.value = result;
        debugPrint('ActivityService: loaded ${result.length} lead activity groups from server');
        _loaded = true;
        return;
      }
    } catch (e) {
      debugPrint('ActivityService: server fetch failed, falling back to local ($e)');
    }

    // Fallback to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final result = <String, List<ActivityModel>>{};
        map.forEach((leadId, list) {
          final arr = (list as List).cast<Map<String, dynamic>>();
          result[leadId] = arr.map(ActivityModel.fromJson).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        });
        byLead.value = result;
      }
    } catch (e) {
      debugPrint('ActivityService.load: local storage failed ($e)');
      byLead.value = {};
    } finally {
      _loaded = true;
    }
  }

  ActivityModel _fromServerJson(Map<String, dynamic> m) {
    return ActivityModel(
      id: m['id'] as String? ?? const Uuid().v4(),
      leadId: m['lead_id'] as String? ?? '',
      type: _parseType(m['type'] as String?),
      text: m['content'] as String?,
      createdAt: DateTime.tryParse(m['ts'] as String? ?? '') ?? DateTime.now(),
    );
  }

  ActivityType _parseType(String? s) {
    if (s == null) return ActivityType.note;
    for (final v in ActivityType.values) {
      if (v.name == s) return v;
    }
    return ActivityType.note;
  }

  Future<void> _saveLocal() async {
    if (!_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = <String, List<Map<String, dynamic>>>{};
      byLead.value.forEach((k, v) {
        map[k] = v.map((e) => e.toJson()).toList();
      });
      await prefs.setString(_prefsKey, jsonEncode(map));
    } catch (e) {
      // Silently skip
    }
  }

  Future<ActivityModel> add({
    required String leadId,
    required ActivityType type,
    String? text,
  }) async {
    final now = DateTime.now();
    // Idempotency: skip duplicate within 1s
    final existingList = byLead.value[leadId] ?? const <ActivityModel>[];
    if (existingList.isNotEmpty) {
      final last = existingList.first;
      final isSameType = last.type == type;
      final isSameText = (last.text ?? '') == (text ?? '');
      final isRecent = now.difference(last.createdAt).inMilliseconds.abs() <= 1000;
      if (isSameType && isSameText && isRecent) {
        return last;
      }
    }

    final a = ActivityModel(
      id: const Uuid().v4(),
      leadId: leadId,
      type: type,
      text: text,
      createdAt: now,
    );
    final map = {...byLead.value};
    final list = [...(map[leadId] ?? const <ActivityModel>[])];
    list.insert(0, a);
    map[leadId] = list;
    byLead.value = map;
    await _saveLocal();

    // Persist to server (fire-and-forget for offline support)
    try {
      await _api.createActivity({
        'id': a.id,
        'lead_id': a.leadId,
        'type': a.type.name,
        'content': a.text ?? '',
        'ts': a.createdAt.toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('ActivityService: server create failed for ${a.id}: $e');
    }

    return a;
  }

  List<ActivityModel> listFor(String leadId) => byLead.value[leadId] ?? const <ActivityModel>[];
}
