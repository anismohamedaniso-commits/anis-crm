import 'package:anis_crm/models/script.dart';
import 'package:anis_crm/services/script_service.dart';
import 'package:anis_crm/theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom sheet for managing and reading call scripts.
class CallScriptsSheet extends StatefulWidget {
  const CallScriptsSheet({super.key});

  @override
  State<CallScriptsSheet> createState() => _CallScriptsSheetState();
}

class _CallScriptsSheetState extends State<CallScriptsSheet> {
  @override
  void initState() {
    super.initState();
    // Ensure scripts are loaded
    ScriptService.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: AppSpacing.paddingLg,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.menu_book_outlined, color: cs.primary),
                const SizedBox(width: 8),
                Text('Call scripts', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(tooltip: 'Reset samples', onPressed: () async => await ScriptService.instance.resetToSamples(), icon: const Icon(Icons.restore_page_outlined)),
                FilledButton.icon(onPressed: () => _openEditor(context), icon: const Icon(Icons.add), label: const Text('New')),
              ]),
              const SizedBox(height: 8),
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: ScriptService.instance.scripts,
                  builder: (context, List<ScriptModel> list, _) {
                    if (list.isEmpty) {
                      return Center(
                        child: Text('No scripts yet. Create your first one.', style: Theme.of(context).textTheme.bodyMedium?.withColor(cs.onSurfaceVariant)),
                      );
                    }
                    return ListView.separated(
                      controller: controller,
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final s = list[i];
                        return Card(
                          child: ListTile(
                            title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: s.category != null ? Text(s.category!, style: Theme.of(context).textTheme.labelSmall?.withColor(cs.onSurfaceVariant)) : null,
                            leading: const Icon(Icons.record_voice_over_outlined),
                            trailing: Wrap(spacing: 4, children: [
                              IconButton(tooltip: 'View', onPressed: () => _openViewer(context, s), icon: const Icon(Icons.visibility_outlined)),
                              IconButton(tooltip: 'Edit', onPressed: () => _openEditor(context, script: s), icon: const Icon(Icons.edit_outlined)),
                              IconButton(tooltip: 'Delete', onPressed: () async => await ScriptService.instance.deleteScript(s.id), icon: const Icon(Icons.delete_outline)),
                            ]),
                            onTap: () => _openViewer(context, s),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  void _openViewer(BuildContext context, ScriptModel script) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScriptViewerSheet(script: script),
    );
  }

  void _openEditor(BuildContext context, {ScriptModel? script}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScriptEditorSheet(script: script),
    );
  }
}

class _ScriptViewerSheet extends StatelessWidget {
  const _ScriptViewerSheet({required this.script});
  final ScriptModel script;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.menu_book, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(script.title, style: Theme.of(context).textTheme.titleLarge)),
            IconButton(tooltip: 'Close', onPressed: () => context.pop(), icon: const Icon(Icons.close))
          ]),
          if (script.category != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              child: Text(script.category!, style: Theme.of(context).textTheme.labelSmall?.withColor(cs.onSurfaceVariant)),
            ),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(16),
            child: SelectableText(script.body, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(onPressed: () => context.pop(), icon: const Icon(Icons.check_circle_outline), label: const Text('Got it')),
          )
        ]),
      ),
    );
  }
}

class _ScriptEditorSheet extends StatefulWidget {
  const _ScriptEditorSheet({this.script});
  final ScriptModel? script;

  @override
  State<_ScriptEditorSheet> createState() => _ScriptEditorSheetState();
}

class _ScriptEditorSheetState extends State<_ScriptEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _category;
  late final TextEditingController _body;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.script?.title ?? '');
    _category = TextEditingController(text: widget.script?.category ?? '');
    _body = TextEditingController(text: widget.script?.body ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _category.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEditing = widget.script != null;
    return DecoratedBox(
      decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(isEditing ? Icons.edit_outlined : Icons.add, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(isEditing ? 'Edit script' : 'New script', style: Theme.of(context).textTheme.titleLarge)),
              IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close)),
            ]),
            const SizedBox(height: 8),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title', prefixIcon: Icon(Icons.title_outlined)),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _category,
              decoration: const InputDecoration(labelText: 'Category (optional)', prefixIcon: Icon(Icons.category_outlined)),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _body,
              minLines: 6,
              maxLines: 12,
              decoration: const InputDecoration(labelText: 'Script body', alignLabelWithHint: true, prefixIcon: Icon(Icons.notes_outlined)),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter the script body' : null,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(isEditing ? 'Save' : 'Add'),
              ),
            )
          ]),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final title = _title.text.trim();
    final category = _category.text.trim().isEmpty ? null : _category.text.trim();
    final body = _body.text.trim();
    if (widget.script == null) {
      await ScriptService.instance.addScript(title: title, body: body, category: category);
    } else {
      await ScriptService.instance.updateScript(widget.script!.copyWith(title: title, body: body, category: category));
    }
    if (mounted) context.pop();
  }
}
