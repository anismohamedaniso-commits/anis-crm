import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:anis_crm/components/brand_logo.dart';
import 'package:anis_crm/models/kpi_target.dart';
import 'package:anis_crm/models/lead.dart';
import 'package:anis_crm/services/kpi_service.dart';
import 'package:anis_crm/services/lead_service.dart';
import 'package:anis_crm/state/app_state.dart';
import 'package:anis_crm/theme.dart';

/// Full-featured KPIs & Targets dashboard page.
class KpiDashboardPage extends StatefulWidget {
  const KpiDashboardPage({super.key});

  @override
  State<KpiDashboardPage> createState() => _KpiDashboardPageState();
}

class _KpiDashboardPageState extends State<KpiDashboardPage> {
  @override
  void initState() {
    super.initState();
    KpiService.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const BrandHeaderBar(),
        const SizedBox(height: 8),
        Text('KPIs & Targets', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 4),
        Text(
          'Track performance and set goals for your sales team',
          style: Theme.of(context).textTheme.bodyLarge?.withColor(cs.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Overall Performance Summary ──────────────────────────────
        _OverviewCards(),
        const SizedBox(height: AppSpacing.lg),

        // ── KPI Targets ──────────────────────────────────────────────
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Active Targets', style: Theme.of(context).textTheme.titleLarge),
            FilledButton.tonalIcon(
              onPressed: () => _showAddTargetDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Target'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ValueListenableBuilder<List<KpiTarget>>(
          valueListenable: KpiService.instance.targets,
          builder: (context, targets, _) {
            if (targets.isEmpty) {
              return Card(
                child: Padding(
                  padding: AppSpacing.paddingLg,
                  child: Center(
                    child: Column(children: [
                      Icon(Icons.track_changes, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text('No targets yet', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('Add your first KPI target to start tracking', style: Theme.of(context).textTheme.bodyMedium?.withColor(cs.onSurfaceVariant)),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _showAddTargetDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Target'),
                      ),
                    ]),
                  ),
                ),
              );
            }

            final achieved = targets.where((t) => t.isAchieved).toList();
            final inProgress = targets.where((t) => !t.isAchieved).toList();

            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (inProgress.isNotEmpty) ...[
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: inProgress.map((t) => _KpiTargetCard(
                    target: t,
                    onEdit: () => _showEditTargetDialog(context, t),
                    onDelete: () => _confirmDelete(context, t),
                  )).toList(),
                ),
              ],
              if (achieved.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Row(children: [
                  const Icon(Icons.emoji_events, color: AppColors.success, size: 20),
                  const SizedBox(width: 8),
                  Text('Achieved (${achieved.length})', style: Theme.of(context).textTheme.titleMedium?.withColor(AppColors.success)),
                ]),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: achieved.map((t) => _KpiTargetCard(
                    target: t,
                    onEdit: () => _showEditTargetDialog(context, t),
                    onDelete: () => _confirmDelete(context, t),
                  )).toList(),
                ),
              ],
            ]);
          },
        ),

        const SizedBox(height: AppSpacing.xl),

