import 'dart:async';
import 'dart:convert';

import 'package:anis_crm/models/message.dart';
import 'package:anis_crm/models/activity.dart';
import 'package:anis_crm/services/activity_service.dart';
import 'package:anis_crm/supabase/supabase_config.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Handles WhatsApp messages per-lead with local persistence and Supabase sync.
class MessageService {
  MessageService._();
  static final MessageService instance = MessageService._();

  static const _prefsKey = 'messages_v1';

  final ValueNotifier<Map<String, List<MessageModel>>> byLead = ValueNotifier({});

  final Map<String, RealtimeChannel> _subscriptions = {};
  bool _loaded = false;

  Future<void> loadAll() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final result = <String, List<MessageModel>>{};
        map.forEach((leadId, list) {
          final arr = (list as List).cast<Map<String, dynamic>>();
          result[leadId] = arr.map(MessageModel.fromJson).toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        });
        byLead.value = result;
      }
    } catch (e) {
      debugPrint('MessageService.loadAll: SharedPreferences unavailable on web, using in-memory ($e)');
      byLead.value = {};
    } finally {
      _loaded = true;
    }
  }

  Future<void> _save() async {
    if (!_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = <String, List<Map<String, dynamic>>>{};
      byLead.value.forEach((k, v) => map[k] = v.map((e) => e.toJson()).toList());
      await prefs.setString(_prefsKey, jsonEncode(map));
    } catch (e) {
      debugPrint('MessageService._save error: $e');
    }
  }

  List<MessageModel> listFor(String leadId) => byLead.value[leadId] ?? const <MessageModel>[];

  /// Subscribe to realtime DB changes for a given lead (Supabase only).
  void subscribeLead(String leadId) {
    try {
      if (_subscriptions.containsKey(leadId)) return;
      final client = SupabaseConfig.client;
      final ch = client
          .channel('public:messages:lead_id=$leadId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'messages',
            callback: (payload) {
              final row = payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord;
              if (row.isEmpty) return;
              if ((row['lead_id']?.toString() ?? '') != leadId) return;
              final m = MessageModel.fromJson(row);
              final map = {...byLead.value};
              final list = [...(map[leadId] ?? const <MessageModel>[])];
              final idx = list.indexWhere((e) => e.id == m.id);
              if (idx >= 0) {
                list[idx] = m;
              } else {
                list.add(m);
                list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
              }
              map[leadId] = list;
              byLead.value = map;
            },
          )
          .subscribe();
      _subscriptions[leadId] = ch;
    } catch (e) {
      debugPrint('MessageService.subscribeLead error: $e');
    }
  }

  Future<void> unsubscribeLead(String leadId) async {
    final ch = _subscriptions.remove(leadId);
    if (ch != null) {
      try {
        await SupabaseConfig.client.removeChannel(ch);
      } catch(e) {
        debugPrint('MessageService.unsubscribeLead error: $e');
      }
    }
  }

  /// Loads history from Supabase for a lead, merges into local cache.
  Future<void> hydrateFromRemote(String leadId) async {
    try {
      final user = SupabaseConfig.auth.currentUser;
      final session = SupabaseConfig.auth.currentSession;
      if (user == null || session == null || session.accessToken.isEmpty) {
        debugPrint('MessageService.hydrateFromRemote: not authenticated, skip');
        return;
      }
      final rows = await SupabaseConfig.client
          .from('messages')
          .select('*')
          .eq('lead_id', leadId)
          .order('created_at', ascending: true) as List<dynamic>;
      final remote = rows.cast<Map<String, dynamic>>().map(MessageModel.fromJson).toList();
      if (remote.isEmpty) return;
      final map = {...byLead.value};
      final local = [...(map[leadId] ?? const <MessageModel>[])];
      final merged = <MessageModel>[...local];
      for (final m in remote) {
        final idx = merged.indexWhere((e) => e.id == m.id);
        if (idx >= 0) merged[idx] = m; else merged.add(m);
      }
      merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      map[leadId] = merged;
      byLead.value = map;
      await _save();
    } catch (e) {
      debugPrint('MessageService.hydrateFromRemote error: $e');
    }
  }

  /// Sends a WhatsApp message using Supabase Edge Function. Updates local state and logs an Activity.
  Future<MessageModel> sendWhatsApp({
    required String leadId,
    required String toPhone,
    required String text,
  }) async {
    final now = DateTime.now();
    final temp = MessageModel(
      id: const Uuid().v4(),
      leadId: leadId,
      phone: toPhone,
      channel: 'whatsapp',
      direction: MessageDirection.outgoing,
      text: text,
      status: MessageStatus.sending,
      createdAt: now,
      updatedAt: now,
    );
    // Optimistic add
    final map = {...byLead.value};
    final list = [...(map[leadId] ?? const <MessageModel>[])];
    list.add(temp);
    map[leadId] = list..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    byLead.value = map;

    // Try remote send
    try {
      final user = SupabaseConfig.auth.currentUser;
      final session = SupabaseConfig.auth.currentSession;
      if (user == null || session == null || session.accessToken.isEmpty) {
        throw Exception('Not authenticated');
      }
      final resp = await SupabaseConfig.client.functions.invoke(
        'send_whatsapp_message',
        body: {
          'lead_id': leadId,
          'to_phone': toPhone,
          'text': text,
        },
        method: HttpMethod.post,
      );
      final data = (resp.data is String) ? jsonDecode(resp.data as String) : resp.data as Map<String, dynamic>;
      final saved = MessageModel.fromJson(data['message'] as Map<String, dynamic>? ?? data);
      // Merge update
      final map2 = {...byLead.value};
      final list2 = [...(map2[leadId] ?? const <MessageModel>[])];
      final idx = list2.indexWhere((e) => e.id == temp.id);
      if (idx >= 0) {
        list2[idx] = saved.copyWith(id: saved.id.isEmpty ? temp.id : saved.id);
      } else {
        list2.add(saved);
      }
      map2[leadId] = list2..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      byLead.value = map2;
      await _save();
      // Log activity
      await ActivityService.instance.add(leadId: leadId, type: ActivityType.message, text: 'WhatsApp message sent');
      return saved;
    } catch (e) {
      debugPrint('MessageService.sendWhatsApp error: $e');
      // Mark as failed
      final map3 = {...byLead.value};
      final list3 = [...(map3[leadId] ?? const <MessageModel>[])];
      final idx = list3.indexWhere((m) => m.id == temp.id);
      if (idx >= 0) {
        list3[idx] = list3[idx].copyWith(status: MessageStatus.failed, updatedAt: DateTime.now());
        map3[leadId] = list3;
        byLead.value = map3;
        await _save();
      }
      rethrow;
    }
  }
}
