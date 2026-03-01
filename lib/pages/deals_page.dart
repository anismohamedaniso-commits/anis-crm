import 'package:flutter/material.dart';
import 'package:anis_crm/theme.dart';
import 'package:anis_crm/models/deal_model.dart';
import 'package:anis_crm/services/deal_service.dart';
import 'package:anis_crm/services/auth_service.dart';
import 'package:anis_crm/utils/snackbar_utils.dart';
import 'package:anis_crm/utils/confirm_dialog.dart';

/// Deals / Revenue Pipeline — Kanban board + metrics.
class DealsPage extends StatefulWidget {
  const DealsPage({super.key});
  @override
  State<DealsPage> createState() => _DealsPageState();
}

class _DealsPageState extends State<DealsPage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await DealService.instance.load();
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
    final cs = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.monetization_on_rounded, color: cs.primary, size: 22),
          ),
          const SizedBox(width: 10),
          Text('Deals Pipeline', style: context.textStyles.titleLarge?.semiBold),
        ]),
        centerTitle: false,
        actions: [
          FilledButton.icon(
            onPressed: () => _showCreateDialog(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New Deal'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MetricsRow(),
                    const SizedBox(height: AppSpacing.xl),
                    if (isWide) _DesktopKanban(onStageChange: _onStageChange, onTap: _onTapDeal)
                    else _MobileKanban(onStageChange: _onStageChange, onTap: _onTapDeal),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _onStageChange(DealModel deal, DealStage newStage) async {
    final ok = await DealService.instance.updateStage(deal.id, newStage);
    if (ok) {
      _snack('${deal.title} moved to ${newStage.label}');
      setState(() {});
    } else {
      _snack('Failed to update deal', error: true);
    }
  }

  void _onTapDeal(DealModel deal) => _showEditDialog(deal);

  // ── Create Deal Dialog ────────────────────────────────────────────────
  void _showCreateDialog() async {
    if (!mounted) return;

    final titleCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    bool saving = false;
    final me = AuthService.instance.user;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) {
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;
        final canSave = titleCtrl.text.trim().isNotEmpty &&
            (double.tryParse(valueCtrl.text) ?? 0) > 0 &&
            !saving;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [cs.primary.withOpacity(0.12), cs.primary.withOpacity(0.04)]),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.handshake_rounded, color: cs.primary, size: 32),
                ),
                const SizedBox(height: 16),
                Text('New Deal', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Enter deal name and value',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 24),

                // Deal title
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Deal Title',
                    hintText: 'e.g. Website Redesign',
                    prefixIcon: Icon(Icons.title_rounded, color: cs.primary, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withOpacity(0.3),
                  ),
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => ss(() {}),
                ),
                const SizedBox(height: 16),

                // Deal value
                TextField(
                  controller: valueCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Value (EGP)',
                    hintText: 'e.g. 5000',
                    prefixText: 'E£ ',
                    prefixIcon: Icon(Icons.attach_money_rounded, color: cs.primary, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withOpacity(0.3),
                  ),
                  onChanged: (_) => ss(() {}),
                ),
                const SizedBox(height: 16),

                // Notes (optional)
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'Any extra details...',
                    prefixIcon: Icon(Icons.notes_rounded, color: cs.primary, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withOpacity(0.3),
                  ),
                ),
                const SizedBox(height: 28),

                // Actions
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: canSave
                          ? () async {
                              ss(() => saving = true);
                              final dealValue = double.tryParse(valueCtrl.text) ?? 0;
                              final deal = await DealService.instance.create(
                                title: titleCtrl.text.trim(),
                                value: dealValue,
                                currency: 'EGP',
                                leadId: '',
                                leadName: '',
                                ownerId: me?.id ?? '',
                                ownerName: me?.name ?? '',
                                notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (deal != null) {
                                _snack('Deal created: E£ ${dealValue.toInt()}');
                                setState(() {});
                              } else {
                                final err = DealService.instance.lastError;
                                _snack(err != null ? 'Failed to create deal: $err' : 'Failed to create deal', error: true);
                              }
                            }
                          : null,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Create Deal'),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        );
      }),
    );
  }

  // ── Edit Deal Dialog ──────────────────────────────────────────────────
  void _showEditDialog(DealModel deal) {
    final valueCtrl = TextEditingController(text: deal.value.toStringAsFixed(0));
    final notesCtrl = TextEditingController(text: deal.notes ?? '');
    DealStage stage = deal.stage;
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) {
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Header with delete
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.edit_rounded, color: cs.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(deal.title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (deal.leadName.isNotEmpty)
                        Text(deal.leadName, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ]),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: cs.error),
                    tooltip: 'Delete deal',
                    onPressed: () async {
                      final confirmed = await ConfirmDialog.show(
                        context,
                        title: 'Delete Deal',
                        message: 'Are you sure you want to delete "${deal.title}"? This action cannot be undone.',
                      );
                      if (!confirmed) return;
                      Navigator.pop(ctx);
                      final ok = await DealService.instance.delete(deal.id);
                      if (ok) {
                        _snack('Deal deleted');
                        setState(() {});
                      }
                    },
                  ),
                ]),
                const SizedBox(height: 24),
                // Value
                TextField(
                  controller: valueCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Value (${deal.currency})',
                    prefixText: 'E£ ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withOpacity(0.3),
                  ),
                ),
                const SizedBox(height: 14),
                // Stage
                DropdownButtonFormField<DealStage>(
                  value: stage,
                  decoration: InputDecoration(
                    labelText: 'Stage',
                    prefixIcon: Icon(Icons.flag_rounded, color: cs.primary, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withOpacity(0.3),
                  ),
                  items: DealStage.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label))).toList(),
                  onChanged: (v) => ss(() => stage = v ?? stage),
                ),
                const SizedBox(height: 14),
                // Notes
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withOpacity(0.3),
                  ),
                ),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              ss(() => saving = true);
                              final ok = await DealService.instance.update(deal.id, {
                                'value': double.tryParse(valueCtrl.text) ?? deal.value,
                                'stage': stage.apiName,
                                'notes': notesCtrl.text.trim(),
                              });
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (ok) {
                                _snack('Deal updated');
                                setState(() {});
                              }
                            },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save Changes'),
                    ),
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
// METRICS ROW
// ═════════════════════════════════════════════════════════════════════════════

