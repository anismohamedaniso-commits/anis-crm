import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/campaign.dart';
import '../models/lead.dart';
import '../models/market.dart';
import '../services/campaign_service.dart';
import '../services/lead_service.dart';
import '../state/app_state.dart';
import '../theme.dart';

const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

// =============================================================================
// CAMPAIGNS PAGE
// =============================================================================

class CampaignsPage extends StatefulWidget {
  const CampaignsPage({super.key});
  @override
  State<CampaignsPage> createState() => _CampaignsPageState();
}

class _CampaignsPageState extends State<CampaignsPage> {
  @override
  void initState() {
    super.initState();
    CampaignService.instance.load();
    LeadService.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final market = context.watch<AppState>().selectedMarket;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(
        children: [
          _TopBar(market: market, onAdd: () => _showCreateDialog(context, market)),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: CampaignService.instance.campaigns,
              builder: (context, List<CampaignModel> allCampaigns, _) {
                final campaigns = allCampaigns
                    .where((c) => c.market == market.id || c.market == 'all')
                    .toList()
                  ..sort((a, b) => b.startDate.compareTo(a.startDate));
                if (campaigns.isEmpty) {
                  return _EmptyState(onAdd: () => _showCreateDialog(context, market));
                }
                return ValueListenableBuilder(
                  valueListenable: LeadService.instance.leads,
                  builder: (context, List<LeadModel> allLeads, _) {
                    final marketLeads = allLeads.where((l) => l.country == market.id).toList();
                    return ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: campaigns.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                      itemBuilder: (_, i) => _CampaignCard(
                        campaign: campaigns[i],
                        leads: marketLeads.where((l) => l.campaign == campaigns[i].id).toList(),
                        allMarketLeads: marketLeads,
                        market: market,
                        onEdit: () => _showEditDialog(context, campaigns[i], market),
                        onDelete: () => _confirmDelete(context, campaigns[i]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, Market market) async {
    final created = await showDialog<CampaignModel>(
      context: context,
      builder: (_) => _CampaignEditorDialog(market: market),
    );
    if (created != null && mounted) setState(() {});
  }

  Future<void> _showEditDialog(BuildContext context, CampaignModel campaign, Market market) async {
    final updated = await showDialog<CampaignModel>(
      context: context,
      builder: (_) => _CampaignEditorDialog(market: market, existing: campaign),
    );
    if (updated != null && mounted) setState(() {});
  }

  Future<void> _confirmDelete(BuildContext context, CampaignModel campaign) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Campaign'),
        content: Text('Delete "${campaign.name}"? Leads won\'t be deleted, but their campaign assignment will be cleared.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        // Clear campaign from leads that reference this campaign
        final leads = LeadService.instance.leads.value.where((l) => l.campaign == campaign.id).toList();
        for (final l in leads) {
          await LeadService.instance.update(l.copyWith(campaign: ''));
        }
        await CampaignService.instance.delete(campaign.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${campaign.name}" deleted')),
          );
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e')),
          );
          setState(() {});
        }
      }
    }
  }
}

// =============================================================================
// TOP BAR
// =============================================================================

class _TopBar extends StatelessWidget {
  final Market market;
  final VoidCallback onAdd;
  const _TopBar({required this.market, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width < 500 ? 12 : 20,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          Text('${market.flag} Campaigns',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New Campaign'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// EMPTY STATE
// =============================================================================

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.campaign_outlined, size: 56, color: cs.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: AppSpacing.md),
          Text('No campaigns yet', style: context.textStyles.titleSmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: AppSpacing.sm),
          Text('Create your first campaign to start tracking CPL', style: context.textStyles.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.3))),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create Campaign'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// CAMPAIGN CARD (Dashboard per campaign)
// =============================================================================

class _CampaignCard extends StatefulWidget {
  final CampaignModel campaign;
  final List<LeadModel> leads;
  final List<LeadModel> allMarketLeads;
  final Market market;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CampaignCard({
    required this.campaign,
    required this.leads,
    required this.allMarketLeads,
    required this.market,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_CampaignCard> createState() => _CampaignCardState();
}

class _CampaignCardState extends State<_CampaignCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final c = widget.campaign;
    final leads = widget.leads;
    final mkt = widget.market;

    final totalLeads = leads.length;
    final cpl = totalLeads > 0 ? c.budget / totalLeads : 0.0;
    final converted = leads.where((l) => l.status == LeadStatus.converted).length;
    final conversionRate = totalLeads > 0 ? (converted / totalLeads * 100) : 0.0;
    final cpa = converted > 0 ? c.budget / converted : 0.0;

    // Status breakdown
    final statusCounts = <LeadStatus, int>{};
    for (final l in leads) {
      statusCounts[l.status] = (statusCounts[l.status] ?? 0) + 1;
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────
          InkWell(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppRadius.lg),
              topRight: Radius.circular(AppRadius.lg),
            ),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(Icons.campaign_rounded, color: cs.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(c.name, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 8),
                            _StatusBadge(status: c.status),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_fmtDate(c.startDate)}${c.endDate != null ? ' – ${_fmtDate(c.endDate!)}' : ''}  ·  ${_marketLabel(c.market)}',
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        if (c.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            c.description,
                            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                            maxLines: _expanded ? 5 : 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, size: 20, color: cs.onSurfaceVariant),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      if (c.isActive)
                        const PopupMenuItem(value: 'pause', child: Text('Pause Campaign')),
                      if (c.isPaused)
                        const PopupMenuItem(value: 'resume', child: Text('Resume Campaign')),
                      if (!c.isCompleted)
                        const PopupMenuItem(value: 'complete', child: Text('Mark Completed')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                    onSelected: (v) {
                      if (v == 'edit') widget.onEdit();
                      if (v == 'delete') widget.onDelete();
                      if (v == 'pause') _setStatus('paused');
                      if (v == 'resume') _setStatus('active');
                      if (v == 'complete') _setStatus('completed');
                    },
                  ),
                  Icon(
                    _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // ── KPI strip ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth > 500;
              final cards = [
                _KpiItem('Total Leads', '$totalLeads', Icons.people_outline_rounded, cs.primary),
                _KpiItem('Budget', mkt.fmtRevenue(c.budget), Icons.account_balance_wallet_outlined, Colors.teal),
                _KpiItem('CPL', totalLeads > 0 ? '${cpl.toStringAsFixed(0)} ${mkt.currency}' : '—', Icons.trending_down_rounded, Colors.orange),
                _KpiItem('Converted', '$converted (${conversionRate.toStringAsFixed(0)}%)', Icons.check_circle_outline_rounded, Colors.green),
              ];
              if (wide) {
                return Row(
                  children: cards.map((k) => Expanded(child: _kpiTile(context, k))).toList(),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: cards.map((k) => SizedBox(width: (constraints.maxWidth - 8) / 2, child: _kpiTile(context, k))).toList(),
              );
            }),
          ),

          // ── Expanded detail ────────────────────────────
          if (_expanded) ...[
            Divider(height: 1, color: cs.outline.withValues(alpha: 0.08)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Campaign Overview Section ──
                  _SectionHeader(title: 'Campaign Overview', icon: Icons.info_outline_rounded),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _DetailChip(label: 'Duration', value: '${c.durationDays} days'),
                      _DetailChip(label: 'Status', value: c.status[0].toUpperCase() + c.status.substring(1)),
                      _DetailChip(label: 'Market', value: _marketLabel(c.market)),
                      _DetailChip(label: 'Created', value: _fmtDate(c.createdAt)),
                    ],
                  ),

                  // ── Lead Status Breakdown ──
                  const SizedBox(height: 18),
                  _SectionHeader(title: 'Lead Status Breakdown', icon: Icons.pie_chart_outline_rounded),
                  const SizedBox(height: 12),
                  if (leads.isEmpty)
                    Text('No leads assigned yet', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant))
                  else ...[
                    // Status bar visualization
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 10,
                        child: Row(
                          children: LeadStatus.values
                              .where((s) => (statusCounts[s] ?? 0) > 0)
                              .map((s) => Expanded(
                                    flex: statusCounts[s]!,
                                    child: Container(color: _statusColor(s, cs)),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...LeadStatus.values.where((s) => (statusCounts[s] ?? 0) > 0).map((s) {
                      final count = statusCounts[s]!;
                      final pct = (count / totalLeads * 100).toStringAsFixed(0);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _statusColor(s, cs),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_statusLabel(s),
                                  style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
                            ),
                            Text('$count ($pct%)',
                                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                          ],
                        ),
                      );
                    }),
                  ],

                  // ── Cost Analytics Section ──
                  if (totalLeads > 0) ...[
                    const SizedBox(height: 18),
                    _SectionHeader(title: 'Cost Analytics', icon: Icons.analytics_outlined),
                    const SizedBox(height: 12),
                    _AnalyticsRow(
                      icon: Icons.trending_down_rounded,
                      color: Colors.orange,
                      label: 'Cost Per Lead (CPL)',
                      value: '${cpl.toStringAsFixed(2)} ${mkt.currency}',
                    ),
                    if (converted > 0) ...[
                      const SizedBox(height: 8),
                      _AnalyticsRow(
                        icon: Icons.check_circle_outline,
                        color: Colors.green,
                        label: 'Cost Per Acquisition (CPA)',
                        value: '${cpa.toStringAsFixed(2)} ${mkt.currency}',
                      ),
                    ],
                    const SizedBox(height: 8),
                    _AnalyticsRow(
                      icon: Icons.speed_rounded,
                      color: Colors.deepPurple,
                      label: 'Conversion Rate',
                      value: '${conversionRate.toStringAsFixed(1)}%',
                    ),
                    if (c.durationDays > 0) ...[
                      const SizedBox(height: 8),
                      _AnalyticsRow(
                        icon: Icons.calendar_month_rounded,
                        color: Colors.blue,
                        label: 'Leads / Day',
                        value: (totalLeads / c.durationDays).toStringAsFixed(1),
                      ),
                      const SizedBox(height: 8),
                      _AnalyticsRow(
                        icon: Icons.attach_money_rounded,
                        color: Colors.teal,
                        label: 'Daily Spend Rate',
                        value: '${(c.budget / c.durationDays).toStringAsFixed(0)} ${mkt.currency}/day',
                      ),
                    ],
                    if (converted > 0) ...[
                      const SizedBox(height: 8),
                      _AnalyticsRow(
                        icon: Icons.show_chart_rounded,
                        color: Colors.indigo,
                        label: 'ROI Estimate',
                        value: '${(converted / totalLeads * 100).toStringAsFixed(0)}% yield',
                      ),
                    ],
                  ],

                  // ── Assign Leads button ──
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showBulkAssign(context),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                      label: const Text('Assign Leads'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _setStatus(String newStatus) async {
    final updated = widget.campaign.copyWith(status: newStatus);
    await CampaignService.instance.update(updated);
  }

  Future<void> _showBulkAssign(BuildContext context) async {
    final assigned = await showDialog<int>(
      context: context,
      builder: (_) => _BulkAssignDialog(
        campaign: widget.campaign,
        allMarketLeads: widget.allMarketLeads,
        market: widget.market,
      ),
    );
    if (assigned != null && assigned > 0 && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$assigned lead${assigned == 1 ? '' : 's'} assigned to "${widget.campaign.name}"')),
      );
    }
  }

  Widget _kpiTile(BuildContext context, _KpiItem k) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: k.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(k.icon, size: 16, color: k.color),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(k.label,
                    style: context.textStyles.labelSmall?.copyWith(color: cs.onSurfaceVariant, fontSize: 10)),
                Text(k.value,
                    style: context.textStyles.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: k.color),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _marketLabel(String m) {
    if (m == 'all') return 'All markets';
    return Market.byId(m).label;
  }

  String _statusLabel(LeadStatus s) => switch (s) {
        LeadStatus.fresh => 'Fresh',
        LeadStatus.interested => 'Interested',
        LeadStatus.noAnswer => 'No Answer',
        LeadStatus.followUp => 'Follow Up',
        LeadStatus.notInterested => 'Not Interested',
        LeadStatus.converted => 'Converted',
        LeadStatus.closed => 'Closed',
      };

  Color _statusColor(LeadStatus s, ColorScheme cs) => switch (s) {
        LeadStatus.fresh => Colors.blue,
        LeadStatus.interested => Colors.green,
        LeadStatus.noAnswer => Colors.orange,
        LeadStatus.followUp => Colors.purple,
        LeadStatus.notInterested => Colors.red,
        LeadStatus.converted => Colors.teal,
        LeadStatus.closed => Colors.grey,
      };
}

class _KpiItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiItem(this.label, this.value, this.icon, this.color);
}

// =============================================================================
// HELPER WIDGETS
// =============================================================================

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData icon) = switch (status) {
      'active' => (Colors.green.shade50, Colors.green.shade700, Icons.play_circle_outline_rounded),
      'paused' => (Colors.orange.shade50, Colors.orange.shade700, Icons.pause_circle_outline_rounded),
      'completed' => (Colors.blue.shade50, Colors.blue.shade700, Icons.check_circle_outline_rounded),
      _ => (Colors.grey.shade100, Colors.grey.shade600, Icons.circle_outlined),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(status[0].toUpperCase() + status.substring(1),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.primary),
        const SizedBox(width: 6),
        Text(title, style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface)),
      ],
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;
  final String value;
  const _DetailChip({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant, fontSize: 10)),
          Text(value, style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _AnalyticsRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _AnalyticsRow({required this.icon, required this.color, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w500))),
        Text(value, style: tt.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// =============================================================================
// BULK ASSIGN DIALOG
// =============================================================================

class _BulkAssignDialog extends StatefulWidget {
  final CampaignModel campaign;
  final List<LeadModel> allMarketLeads;
  final Market market;
  const _BulkAssignDialog({required this.campaign, required this.allMarketLeads, required this.market});
  @override
  State<_BulkAssignDialog> createState() => _BulkAssignDialogState();
}

class _BulkAssignDialogState extends State<_BulkAssignDialog> {
  final _search = TextEditingController();
  final _selected = <String>{};
  String _filter = 'unassigned'; // 'unassigned' | 'all' | 'other'
  bool _saving = false;

  List<LeadModel> get _filteredLeads {
    final q = _search.text.trim().toLowerCase();
    var list = widget.allMarketLeads;

    // Filter by assignment status
    if (_filter == 'unassigned') {
      list = list.where((l) => l.campaign == null || l.campaign!.isEmpty).toList();
    } else if (_filter == 'other') {
      // Leads assigned to OTHER campaigns (not this one)
      list = list.where((l) =>
          l.campaign != null && l.campaign!.isNotEmpty && l.campaign != widget.campaign.id).toList();
    }
    // 'all' shows everything not already in this campaign
    list = list.where((l) => l.campaign != widget.campaign.id).toList();

    // Search filter
    if (q.isNotEmpty) {
      list = list.where((l) {
        final name = l.name.toLowerCase();
        final phone = (l.phone ?? '').toLowerCase();
        final email = (l.email ?? '').toLowerCase();
        return name.contains(q) || phone.contains(q) || email.contains(q);
      }).toList();
    }
    return list;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final leads = _filteredLeads;
    final allSelected = leads.isNotEmpty && leads.every((l) => _selected.contains(l.id));

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
              child: Row(
                children: [
                  Icon(Icons.person_add_alt_1_rounded, size: 20, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Assign Leads to "${widget.campaign.name}"',
                        style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ── Search + filter ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search by name, phone, or email…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _filterChip('Unassigned', 'unassigned', cs),
                  const SizedBox(width: 6),
                  _filterChip('Other Campaigns', 'other', cs),
                  const SizedBox(width: 6),
                  _filterChip('All', 'all', cs),
                  const Spacer(),
                  Text('${_selected.length} selected',
                      style: tt.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // ── Select all ──
            if (leads.isNotEmpty)
              InkWell(
                onTap: () {
                  setState(() {
                    if (allSelected) {
                      _selected.removeAll(leads.map((l) => l.id));
                    } else {
                      _selected.addAll(leads.map((l) => l.id));
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: Checkbox(
                          value: allSelected,
                          tristate: false,
                          onChanged: (_) {
                            setState(() {
                              if (allSelected) {
                                _selected.removeAll(leads.map((l) => l.id));
                              } else {
                                _selected.addAll(leads.map((l) => l.id));
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('Select all (${leads.length})',
                          style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),

            Divider(height: 1, color: cs.outline.withValues(alpha: 0.08)),

            // ── Lead list ──
            Expanded(
              child: leads.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _search.text.isNotEmpty
                              ? 'No leads match your search'
                              : 'No available leads to assign',
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: leads.length,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemBuilder: (context, i) {
                        final lead = leads[i];
                        final checked = _selected.contains(lead.id);
                        final otherCampaign = (lead.campaign != null && lead.campaign!.isNotEmpty)
                            ? CampaignService.instance.byId(lead.campaign!)?.name
                            : null;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              if (checked) {
                                _selected.remove(lead.id);
                              } else {
                                _selected.add(lead.id);
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: Checkbox(
                                    value: checked,
                                    onChanged: (v) {
                                      setState(() {
                                        if (v == true) {
                                          _selected.add(lead.id);
                                        } else {
                                          _selected.remove(lead.id);
                                        }
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(lead.name,
                                          style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis),
                                      if (lead.phone != null && lead.phone!.isNotEmpty)
                                        Text(lead.phone!,
                                            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                                // Status pill
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _statusColorForBulk(lead.status, cs).withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    lead.status.name,
                                    style: tt.labelSmall?.copyWith(
                                      color: _statusColorForBulk(lead.status, cs),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                if (otherCampaign != null) ...[
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message: 'Currently in: $otherCampaign',
                                    child: Icon(Icons.swap_horiz_rounded, size: 16, color: Colors.orange.shade400),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // ── Actions ──
            Divider(height: 1, color: cs.outline.withValues(alpha: 0.08)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                children: [
                  if (_selected.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(() => _selected.clear()),
                      child: const Text('Clear Selection'),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _selected.isEmpty || _saving ? null : _assign,
                    icon: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text('Assign ${_selected.length} Lead${_selected.length == 1 ? '' : 's'}'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value, ColorScheme cs) {
    final active = _filter == value;
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 11)),
      selected: active,
      onSelected: (_) => setState(() => _filter = value),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
    );
  }

  Color _statusColorForBulk(LeadStatus s, ColorScheme cs) => switch (s) {
        LeadStatus.fresh => Colors.blue,
        LeadStatus.interested => Colors.green,
        LeadStatus.noAnswer => Colors.orange,
        LeadStatus.followUp => Colors.purple,
        LeadStatus.notInterested => Colors.red,
        LeadStatus.converted => Colors.teal,
        LeadStatus.closed => Colors.grey,
      };

  Future<void> _assign() async {
    if (_selected.isEmpty) return;
    setState(() => _saving = true);
    try {
      final count = await LeadService.instance.bulkSetCampaign(
        _selected.toList(),
        widget.campaign.id,
      );
      if (mounted) Navigator.pop(context, count);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _saving = false);
      }
    }
  }
}

// =============================================================================
// CAMPAIGN EDITOR DIALOG (Create / Edit)
// =============================================================================

class _CampaignEditorDialog extends StatefulWidget {
  final Market market;
  final CampaignModel? existing;
  const _CampaignEditorDialog({required this.market, this.existing});
  @override
  State<_CampaignEditorDialog> createState() => _CampaignEditorDialogState();
}

class _CampaignEditorDialogState extends State<_CampaignEditorDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  late String _marketId;
  late String _status;
  late DateTime _startDate;
  DateTime? _endDate;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _nameCtrl.text = widget.existing!.name;
      _descCtrl.text = widget.existing!.description;
      _budgetCtrl.text = widget.existing!.budget.toStringAsFixed(0);
      _marketId = widget.existing!.market;
      _status = widget.existing!.status;
      _startDate = widget.existing!.startDate;
      _endDate = widget.existing!.endDate;
    } else {
      _marketId = widget.market.id;
      _status = 'active';
      _startDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                children: [
                  Icon(Icons.campaign_rounded, size: 22, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_isEdit ? 'Edit Campaign' : 'New Campaign',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Campaign name
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Campaign Name *',
                  hintText: 'e.g. Facebook Lead Ads - Dec 2024',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 14),
              // Description
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Campaign objective, target audience, notes…',
                  border: OutlineInputBorder(),
                  isDense: true,
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 14),
              // Budget + Status row
              Row(children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _budgetCtrl,
                    decoration: InputDecoration(
                      labelText: 'Budget (${Market.byId(_marketId).currency})',
                      prefixText: '${Market.byId(_marketId).currencySymbol} ',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _status,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(value: 'paused', child: Text('Paused')),
                      DropdownMenuItem(value: 'completed', child: Text('Completed')),
                    ],
                    onChanged: (v) => setState(() => _status = v ?? _status),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              // Market
              DropdownButtonFormField<String>(
                value: _marketId,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Market',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: [
                  ...Market.all.map((m) => DropdownMenuItem(value: m.id, child: Text('${m.flag} ${m.label}'))),
                  const DropdownMenuItem(value: 'all', child: Text('🌍 All Markets')),
                ],
                onChanged: (v) => setState(() => _marketId = v ?? _marketId),
              ),
              const SizedBox(height: 14),
              // Dates row
              Row(children: [
                Expanded(
                  child: _DateButton(
                    label: 'Start Date',
                    date: _startDate,
                    onPick: () => _pickDate(isStart: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateButton(
                    label: 'End Date',
                    date: _endDate,
                    hint: 'Optional',
                    onPick: () => _pickDate(isStart: false),
                    onClear: _endDate != null ? () => setState(() => _endDate = null) : null,
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isEdit ? 'Update' : 'Create'),
                  ),
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final description = _descCtrl.text.trim();
    final budget = double.tryParse(_budgetCtrl.text.trim()) ?? 0;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        final updated = widget.existing!.copyWith(
          name: name,
          description: description,
          market: _marketId,
          budget: budget,
          status: _status,
          startDate: _startDate,
          endDate: _endDate,
          clearEndDate: _endDate == null,
        );
        await CampaignService.instance.update(updated);
        if (context.mounted) Navigator.pop(context, updated);
      } else {
        final created = await CampaignService.instance.create(
          name: name,
          description: description,
          market: _marketId,
          budget: budget,
          status: _status,
          startDate: _startDate,
          endDate: _endDate,
        );
        if (context.mounted) Navigator.pop(context, created);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// Helper for date picker buttons in the editor
class _DateButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final String? hint;
  final VoidCallback onPick;
  final VoidCallback? onClear;
  const _DateButton({required this.label, this.date, this.hint, required this.onPick, this.onClear});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 42),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          onPressed: onPick,
          icon: const Icon(Icons.calendar_today_rounded, size: 16),
          label: Row(
            children: [
              Expanded(
                child: Text(
                  date != null ? _fmtDate(date!) : (hint ?? '—'),
                  style: TextStyle(color: date != null ? null : cs.onSurfaceVariant),
                ),
              ),
              if (onClear != null)
                GestureDetector(
                  onTap: onClear,
                  child: Icon(Icons.close_rounded, size: 14, color: cs.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
