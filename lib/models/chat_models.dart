/// Chat channel model (Direct message or group).
class ChatChannel {
  final String id;
  final String name;
  final String type; // 'direct', 'group', 'general'
  final List<String> memberIds;
  final List<String> memberNames;
  final String createdBy;
  final DateTime createdAt;
  // Populated from server
  final String lastMessage;
  final String lastMessageAt;
  final String lastMessageBy;
  final int messageCount;

  const ChatChannel({
    required this.id,
    required this.name,
    this.type = 'direct',
    this.memberIds = const [],
    this.memberNames = const [],
    this.createdBy = '',
    required this.createdAt,
    this.lastMessage = '',
    this.lastMessageAt = '',
    this.lastMessageBy = '',
    this.messageCount = 0,
  });

  factory ChatChannel.fromJson(Map<String, dynamic> j) => ChatChannel(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        type: j['type'] as String? ?? 'direct',
        memberIds: (j['member_ids'] as List?)?.cast<String>() ?? [],
        memberNames: (j['member_names'] as List?)?.cast<String>() ?? [],
        createdBy: j['created_by'] as String? ?? '',
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
        lastMessage: j['last_message'] as String? ?? '',
        lastMessageAt: j['last_message_at'] as String? ?? '',
        lastMessageBy: j['last_message_by'] as String? ?? '',
        messageCount: j['message_count'] as int? ?? 0,
      );

  /// Display name for DM channels
  String displayName(String currentUserId) {
    if (type == 'general') return 'General';
    if (type == 'direct' && memberNames.length == 2) {
      final idx = memberIds.indexOf(currentUserId);
      return memberNames[idx == 0 ? 1 : 0];
    }
    return name.isNotEmpty ? name : memberNames.join(', ');
  }
}

/// Chat message model.
class ChatMessage {
  final String id;
  final String channelId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime ts;

  const ChatMessage({
    required this.id,
    required this.channelId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.ts,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String? ?? '',
        channelId: j['channel_id'] as String? ?? '',
        senderId: j['sender_id'] as String? ?? '',
        senderName: j['sender_name'] as String? ?? '',
        text: j['text'] as String? ?? '',
        ts: DateTime.tryParse(j['ts'] as String? ?? '') ?? DateTime.now(),
      );

  bool isMe(String userId) => senderId == userId;
}
