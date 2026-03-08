import 'package:anis_crm/components/priorities_panel.dart';
import 'package:anis_crm/engine/priorities_engine.dart';
import 'package:anis_crm/engine/insights_engine.dart';
import 'package:anis_crm/services/ai_executor.dart';
import 'package:anis_crm/services/lead_service.dart';
import 'package:anis_crm/services/activity_service.dart';
import 'package:anis_crm/services/task_service.dart';
import 'package:anis_crm/services/campaign_service.dart';
import 'package:anis_crm/models/campaign.dart';
import 'package:anis_crm/state/app_state.dart';
import 'package:anis_crm/models/lead.dart';
import 'package:anis_crm/models/market.dart';
import 'package:anis_crm/models/activity.dart';
import 'package:anis_crm/models/task_model.dart';
import 'package:anis_crm/theme.dart';
import 'package:flutter/material.dart';
import 'package:anis_crm/components/scripts_sheet.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:anis_crm/components/staggered_list.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD PAGE
// ─────────────────────────────────────────────────────────────────────────────

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──
        _DashboardHeader(),
        const SizedBox(height: AppSpacing.lg),

        // ── KPI + Tasks driven by live data ──
        ValueListenableBuilder(
          valueListenable: LeadService.instance.leads,
          builder: (context, List<LeadModel> allLeads, _) {
            // Filter by selected market
            final market = context.watch<AppState>().selectedMarket;
            final leads = allLeads.where((l) => l.country == market.id).toList();
            return ValueListenableBuilder(
              valueListenable: TaskService.instance.tasks,
              builder: (context, List<TaskModel> tasks, _) {
                return _DashboardBody(leads: leads, tasks: tasks, market: market);
              },
            );
          },
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final dateStr = '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
    final cs = Theme.of(context).colorScheme;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AnimateIn(
        delay: const Duration(milliseconds: 60),
        child: Text(greeting, style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
      ),
      const SizedBox(height: 4),
      AnimateIn(
        delay: const Duration(milliseconds: 100),
        child: Text(dateStr, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN BODY
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.leads, required this.tasks, required this.market});
  final List<LeadModel> leads;
  final List<TaskModel> tasks;
  final Market market;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    bool isToday(DateTime? dt) =>
        dt != null && dt.year == now.year && dt.month == now.month && dt.day == now.day;

    final total = leads.length;
    final counts = <LeadStatus, int>{for (final s in LeadStatus.values) s: 0};
    for (final l in leads) { counts[l.status] = (counts[l.status] ?? 0) + 1; }

    final active = (counts[LeadStatus.fresh] ?? 0) +
        (counts[LeadStatus.interested] ?? 0) +
        (counts[LeadStatus.followUp] ?? 0) +
        (counts[LeadStatus.noAnswer] ?? 0);
    final converted = counts[LeadStatus.converted] ?? 0;
    final convRate = total > 0 ? (converted / total * 100) : 0.0;
    final revenue = leads
        .where((l) => l.status == LeadStatus.converted && l.dealValue != null)
        .fold(0.0, (s, l) => s + l.dealValue!);

    final followupsToday = leads.where((l) => isToday(l.nextFollowupAt)).toList();
    final overdueFollowups = leads
        .where((l) => l.nextFollowupAt != null && l.nextFollowupAt!.isBefore(now) && !isToday(l.nextFollowupAt))
        .toList()
      ..sort((a, b) => a.nextFollowupAt!.compareTo(b.nextFollowupAt!));

    final dueTasks = tasks
        .where((t) => t.status.apiName != 'done' && isToday(DateTime.tryParse(t.dueDate ?? '')))
        .length;
    final overdueTasks = tasks
        .where((t) => t.status.apiName != 'done' && t.dueDate != null && DateTime.tryParse(t.dueDate!)?.isBefore(now) == true && !isToday(DateTime.tryParse(t.dueDate!)))
        .length;
    final doneTasks = tasks.where((t) => t.status.apiName == 'done').length;

    final dk = Theme.of(context).brightness == Brightness.dark;

    String fmtRev(double v) {
      return market.fmtRevenue(v);
    }

    // Empty state
    if (total == 0) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _KpiGrid(metrics: [
          _KpiData('Total Leads', '0', Icons.people_outline_rounded, AppColors.info, dk),
          _KpiData('Active Pipeline', '0', Icons.moving_rounded, const Color(0xFF2196F3), dk),
          _KpiData('Converted', '0', Icons.check_circle_outline_rounded, AppColors.success, dk),
          _KpiData('Revenue', '0 ${market.currency}', Icons.monetization_on_outlined, const Color(0xFF9C27B0), dk),
        ]),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: AppSpacing.paddingLg,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Welcome! Let\'s get you started', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Add your first leads or import a file to begin tracking progress.', style: Theme.of(context).textTheme.bodyMedium?.withColor(Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                FilledButton.icon(onPressed: () => context.go('/app/leads'), icon: const Icon(Icons.person_add_alt_1), label: const Text('Add lead')),
                OutlinedButton.icon(onPressed: () => context.go('/app/leads'), icon: const Icon(Icons.file_upload_outlined), label: const Text('Import leads')),
              ]),
            ]),
          ),
        ),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── KPI Cards ──
      _KpiGrid(metrics: [
        _KpiData('Total Leads', '$total', Icons.people_outline_rounded, AppColors.info, dk, subtitle: '${leads.where((l) => l.createdAt.year == now.year && l.createdAt.month == now.month).length} new this month'),
        _KpiData('Active Pipeline', '$active', Icons.moving_rounded, const Color(0xFF2196F3), dk, subtitle: 'fresh + interested + follow-up'),
        _KpiData('Converted', '$converted', Icons.check_circle_outline_rounded, AppColors.success, dk, subtitle: '${convRate.toStringAsFixed(1)}% conversion rate'),
        _KpiData('Revenue', fmtRev(revenue), Icons.monetization_on_outlined, const Color(0xFF9C27B0), dk, subtitle: 'from converted leads'),
        _KpiData('Follow-ups Today', '${followupsToday.length}', Icons.alarm_rounded, AppColors.warning, dk,
            subtitle: overdueFollowups.isNotEmpty ? '${overdueFollowups.length} overdue' : 'all on track',
            urgent: overdueFollowups.isNotEmpty),
        _KpiData('Tasks Today', '$dueTasks', Icons.task_alt_rounded, AppColors.info, dk,
            subtitle: overdueTasks > 0 ? '$overdueTasks overdue • $doneTasks done' : '$doneTasks done',
            urgent: overdueTasks > 0),
      ]),

      const SizedBox(height: AppSpacing.lg),

      // ── Campaign KPIs ──
      _CampaignKpiStrip(leads: leads, market: market, dk: dk),

      const SizedBox(height: AppSpacing.lg),

      // ── Pipeline snapshot ──
      _PipelineSnapshot(leads: leads, counts: counts, total: total),

      const SizedBox(height: AppSpacing.lg),

      // ── What to do today ──
      Text('What to do today', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      _PrioritiesSection(leads: leads),

      const SizedBox(height: AppSpacing.lg),

      // ── AI Insights ──
      _AiInsightsSection(leads: leads),

      const SizedBox(height: AppSpacing.lg),

      // ── Follow-ups ──
      _FollowupsCard(followupsToday: followupsToday, overdueFollowups: overdueFollowups),

      const SizedBox(height: AppSpacing.lg),

      // ── Recent Activity ──
      _RecentActivityCard(),

      const SizedBox(height: AppSpacing.lg),

      // ── Quick Actions ──
      _ShortcutsRow(),

      const SizedBox(height: AppSpacing.lg),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI GRID
// ─────────────────────────────────────────────────────────────────────────────

class _KpiData {
  const _KpiData(this.label, this.value, this.icon, this.color, this.dk, {this.subtitle, this.urgent = false});
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool dk;
  final String? subtitle;
  final bool urgent;
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.metrics});
  final List<_KpiData> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth >= 1100 ? 6 : c.maxWidth >= 800 ? 3 : 2;
      return Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
        ...metrics.map((m) => SizedBox(
          width: (c.maxWidth - (cols - 1) * AppSpacing.sm) / cols,
          child: _KpiCard(data: m),
        )),
      ]);
    });
  }
}