class _MetricsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final svc = DealService.instance;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final dk = Theme.of(context).brightness == Brightness.dark;

    return Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.md, children: [
      _MetricCard(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Total Value',
        value: _formatCurrency(svc.totalPipelineValue),
        color: AppColors.info,
        dk: dk,
      ),
      _MetricCard(
        icon: Icons.check_circle_rounded,
        label: 'Done',
        value: _formatCurrency(svc.doneValue),
        color: AppColors.success,
        dk: dk,
      ),
      _MetricCard(
        icon: Icons.hourglass_bottom_rounded,
        label: 'Unfinished',
        value: _formatCurrency(svc.unfinishedValue),
        color: AppColors.warning,
        dk: dk,
      ),
      _MetricCard(
        icon: Icons.percent_rounded,
        label: 'Completion',
        value: '${svc.completionRate.toStringAsFixed(1)}%',
        color: const Color(0xFF9C27B0),
        dk: dk,
      ),
    ]);
  }

  static String _formatCurrency(double v) {
    if (v >= 1000000) return 'E£${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return 'E£${(v / 1000).toStringAsFixed(1)}K';
    return 'E£${v.toStringAsFixed(0)}';
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.icon, required this.label, required this.value, required this.color, required this.dk});
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool dk;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: color.withOpacity(dk ? 0.2 : 0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(dk ? 0.25 : 0.15), color.withOpacity(dk ? 0.1 : 0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 14),
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// KANBAN BOARD
// ═════════════════════════════════════════════════════════════════════════════

final _stageColumns = <_StageCol>[
  _StageCol(DealStage.unfinished, 'Unfinished', AppColors.warning),
  _StageCol(DealStage.done, 'Done', AppColors.success),
];

class _StageCol {
  final DealStage stage;
  final String title;
  final Color color;
  const _StageCol(this.stage, this.title, this.color);
}

class _DesktopKanban extends StatelessWidget {
  const _DesktopKanban({required this.onStageChange, required this.onTap});
  final Future<void> Function(DealModel, DealStage) onStageChange;
  final void Function(DealModel) onTap;

  @override
  Widget build(BuildContext context) {
    final grouped = DealService.instance.byStage;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final col in _stageColumns)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              child: _KanbanColumn(
                stage: col.stage,
                title: col.title,
                color: col.color,
                deals: grouped[col.stage] ?? [],
                onStageChange: onStageChange,
                onTap: onTap,
              ),
            ),
        ]),
      ),
    );
  }
}