        // ── Lead Source Breakdown ──────────────────────────────────────
        Text('Lead Source Breakdown', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        _LeadSourceBreakdown(),

        const SizedBox(height: AppSpacing.xl),

        // ── Conversion Funnel ────────────────────────────────────────
        Text('Conversion Funnel', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        _ConversionFunnel(),

        const SizedBox(height: AppSpacing.xl),
      ]),
    );
  }

  // ── Dialogs ──────────────────────────────────────────────────────────

  void _showAddTargetDialog(BuildContext context) {
    _showTargetFormDialog(context, null);
  }

  void _showEditTargetDialog(BuildContext context, KpiTarget existing) {
    _showTargetFormDialog(context, existing);
  }

  void _showTargetFormDialog(BuildContext context, KpiTarget? existing) {
    final isEditing = existing != null;
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final targetCtrl = TextEditingController(text: existing?.target.toString() ?? '');
    var selectedMetric = existing?.metric ?? KpiMetric.leadsCreated;
    var selectedPeriod = existing?.period ?? KpiPeriod.monthly;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Target' : 'Add New Target'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width < 500 ? double.infinity : 400,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(labelText: 'Label', hintText: 'e.g. Monthly sales calls'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<KpiMetric>(
                value: selectedMetric,
                decoration: const InputDecoration(labelText: 'Metric'),
                items: KpiMetric.values
                    .map((m) => DropdownMenuItem(value: m, child: Text(m.displayName)))
                    .toList(),
                onChanged: (v) { if (v != null) setDialogState(() => selectedMetric = v); },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<KpiPeriod>(
                value: selectedPeriod,
                decoration: const InputDecoration(labelText: 'Period'),
                items: KpiPeriod.values
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.displayName)))
                    .toList(),
                onChanged: (v) { if (v != null) setDialogState(() => selectedPeriod = v); },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: targetCtrl,
                decoration: const InputDecoration(labelText: 'Target Value', hintText: 'e.g. 50'),
                keyboardType: TextInputType.number,
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final label = labelCtrl.text.trim();
                final targetVal = int.tryParse(targetCtrl.text.trim()) ?? 0;
                if (label.isEmpty || targetVal <= 0) return;

                if (isEditing) {
                  KpiService.instance.updateTarget(existing.copyWith(
                    label: label,
                    metric: selectedMetric,
                    period: selectedPeriod,
                    target: targetVal,
                  ));
                } else {
                  KpiService.instance.addTarget(KpiTarget(
                    id: const Uuid().v4(),
                    label: label,
                    metric: selectedMetric,
                    period: selectedPeriod,
                    target: targetVal,
                    createdAt: DateTime.now(),
                  ));
                }
                Navigator.pop(ctx);
              },
              child: Text(isEditing ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, KpiTarget target) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Target'),
        content: Text('Remove "${target.label}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              KpiService.instance.removeTarget(target.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// OVERVIEW CARDS — Big numbers at the top
// ═══════════════════════════════════════════════════════════════════════════

class _OverviewCards extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: LeadService.instance.leads,
      builder: (context, List<LeadModel> allLeads, _) {
        final marketId = context.watch<AppState>().selectedMarketId;
        final leads = allLeads.where((l) => l.country == marketId).toList();
        final now = DateTime.now();
        final monthStart = DateTime(now.year, now.month, 1);
        final leadsThisMonth = leads.where((l) => !l.createdAt.isBefore(monthStart)).length;
        final convertedThisMonth = leads.where((l) => l.status == LeadStatus.converted && !l.updatedAt.isBefore(monthStart)).length;
        final activeLeads = leads.where((l) =>
            l.status == LeadStatus.fresh ||
            l.status == LeadStatus.interested ||
            l.status == LeadStatus.followUp ||
            l.status == LeadStatus.noAnswer).length;
        final conversionRate = leads.isNotEmpty
            ? ((leads.where((l) => l.status == LeadStatus.converted).length / leads.length) * 100).toStringAsFixed(1)
            : '0.0';

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            _OverviewCard(
              icon: Icons.trending_up,
              label: 'Leads This Month',
              value: '$leadsThisMonth',
              color: AppColors.info,
            ),
            _OverviewCard(
              icon: Icons.check_circle_outline,
              label: 'Converted This Month',
              value: '$convertedThisMonth',
              color: AppColors.success,
            ),
            _OverviewCard(
              icon: Icons.people_outline,
              label: 'Active Pipeline',
              value: '$activeLeads',
              color: Theme.of(context).colorScheme.primary,
            ),
            _OverviewCard(
              icon: Icons.percent,
              label: 'Conversion Rate',
              value: '$conversionRate%',
              color: AppColors.warning,
            ),
          ],
        );
      },
    );
  }
}

class _OverviewCard extends StatefulWidget {
  const _OverviewCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  State<_OverviewCard> createState() => _OverviewCardState();
}