class _KpiCard extends StatefulWidget {
  const _KpiCard({required this.data});
  final _KpiData data;
  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = widget.data.urgent ? AppColors.danger : widget.data.color;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        child: Card(
          elevation: _hovered ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: widget.data.urgent
                ? BorderSide(color: AppColors.danger.withValues(alpha: 0.4))
                : BorderSide(color: cs.outline.withValues(alpha: _hovered ? 0.15 : 0.06)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: widget.data.dk ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.data.icon, color: c, size: 18),
                ),
                if (widget.data.urgent) ...[
                  const Spacer(),
                  Icon(Icons.circle, color: AppColors.danger, size: 8),
                ],
              ]),
              const SizedBox(height: 12),
              Text(widget.data.value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800, letterSpacing: -0.5,
                    color: widget.data.urgent ? AppColors.danger : c,
                  )),
              const SizedBox(height: 2),
              Text(widget.data.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
              if (widget.data.subtitle != null) ...[
                const SizedBox(height: 4),
                Text(widget.data.subtitle!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PIPELINE SNAPSHOT
// ─────────────────────────────────────────────────────────────────────────────

class _PipelineSnapshot extends StatelessWidget {
  const _PipelineSnapshot({required this.leads, required this.counts, required this.total});
  final List<LeadModel> leads;
  final Map<LeadStatus, int> counts;
  final int total;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (total == 0) return const SizedBox.shrink();

    const stages = [
      (s: LeadStatus.fresh, label: 'Fresh', color: Color(0xFF2196F3)),
      (s: LeadStatus.interested, label: 'Interested', color: AppColors.success),
      (s: LeadStatus.followUp, label: 'Follow Up', color: AppColors.warning),
      (s: LeadStatus.noAnswer, label: 'No Answer', color: Color(0xFFFFC107)),
      (s: LeadStatus.converted, label: 'Converted', color: Color(0xFF9C27B0)),
      (s: LeadStatus.notInterested, label: 'Not Interested', color: AppColors.danger),
      (s: LeadStatus.closed, label: 'Closed', color: Color(0xFF607D8B)),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.stacked_bar_chart_rounded, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Text('Pipeline Snapshot', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            TextButton(
              onPressed: () => context.go('/app/pipeline'),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero),
              child: const Text('View full pipeline'),
            ),
          ]),
          const SizedBox(height: 12),

          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 18,
              child: Row(
                children: stages.map((st) {
                  final count = counts[st.s] ?? 0;
                  if (count == 0) return const SizedBox.shrink();
                  return Expanded(flex: count, child: Container(color: st.color));
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Legend
          Wrap(spacing: 14, runSpacing: 6,
            children: stages.map((st) {
              final count = counts[st.s] ?? 0;
              if (count == 0) return const SizedBox.shrink();
              final pct = (count / total * 100).toStringAsFixed(0);
              return Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 9, height: 9, decoration: BoxDecoration(color: st.color, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 5),
                Text('${st.label} $count ($pct%)', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
              ]);
            }).toList(),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOLLOW-UPS CARD
// ─────────────────────────────────────────────────────────────────────────────

class _FollowupsCard extends StatelessWidget {
  const _FollowupsCard({required this.followupsToday, required this.overdueFollowups});
  final List<LeadModel> followupsToday;
  final List<LeadModel> overdueFollowups;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasItems = followupsToday.isNotEmpty || overdueFollowups.isNotEmpty;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: overdueFollowups.isNotEmpty
            ? BorderSide(color: AppColors.danger.withValues(alpha: 0.3))
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.alarm_rounded, size: 18,
                color: overdueFollowups.isNotEmpty ? AppColors.danger : cs.primary),
            const SizedBox(width: 8),
            Text("Today's Follow-ups",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            if (overdueFollowups.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${overdueFollowups.length} overdue',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.danger, fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
          const SizedBox(height: 10),
          if (!hasItems)
            Text('No follow-ups scheduled for today.',
                style: Theme.of(context).textTheme.bodyMedium?.withColor(cs.onSurfaceVariant))
          else ...[
            ...overdueFollowups.map((l) => _FollowupTile(lead: l, overdue: true, cs: cs, context: context)),
            ...followupsToday.map((l) => _FollowupTile(lead: l, overdue: false, cs: cs, context: context)),
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => context.go('/app/calendar'),
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: const Text('Open calendar'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _FollowupTile extends StatelessWidget {
  const _FollowupTile({required this.lead, required this.overdue, required this.cs, required this.context});
  final LeadModel lead;
  final bool overdue;
  final ColorScheme cs;
  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(lead.status);
    final daysAgo = overdue && lead.nextFollowupAt != null ? DateTime.now().difference(lead.nextFollowupAt!).inDays : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Text(
            lead.name.isNotEmpty ? lead.name[0].toUpperCase() : '?',
            style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(lead.name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            if (overdue)
              Text('${daysAgo > 0 ? '$daysAgo day${daysAgo > 1 ? 's' : ''} overdue' : 'Was due today'} \u00b7 ${lead.phone ?? ''}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.danger)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(_statusLabel(lead.status), style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 6),
        TextButton(
          onPressed: () => context.push('/app/lead/${lead.id}'),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero),
          child: const Text('Open'),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRIORITIES
// ─────────────────────────────────────────────────────────────────────────────

class _PrioritiesSection extends StatelessWidget {
  const _PrioritiesSection({required this.leads});
  final List<LeadModel> leads;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final useAi = app.aiConnected && app.aiPrioritiesEnabled;
    if (!useAi) {
      final priorities = PrioritiesEngine.generate(leads);
      return PrioritiesPanel(priorities: priorities);
    }
    return FutureBuilder(
      future: AiExecutor.instance.priorities(app, leads),
      builder: (context, AsyncSnapshot<List<LeadPriority>> snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Card(
            child: Padding(
              padding: AppSpacing.paddingLg,
              child: Row(children: [
                const SizedBox(width: 4),
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Text('Loading AI priorities\u2026', style: Theme.of(context).textTheme.bodyMedium),
              ]),
            ),
          );
        }
        if (snap.hasError || !snap.hasData) {
          final fallback = PrioritiesEngine.generate(leads);
          return PrioritiesPanel(priorities: fallback, note: 'AI unavailable. Showing rule-based priorities.');
        }
        final list = snap.data!;
        return PrioritiesPanel(
          priorities: list.isEmpty ? PrioritiesEngine.generate(leads) : list,
          note: list.isEmpty ? 'AI returned no priorities. Showing rule-based instead.' : null,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RECENT ACTIVITY
// ─────────────────────────────────────────────────────────────────────────────

class _RecentActivityCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder(
      valueListenable: ActivityService.instance.byLead,
      builder: (context, Map<String, List<ActivityModel>> byLead, _) {
        final all = <ActivityModel>[];
        byLead.forEach((_, list) => all.addAll(list));
        all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final recent = all.take(6).toList();

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.bolt_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text('Recent Activity', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 10),
              if (recent.isEmpty)
                Text('No recent activity yet.', style: Theme.of(context).textTheme.bodyMedium?.withColor(cs.onSurfaceVariant))
              else
                ...recent.asMap().entries.map((entry) {
                  final i = entry.key;
                  final a = entry.value;
                  final lead = LeadService.instance.leads.value.firstWhere(
                    (l) => l.id == a.leadId,
                    orElse: () => LeadModel(
                      id: a.leadId, name: 'Unknown lead',
                      status: LeadStatus.interested,
                      createdAt: DateTime.now(), updatedAt: DateTime.now(),
                    ),
                  );
                  final icon = switch (a.type) {
                    ActivityType.note => Icons.note_outlined,
                    ActivityType.call => Icons.phone_outlined,
                    ActivityType.message => Icons.chat_bubble_outline,
                    ActivityType.followup => Icons.event_note_outlined,
                  };
                  return Column(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                          child: Icon(icon, size: 15, color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${lead.name} \u2022 ${a.type.name}${a.text != null ? ': ${a.text}' : ''}',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(a.createdAt.toLocal().toString().substring(0, 16),
                            style: Theme.of(context).textTheme.labelSmall?.withColor(cs.onSurfaceVariant)),
                      ]),
                    ),
                    if (i < recent.length - 1)
                      Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),
                  ]);
                }),
            ]),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK ACTIONS
// ─────────────────────────────────────────────────────────────────────────────

class _ShortcutsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.grid_view_rounded, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _QuickActionBtn(icon: Icons.person_add_alt_1, label: 'Add Lead', color: cs.primary, onTap: () => context.go('/app/leads')),
            _QuickActionBtn(icon: Icons.calendar_today_outlined, label: 'Follow-ups', color: AppColors.info, onTap: () => context.go('/app/calendar')),
            _QuickActionBtn(icon: Icons.view_kanban, label: 'Pipeline', color: const Color(0xFF9C27B0), onTap: () => context.go('/app/pipeline')),
            _QuickActionBtn(icon: Icons.menu_book_outlined, label: 'Call Scripts', color: AppColors.success,
                onTap: () => showModalBottomSheet(
                  context: context, isScrollControlled: true, useSafeArea: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const CallScriptsSheet(),
                )),
            _QuickActionBtn(icon: Icons.task_outlined, label: 'Tasks', color: Colors.orange, onTap: () => context.go('/app/tasks')),
            _QuickActionBtn(icon: Icons.chat_outlined, label: 'Team Chat', color: const Color(0xFF00897B), onTap: () => context.go('/app/chat')),
            _QuickActionBtn(icon: Icons.bar_chart_rounded, label: 'Reports', color: AppColors.warning, onTap: () => context.go('/app/reports')),
          ]),
        ]),
      ),
    );
  }
}

class _QuickActionBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionBtn({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  State<_QuickActionBtn> createState() => _QuickActionBtnState();
}

class _QuickActionBtnState extends State<_QuickActionBtn> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _hovered ? widget.color.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _hovered ? widget.color.withValues(alpha: 0.25) : Theme.of(context).colorScheme.outline.withValues(alpha: 0.12)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(widget.icon, size: 18, color: widget.color),
            const SizedBox(width: 10),
            Text(widget.label, style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: _hovered ? widget.color : Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI INSIGHTS
// ─────────────────────────────────────────────────────────────────────────────

class _AiInsightsSection extends StatelessWidget {
  const _AiInsightsSection({required this.leads});
  final List<LeadModel> leads;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final deterministicInsights = InsightsEngine.generate(leads);
    final useAi = app.aiConnected && app.aiInsightsEnabled;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.auto_awesome, color: cs.primary, size: 18),
            const SizedBox(width: 8),
            Text('AI Insights', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: useAi ? AppColors.infoBg : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                useAi ? 'AI (local)' : 'Rule-based',
                style: Theme.of(context).textTheme.labelSmall?.withColor(useAi ? AppColors.info : cs.onSurfaceVariant),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text('Key observations about your pipeline',
              style: Theme.of(context).textTheme.bodySmall?.withColor(cs.onSurfaceVariant)),
          const SizedBox(height: 14),

          if (deterministicInsights.isEmpty && !useAi)
            Container(
              padding: AppSpacing.paddingMd,
              decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Text('No notable patterns detected today.', style: Theme.of(context).textTheme.bodyMedium),
            )
          else
            ...deterministicInsights.map((i) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(padding: EdgeInsets.only(top: 6), child: Icon(Icons.circle, size: 5, color: Colors.black54)),
                const SizedBox(width: 8),
                Expanded(child: Text(i.text, style: Theme.of(context).textTheme.bodyMedium)),
              ]),
            )),

          if (useAi && leads.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            FutureBuilder<String>(
              future: AiExecutor.instance.aiDailyInsights(app, leads),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Row(children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)),
                    const SizedBox(width: 12),
                    Text('Analyzing your pipeline with AI\u2026', style: Theme.of(context).textTheme.bodyMedium?.withColor(cs.onSurfaceVariant)),
                  ]);
                }
                if (snap.hasError || !snap.hasData || snap.data!.isEmpty) {
                  return Text('AI analysis unavailable.', style: Theme.of(context).textTheme.bodySmall?.withColor(cs.onSurfaceVariant));
                }
                return Container(
                  width: double.infinity,
                  padding: AppSpacing.paddingMd,
                  decoration: BoxDecoration(
                    color: AppColors.infoBg,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.info.withValues(alpha: 0.15)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.auto_awesome, size: 14, color: AppColors.info),
                      const SizedBox(width: 6),
                      Text('AI Analysis', style: Theme.of(context).textTheme.labelMedium?.semiBold.withColor(AppColors.info)),
                    ]),
                    const SizedBox(height: 8),
                    SelectableText(snap.data!, style: Theme.of(context).textTheme.bodyMedium?.withHeight(1.5)),
                  ]),
                );
              },
            ),
          ],
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CAMPAIGN KPI STRIP
// ─────────────────────────────────────────────────────────────────────────────