class _MobileKanban extends StatelessWidget {
  const _MobileKanban({required this.onStageChange, required this.onTap});
  final Future<void> Function(DealModel, DealStage) onStageChange;
  final void Function(DealModel) onTap;

  @override
  Widget build(BuildContext context) {
    final grouped = DealService.instance.byStage;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final col in _stageColumns) ...[
        _KanbanColumn(
          stage: col.stage,
          title: col.title,
          color: col.color,
          deals: grouped[col.stage] ?? [],
          onStageChange: onStageChange,
          onTap: onTap,
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    ]);
  }
}

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({
    required this.stage,
    required this.title,
    required this.color,
    required this.deals,
    required this.onStageChange,
    required this.onTap,
  });
  final DealStage stage;
  final String title;
  final Color color;
  final List<DealModel> deals;
  final Future<void> Function(DealModel, DealStage) onStageChange;
  final void Function(DealModel) onTap;

  @override
  Widget build(BuildContext context) {
    final totalValue = deals.fold<double>(0, (s, d) => s + d.value);
    final dk = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: 260,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: dk ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${deals.length}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            Text(_MetricsRow._formatCurrency(totalValue),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 8),
        // Cards
        DragTarget<DealModel>(
          onAcceptWithDetails: (details) => onStageChange(details.data, stage),
          builder: (ctx, candidateData, rejectedData) {
            return Container(
              decoration: candidateData.isNotEmpty
                  ? BoxDecoration(
                      border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    )
                  : null,
              child: Column(
                children: deals.isEmpty
                    ? [
                        SizedBox(
                          height: 60,
                          child: Center(
                            child: Text('No deals', style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                            )),
                          ),
                        )
                      ]
                    : deals.map((d) => _DealCard(deal: d, color: color, onTap: () => onTap(d))).toList(),
              ),
            );
          },
        ),
      ]),
    );
  }
}

class _DealCard extends StatelessWidget {
  const _DealCard({required this.deal, required this.color, required this.onTap});
  final DealModel deal;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Draggable<DealModel>(
      data: deal,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(width: 240, child: _cardContent(context)),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: _cardContent(context)),
      child: GestureDetector(onTap: onTap, child: _cardContent(context)),
    );
  }

  Widget _cardContent(BuildContext context) {
    final dk = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outline.withOpacity(0.08)),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: color, width: 3.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(deal.title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(dk ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  deal.formattedValue,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
                ),
              ),
            ]),
            if (deal.leadName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: color.withOpacity(0.15),
                  child: Text(
                    deal.leadName.isNotEmpty ? deal.leadName[0].toUpperCase() : '?',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(deal.leadName, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ]),
            ],
            if (deal.ownerName.isNotEmpty) ...[
              const SizedBox(height: 5),
              Row(children: [
                Icon(Icons.person_outline_rounded, size: 14, color: cs.onSurfaceVariant.withOpacity(0.6)),
                const SizedBox(width: 4),
                Text(deal.ownerName, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant.withOpacity(0.7), fontSize: 11)),
              ]),
            ],
            if (deal.expectedCloseDate != null && deal.expectedCloseDate!.isNotEmpty) ...[
              const SizedBox(height: 5),
              Row(children: [
                Icon(Icons.schedule_rounded, size: 14, color: cs.onSurfaceVariant.withOpacity(0.6)),
                const SizedBox(width: 4),
                Text(deal.expectedCloseDate!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant.withOpacity(0.7), fontSize: 11)),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}
