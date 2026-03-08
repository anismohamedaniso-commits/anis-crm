import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:anis_crm/theme.dart';
import 'package:anis_crm/models/lead.dart';
import 'package:anis_crm/models/task_model.dart';
import 'package:anis_crm/services/lead_service.dart';
import 'package:anis_crm/services/task_service.dart';
import 'package:anis_crm/state/app_state.dart';
import 'package:anis_crm/utils/excel_builder.dart';
import 'package:anis_crm/utils/excel_download_stub.dart'
    if (dart.library.html) 'package:anis_crm/utils/excel_download_web.dart';
import 'package:anis_crm/services/campaign_service.dart';
import 'package:anis_crm/models/campaign.dart';

// ══════════════════════════════════════════════════════════════════════════════
// REPORTS & ANALYTICS PAGE — Enhanced
// ══════════════════════════════════════════════════════════════════════════════

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  bool _loading = true;
  bool _exporting = false;

  List<LeadModel> _leads = [];
  List<TaskModel> _tasks = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    await Future.wait([
      LeadService.instance.load(),
      TaskService.instance.load(),
    ]);
    if (mounted) {
      setState(() {
        _leads = LeadService.instance.leads.value;
        _tasks = TaskService.instance.tasks.value;
        _loading = false;
      });
    }
  }

  Future<void> _exportExcel() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      // Use market-filtered leads, not the full list
      final market = context.read<AppState>().selectedMarket;
      final exportLeads = _leads.where((l) => l.country == market.id).toList();
      final bytes = buildLeadsExcel(exportLeads);
      final now = DateTime.now();
      final fname =
          'tick_talk_${market.id}_leads_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.xlsx';
      final ok = await downloadExcelFile(bytes, fname);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? '\u2713 Excel exported \u2014 ${exportLeads.length} ${market.label} leads, 4 sheets'
              : 'Export not supported on this platform'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: ok
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.error,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // React to market changes
    final market = context.watch<AppState>().selectedMarket;
    final filteredLeads = _leads.where((l) => l.country == market.id).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('Reports & Analytics',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : FilledButton.icon(
                    onPressed: _exportExcel,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Export Excel'),
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Overview'),
            Tab(icon: Icon(Icons.filter_alt_outlined, size: 18), text: 'Pipeline'),
            Tab(icon: Icon(Icons.bar_chart_rounded, size: 18), text: 'Breakdown'),
            Tab(icon: Icon(Icons.task_alt_outlined, size: 18), text: 'Activity'),
            Tab(icon: Icon(Icons.campaign_outlined, size: 18), text: 'Campaigns'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _OverviewTab(leads: filteredLeads, tasks: _tasks),
                _PipelineTab(leads: filteredLeads),
                _BreakdownTab(leads: filteredLeads),
                _ActivityTab(leads: filteredLeads, tasks: _tasks),
                _CampaignsTab(leads: filteredLeads, marketId: market.id),
              ],
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// OVERVIEW TAB
// ══════════════════════════════════════════════════════════════════════════════

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.leads, required this.tasks});
  final List<LeadModel> leads;
  final List<TaskModel> tasks;

  @override
  Widget build(BuildContext context) {
    final dk = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    final total = leads.length;
    final converted = leads.where((l) => l.status == LeadStatus.converted).length;
    final rate = total > 0 ? (converted / total * 100) : 0.0;
    final revenue = leads
        .where((l) => l.status == LeadStatus.converted && l.dealValue != null)
        .fold(0.0, (s, l) => s + l.dealValue!);
    final avgDeal = converted > 0 ? revenue / converted : 0.0;
    final active = leads
        .where((l) => [
              LeadStatus.fresh,
              LeadStatus.interested,
              LeadStatus.followUp,
              LeadStatus.noAnswer
            ].contains(l.status))
        .length;

    bool isToday(DateTime? dt) =>
        dt != null &&
        dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day;

    final followToday = leads.where((l) => isToday(l.nextFollowupAt)).length;
    final overdue = leads
        .where((l) =>
            l.nextFollowupAt != null &&
            l.nextFollowupAt!.isBefore(now) &&
            !isToday(l.nextFollowupAt))
        .length;

    final doneTasks = tasks.where((t) => t.status.apiName == 'done').length;
    final tasksDue = tasks
        .where((t) =>
            t.status.apiName != 'done' &&
            t.dueDate != null &&
            DateTime.tryParse(t.dueDate!)?.isBefore(now) == true)
        .length;

    final thisMonth = leads
        .where((l) => l.createdAt.year == now.year && l.createdAt.month == now.month)
        .length;

    String fmtRevenue(double v) {
      return context.read<AppState>().selectedMarket.fmtRevenue(v);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Key Metrics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.md),
          Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.md, children: [
            _KpiCard(label: 'Total Leads', value: '$total', icon: Icons.people_outline_rounded, color: AppColors.info, dk: dk, subtitle: '$thisMonth new this month'),
            _KpiCard(label: 'Active Pipeline', value: '$active', icon: Icons.moving_rounded, color: const Color(0xFF2196F3), dk: dk, subtitle: 'fresh + interested + follow-up'),
            _KpiCard(label: 'Converted', value: '$converted', icon: Icons.check_circle_outline_rounded, color: AppColors.success, dk: dk, subtitle: '${rate.toStringAsFixed(1)}% conversion rate'),
            _KpiCard(label: 'Conversion Rate', value: '${rate.toStringAsFixed(1)}%', icon: Icons.trending_up_rounded, color: AppColors.success, dk: dk, subtitle: '$converted out of $total leads'),
            _KpiCard(label: 'Total Revenue', value: fmtRevenue(revenue), icon: Icons.monetization_on_outlined, color: const Color(0xFF9C27B0), dk: dk, subtitle: 'from converted leads'),
            _KpiCard(label: 'Avg Deal Value', value: fmtRevenue(avgDeal), icon: Icons.attach_money_rounded, color: const Color(0xFF9C27B0), dk: dk, subtitle: 'per converted lead'),
            _KpiCard(label: 'Follow-ups Today', value: '$followToday', icon: Icons.alarm_rounded, color: AppColors.warning, dk: dk, subtitle: overdue > 0 ? '$overdue overdue' : 'all on track', urgent: overdue > 0),
            _KpiCard(label: 'Tasks Done', value: '$doneTasks/${tasks.length}', icon: Icons.task_alt_rounded, color: AppColors.info, dk: dk, subtitle: tasksDue > 0 ? '$tasksDue overdue' : 'no overdue tasks', urgent: tasksDue > 0),
          ]),
          const SizedBox(height: AppSpacing.xl),
          Text('Conversion Funnel',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.md),
          _MiniFunnel(leads: leads),
          if (overdue > 0) ...[
            const SizedBox(height: AppSpacing.xl),
            _AlertBanner(
              icon: Icons.warning_amber_rounded,
              color: AppColors.warning,
              title: '$overdue overdue follow-up${overdue > 1 ? 's' : ''}',
              subtitle: 'These leads required contact before today',
              dk: dk,
            ),
          ],
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.dk,
    this.subtitle,
    this.urgent = false,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool dk;
  final String? subtitle;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveColor = urgent ? AppColors.danger : color;
    return SizedBox(
      width: 210,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: urgent
                ? BorderSide(color: AppColors.danger.withValues(alpha: 0.4))
                : BorderSide.none),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: dk ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: effectiveColor, size: 20),
              ),
              if (urgent) ...[
                const Spacer(),
                Icon(Icons.circle, color: AppColors.danger, size: 8),
              ]
            ]),
            const SizedBox(height: 12),
            Text(value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: urgent ? AppColors.danger : cs.onSurface)),
            const SizedBox(height: 2),
            Text(label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
            ]
          ]),
        ),
      ),
    );
  }
}

