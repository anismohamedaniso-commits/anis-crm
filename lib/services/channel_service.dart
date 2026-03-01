import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:anis_crm/state/app_state.dart';
import 'package:anis_crm/supabase/supabase_config.dart';

/// Handles syncing channel connection status with Supabase edge function 'channels'.
class ChannelService {
  ChannelService._();
  static final ChannelService instance = ChannelService._();

  final _fn = SupabaseConfig.client.functions;

  /// Check if we have a valid authenticated user and a non-empty access token.
  /// Returns true only when both user and session token are present.
  bool _hasValidAuth() {
    try {
      final session = SupabaseConfig.auth.currentSession;
      final user = SupabaseConfig.auth.currentUser;
      final token = session?.accessToken;
      if (user == null || session == null) return false;
      if (token == null || token.isEmpty) return false;
      return true;
    } catch (e) {
      debugPrint('ChannelService._hasValidAuth error: $e');
      return false;
    }
  }

  /// Load channel connections from Supabase and hydrate AppState. No-op if not authenticated.
  Future<void> hydrateFromRemote(AppState appState) async {
    if (!_hasValidAuth()) {
      debugPrint('ChannelService: skipping hydration (not authenticated)');
      return;
    }
    try {
      final resp = await _fn.invoke('channels', method: HttpMethod.get);
      if (resp.data == null) return;
      final map = (resp.data is String) ? jsonDecode(resp.data as String) : resp.data as Map<String, dynamic>;
      final list = (map['channels'] as List?)?.cast<dynamic>() ?? const [];
      final byProvider = <String, dynamic>{};
      for (final item in list) {
        if (item is Map) {
          final p = (item['provider'] ?? '').toString().toLowerCase();
          byProvider[p] = item;
        }
      }
      // Map into AppState switches
      appState.setWhatsAppConnected((byProvider['whatsapp']?['connected'] ?? false) == true);
      appState.setInstagramConnected((byProvider['instagram']?['connected'] ?? false) == true);
      appState.setFacebookConnected((byProvider['facebook']?['connected'] ?? false) == true);
      appState.setWebFormsEnabled((byProvider['webforms']?['connected'] ?? false) == true);
      appState.setEmailChannelEnabled((byProvider['email']?['connected'] ?? false) == true);
      debugPrint('ChannelService: hydrated channel states from remote');
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('status: 401') || msg.contains('Invalid or expired token')) {
        debugPrint('ChannelService: unauthorized while hydrating, skipping.');
        return;
      }
      debugPrint('ChannelService.hydrateFromRemote error: $e');
    }
  }

  /// Persist a single provider connection state to Supabase 'channels' function.
  Future<void> setConnection(String provider, bool connected, {Map<String, dynamic>? details}) async {
    if (!_hasValidAuth()) {
      debugPrint('ChannelService.setConnection: not authenticated, skipping remote sync');
      return;
    }
    try {
      final body = {
        'provider': provider,
        'connected': connected,
        if (details != null) 'details': details,
      };
      await _fn.invoke('channels', body: body, method: HttpMethod.post);
      debugPrint('ChannelService: setConnection $provider -> $connected');
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('status: 401') || msg.contains('Invalid or expired token')) {
        debugPrint('ChannelService: unauthorized while setting connection, skipping.');
        return;
      }
      debugPrint('ChannelService.setConnection error: $e');
      rethrow;
    }
  }

  /// Fetch the current details blob for a given provider from Supabase.
  /// Returns null if unavailable or on error.
  Future<Map<String, dynamic>?> getProviderDetails(String provider) async {
    if (!_hasValidAuth()) {
      debugPrint('ChannelService.getProviderDetails: not authenticated');
      return null;
    }
    try {
      final resp = await _fn.invoke('channels', method: HttpMethod.get);
      if (resp.data == null) return null;
      final map = (resp.data is String) ? jsonDecode(resp.data as String) : resp.data as Map<String, dynamic>;
      final list = (map['channels'] as List?)?.cast<dynamic>() ?? const [];
      for (final item in list) {
        if (item is Map) {
          final p = (item['provider'] ?? '').toString().toLowerCase();
          if (p == provider.toLowerCase()) {
            final details = item['details'];
            if (details is Map<String, dynamic>) return details;
            if (details is Map) return Map<String, dynamic>.from(details);
            return null;
          }
        }
      }
      return null;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('status: 401') || msg.contains('Invalid or expired token')) {
        debugPrint('ChannelService: unauthorized while fetching provider details, skipping.');
        return null;
      }
      debugPrint('ChannelService.getProviderDetails error: $e');
      return null;
    }
  }
}
