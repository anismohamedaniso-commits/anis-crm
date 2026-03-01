/// In-app notification model.
class NotificationModel {
  final String id;
  final String userId;
  final String type; // lead_assigned, task_assigned, chat_message, etc.
  final String title;
  final String body;
  final String actionUrl;
  final String fromUserId;
  final String fromUserName;
  final bool read;
  final DateTime ts;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    this.body = '',
    this.actionUrl = '',
    this.fromUserId = '',
    this.fromUserName = '',
    this.read = false,
    required this.ts,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> j) => NotificationModel(
        id: j['id'] as String? ?? '',
        userId: j['user_id'] as String? ?? '',
        type: j['type'] as String? ?? '',
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        actionUrl: j['action_url'] as String? ?? '',
        fromUserId: j['from_user_id'] as String? ?? '',
        fromUserName: j['from_user_name'] as String? ?? '',
        read: j['read'] as bool? ?? false,
        ts: DateTime.tryParse(j['ts'] as String? ?? '') ?? DateTime.now(),
      );

  NotificationModel copyWith({bool? read}) => NotificationModel(
        id: id,
        userId: userId,
        type: type,
        title: title,
        body: body,
        actionUrl: actionUrl,
        fromUserId: fromUserId,
        fromUserName: fromUserName,
        read: read ?? this.read,
        ts: ts,
      );
}