class _OverviewCardState extends State<_OverviewCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: SizedBox(
        width: 220,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          child: Card(
            elevation: _hovered ? 3 : 0,
            child: Padding(
              padding: AppSpacing.paddingLg,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(widget.icon, size: 20, color: widget.color),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(widget.value, style: Theme.of(context).textTheme.headlineSmall?.semiBold.withColor(widget.color)),
                const SizedBox(height: 4),
                Text(widget.label, style: Theme.of(context).textTheme.labelLarge?.withColor(cs.onSurfaceVariant)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// KPI TARGET CARD — Individual target with progress bar
// ═══════════════════════════════════════════════════════════════════════════

class _KpiTargetCard extends StatelessWidget {
  const _KpiTargetCard({
    required this.target,
    required this.onEdit,
    required this.onDelete,
  });

  final KpiTarget target;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  IconData _iconForMetric(KpiMetric m) {
    switch (m) {
      case KpiMetric.leadsCreated: return Icons.person_add_alt_1;
      case KpiMetric.leadsConverted: return Icons.check_circle;
      case KpiMetric.callsMade: return Icons.phone;
      case KpiMetric.followUpsDone: return Icons.event_available;
      case KpiMetric.emailsSent: return Icons.email;
      case KpiMetric.responseRate: return Icons.speed;
    }
  }

  Color _progressColor(double progress) {
    if (progress >= 1.0) return AppColors.success;
    if (progress >= 0.7) return AppColors.info;
    if (progress >= 0.4) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pColor = _progressColor(target.progress);
    final pctText = '${(target.progress * 100).toStringAsFixed(0)}%';

    return SizedBox(
      width: 320,
      child: Card(
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header row
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: pColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(_iconForMetric(target.metric), size: 20, color: pColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(target.label, style: Theme.of(context).textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                  Text('${target.period.displayName} • ${target.metric.displayName}',
                      style: Theme.of(context).textTheme.labelSmall?.withColor(cs.onSurfaceVariant)),
                ]),
              ),
              if (target.isAchieved)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.emoji_events, size: 14, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text('Done', style: Theme.of(context).textTheme.labelSmall?.bold.withColor(AppColors.success)),
                  ]),
                ),
              PopupMenuButton<String>(
                iconSize: 18,
                padding: EdgeInsets.zero,
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ]),
            const SizedBox(height: 16),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: target.progress,
                minHeight: 10,
                backgroundColor: cs.surfaceContainerHighest,
                color: pColor,
              ),
            ),
            const SizedBox(height: 10),

            // Stats row
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${target.current} / ${target.target}',
                  style: Theme.of(context).textTheme.bodyMedium?.semiBold),
              Text(pctText,
                  style: Theme.of(context).textTheme.bodyMedium?.bold.withColor(pColor)),
            ]),
            if (!target.isAchieved) ...[
              const SizedBox(height: 4),
              Text('${target.remaining} remaining',
                  style: Theme.of(context).textTheme.labelSmall?.withColor(cs.onSurfaceVariant)),
            ],
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LEAD SOURCE BREAKDOWN — Horizontal bar chart
// ═══════════════════════════════════════════════════════════════════════════

