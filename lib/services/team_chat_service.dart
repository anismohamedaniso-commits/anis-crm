import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:anis_crm/models/chat_models.dart';
import 'package:anis_crm/services/api_client.dart';
import 'package:anis_crm/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for team chat channels and messages.
/// Uses Supabase Realtime for live message delivery when available,
/// with REST API fallback.
class TeamChatService extends ChangeNotifier {
  TeamChatService._();
  static final TeamChatService instance = TeamChatService._();

  List<ChatChannel> _channels = [];
  List<ChatChannel> get channels => _channels;

  final Map<String, List<ChatMessage>> _messages = {};
  List<ChatMessage> messagesFor(String channelId) => _messages[channelId] ?? [];

  String? _activeChannelId;
  String? get activeChannelId => _activeChannelId;

  Timer? _pollTimer;
  RealtimeChannel? _realtimeChannel;
  bool _useRealtime = true;

  /// Load channels list
  Future<void> loadChannels() async {
    try {
      final data = await ApiClient.instance.getChatChannels();
      if (data != null) {
        _channels = data.map((j) => ChatChannel.fromJson(j)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('TeamChatService.loadChannels error: $e');
    }
  }

  /// Load messages for a channel
  Future<void> loadMessages(String channelId) async {
    try {
      final data = await ApiClient.instance.getChatMessages(channelId);
      if (data != null) {
        _messages[channelId] = data.map((j) => ChatMessage.fromJson(j)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('TeamChatService.loadMessages error: $e');
    }
  }

  /// Set active channel and start listening for messages
  void setActiveChannel(String channelId) {
    _activeChannelId = channelId;
    loadMessages(channelId);
    _subscribeRealtime(channelId);
  }

  /// Subscribe to Supabase Realtime for live chat messages.
  /// Falls back to polling if Realtime is unavailable.
  void _subscribeRealtime(String channelId) {
    // Clean up previous subscription
    _unsubscribeRealtime();
    _pollTimer?.cancel();

    if (!_useRealtime) {
      _startPolling(channelId);
      return;
    }

    try {
      _realtimeChannel = SupabaseConfig.client
          .channel('chat_messages:$channelId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'chat_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'channel_id',
              value: channelId,
            ),
            callback: (payload) {
              final newRow = payload.newRecord;
              if (newRow.isNotEmpty) {
                final msg = ChatMessage.fromJson(newRow);
                _messages.putIfAbsent(channelId, () => []);
                // Avoid duplicates
                final exists = _messages[channelId]!.any((m) => m.id == msg.id);
                if (!exists) {
                  _messages[channelId]!.add(msg);
                  notifyListeners();
                }
              }
            },
          )
          .subscribe((status, [error]) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          debugPrint('Realtime: subscribed to chat_messages:$channelId');
        } else if (status == RealtimeSubscribeStatus.channelError) {
          debugPrint('Realtime: channel error, falling back to polling');
          _useRealtime = false;
          _startPolling(channelId);
        }
      });
    } catch (e) {
      debugPrint('Realtime subscribe failed, falling back to polling: $e');
      _useRealtime = false;
      _startPolling(channelId);
    }
  }

  void _unsubscribeRealtime() {
    if (_realtimeChannel != null) {
      SupabaseConfig.client.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
  }

  void _startPolling(String channelId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_activeChannelId == channelId) {
        loadMessages(channelId);
      }
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _unsubscribeRealtime();
    _activeChannelId = null;
  }

  /// Send a message to a channel
  Future<bool> sendMessage(String channelId, String text) async {
    try {
      final result = await ApiClient.instance.sendChatMessage(channelId, text);
      if (result != null) {
        final msg = ChatMessage.fromJson(result);
        _messages.putIfAbsent(channelId, () => []);
        // Only add if not already received via Realtime
        final exists = _messages[channelId]!.any((m) => m.id == msg.id);
        if (!exists) {
          _messages[channelId]!.add(msg);
          notifyListeners();
        }
        return true;
      }
    } catch (e) {
      debugPrint('TeamChatService.sendMessage error: $e');
    }
    return false;
  }

  /// Create or get a direct channel with another user
  Future<ChatChannel?> getOrCreateDM(String otherUserId, String otherUserName,
      String myId, String myName) async {
    try {
      final result = await ApiClient.instance.createChatChannel({
        'type': 'direct',
        'member_ids': [myId, otherUserId],
        'member_names': [myName, otherUserName],
        'name': '',
      });
      if (result != null) {
        final ch = ChatChannel.fromJson(result);
        await loadChannels();
        return ch;
      }
    } catch (e) {
      debugPrint('TeamChatService.getOrCreateDM error: $e');
    }
    return null;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
