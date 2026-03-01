enum MessageDirection { outgoing, incoming }

enum MessageStatus { composing, sending, sent, delivered, failed }

class MessageModel {
  final String id; // uuid (local temp id for unsynced)
  final String leadId;
  final String phone; // E.164 when possible
  final String channel; // e.g., 'whatsapp'
  final MessageDirection direction;
  final String text;
  final MessageStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MessageModel({
    required this.id,
    required this.leadId,
    required this.phone,
    required this.channel,
    required this.direction,
    required this.text,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  MessageModel copyWith({
    String? id,
    String? leadId,
    String? phone,
    String? channel,
    MessageDirection? direction,
    String? text,
    MessageStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => MessageModel(
        id: id ?? this.id,
        leadId: leadId ?? this.leadId,
        phone: phone ?? this.phone,
        channel: channel ?? this.channel,
        direction: direction ?? this.direction,
        text: text ?? this.text,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'lead_id': leadId,
        'phone': phone,
        'channel': channel,
        'direction': direction.name,
        'text': text,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final dirRaw = (json['direction'] as String?)?.toLowerCase() ?? 'incoming';
    final stRaw = (json['status'] as String?)?.toLowerCase() ?? 'sent';
    MessageDirection dir;
    switch (dirRaw) {
      case 'out':
      case 'outgoing':
        dir = MessageDirection.outgoing;
        break;
      default:
        dir = MessageDirection.incoming;
    }
    MessageStatus st;
    switch (stRaw) {
      case 'composing':
        st = MessageStatus.composing; break;
      case 'sending':
        st = MessageStatus.sending; break;
      case 'delivered':
        st = MessageStatus.delivered; break;
      case 'failed':
        st = MessageStatus.failed; break;
      default:
        st = MessageStatus.sent;
    }
    return MessageModel(
      id: json['id']?.toString() ?? '',
      leadId: json['lead_id']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      channel: (json['channel']?.toString() ?? 'whatsapp').toLowerCase(),
      direction: dir,
      text: json['text']?.toString() ?? '',
      status: st,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