class _CampaignKpiStrip extends StatelessWidget {
  const _CampaignKpiStrip({required this.leads, required this.market, required this.dk});
  final List<LeadModel> leads;
  final Market market;
  final bool dk;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: CampaignService.instance.campaigns,
      builder: (context, List<CampaignModel> allCampaigns, _) {
        final campaigns = CampaignService.instance.forMarket(market.id);
        if (campaigns.isEmpty) return const SizedBox.shrink();

        final totalBudget = campaigns.fold(0.0, (s, c) => s + c.budget);
        final assignedLeads = leads.where((l) => l.campaign != null && l.campaign!.isNotEmpty).length;
        final avgCpl = assignedLeads > 0 ? totalBudget / assignedLeads : 0.0;
        final fmtBudget = market.fmtRevenue(totalBudget);
        final fmtCpl = assignedLeads > 0 ? market.fmtRevenue(avgCpl) : '-';

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(color: const Color(0xFF2196F3).withValues(alpha: 0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.campaign_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Campaigns', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton(
                  onPressed: () => GoRouter.of(context).go('/app/campaigns'),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero),
                  child: const Text('View all'),
                ),
              ]),
              const SizedBox(height: 12),
              _KpiGrid(metrics: [
                _KpiData('Active', '${campaigns.length}', Icons.campaign_outlined, const Color(0xFF2196F3), dk),
                _KpiData('Total Spend', fmtBudget, Icons.account_balance_wallet_outlined, const Color(0xFF9C27B0), dk),
                _KpiData('Avg CPL', fmtCpl, Icons.price_check_rounded, AppColors.success, dk, subtitle: '$assignedLeads leads assigned'),
              ]),
            ]),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

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
