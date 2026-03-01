import 'dart:convert';

/// ScriptModel represents a ready-to-read call script.
/// Includes metadata and timestamps. Persisted via ScriptService.
class ScriptModel {
  final String id;
  final String title;
  final String body;
  final String? category;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ScriptModel({
    required this.id,
    required this.title,
    required this.body,
    this.category,
    required this.createdAt,
    required this.updatedAt,
  });

  ScriptModel copyWith({
    String? id,
    String? title,
    String? body,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ScriptModel(
        id: id ?? this.id,
        title: title ?? this.title,
        body: body ?? this.body,
        category: category ?? this.category,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'category': category,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  static ScriptModel fromJson(Map<String, dynamic> json) => ScriptModel(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Untitled',
        body: json['body'] as String? ?? '',
        category: json['category'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      );

  static List<ScriptModel> decodeList(String raw) {
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list.map((e) => ScriptModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  static String encodeList(List<ScriptModel> list) => json.encode(list.map((e) => e.toJson()).toList());
}
