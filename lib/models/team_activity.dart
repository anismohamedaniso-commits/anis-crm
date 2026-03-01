/// Represents a team-wide activity (e.g. "Anis assigned lead X to Sarah").
class TeamActivity {
  final String id;
  final String userId;
  final String userName;
  final String action; // e.g. 'created_lead', 'assigned_lead', 'created_task'
  final String targetType; // 'lead', 'task', 'note'
  final String targetId;
  final String targetName;
  final String detail;
  final DateTime ts;

  const TeamActivity({
    required this.id,
    required this.userId,
    required this.userName,
    required this.action,
    required this.targetType,
    this.targetId = '',
    this.targetName = '',
    this.detail = '',
    required this.ts,
  });

  factory TeamActivity.fromJson(Map<String, dynamic> j) => TeamActivity(
        id: j['id'] as String? ?? '',
        userId: j['user_id'] as String? ?? '',
        userName: j['user_name'] as String? ?? '',
        action: j['action'] as String? ?? '',
        targetType: j['target_type'] as String? ?? '',
        targetId: j['target_id'] as String? ?? '',
        targetName: j['target_name'] as String? ?? '',
        detail: j['detail'] as String? ?? '',
        ts: DateTime.tryParse(j['ts'] as String? ?? '') ?? DateTime.now(),
      );

  /// Human-readable description of the action
  String get description {
    switch (action) {
      case 'created_lead':
        return 'created lead "$targetName"';
      case 'assigned_lead':
        return 'assigned lead "$targetName"';
      case 'added_note':
        return 'added a note on "$targetName"';
      case 'created_task':
        return 'created task "$targetName"';
      case 'deleted_task':
        return 'deleted task "$targetName"';
      case 'moved_task_in_progress':
        return 'started working on "$targetName"';
      case 'moved_task_done':
        return 'completed task "$targetName"';
      case 'moved_task_todo':
        return 'moved "$targetName" back to To Do';
      default:
        return '$action "$targetName"';
    }
  }
}