class _MiniFunnel extends StatelessWidget {
  const _MiniFunnel({required this.leads});
  final List<LeadModel> leads;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = leads.length;
    if (total == 0) return const SizedBox.shrink();

    final stages = [
      _FunnelStage('Fresh', LeadStatus.fresh, const Color(0xFF2196F3)),
      _FunnelStage('Interested', LeadStatus.interested, AppColors.success),
      _FunnelStage('Follow-Up', LeadStatus.followUp, AppColors.warning),
      _FunnelStage('No Answer', LeadStatus.noAnswer, const Color(0xFFFFC107)),
      _FunnelStage('Converted', LeadStatus.converted, const Color(0xFF9C27B0)),
      _FunnelStage('Not Interested', LeadStatus.notInterested, AppColors.danger),
      _FunnelStage('Closed', LeadStatus.closed, const Color(0xFF607D8B)),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: stages.map((stage) {
            final count = leads.where((l) => l.status == stage.status).length;
            if (count == 0) return const SizedBox.shrink();
            final pct = count / total;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(color: stage.color, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 8),
                  Text(stage.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('$count',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    child: Text('${(pct * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        textAlign: TextAlign.right),
                  ),
                ]),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: stage.color.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(stage.color),
                  ),
                ),
              ]),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _FunnelStage {
  const _FunnelStage(this.label, this.status, this.color);
  final String label;
  final LeadStatus status;
  final Color color;
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner(
      {required this.icon, required this.color, required this.title, required this.subtitle, required this.dk});
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool dk;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: dk ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: color)),
          Text(subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color.withValues(alpha: 0.8))),
        ]),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PIPELINE TAB
