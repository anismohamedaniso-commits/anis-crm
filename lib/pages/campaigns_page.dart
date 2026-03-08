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
      // Clear campaign from leads that reference this campaign
      final leads = LeadService.instance.leads.value.where((l) => l.campaign == campaign.id).toList();
      for (final l in leads) {
        await LeadService.instance.update(l.copyWith(campaign: ''));
      }
      await CampaignService.instance.delete(campaign.id);
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
  final Market market;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CampaignCard({
    required this.campaign,
    required this.leads,
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
                        Text(c.name, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          'Started ${_fmtDate(c.startDate)}  ·  ${_marketLabel(c.market)}',
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, size: 20, color: cs.onSurfaceVariant),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                    onSelected: (v) {
                      if (v == 'edit') widget.onEdit();
                      if (v == 'delete') widget.onDelete();
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
                _KpiItem('Converted', '${statusCounts[LeadStatus.converted] ?? 0}', Icons.check_circle_outline_rounded, Colors.green),
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
                  Text('Lead Status Breakdown',
                      style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface)),
                  const SizedBox(height: 12),
                  if (leads.isEmpty)
                    Text('No leads assigned yet', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant))
                  else
                    ...LeadStatus.values.where((s) => (statusCounts[s] ?? 0) > 0).map((s) {
                      final count = statusCounts[s]!;
                      final pct = (count / totalLeads * 100).toStringAsFixed(0);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
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
                  const SizedBox(height: 8),
                  // Budget efficiency
                  if (totalLeads > 0) ...[
                    Divider(height: 1, color: cs.outline.withValues(alpha: 0.08)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.analytics_outlined, size: 16, color: cs.primary),
                        const SizedBox(width: 6),
                        Text('Cost Per Lead: ', style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                        Text('${cpl.toStringAsFixed(2)} ${mkt.currency}',
                            style: tt.bodySmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    if ((statusCounts[LeadStatus.converted] ?? 0) > 0) ...[
                      const SizedBox(height: 6),
                      Builder(builder: (_) {
                        final conv = statusCounts[LeadStatus.converted]!;
                        final cpa = c.budget / conv;
                        return Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                            const SizedBox(width: 6),
                            Text('Cost Per Acquisition: ', style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                            Text('${cpa.toStringAsFixed(2)} ${mkt.currency}',
                                style: tt.bodySmall?.copyWith(color: Colors.green, fontWeight: FontWeight.w700)),
                          ],
                        );
                      }),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
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
  final _budgetCtrl = TextEditingController();
  late String _marketId;
  late DateTime _startDate;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _nameCtrl.text = widget.existing!.name;
      _budgetCtrl.text = widget.existing!.budget.toStringAsFixed(0);
      _marketId = widget.existing!.market;
      _startDate = widget.existing!.startDate;
    } else {
      _marketId = widget.market.id;
      _startDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Campaign' : 'New Campaign'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Campaign Name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _budgetCtrl,
            decoration: InputDecoration(
              labelText: 'Budget (${Market.byId(_marketId).currency})',
              prefixText: '${Market.byId(_marketId).currencySymbol} ',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          Row(children: [
            const Text('Market:'),
            const SizedBox(width: 8),
            Flexible(
              child: DropdownButton<String>(
                value: _marketId,
                isExpanded: true,
                items: [
                  ...Market.all.map((m) => DropdownMenuItem(value: m.id, child: Text('${m.flag} ${m.label}'))),
                  const DropdownMenuItem(value: 'all', child: Text('🌍 All Markets')),
                ],
                onChanged: (v) => setState(() => _marketId = v ?? _marketId),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            const Text('Start Date:'),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_rounded, size: 16),
                label: Text(_fmtDate(_startDate)),
              ),
            ),
          ]),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_isEdit ? 'Update' : 'Create'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
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
          market: _marketId,
          budget: budget,
          startDate: _startDate,
        );
        await CampaignService.instance.update(updated);
        if (context.mounted) Navigator.pop(context, updated);
      } else {
        final created = await CampaignService.instance.create(
          name: name,
          market: _marketId,
          budget: budget,
          startDate: _startDate,
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
