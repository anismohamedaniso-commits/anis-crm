import 'package:flutter/material.dart';
import 'package:anis_crm/theme.dart';
import 'package:anis_crm/models/custom_field.dart';
import 'package:anis_crm/services/custom_field_service.dart';
import 'package:anis_crm/utils/snackbar_utils.dart';

/// Settings page for managing custom lead fields.
class CustomFieldsPage extends StatefulWidget {
  const CustomFieldsPage({super.key});
  @override
  State<CustomFieldsPage> createState() => _CustomFieldsPageState();
}

class _CustomFieldsPageState extends State<CustomFieldsPage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await CustomFieldService.instance.load();
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
        title: Text('Custom Fields', style: context.textStyles.titleLarge?.semiBold),
        centerTitle: false,
        actions: [
          FilledButton.tonalIcon(
            onPressed: _showCreateDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Field'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ValueListenableBuilder<List<CustomField>>(
              valueListenable: CustomFieldService.instance.fields,
              builder: (ctx, fields, _) {
                if (fields.isEmpty) {
                  return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.tune, size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      Text('No custom fields defined', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('Add custom fields to capture extra information on every lead.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _showCreateDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add First Field'),
                      ),
                    ]),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: fields.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) => _FieldCard(
                    field: fields[i],
                    onDelete: () => _deleteField(fields[i]),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _deleteField(CustomField field) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Field?'),
        content: Text('Remove "${field.name}" from all leads?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      final ok = await CustomFieldService.instance.delete(field.id);
      if (ok) _snack('Field deleted');
      setState(() {});
    }
  }

  // ── Create dialog ─────────────────────────────────────────────────────
  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    CustomFieldType type = CustomFieldType.text;
    bool required = false;
    final optionsCtrl = TextEditingController();
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Add Custom Field', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 20),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Field Name *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<CustomFieldType>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                  items: CustomFieldType.values
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                      .toList(),
                  onChanged: (v) => ss(() => type = v ?? type),
                ),
                if (type == CustomFieldType.select) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: optionsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Options (comma-separated)',
                      border: OutlineInputBorder(),
                      hintText: 'e.g. Option A, Option B, Option C',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Required'),
                  value: required,
                  onChanged: (v) => ss(() => required = v),
                ),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (nameCtrl.text.trim().isEmpty) return;
                            ss(() => saving = true);
                            final options = type == CustomFieldType.select
                                ? optionsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
                                : <String>[];
                            final result = await CustomFieldService.instance.create({
                              'name': nameCtrl.text.trim(),
                              'field_type': type.name,
                              'options': options,
                              'required': required,
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (result != null) {
                              _snack('Field added');
                              setState(() {});
                            } else {
                              _snack('Failed to create field', error: true);
                            }
                          },
                    child: saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Create'),
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
class _FieldCard extends StatelessWidget {
  const _FieldCard({required this.field, required this.onDelete});
  final CustomField field;
  final VoidCallback onDelete;

  IconData get _typeIcon => switch (field.fieldType) {
        CustomFieldType.text => Icons.text_fields,
        CustomFieldType.number => Icons.tag,
        CustomFieldType.date => Icons.calendar_today,
        CustomFieldType.select => Icons.list,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Icon(_typeIcon, color: cs.primary, size: 20),
        ),
        title: Text(field.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${field.fieldType.label}${field.required ? '  •  Required' : ''}'
          '${field.options.isNotEmpty ? '  •  ${field.options.join(", ")}' : ''}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: cs.error),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
