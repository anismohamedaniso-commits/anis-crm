/// Task management model.
class TaskModel {
  final String id;
  final String title;
  final String description;
  final TaskStatus status;
  final TaskPriority priority;
  final String assignedTo;
  final String assignedToName;
  final String createdBy;
  final String createdByName;
  final String leadId;
  final String leadName;
  final String? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TaskModel({
    required this.id,
    required this.title,
    this.description = '',
    this.status = TaskStatus.todo,
    this.priority = TaskPriority.medium,
    this.assignedTo = '',
    this.assignedToName = '',
    this.createdBy = '',
    this.createdByName = '',
    this.leadId = '',
    this.leadName = '',
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskModel.fromJson(Map<String, dynamic> j) => TaskModel(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        description: j['description'] as String? ?? '',
        status: TaskStatusX.fromName(j['status'] as String?),
        priority: TaskPriorityX.fromName(j['priority'] as String?),
        assignedTo: j['assigned_to'] as String? ?? '',
        assignedToName: j['assigned_to_name'] as String? ?? '',
        createdBy: j['created_by'] as String? ?? '',
        createdByName: j['created_by_name'] as String? ?? '',
        leadId: j['lead_id'] as String? ?? '',
        leadName: j['lead_name'] as String? ?? '',
        dueDate: j['due_date'] as String?,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(j['updated_at'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'status': status.name,
        'priority': priority.name,
        'assigned_to': assignedTo,
        'assigned_to_name': assignedToName,
        'created_by': createdBy,
        'created_by_name': createdByName,
        'lead_id': leadId,
        'lead_name': leadName,
        'due_date': dueDate,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  TaskModel copyWith({
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    String? assignedTo,
    String? assignedToName,
    String? leadId,
    String? leadName,
    String? dueDate,
  }) =>
      TaskModel(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        status: status ?? this.status,
        priority: priority ?? this.priority,
        assignedTo: assignedTo ?? this.assignedTo,
        assignedToName: assignedToName ?? this.assignedToName,
        createdBy: createdBy,
        createdByName: createdByName,
        leadId: leadId ?? this.leadId,
        leadName: leadName ?? this.leadName,
        dueDate: dueDate ?? this.dueDate,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  bool get isOverdue {
    if (dueDate == null || dueDate!.isEmpty || status == TaskStatus.done) return false;
    final d = DateTime.tryParse(dueDate!);
    return d != null && d.isBefore(DateTime.now());
  }
}

enum TaskStatus { todo, inProgress, done }

enum TaskPriority { low, medium, high }

extension TaskStatusX on TaskStatus {
  static TaskStatus fromName(String? n) {
    switch (n) {
      case 'in_progress':
      case 'inProgress':
        return TaskStatus.inProgress;
      case 'done':
        return TaskStatus.done;
      default:
        return TaskStatus.todo;
    }
  }

  String get apiName {
    switch (this) {
      case TaskStatus.todo:
        return 'todo';
      case TaskStatus.inProgress:
        return 'in_progress';
      case TaskStatus.done:
        return 'done';
    }
  }

  String get label {
    switch (this) {
      case TaskStatus.todo:
        return 'To Do';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.done:
        return 'Done';
    }
  }
}

extension TaskPriorityX on TaskPriority {
  static TaskPriority fromName(String? n) {
    switch (n) {
      case 'high':
        return TaskPriority.high;
      case 'low':
        return TaskPriority.low;
      default:
        return TaskPriority.medium;
    }
  }

  String get label {
    switch (this) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
    }
  }
}
