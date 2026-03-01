/// Model for user-defined custom fields on leads.
class CustomField {
  final String id;
  final String name;
  final CustomFieldType fieldType;
  final List<String> options; // only for 'select' type
  final bool required;
  final DateTime? createdAt;

  const CustomField({
    required this.id,
    required this.name,
    required this.fieldType,
    this.options = const [],
    this.required = false,
    this.createdAt,
  });

  factory CustomField.fromJson(Map<String, dynamic> j) => CustomField(
        id: j['id']?.toString() ?? '',
        name: j['name'] ?? '',
        fieldType: CustomFieldTypeX.fromName(j['field_type'] ?? 'text'),
        options: (j['options'] as List?)?.map((e) => e.toString()).toList() ?? [],
        required: j['required'] == true,
        createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at']) : null,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'field_type': fieldType.name,
        'options': options,
        'required': required,
      };
}

enum CustomFieldType { text, number, date, select }

extension CustomFieldTypeX on CustomFieldType {
  static CustomFieldType fromName(String n) =>
      CustomFieldType.values.firstWhere((e) => e.name == n, orElse: () => CustomFieldType.text);

  String get label => switch (this) {
        CustomFieldType.text => 'Text',
        CustomFieldType.number => 'Number',
        CustomFieldType.date => 'Date',
        CustomFieldType.select => 'Select',
      };
}