class _LeadSourceBreakdown extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: LeadService.instance.leads,
      builder: (context, List<LeadModel> allLeads, _) {
        final marketId = context.watch<AppState>().selectedMarketId;
        final leads = allLeads.where((l) => l.country == marketId).toList();
        final cs = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        if (leads.isEmpty) {
          return Card(
            child: Padding(
              padding: AppSpacing.paddingLg,
              child: Text('No leads yet', style: Theme.of(context).textTheme.bodyMedium?.withColor(cs.onSurfaceVariant)),
            ),
          );
        }

        final counts = <LeadSource, int>{};
        for (final l in leads) {
          counts[l.source] = (counts[l.source] ?? 0) + 1;
        }
        final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final max = sorted.first.value;

        final sourceColors = <LeadSource, Color>{
          LeadSource.whatsapp: const Color(0xFF25D366),
          LeadSource.facebook: const Color(0xFF1877F2),
          LeadSource.instagram: const Color(0xFFE4405F),
          LeadSource.linkedin: const Color(0xFF0A66C2),
          LeadSource.tiktok: isDark ? const Color(0xFFEEEEEE) : const Color(0xFF010101),
          LeadSource.email: AppColors.info,
          LeadSource.phone: AppColors.success,
          LeadSource.web: cs.primary,
          LeadSource.manual: AppColors.neutralDark,
          LeadSource.imported: AppColors.warning,
        };

        return Card(
          child: Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              children: sorted.map((e) {
                final color = sourceColors[e.key] ?? cs.primary;
                final pct = leads.isNotEmpty ? ((e.value / leads.length) * 100).toStringAsFixed(1) : '0';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        e.key.name[0].toUpperCase() + e.key.name.substring(1),
                        style: Theme.of(context).textTheme.bodySmall?.semiBold,
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: LinearProgressIndicator(
                          value: max > 0 ? e.value / max : 0,
                          minHeight: 14,
                          backgroundColor: cs.surfaceContainerHighest,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 60,
                      child: Text('${e.value} ($pct%)',
                          style: Theme.of(context).textTheme.labelSmall?.semiBold,
                          textAlign: TextAlign.end),
                    ),
                  ]),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CONVERSION FUNNEL — Visual step-down funnel
// ═══════════════════════════════════════════════════════════════════════════

class _ConversionFunnel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: LeadService.instance.leads,
      builder: (context, List<LeadModel> allLeads, _) {
        final marketId = context.watch<AppState>().selectedMarketId;
        final leads = allLeads.where((l) => l.country == marketId).toList();
        final cs = Theme.of(context).colorScheme;
        if (leads.isEmpty) {
          return Card(
            child: Padding(
              padding: AppSpacing.paddingLg,
              child: Text('No leads yet', style: Theme.of(context).textTheme.bodyMedium?.withColor(cs.onSurfaceVariant)),
            ),
          );
        }

        final total = leads.length;
        final contacted = leads.where((l) => l.lastContactedAt != null).length;
        final interested = leads.where((l) =>
            l.status == LeadStatus.interested ||
            l.status == LeadStatus.followUp ||
            l.status == LeadStatus.converted).length;
        final converted = leads.where((l) => l.status == LeadStatus.converted).length;

        final stages = [
          _FunnelStage('All Leads', total, cs.primary),
          _FunnelStage('Contacted', contacted, AppColors.info),
          _FunnelStage('Interested', interested, AppColors.warning),
          _FunnelStage('Converted', converted, AppColors.success),
        ];

        return Card(
          child: Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              children: [
                for (int i = 0; i < stages.length; i++) ...[
                  _FunnelBar(
                    stage: stages[i],
                    maxValue: total,
                    previousValue: i > 0 ? stages[i - 1].value : null,
                  ),
                  if (i < stages.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Icon(Icons.keyboard_arrow_down, size: 20, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FunnelStage {
  final String label;
  final int value;
  final Color color;
  const _FunnelStage(this.label, this.value, this.color);
}

class _FunnelBar extends StatelessWidget {
  const _FunnelBar({required this.stage, required this.maxValue, this.previousValue});

  final _FunnelStage stage;
  final int maxValue;
  final int? previousValue;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fraction = maxValue > 0 ? (stage.value / maxValue).clamp(0.0, 1.0) : 0.0;
    final dropRate = previousValue != null && previousValue! > 0
        ? '${((stage.value / previousValue!) * 100).toStringAsFixed(0)}% of previous'
        : '';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(stage.label, style: Theme.of(context).textTheme.bodyMedium?.semiBold),
        Row(children: [
          Text('${stage.value}', style: Theme.of(context).textTheme.bodyMedium?.bold.withColor(stage.color)),
          if (dropRate.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(dropRate, style: Theme.of(context).textTheme.labelSmall?.withColor(cs.onSurfaceVariant)),
          ],
        ]),
      ]),
      const SizedBox(height: 6),
      FractionallySizedBox(
        widthFactor: fraction == 0 ? 0.02 : fraction, // min width for empty
        child: Container(
          height: 28,
          decoration: BoxDecoration(
            color: stage.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: stage.color.withValues(alpha: 0.4)),
          ),
          alignment: Alignment.center,
          child: fraction > 0.15
              ? Text('${(fraction * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.labelSmall?.bold.withColor(stage.color))
              : null,
        ),
      ),
    ]);
  }
}