// ══════════════════════════════════════════════════════════════════════════════

class _PipelineTab extends StatelessWidget {
  const _PipelineTab({required this.leads});
  final List<LeadModel> leads;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dk = Theme.of(context).brightness == Brightness.dark;
    final total = leads.length;

    final pipeline = [
      _PipelineRow('Fresh', LeadStatus.fresh, const Color(0xFF2196F3), 'New leads not yet contacted', Icons.fiber_new_rounded),
      _PipelineRow('Interested', LeadStatus.interested, AppColors.success, 'Expressed interest, move forward', Icons.thumb_up_alt_outlined),
      _PipelineRow('Follow Up', LeadStatus.followUp, AppColors.warning, 'Needs another touchpoint', Icons.alarm_rounded),
      _PipelineRow('No Answer', LeadStatus.noAnswer, const Color(0xFFFFC107), 'Reached out, no response', Icons.phone_missed_outlined),
      _PipelineRow('Converted', LeadStatus.converted, const Color(0xFF9C27B0), 'Deal closed successfully', Icons.emoji_events_outlined),
      _PipelineRow('Not Interested', LeadStatus.notInterested, AppColors.danger, 'Declined the offer', Icons.thumb_down_alt_outlined),
      _PipelineRow('Closed', LeadStatus.closed, const Color(0xFF607D8B), 'Archived / no longer active', Icons.archive_outlined),
    ];

    final revenue = leads
        .where((l) => l.status == LeadStatus.converted && l.dealValue != null)
        .fold(0.0, (s, l) => s + l.dealValue!);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Pipeline Stages',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('${leads.length} total leads across all stages',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.md),
        if (total > 0) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: pipeline.map((p) {
                  final count = leads.where((l) => l.status == p.status).length;
                  if (count == 0) return const SizedBox.shrink();
                  return Expanded(flex: count, child: Container(color: p.color));
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12, runSpacing: 4,
            children: pipeline.where((p) => leads.any((l) => l.status == p.status)).map((p) {
              final count = leads.where((l) => l.status == p.status).length;
              return Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: p.color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 4),
                Text('${p.label} ($count)', style: Theme.of(context).textTheme.labelSmall),
              ]);
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        ...pipeline.map((p) {
          final count = leads.where((l) => l.status == p.status).length;
          final pct = total > 0 ? count / total : 0.0;
          final stageRevenue = leads
              .where((l) => l.status == p.status && l.dealValue != null)
              .fold(0.0, (s, l) => s + l.dealValue!);
          return _PipelineCard(row: p, count: count, total: total, pct: pct, revenue: stageRevenue, dk: dk, cs: cs);
        }),
        const SizedBox(height: AppSpacing.lg),
        if (revenue > 0)
          Card(
            elevation: 0,
            color: const Color(0xFF9C27B0).withValues(alpha: dk ? 0.15 : 0.06),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              side: BorderSide(color: const Color(0xFF9C27B0).withValues(alpha: 0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Icon(Icons.monetization_on_outlined, color: Color(0xFF9C27B0), size: 24),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Total Revenue from Conversions',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  Text(
                      context.read<AppState>().selectedMarket.fmtRevenue(revenue),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800, color: const Color(0xFF9C27B0))),
                ]),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _PipelineRow {
  const _PipelineRow(this.label, this.status, this.color, this.description, this.icon);
  final String label;
  final LeadStatus status;
  final Color color;
  final String description;
  final IconData icon;
}

class _PipelineCard extends StatelessWidget {
  const _PipelineCard({
    required this.row, required this.count, required this.total,
    required this.pct, required this.revenue, required this.dk, required this.cs,
  });
  final _PipelineRow row;
  final int count;
  final int total;
  final double pct;
  final double revenue;
  final bool dk;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: count > 0
              ? BorderSide(color: row.color.withValues(alpha: 0.25))
              : BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: row.color.withValues(alpha: dk ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(row.icon, color: row.color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(row.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(row.description,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                if (count > 0) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct, minHeight: 4,
                      backgroundColor: row.color.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation(row.color),
                    ),
                  ),
                ],
              ]),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$count',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: count > 0 ? row.color : cs.onSurfaceVariant)),
              Text('${(pct * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
              if (revenue > 0)
                Text(
                    revenue >= 1000
                        ? '${(revenue / 1000).toStringAsFixed(1)}K'
                        : revenue.toStringAsFixed(0),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF9C27B0), fontWeight: FontWeight.w700)),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// BREAKDOWN TAB
