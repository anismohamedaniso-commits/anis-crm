import 'package:flutter/foundation.dart';
import 'package:anis_crm/models/custom_field.dart';
import 'package:anis_crm/services/api_client.dart';

/// Manages custom lead fields.
class CustomFieldService {
  CustomFieldService._();
  static final instance = CustomFieldService._();

  final ValueNotifier<List<CustomField>> fields = ValueNotifier([]);

  // ── CRUD ────────────────────────────────────────────────────────────────
  Future<void> load() async {
    try {
      final res = await ApiClient.instance.getCustomFields();
      fields.value = (res as List).map((j) => CustomField.fromJson(j)).toList();
    } catch (_) {}
  }

  Future<CustomField?> create(Map<String, dynamic> data) async {
    try {
      final res = await ApiClient.instance.createCustomField(data);
      final cf = CustomField.fromJson(res as Map<String, dynamic>);
      fields.value = [...fields.value, cf];
      return cf;
    } catch (_) {
      return null;
    }
  }

  Future<bool> delete(String id) async {
    try {
      await ApiClient.instance.deleteCustomField(id);
      fields.value = fields.value.where((f) => f.id != id).toList();
      return true;
    } catch (_) {
      return false;
    }
  }
}
