enum ActivityType { call, message, note, followup }

class ActivityModel {
  final String id;
  final String leadId;
  final ActivityType type;
  final String? text;
  final DateTime createdAt;

  const ActivityModel({
    required this.id,
    required this.leadId,
    required this.type,
    this.text,
    required this.createdAt,
  });

  ActivityModel copyWith({
    String? id,
    String? leadId,
    ActivityType? type,
    String? text,
    DateTime? createdAt,
  }) => ActivityModel(
        id: id ?? this.id,
        leadId: leadId ?? this.leadId,
        type: type ?? this.type,
        text: text ?? this.text,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'lead_id': leadId,
        'type': type.name,
        'text': text,
        'created_at': createdAt.toIso8601String(),
      };

  factory ActivityModel.fromJson(Map<String, dynamic> json) => ActivityModel(
        id: json['id'] as String,
        leadId: json['lead_id'] as String,
        type: ActivityType.values.firstWhere(
          (e) => e.name == (json['type'] as String? ?? 'note'),
          orElse: () => ActivityType.note,
        ),
        text: json['text'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}
