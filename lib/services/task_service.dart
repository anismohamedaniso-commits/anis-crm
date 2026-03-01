import 'package:flutter/foundation.dart';
import 'package:anis_crm/models/task_model.dart';
import 'package:anis_crm/services/api_client.dart';

/// Service for task management.
class TaskService {
  TaskService._();
  static final TaskService instance = TaskService._();

  final ValueNotifier<List<TaskModel>> tasks = ValueNotifier([]);
  bool _loading = false;
  bool get isLoading => _loading;

  Future<void> load({String? assignedTo, String? status}) async {
    _loading = true;
    try {
      final data = await ApiClient.instance.getTasks(
        assignedTo: assignedTo,
        status: status,
      );
      if (data != null) {
        tasks.value = data.map((j) => TaskModel.fromJson(j)).toList();
      }
    } catch (e) {
      debugPrint('TaskService.load error: $e');
    }
    _loading = false;
  }

  Future<TaskModel?> create({
    required String title,
    String description = '',
    String priority = 'medium',
    String assignedTo = '',
    String assignedToName = '',
    String leadId = '',
    String leadName = '',
    String? dueDate,
  }) async {
    try {
      final result = await ApiClient.instance.createTask({
        'title': title,
        'description': description,
        'priority': priority,
        'assigned_to': assignedTo,
        'assigned_to_name': assignedToName,
        'lead_id': leadId,
        'lead_name': leadName,
        'due_date': dueDate ?? '',
      });
      if (result != null) {
        final task = TaskModel.fromJson(result);
        tasks.value = [task, ...tasks.value];
        return task;
      }
    } catch (e) {
      debugPrint('TaskService.create error: $e');
    }
    return null;
  }

  Future<bool> updateStatus(String taskId, TaskStatus status) async {
    final ok = await ApiClient.instance.updateTask(taskId, {
      'status': status.apiName,
    });
    if (ok) {
      tasks.value = tasks.value.map((t) {
        if (t.id == taskId) return t.copyWith(status: status);
        return t;
      }).toList();
    }
    return ok;
  }

  Future<bool> update(String taskId, Map<String, dynamic> fields) async {
    final ok = await ApiClient.instance.updateTask(taskId, fields);
    if (ok) await load();
    return ok;
  }

  Future<bool> delete(String taskId) async {
    final ok = await ApiClient.instance.deleteTask(taskId);
    if (ok) {
      tasks.value = tasks.value.where((t) => t.id != taskId).toList();
    }
    return ok;
  }

  Future<void> refresh() => load();
}
