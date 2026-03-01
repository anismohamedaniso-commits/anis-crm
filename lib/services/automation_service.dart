import 'package:flutter/foundation.dart';
import 'package:anis_crm/models/automation_rule.dart';
import 'package:anis_crm/services/api_client.dart';

/// Service for workflow automation rules.
class AutomationService {
  AutomationService._();
  static final AutomationService instance = AutomationService._();

  final ValueNotifier<List<AutomationRule>> rules = ValueNotifier([]);

  Future<void> load() async {
    try {
      final data = await ApiClient.instance.getAutomationRules();
      if (data != null) {
        rules.value = data.map((j) => AutomationRule.fromJson(j)).toList();
      }
    } catch (e) {
      debugPrint('AutomationService.load error: $e');
    }
  }

  Future<AutomationRule?> create(Map<String, dynamic> payload) async {
    try {
      final result = await ApiClient.instance.createAutomationRule(payload);
      if (result != null) {
        final rule = AutomationRule.fromJson(result);
        rules.value = [rule, ...rules.value];
        return rule;
      }
    } catch (e) {
      debugPrint('AutomationService.create error: $e');
    }
    return null;
  }

  Future<bool> update(String ruleId, Map<String, dynamic> fields) async {
    final ok = await ApiClient.instance.updateAutomationRule(ruleId, fields);
    if (ok) await load();
    return ok;
  }

  Future<bool> toggleEnabled(String ruleId, bool enabled) async {
    return update(ruleId, {'enabled': enabled});
  }

  Future<bool> delete(String ruleId) async {
    final ok = await ApiClient.instance.deleteAutomationRule(ruleId);
    if (ok) {
      rules.value = rules.value.where((r) => r.id != ruleId).toList();
    }
    return ok;
  }

  /// Trigger rules evaluation server-side (e.g. after lead status change).
  Future<void> evaluate(String trigger, Map<String, dynamic> context) async {
    try {
      await ApiClient.instance.evaluateAutomation(trigger, context);
    } catch (e) {
      debugPrint('AutomationService.evaluate error: $e');
    }
  }
}