// ══════════════════════════════════════════════════════════════════════════════

class _BreakdownTab extends StatefulWidget {
  const _BreakdownTab({required this.leads});
  final List<LeadModel> leads;
  @override
  State<_BreakdownTab> createState() => _BreakdownTabState();
}

class _BreakdownTabState extends State<_BreakdownTab> {
  int _dateFilter = -1;

  List<LeadModel> get _filtered {
    if (_dateFilter == -1) return widget.leads;
    final cutoff = DateTime.now().subtract(Duration(days: _dateFilter));
    return widget.leads.where((l) => l.createdAt.isAfter(cutoff)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final leads = _filtered;
    final total = leads.length;

    final byStatus = <LeadStatus, int>{};
    final bySource = <LeadSource, int>{};
    for (final l in leads) {
      byStatus[l.status] = (byStatus[l.status] ?? 0) + 1;
      bySource[l.source] = (bySource[l.source] ?? 0) + 1;
    }

    const filters = [
      (label: '7 Days', days: 7),
      (label: '30 Days', days: 30),
      (label: '90 Days', days: 90),
      (label: 'All Time', days: -1),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Period:', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
          const SizedBox(width: 10),
          ...filters.map((f) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(f.label),
                  selected: _dateFilter == f.days,
                  onSelected: (_) => setState(() => _dateFilter = f.days),
                  showCheckmark: false,
                ),
              )),
        ]),
        const SizedBox(height: 6),
        Text('$total leads in selected period',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.lg),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.label_outline_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text('By Status', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 14),
              if (total == 0)
                Text('No leads in this period', style: Theme.of(context).textTheme.bodySmall)
              else
                ...LeadStatus.values.map((s) {
                  final count = byStatus[s] ?? 0;
                  if (count == 0) return const SizedBox.shrink();
                  return _BreakdownBar(label: _statusLabel(s), count: count, total: total, color: _statusColor(s));
                }),
            ]),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.hub_outlined, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text('By Source', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 14),
              if (total == 0)
                Text('No leads in this period', style: Theme.of(context).textTheme.bodySmall)
              else
                ...() {
                  final sorted = bySource.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
                  return sorted.map((e) => _BreakdownBar(label: _sourceLabel(e.key), count: e.value, total: total, color: _sourceColor(e.key)));
                }(),
            ]),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (leads.any((l) => l.dealValue != null))
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.monetization_on_outlined, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Text('Revenue by Source', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 14),
                ...() {
                  final bySourceRevenue = <LeadSource, double>{};
                  for (final l in leads) {
                    if (l.dealValue != null && l.status == LeadStatus.converted) {
                      bySourceRevenue[l.source] = (bySourceRevenue[l.source] ?? 0) + l.dealValue!;
                    }
                  }
                  if (bySourceRevenue.isEmpty) {
                    return [Text('No revenue data yet', style: Theme.of(context).textTheme.bodySmall)];
                  }
                  final maxRev = bySourceRevenue.values.fold(0.0, (m, v) => v > m ? v : m);
                  final sorted = bySourceRevenue.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
                  return sorted.map((e) {
                    final pct = maxRev > 0 ? e.value / maxRev : 0.0;
                    final fmtRev = context.read<AppState>().selectedMarket.fmtRevenue(e.value);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        SizedBox(width: 110, child: Text(_sourceLabel(e.key), style: Theme.of(context).textTheme.bodySmall)),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct, minHeight: 14,
                              backgroundColor: _sourceColor(e.key).withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation(_sourceColor(e.key)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(width: 80, child: Text(fmtRev, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
                      ]),
                    );
                  }).toList();
                }(),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _BreakdownBar extends StatelessWidget {
  const _BreakdownBar({required this.label, required this.count, required this.total, required this.color});
  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        SizedBox(width: 120, child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct, minHeight: 18,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(width: 36, child: Text('$count', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
        SizedBox(width: 42, child: Text('${(pct * 100).toStringAsFixed(0)}%', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant), textAlign: TextAlign.right)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ACTIVITY TAB
// ══════════════════════════════════════════════════════════════════════════════

class _ActivityTab extends StatelessWidget {
  const _ActivityTab({required this.leads, required this.tasks});
  final List<LeadModel> leads;
  final List<TaskModel> tasks;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dk = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    bool isToday(DateTime? dt) =>
        dt != null && dt.year == now.year && dt.month == now.month && dt.day == now.day;

    final doneT = tasks.where((t) => t.status.apiName == 'done').length;
    final pendingT = tasks.where((t) => t.status.apiName != 'done').length;
    final overdueT = tasks
        .where((t) =>
            t.status.apiName != 'done' &&
            t.dueDate != null &&
            DateTime.tryParse(t.dueDate!)?.isBefore(now) == true)
        .length;
    final taskRate = tasks.isNotEmpty ? (doneT / tasks.length * 100) : 0.0;

    final followToday = leads.where((l) => isToday(l.nextFollowupAt)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final overdue = leads
        .where((l) =>
            l.nextFollowupAt != null &&
            l.nextFollowupAt!.isBefore(now) &&
            !isToday(l.nextFollowupAt))
        .toList()
      ..sort((a, b) => a.nextFollowupAt!.compareTo(b.nextFollowupAt!));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Tasks Overview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.md),
        Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.md, children: [
          _KpiCard(label: 'Total Tasks', value: '${tasks.length}', icon: Icons.list_alt_rounded, color: AppColors.info, dk: dk),
          _KpiCard(label: 'Completed', value: '$doneT', icon: Icons.check_circle_outline_rounded, color: AppColors.success, dk: dk),
          _KpiCard(label: 'Pending', value: '$pendingT', icon: Icons.pending_outlined, color: AppColors.warning, dk: dk),
          _KpiCard(label: 'Overdue Tasks', value: '$overdueT', icon: Icons.warning_amber_rounded, color: AppColors.danger, dk: dk, urgent: overdueT > 0),
        ]),
        if (tasks.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Completion Rate',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('${taskRate.toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: cs.primary)),
                ]),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: taskRate / 100, minHeight: 10,
                    backgroundColor: AppColors.success.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation(AppColors.success),
                  ),
                ),
              ]),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Text('Follow-ups Today',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.sm),
        if (followToday.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No follow-ups scheduled for today.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          )
        else
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: Column(
              children: followToday.asMap().entries.map((e) => _FollowupTile(
                  lead: e.value, isLast: e.key == followToday.length - 1, urgent: false, cs: cs)).toList(),
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
        Row(children: [
          Text('Overdue Follow-ups',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          if (overdue.isNotEmpty) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
              child: Text('${overdue.length}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
        const SizedBox(height: AppSpacing.sm),
        if (overdue.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No overdue follow-ups. Great job!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.success)),
          )
        else
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              side: BorderSide(color: AppColors.danger.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: overdue.asMap().entries.map((e) => _FollowupTile(
                  lead: e.value, isLast: e.key == overdue.length - 1, urgent: true, cs: cs)).toList(),
            ),
          ),
      ]),
    );
  }
}

