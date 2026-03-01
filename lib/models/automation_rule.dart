/// Workflow automation rule model.
///
/// Defines trigger → condition → action rules that fire automatically
/// when leads change status, are created, or become inactive.
class AutomationRule {
  final String id;
  final String name;
  final bool enabled;
  final RuleTrigger trigger;
  final Map<String, String> conditions; // e.g. {'source': 'facebook', 'status': 'fresh'}
  final RuleAction action;
  final Map<String, String> actionParams; // e.g. {'assign_to': 'user-id', 'status': 'followUp'}
  final DateTime createdAt;
  final DateTime updatedAt;

  const AutomationRule({
    required this.id,
    required this.name,
    this.enabled = true,
    required this.trigger,
    this.conditions = const {},
    required this.action,
    this.actionParams = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory AutomationRule.fromJson(Map<String, dynamic> j) => AutomationRule(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        enabled: j['enabled'] as bool? ?? true,
        trigger: RuleTriggerX.fromName(j['trigger'] as String?),
        conditions: (j['conditions'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v.toString())) ??
            {},
        action: RuleActionX.fromName(j['action'] as String?),
        actionParams: (j['action_params'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v.toString())) ??
            {},
        createdAt:
            DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
        updatedAt:
            DateTime.tryParse(j['updated_at'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'trigger': trigger.name,
        'conditions': conditions,
        'action': action.name,
        'action_params': actionParams,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  AutomationRule copyWith({
    String? name,
    bool? enabled,
    RuleTrigger? trigger,
    Map<String, String>? conditions,
    RuleAction? action,
    Map<String, String>? actionParams,
  }) =>
      AutomationRule(
        id: id,
        name: name ?? this.name,
        enabled: enabled ?? this.enabled,
        trigger: trigger ?? this.trigger,
        conditions: conditions ?? this.conditions,
        action: action ?? this.action,
        actionParams: actionParams ?? this.actionParams,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}

/// When this rule fires.
enum RuleTrigger {
  leadCreated,
  leadStatusChanged,
  leadInactive, // no activity for N days
  dealStageChanged,
}

/// What the rule does.
enum RuleAction {
  assignLead,
  changeStatus,
  createTask,
  sendNotification,
}

extension RuleTriggerX on RuleTrigger {
  static RuleTrigger fromName(String? n) {
    switch (n) {
      case 'leadCreated':
        return RuleTrigger.leadCreated;
      case 'leadStatusChanged':
        return RuleTrigger.leadStatusChanged;
      case 'leadInactive':
        return RuleTrigger.leadInactive;
      case 'dealStageChanged':
        return RuleTrigger.dealStageChanged;
      default:
        return RuleTrigger.leadCreated;
    }
  }

  String get label {
    switch (this) {
      case RuleTrigger.leadCreated:
        return 'Lead Created';
      case RuleTrigger.leadStatusChanged:
        return 'Lead Status Changed';
      case RuleTrigger.leadInactive:
        return 'Lead Inactive';
      case RuleTrigger.dealStageChanged:
        return 'Deal Stage Changed';
    }
  }
}

extension RuleActionX on RuleAction {
  static RuleAction fromName(String? n) {
    switch (n) {
      case 'assignLead':
        return RuleAction.assignLead;
      case 'changeStatus':
        return RuleAction.changeStatus;
      case 'createTask':
        return RuleAction.createTask;
      case 'sendNotification':
        return RuleAction.sendNotification;
      default:
        return RuleAction.assignLead;
    }
  }

  String get label {
    switch (this) {
      case RuleAction.assignLead:
        return 'Assign Lead';
      case RuleAction.changeStatus:
        return 'Change Status';
      case RuleAction.createTask:
        return 'Create Follow-Up Task';
      case RuleAction.sendNotification:
        return 'Send Notification';
    }
  }
}
