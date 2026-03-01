import 'package:flutter/material.dart';
import 'package:anis_crm/theme.dart';
import 'package:anis_crm/models/automation_rule.dart';
import 'package:anis_crm/services/automation_service.dart';
import 'package:anis_crm/services/auth_service.dart';
import 'package:anis_crm/utils/snackbar_utils.dart';

/// Workflow Automation rules management page.
class AutomationPage extends StatefulWidget {
  const AutomationPage({super.key});
  @override
  State<AutomationPage> createState() => _AutomationPageState();
}

class _AutomationPageState extends State<AutomationPage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await AutomationService.instance.load();
    if (mounted) setState(() => _loading = false);
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    if (error) {
      AppSnackbar.error(context, msg);
    } else {
      AppSnackbar.success(context, msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Automation', style: context.textStyles.titleLarge?.semiBold),
        centerTitle: false,
        actions: [
          FilledButton.tonalIcon(
            onPressed: _showCreateDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Rule'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ValueListenableBuilder<List<AutomationRule>>(
              valueListenable: AutomationService.instance.rules,
              builder: (ctx, rules, _) {
                if (rules.isEmpty) {
                  return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.auto_fix_high, size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      Text('No automation rules yet', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('Create rules to automate lead routing, task creation, and notifications.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _showCreateDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Create First Rule'),
                      ),
                    ]),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: rules.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) => _RuleCard(
                    rule: rules[i],
                    onToggle: (v) => _toggle(rules[i], v),
                    onEdit: () => _showEditDialog(rules[i]),
                    onDelete: () => _delete(rules[i]),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _toggle(AutomationRule rule, bool enabled) async {
    final ok = await AutomationService.instance.toggleEnabled(rule.id, enabled);
    if (ok) setState(() {});
  }

  Future<void> _delete(AutomationRule rule) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Rule?'),
        content: Text('Are you sure you want to delete "${rule.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      final ok = await AutomationService.instance.delete(rule.id);
      if (ok) _snack('Rule deleted');
      setState(() {});
    }
  }

  // ── Create / Edit dialogs ─────────────────────────────────────────────
  void _showCreateDialog() => _showRuleDialog(null);
  void _showEditDialog(AutomationRule rule) => _showRuleDialog(rule);

  void _showRuleDialog(AutomationRule? existing) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    RuleTrigger trigger = existing?.trigger ?? RuleTrigger.leadCreated;
    RuleAction action = existing?.action ?? RuleAction.assignLead;
    String condSource = existing?.conditions['source'] ?? '';
    String condStatus = existing?.conditions['status'] ?? '';
    String paramAssignTo = existing?.actionParams['assign_to'] ?? '';
    String paramAssignToName = existing?.actionParams['assign_to_name'] ?? '';
    String paramStatus = existing?.actionParams['status'] ?? '';
    String paramTaskTitle = existing?.actionParams['task_title'] ?? '';
    String paramNotifMsg = existing?.actionParams['message'] ?? '';
    bool saving = false;

    // Load team members for assign
    List<CrmUser> team = [];
    try { team = await AuthService.instance.listUsers(); } catch (_) {}
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(existing == null ? 'New Automation Rule' : 'Edit Rule',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 20),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Rule Name *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                // Trigger
                DropdownButtonFormField<RuleTrigger>(
                  value: trigger,
                  decoration: const InputDecoration(labelText: 'When (Trigger)', border: OutlineInputBorder()),
                  items: RuleTrigger.values
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                      .toList(),
                  onChanged: (v) => ss(() => trigger = v ?? trigger),
                ),
                const SizedBox(height: 12),
                // Conditions
                Text('Conditions (optional)', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: condSource.isEmpty ? null : condSource,
                      decoration: const InputDecoration(labelText: 'Source', border: OutlineInputBorder()),
                      items: ['facebook', 'whatsapp', 'instagram', 'web', 'email', 'manual', 'imported']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => ss(() => condSource = v ?? ''),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: condStatus.isEmpty ? null : condStatus,
                      decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                      items: ['fresh', 'interested', 'noAnswer', 'followUp', 'notInterested', 'converted', 'closed']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => ss(() => condStatus = v ?? ''),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                // Action
                DropdownButtonFormField<RuleAction>(
                  value: action,
                  decoration: const InputDecoration(labelText: 'Then (Action)', border: OutlineInputBorder()),
                  items: RuleAction.values
                      .map((a) => DropdownMenuItem(value: a, child: Text(a.label)))
                      .toList(),
                  onChanged: (v) => ss(() => action = v ?? action),
                ),
                const SizedBox(height: 12),
                // Action params
                if (action == RuleAction.assignLead)
                  DropdownButtonFormField<CrmUser>(
                    value: team.where((u) => u.id == paramAssignTo).firstOrNull,
                    decoration: const InputDecoration(labelText: 'Assign To', border: OutlineInputBorder()),
                    items: team.map((u) => DropdownMenuItem(value: u, child: Text(u.name))).toList(),
                    onChanged: (v) => ss(() {
                      paramAssignTo = v?.id ?? '';
                      paramAssignToName = v?.name ?? '';
                    }),
                  ),
                if (action == RuleAction.changeStatus)
                  DropdownButtonFormField<String>(
                    value: paramStatus.isEmpty ? null : paramStatus,
                    decoration: const InputDecoration(labelText: 'New Status', border: OutlineInputBorder()),
                    items: ['fresh', 'interested', 'noAnswer', 'followUp', 'notInterested', 'converted', 'closed']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => ss(() => paramStatus = v ?? ''),
                  ),
                if (action == RuleAction.createTask)
                  TextField(
                    decoration: const InputDecoration(labelText: 'Task Title', border: OutlineInputBorder()),
                    onChanged: (v) => paramTaskTitle = v,
                    controller: TextEditingController(text: paramTaskTitle),
                  ),
                if (action == RuleAction.sendNotification)
                  TextField(
                    decoration: const InputDecoration(labelText: 'Notification Message', border: OutlineInputBorder()),
                    onChanged: (v) => paramNotifMsg = v,
                    controller: TextEditingController(text: paramNotifMsg),
                  ),
                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (nameCtrl.text.trim().isEmpty) return;
                            ss(() => saving = true);
                            final conditions = <String, String>{};
                            if (condSource.isNotEmpty) conditions['source'] = condSource;
                            if (condStatus.isNotEmpty) conditions['status'] = condStatus;

                            final actionParams = <String, String>{};
                            if (action == RuleAction.assignLead) {
                              actionParams['assign_to'] = paramAssignTo;
                              actionParams['assign_to_name'] = paramAssignToName;
                            }
                            if (action == RuleAction.changeStatus) actionParams['status'] = paramStatus;
                            if (action == RuleAction.createTask) actionParams['task_title'] = paramTaskTitle;
                            if (action == RuleAction.sendNotification) actionParams['message'] = paramNotifMsg;

                            final payload = {
                              'name': nameCtrl.text.trim(),
                              'trigger': trigger.name,
                              'action': action.name,
                              'conditions': conditions,
                              'action_params': actionParams,
                              'enabled': existing?.enabled ?? true,
                            };
                            bool ok;
                            if (existing != null) {
                              ok = await AutomationService.instance.update(existing.id, payload);
                            } else {
                              ok = (await AutomationService.instance.create(payload)) != null;
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (ok) {
                              _snack(existing == null ? 'Rule created' : 'Rule updated');
                              setState(() {});
                            } else {
                              _snack('Failed to save rule', error: true);
                            }
                          },
                    child: saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(existing == null ? 'Create' : 'Save'),
                  ),
                ]),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Rule Card
// ═════════════════════════════════════════════════════════════════════════════

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.rule, required this.onToggle, required this.onEdit, required this.onDelete});
  final AutomationRule rule;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dk = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(rule.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ),
            Switch.adaptive(
              value: rule.enabled,
              onChanged: onToggle,
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            _Chip(Icons.bolt, 'When: ${rule.trigger.label}', AppColors.info, dk),
            _Chip(Icons.play_arrow, 'Then: ${rule.action.label}', AppColors.success, dk),
            if (rule.conditions.isNotEmpty)
              _Chip(Icons.filter_alt, 'If: ${rule.conditions.entries.map((e) => '${e.key}=${e.value}').join(', ')}',
                  AppColors.warning, dk),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit'),
            ),
            TextButton.icon(
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline, size: 16, color: cs.error),
              label: Text('Delete', style: TextStyle(color: cs.error)),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.icon, this.text, this.color, this.dk);
  final IconData icon;
  final String text;
  final Color color;
  final bool dk;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dk ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
