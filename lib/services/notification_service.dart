import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:anis_crm/models/notification_model.dart';
import 'package:anis_crm/services/api_client.dart';

/// Service for user notifications with polling.
class NotificationService extends ChangeNotifier {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  List<NotificationModel> _notifications = [];
  List<NotificationModel> get notifications => _notifications;

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  Timer? _pollTimer;

  /// Start polling for notifications every 15 seconds.
  void startPolling() {
    _pollTimer?.cancel();
    load(); // initial load
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => load());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> load() async {
    try {
      final data = await ApiClient.instance.getNotifications();
      if (data != null) {
        final list = (data['notifications'] as List)
            .cast<Map<String, dynamic>>()
            .map((j) => NotificationModel.fromJson(j))
            .toList();
        _notifications = list;
        _unreadCount = data['unread_count'] as int? ?? 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('NotificationService.load error: $e');
    }
  }

  Future<void> markRead(String id) async {
    // Optimistic update
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      _notifications[idx] = _notifications[idx].copyWith(read: true);
      _unreadCount = _notifications.where((n) => !n.read).length;
      notifyListeners();
    }
    await ApiClient.instance.markNotificationRead(id);
  }

  Future<void> markAllRead() async {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(read: true);
    }
    _unreadCount = 0;
    notifyListeners();
    await ApiClient.instance.markAllNotificationsRead();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