class _FollowupTile extends StatelessWidget {
  const _FollowupTile({required this.lead, required this.isLast, required this.urgent, required this.cs});
  final LeadModel lead;
  final bool isLast;
  final bool urgent;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysAgo = lead.nextFollowupAt != null ? now.difference(lead.nextFollowupAt!).inDays : 0;
    return Column(children: [
      ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: _statusColor(lead.status).withValues(alpha: 0.15),
          child: Text(
            lead.name.isNotEmpty ? lead.name[0].toUpperCase() : '?',
            style: TextStyle(color: _statusColor(lead.status), fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
        title: Text(lead.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          urgent
              ? '${daysAgo > 0 ? '$daysAgo day${daysAgo > 1 ? 's' : ''} overdue' : 'Due today'} \u00b7 ${lead.phone ?? 'No phone'}'
              : lead.phone ?? 'No phone',
          style: TextStyle(fontSize: 12, color: urgent ? AppColors.danger : cs.onSurfaceVariant),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _statusColor(lead.status).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(_statusLabel(lead.status),
              style: TextStyle(fontSize: 11, color: _statusColor(lead.status), fontWeight: FontWeight.w700)),
        ),
      ),
      if (!isLast)
        Divider(height: 1, indent: 56, color: cs.outlineVariant.withValues(alpha: 0.4)),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CAMPAIGNS TAB
// ══════════════════════════════════════════════════════════════════════════════

class _CampaignsTab extends StatelessWidget {
  const _CampaignsTab({required this.leads, required this.marketId});
  final List<LeadModel> leads;
  final String marketId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dk = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder(
      valueListenable: CampaignService.instance.campaigns,
      builder: (context, List<CampaignModel> allCampaigns, _) {
        final campaigns = CampaignService.instance.forMarket(marketId);
        final totalBudget = campaigns.fold(0.0, (s, c) => s + c.budget);

        // Count leads per campaign
        final leadsByCampaign = <String, int>{};
        for (final l in leads) {
          if (l.campaign != null && l.campaign!.isNotEmpty) {
            leadsByCampaign[l.campaign!] = (leadsByCampaign[l.campaign!] ?? 0) + 1;
          }
        }
        final assignedLeads = leadsByCampaign.values.fold(0, (s, v) => s + v);
        final unassigned = leads.length - assignedLeads;

        String fmtBudget(double v) {
          return context.read<AppState>().selectedMarket.fmtRevenue(v);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Campaign Analytics',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.md),

              // KPI strip
              Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.md, children: [
                _KpiCard(label: 'Active Campaigns', value: '${campaigns.length}', icon: Icons.campaign_outlined, color: const Color(0xFF2196F3), dk: dk),
                _KpiCard(label: 'Total Budget', value: fmtBudget(totalBudget), icon: Icons.account_balance_wallet_outlined, color: const Color(0xFF9C27B0), dk: dk),
                _KpiCard(
                  label: 'Avg CPL',
                  value: assignedLeads > 0 ? fmtBudget(totalBudget / assignedLeads) : '-',
                  icon: Icons.price_check_rounded,
                  color: AppColors.success,
                  dk: dk,
                  subtitle: assignedLeads > 0 ? '$assignedLeads leads assigned' : 'No leads assigned yet',
                ),
                _KpiCard(label: 'Unassigned Leads', value: '$unassigned', icon: Icons.person_off_outlined, color: AppColors.warning, dk: dk, subtitle: 'not linked to any campaign'),
              ]),
              const SizedBox(height: AppSpacing.xl),

              if (campaigns.isEmpty)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(children: [
                      Icon(Icons.campaign_outlined, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text('No campaigns yet', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Create campaigns from the Campaigns page to see analytics here.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          textAlign: TextAlign.center),
                    ]),
                  ),
                )
              else ...[
                // Campaign comparison table
                Text('Campaign Comparison',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.sm),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Header
                        Row(children: [
                          Expanded(flex: 3, child: Text('Campaign', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurfaceVariant))),
                          Expanded(flex: 2, child: Text('Budget', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurfaceVariant), textAlign: TextAlign.right)),
                          Expanded(flex: 1, child: Text('Leads', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurfaceVariant), textAlign: TextAlign.right)),
                          Expanded(flex: 2, child: Text('CPL', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurfaceVariant), textAlign: TextAlign.right)),
                        ]),
                        const Divider(height: 16),
                        ...campaigns.map((c) {
                          final count = leadsByCampaign[c.id] ?? 0;
                          final cpl = count > 0 ? c.budget / count : 0.0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(children: [
                              Expanded(flex: 3, child: Text(c.name, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                              Expanded(flex: 2, child: Text(fmtBudget(c.budget), style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.right)),
                              Expanded(flex: 1, child: Text('$count', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
                              Expanded(flex: 2, child: Text(count > 0 ? fmtBudget(cpl) : '-', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: count > 0 ? AppColors.success : cs.onSurfaceVariant), textAlign: TextAlign.right)),
                            ]),
                          );
                        }),
                        const Divider(height: 16),
                        // Total row
                        Row(children: [
                          Expanded(flex: 3, child: Text('Total', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800))),
                          Expanded(flex: 2, child: Text(fmtBudget(totalBudget), style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
                          Expanded(flex: 1, child: Text('$assignedLeads', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.right)),
                          Expanded(flex: 2, child: Text(assignedLeads > 0 ? fmtBudget(totalBudget / assignedLeads) : '-', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: AppColors.success), textAlign: TextAlign.right)),
                        ]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Budget distribution bar
                Text('Budget Distribution',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.sm),
                if (totalBudget > 0)
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              height: 14,
                              child: Row(
                                children: campaigns.map((c) {
                                  if (c.budget <= 0) return const SizedBox.shrink();
                                  return Expanded(
                                    flex: (c.budget * 100 / totalBudget).round().clamp(1, 100),
                                    child: Container(color: _campaignColor(campaigns.indexOf(c))),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(spacing: 14, runSpacing: 6, children: campaigns.map((c) {
                            final pct = totalBudget > 0 ? (c.budget / totalBudget * 100).toStringAsFixed(0) : '0';
                            final idx = campaigns.indexOf(c);
                            return Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(width: 9, height: 9, decoration: BoxDecoration(color: _campaignColor(idx), borderRadius: BorderRadius.circular(3))),
                              const SizedBox(width: 5),
                              Text('${c.name} ($pct%)', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                            ]);
                          }).toList()),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

Color _campaignColor(int index) {
  const colors = [
    Color(0xFF2196F3), Color(0xFF9C27B0), Color(0xFF4CAF50),
    Color(0xFFFF9800), Color(0xFFE91E63), Color(0xFF00BCD4),
    Color(0xFF795548), Color(0xFF607D8B),
  ];
  return colors[index % colors.length];
}

// ══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════════════════════════════════════════

String _statusLabel(LeadStatus s) {
  switch (s) {
    case LeadStatus.fresh: return 'Fresh';
    case LeadStatus.interested: return 'Interested';
    case LeadStatus.followUp: return 'Follow Up';
    case LeadStatus.noAnswer: return 'No Answer';
    case LeadStatus.converted: return 'Converted';
    case LeadStatus.notInterested: return 'Not Interested';
    case LeadStatus.closed: return 'Closed';
  }
}

String _sourceLabel(LeadSource s) {
  switch (s) {
    case LeadSource.whatsapp: return 'WhatsApp';
    case LeadSource.instagram: return 'Instagram';
    case LeadSource.facebook: return 'Facebook';
    case LeadSource.linkedin: return 'LinkedIn';
    case LeadSource.tiktok: return 'TikTok';
    case LeadSource.web: return 'Website';
    case LeadSource.email: return 'Email';
    case LeadSource.phone: return 'Phone';
    case LeadSource.manual: return 'Manual';
    case LeadSource.imported: return 'Imported';
  }
}

Color _statusColor(LeadStatus s) {
  switch (s) {
    case LeadStatus.fresh: return const Color(0xFF2196F3);
    case LeadStatus.interested: return AppColors.success;
    case LeadStatus.followUp: return AppColors.warning;
    case LeadStatus.noAnswer: return const Color(0xFFFFC107);
    case LeadStatus.converted: return const Color(0xFF9C27B0);
    case LeadStatus.notInterested: return AppColors.danger;
    case LeadStatus.closed: return const Color(0xFF607D8B);
  }
}

Color _sourceColor(LeadSource s) {
  switch (s) {
    case LeadSource.whatsapp: return const Color(0xFF25D366);
    case LeadSource.instagram: return const Color(0xFFE1306C);
    case LeadSource.facebook: return const Color(0xFF1877F2);
    case LeadSource.linkedin: return const Color(0xFF0A66C2);
    case LeadSource.tiktok: return const Color(0xFF333333);
    case LeadSource.web: return const Color(0xFF607D8B);
    case LeadSource.email: return const Color(0xFF4285F4);
    case LeadSource.phone: return const Color(0xFF34A853);
    case LeadSource.manual: return AppColors.warning;
    case LeadSource.imported: return const Color(0xFF9E9E9E);
  }
}
