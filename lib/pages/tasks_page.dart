import 'package:flutter/material.dart';
import 'package:anis_crm/theme.dart';
import 'package:anis_crm/models/task_model.dart';
import 'package:anis_crm/services/task_service.dart';
import 'package:anis_crm/services/auth_service.dart';
import 'package:anis_crm/utils/snackbar_utils.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});
  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  bool _loading = true;
  String _filterStatus = 'all'; // all, todo, in_progress, done
  String _filterAssignee = 'all'; // all, mine

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await TaskService.instance.load();
    if (mounted) setState(() => _loading = false);
  }

  List<TaskModel> get _filtered {
    final me = AuthService.instance.user;
    var list = TaskService.instance.tasks.value;
    if (_filterStatus != 'all') {
      list = list.where((t) => t.status.apiName == _filterStatus).toList();
    }
    if (_filterAssignee == 'mine' && me != null) {
      list = list.where((t) => t.assignedTo == me.id).toList();
    }
    return list;
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    if (error) {
      AppSnackbar.error(context, msg);
    } else {
      AppSnackbar.success(context, msg);
    }
  }

  void _showCreateDialog() async {
    // Load team members for assignment
    List<CrmUser> teamMembers = [];
    try { teamMembers = await AuthService.instance.listUsers(); } catch (_) {}

    if (!mounted) return;

    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String priority = 'medium';
    CrmUser? selectedAssignee;
    String? dueDate;
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) {
          final cs = Theme.of(context).colorScheme;
          final dk = Theme.of(context).brightness == Brightness.dark;
          final tt = Theme.of(context).textTheme;
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Header
                  Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.add_task, color: cs.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Text('New Task', style: tt.titleLarge?.semiBold),
                  ]),
                  const SizedBox(height: 24),
                  // Title
                  TextField(
                    controller: titleCtrl,
                    style: tt.bodyMedium,
                    decoration: InputDecoration(
                      labelText: 'Task title',
                      prefixIcon: Icon(Icons.title, size: 20, color: cs.onSurface.withValues(alpha: 0.35)),
                      filled: true,
                      fillColor: dk ? cs.surface.withValues(alpha: 0.3) : cs.surfaceContainerLow,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Description
                  TextField(
                    controller: descCtrl,
                    style: tt.bodyMedium,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Description (optional)',
                      prefixIcon: Icon(Icons.notes, size: 20, color: cs.onSurface.withValues(alpha: 0.35)),
                      filled: true,
                      fillColor: dk ? cs.surface.withValues(alpha: 0.3) : cs.surfaceContainerLow,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Priority
                  Text('Priority', style: tt.labelSmall?.withColor(cs.onSurface.withValues(alpha: 0.5))),
                  const SizedBox(height: 8),
                  Row(children: [
                    _PriorityChip(label: 'Low', value: 'low', selected: priority == 'low',
                        color: Colors.grey, cs: cs, onTap: () => ss(() => priority = 'low')),
                    const SizedBox(width: 8),
                    _PriorityChip(label: 'Medium', value: 'medium', selected: priority == 'medium',
                        color: Colors.orange, cs: cs, onTap: () => ss(() => priority = 'medium')),
                    const SizedBox(width: 8),
                    _PriorityChip(label: 'High', value: 'high', selected: priority == 'high',
                        color: cs.error, cs: cs, onTap: () => ss(() => priority = 'high')),
                  ]),
                  const SizedBox(height: 18),
                  // Assignee picker
                  Text('Assign to', style: tt.labelSmall?.withColor(cs.onSurface.withValues(alpha: 0.5))),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: dk ? cs.surface.withValues(alpha: 0.3) : cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonFormField<CrmUser>(
                      value: selectedAssignee,
                      isExpanded: true,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.person_add_outlined, size: 20, color: cs.onSurface.withValues(alpha: 0.35)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        hintText: 'Unassigned',
                        hintStyle: tt.bodyMedium?.withColor(cs.onSurface.withValues(alpha: 0.4)),
                      ),
                      items: [
                        DropdownMenuItem<CrmUser>(value: null, child: Text('Unassigned', style: tt.bodyMedium?.withColor(cs.onSurface.withValues(alpha: 0.5)))),
                        ...teamMembers.map((u) => DropdownMenuItem(
                          value: u,
                          child: Row(children: [
                            CircleAvatar(radius: 12, backgroundColor: cs.primary.withValues(alpha: 0.1),
                              child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                                style: tt.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w600))),
                            const SizedBox(width: 10),
                            Text(u.name, style: tt.bodyMedium),
                          ]),
                        )),
                      ],
                      onChanged: (v) => ss(() => selectedAssignee = v),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Due date
                  GestureDetector(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (d != null) ss(() => dueDate = d.toIso8601String().split('T')[0]);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: dk ? cs.surface.withValues(alpha: 0.3) : cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        Icon(Icons.calendar_today_outlined, size: 20, color: cs.onSurface.withValues(alpha: 0.35)),
                        const SizedBox(width: 12),
                        Text(
                          dueDate ?? 'Set due date (optional)',
                          style: tt.bodyMedium?.withColor(dueDate != null ? cs.onSurface : cs.onSurface.withValues(alpha: 0.4)),
                        ),
                        if (dueDate != null) ...[
                          const Spacer(),
                          GestureDetector(
                            onTap: () => ss(() => dueDate = null),
                            child: Icon(Icons.close, size: 16, color: cs.onSurface.withValues(alpha: 0.35)),
                          ),
                        ],
                      ]),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Actions
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: saving ? null : () async {
                        if (titleCtrl.text.trim().isEmpty) {
                          _snack('Title is required', error: true);
                          return;
                        }
                        ss(() => saving = true);
                        final task = await TaskService.instance.create(
                          title: titleCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          priority: priority,
                          assignedTo: selectedAssignee?.id ?? '',
                          assignedToName: selectedAssignee?.name ?? '',
                          dueDate: dueDate,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (task != null) {
                          _snack('Task created');
                        } else {
                          _snack('Failed to create task', error: true);
                        }
                      },
                      icon: saving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.add, size: 18),
                      label: Text(saving ? 'Creating...' : 'Create Task'),
                    ),
                  ]),
                ])),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dk = Theme.of(context).brightness == Brightness.dark;
    final wide = MediaQuery.of(context).size.width >= 760;
    final tt = Theme.of(context).textTheme;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header
      Padding(
        padding: EdgeInsets.symmetric(horizontal: wide ? 8 : 4),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Tasks', style: tt.headlineSmall?.semiBold),
              const SizedBox(height: 4),
              Text('Manage and track team tasks',
                  style: tt.bodySmall?.withColor(cs.onSurface.withValues(alpha: 0.5))),
            ]),
          ),
          FilledButton.icon(
            onPressed: _showCreateDialog,
            icon: const Icon(Icons.add, size: 18),
            label: Text(wide ? 'New Task' : 'New'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 16),

      // Stats row
      Padding(
        padding: EdgeInsets.symmetric(horizontal: wide ? 8 : 4),
        child: ValueListenableBuilder<List<TaskModel>>(
          valueListenable: TaskService.instance.tasks,
          builder: (_, tasks, __) {
            final todo = tasks.where((t) => t.status == TaskStatus.todo).length;
            final inProg = tasks.where((t) => t.status == TaskStatus.inProgress).length;
            final done = tasks.where((t) => t.status == TaskStatus.done).length;
            final overdue = tasks.where((t) => t.isOverdue).length;
            return Row(children: [
              _StatChip(label: 'To Do', count: todo, color: cs.onSurface.withValues(alpha: 0.6), cs: cs, dk: dk),
              const SizedBox(width: 8),
              _StatChip(label: 'In Progress', count: inProg, color: Colors.orange, cs: cs, dk: dk),
              const SizedBox(width: 8),
              _StatChip(label: 'Done', count: done, color: const Color(0xFF2E7D32), cs: cs, dk: dk),
              if (overdue > 0) ...[
                const SizedBox(width: 8),
                _StatChip(label: 'Overdue', count: overdue, color: cs.error, cs: cs, dk: dk),
              ],
            ]);
          },
        ),
      ),
      const SizedBox(height: 12),

      // Filters (scrollable for mobile)
      Padding(
        padding: EdgeInsets.symmetric(horizontal: wide ? 8 : 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _FilterBtn(label: 'All', selected: _filterStatus == 'all', onTap: () => setState(() => _filterStatus = 'all'), cs: cs),
            const SizedBox(width: 6),
            _FilterBtn(label: 'To Do', selected: _filterStatus == 'todo', onTap: () => setState(() => _filterStatus = 'todo'), cs: cs),
            const SizedBox(width: 6),
            _FilterBtn(label: 'In Progress', selected: _filterStatus == 'in_progress', onTap: () => setState(() => _filterStatus = 'in_progress'), cs: cs),
            const SizedBox(width: 6),
            _FilterBtn(label: 'Done', selected: _filterStatus == 'done', onTap: () => setState(() => _filterStatus = 'done'), cs: cs),
            const SizedBox(width: 12),
            _FilterBtn(
              label: _filterAssignee == 'mine' ? 'My Tasks' : 'All Tasks',
              selected: _filterAssignee == 'mine',
              onTap: () => setState(() => _filterAssignee = _filterAssignee == 'all' ? 'mine' : 'all'),
              cs: cs,
              icon: Icons.person_outlined,
            ),
          ]),
        ),
      ),
      const SizedBox(height: 16),

      // Task list
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ValueListenableBuilder<List<TaskModel>>(
                valueListenable: TaskService.instance.tasks,
                builder: (_, __, ___) {
                  final tasks = _filtered;
                  if (tasks.isEmpty) {
                    return Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.task_outlined, size: 48, color: cs.onSurface.withValues(alpha: 0.15)),
                        const SizedBox(height: 16),
                        Text('No tasks found', style: tt.titleMedium?.semiBold),
                        const SizedBox(height: 6),
                        Text('Create your first task to get started',
                            style: tt.bodySmall?.withColor(cs.onSurface.withValues(alpha: 0.45))),
                      ]),
                    );
                  }
                  return ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: wide ? 8 : 4),
                    itemCount: tasks.length,
                    itemBuilder: (_, i) => _TaskCard(
                      task: tasks[i],
                      cs: cs,
                      dk: dk,
                      onStatusChange: (s) async {
                        await TaskService.instance.updateStatus(tasks[i].id, s);
                        _snack('Task moved to ${s.label}');
                      },
                      onDelete: () async {
                        await TaskService.instance.delete(tasks[i].id);
                        _snack('Task deleted');
                      },
                    ),
                  );
                },
              ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TASK CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _TaskCard extends StatefulWidget {
  final TaskModel task;
  final ColorScheme cs;
  final bool dk;
  final Function(TaskStatus) onStatusChange;
  final VoidCallback onDelete;
  const _TaskCard({required this.task, required this.cs, required this.dk,
      required this.onStatusChange, required this.onDelete});
  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final cs = widget.cs;
    final dk = widget.dk;
    final priorityColor = t.priority == TaskPriority.high
        ? cs.error
        : t.priority == TaskPriority.medium
            ? Colors.orange
            : Colors.grey;
    final statusColor = t.status == TaskStatus.done
        ? const Color(0xFF2E7D32)
        : t.status == TaskStatus.inProgress
            ? Colors.orange
            : cs.onSurface.withValues(alpha: 0.5);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: _hovered
              ? (dk ? cs.surface.withValues(alpha: 0.8) : cs.surface)
              : (dk ? cs.surface.withValues(alpha: 0.5) : cs.surface.withValues(alpha: 0.8)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: t.isOverdue
                ? cs.error.withValues(alpha: 0.3)
                : _hovered
                    ? cs.primary.withValues(alpha: 0.15)
                    : cs.outline.withValues(alpha: dk ? 0.08 : 0.05)),
        ),
        child: Row(children: [
          // Status checkbox
          GestureDetector(
            onTap: () {
              final next = t.status == TaskStatus.todo
                  ? TaskStatus.inProgress
                  : t.status == TaskStatus.inProgress
                      ? TaskStatus.done
                      : TaskStatus.todo;
              widget.onStatusChange(next);
            },
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1.5),
              ),
              child: t.status == TaskStatus.done
                  ? Icon(Icons.check, size: 16, color: statusColor)
                  : t.status == TaskStatus.inProgress
                      ? Icon(Icons.play_arrow, size: 14, color: statusColor)
                      : null,
            ),
          ),
          const SizedBox(width: 14),

          // Content
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: t.status == TaskStatus.done ? TextDecoration.lineThrough : null,
                  )),
              if (t.description.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(t.description,
                    style: Theme.of(context).textTheme.bodySmall?.withColor(cs.onSurface.withValues(alpha: 0.45)),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 4, children: [
                // Priority
                _TagChip(
                  icon: Icons.flag_outlined,
                  label: t.priority.label,
                  color: priorityColor,
                  cs: cs,
                ),
                // Due date
                if (t.dueDate != null && t.dueDate!.isNotEmpty)
                  _TagChip(
                    icon: Icons.schedule,
                    label: t.dueDate!,
                    color: t.isOverdue ? cs.error : cs.onSurface.withValues(alpha: 0.5),
                    cs: cs,
                  ),
                // Assignee
                if (t.assignedToName.isNotEmpty)
                  _TagChip(
                    icon: Icons.person_outlined,
                    label: t.assignedToName,
                    color: cs.primary,
                    cs: cs,
                  ),
                // Lead link
                if (t.leadName.isNotEmpty)
                  _TagChip(
                    icon: Icons.link,
                    label: t.leadName,
                    color: cs.tertiary,
                    cs: cs,
                  ),
                // Created by
                _TagChip(
                  icon: Icons.edit_outlined,
                  label: t.createdByName,
                  color: cs.onSurface.withValues(alpha: 0.4),
                  cs: cs,
                ),
              ]),
            ]),
          ),

          // Actions
          AnimatedOpacity(
            opacity: _hovered ? 1 : 0.3,
            duration: const Duration(milliseconds: 200),
            child: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 20, color: cs.onSurface.withValues(alpha: 0.5)),
              onSelected: (v) {
                if (v == 'delete') widget.onDelete();
                if (v == 'todo') widget.onStatusChange(TaskStatus.todo);
                if (v == 'in_progress') widget.onStatusChange(TaskStatus.inProgress);
                if (v == 'done') widget.onStatusChange(TaskStatus.done);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'todo', child: Text('Move to To Do')),
                const PopupMenuItem(value: 'in_progress', child: Text('Move to In Progress')),
                const PopupMenuItem(value: 'done', child: Text('Move to Done')),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: cs.error)),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final ColorScheme cs;
  const _TagChip({required this.icon, required this.label, required this.color, required this.cs});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10, fontWeight: FontWeight.w500, color: color)),
        ]),
      );
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final ColorScheme cs;
  final bool dk;
  const _StatChip({required this.label, required this.count, required this.color, required this.cs, required this.dk});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: dk ? cs.surface.withValues(alpha: 0.6) : cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withValues(alpha: dk ? 0.1 : 0.06)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$count', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: color)),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.withColor(cs.onSurface.withValues(alpha: 0.45))),
        ]),
      );
}

class _FilterBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;
  final IconData? icon;
  const _FilterBtn({required this.label, required this.selected, required this.onTap, required this.cs, this.icon});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? cs.primary.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? cs.primary.withValues(alpha: 0.3) : cs.outline.withValues(alpha: 0.15)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.5),
                )),
          ]),
        ),
      );
}

class _PriorityChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final Color color;
  final ColorScheme cs;
  final VoidCallback onTap;
  const _PriorityChip({required this.label, required this.value, required this.selected,
      required this.color, required this.cs, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? color.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? color.withValues(alpha: 0.4) : cs.outline.withValues(alpha: 0.15),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.flag_outlined, size: 16, color: selected ? color : cs.onSurface.withValues(alpha: 0.35)),
              const SizedBox(width: 6),
              Text(label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? color : cs.onSurface.withValues(alpha: 0.5),
                  )),
            ]),
          ),
        ),
      );
}
