// Lead Detail Page — Premium UI/UX v2


import 'package:anis_crm/components/skeleton.dart';
import 'package:anis_crm/theme.dart';
import 'package:anis_crm/engine/lead_score_engine.dart';
import 'package:anis_crm/models/lead.dart';
import 'package:anis_crm/models/activity.dart';
import 'package:anis_crm/services/lead_service.dart';
import 'package:anis_crm/services/activity_service.dart';
import 'package:anis_crm/services/task_service.dart';
import 'package:anis_crm/models/task_model.dart';
import 'package:anis_crm/services/social_launcher.dart';
import 'package:anis_crm/engine/conversation_suggestions_engine.dart';
import 'package:anis_crm/engine/templates_engine.dart';
import 'package:anis_crm/services/ai_executor.dart';
import 'package:anis_crm/state/app_state.dart';
import 'package:anis_crm/services/auth_service.dart';
import 'package:anis_crm/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

bool _hasPhone(LeadModel? l) => l != null && l.phone != null && l.phone!.isNotEmpty;
bool _hasEmail(LeadModel? l) => l != null && l.email != null && l.email!.isNotEmpty;

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
  return '?';
}

class LeadDetailPage extends StatefulWidget {
  const LeadDetailPage({super.key, this.leadId});
  final String? leadId;

  @override
  State<LeadDetailPage> createState() => _LeadDetailPageState();
}

class _LeadDetailPageState extends State<LeadDetailPage> {
  bool _loading = true;

  LeadModel? _lead;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 200)).then((_) {
      if (!mounted) return;
      _loadLead();
      setState(() => _loading = false);
    });
    LeadService.instance.leads.addListener(_onLeadsChanged);
  }

  @override
  void dispose() {

    LeadService.instance.leads.removeListener(_onLeadsChanged);
    super.dispose();
  }

  void _onLeadsChanged() => _loadLead();

  void _loadLead() {
    final id = widget.leadId;
    if (id == null) return;
    setState(() => _lead = LeadService.instance.byId(id));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 1100;
      return Column(children: [
        // ── HERO BAND ──
        _LeadHeroBand(
          loading: _loading,
          lead: _lead,
          onBack: () => context.go('/app/leads'),
        ),
        // ── BODY (fills remaining height) ──
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: isWide
                ? _buildWide(context)
                : _buildStacked(context),
          ),
        ),
      ]);
    });
  }

  Widget _buildWide(BuildContext context) {
    // Wider left column so status chips don't wrap
    const leftW = 380.0;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Left col scrolls independently
      SizedBox(width: leftW, child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 20),
        child: _LeadSummaryCard(loading: _loading, lead: _lead),
      )),
      const SizedBox(width: 20),
      // Right panel fills remaining height (has internal scroll per tab)
      Expanded(child: _TabbedRightPanel(lead: _lead)),
    ]);
  }

  Widget _buildStacked(BuildContext context) {
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _LeadSummaryCard(loading: _loading, lead: _lead),
        const SizedBox(height: 16),
        SizedBox(height: 600, child: _TabbedRightPanel(lead: _lead)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HERO BAND — full-width premium header
// ═══════════════════════════════════════════════════════════════════════════════

class _LeadHeroBand extends StatelessWidget {
  const _LeadHeroBand({
    required this.loading,
    required this.lead,
    required this.onBack,
  });
  final bool loading;
  final LeadModel? lead;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final app = context.read<AppState>();
    final meta = lead != null ? _statusMeta(lead!.status) : null;
    final statusColor = meta?.$2 ?? cs.primary;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.10))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: loading
          ? const SizedBox(height: 64, child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))))
          : lead == null
              ? SizedBox(height: 64, child: Row(children: [Icon(Icons.error_outline, size: 16, color: cs.error), const SizedBox(width: 8), Text('Lead not found', style: TextStyle(color: cs.error))]))
              : _buildRow(context, cs, statusColor, app),
    );
  }

  Widget _buildRow(BuildContext context, ColorScheme cs, Color statusColor, AppState app) {
    final l = lead!;
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      // ── Identity zone ──
      InkWell(
        onTap: onBack,
        borderRadius: BorderRadius.circular(6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.arrow_back_ios_new_rounded, size: 13, color: cs.primary),
          const SizedBox(width: 4),
          Text('Leads', style: TextStyle(fontSize: 12, color: cs.primary, fontWeight: FontWeight.w500)),
        ]),
      ),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.chevron_right, size: 14, color: cs.onSurfaceVariant.withValues(alpha: 0.3))),
      // Avatar
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Center(child: Text(_initials(l.name), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: statusColor))),
      ),
      const SizedBox(width: 12),
      // Name + sub-info
      Flexible(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: Text(l.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.2), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            _StatusPill(status: l.status),
          ]),
          const SizedBox(height: 2),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (l.phone != null && l.phone!.isNotEmpty) ...[Icon(Icons.phone_outlined, size: 11, color: cs.onSurfaceVariant), const SizedBox(width: 3), Text(l.phone!, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)), const SizedBox(width: 10)],
            if (l.dealValue != null && l.dealValue! > 0) _InfoChip(icon: Icons.attach_money, label: 'EGP ${l.dealValue!.toStringAsFixed(0)}', color: const Color(0xFF2E7D32), filled: true),
          ]),
        ]),
      ),
      const Spacer(),
      // ── Action zone ──
      Row(mainAxisSize: MainAxisSize.min, children: [
        _ActionIconBtn(icon: Icons.call_rounded, label: 'Call', color: const Color(0xFF4CAF50), enabled: _hasPhone(lead), onTap: !_hasPhone(lead) ? null : () async {
          final ok = await SocialLauncher.dialPhone(l.phone!);
          await ActivityService.instance.add(leadId: l.id, type: ActivityType.call, text: ok ? 'Call launched' : 'Call failed');
          await LeadService.instance.setLastContacted(l.id, DateTime.now());
        }),
        const SizedBox(width: 6),
        _ActionIconBtn(icon: Icons.chat_bubble_rounded, label: 'WhatsApp', color: const Color(0xFF25D366), enabled: _hasPhone(lead), onTap: !_hasPhone(lead) ? null : () async {
          final ok = await SocialLauncher.openWhatsApp(phone: l.phone!, message: 'Hi ${l.name}!');
          await ActivityService.instance.add(leadId: l.id, type: ActivityType.message, text: ok ? 'WhatsApp opened' : 'WhatsApp unavailable');
          await LeadService.instance.setLastContacted(l.id, DateTime.now());
        }),
        const SizedBox(width: 6),
        _ActionIconBtn(icon: Icons.mail_outlined, label: 'Email', color: const Color(0xFF2196F3), enabled: _hasEmail(lead), onTap: !_hasEmail(lead) ? null : () async {
          final ok = await SocialLauncher.composeEmail(to: l.email!, subject: 'Hello ${l.name}', body: '');
          await ActivityService.instance.add(leadId: l.id, type: ActivityType.message, text: ok ? 'Email opened' : 'Email unavailable');
          await LeadService.instance.setLastContacted(l.id, DateTime.now());
        }),
        if ((AuthService.instance.user?.canEditLeads ?? false) || (AuthService.instance.user?.canDeleteLeads ?? false))
          Container(width: 1, height: 28, margin: const EdgeInsets.symmetric(horizontal: 10), color: cs.outline.withValues(alpha: 0.2)),
        if (AuthService.instance.user?.canEditLeads ?? false) _IconBtn(icon: Icons.edit_outlined, tooltip: 'Edit', onTap: () => showDialog(context: context, builder: (_) => _EditLeadDialog(lead: l))),
        if (AuthService.instance.user?.canDeleteLeads ?? false) ...[const SizedBox(width: 4), _IconBtn(icon: Icons.delete_outline, tooltip: 'Delete', color: cs.error, onTap: () => _confirmDelete(context, l))],
      ]),
    ]);
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, required this.color, this.filled = false});
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final bg = filled ? color.withValues(alpha: 0.12) : Colors.transparent;
    final border = filled ? color.withValues(alpha: 0.25) : color.withValues(alpha: 0.15);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: filled ? color : Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: filled ? FontWeight.w600 : FontWeight.w400), overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

/// Compact icon+label button used in the header action row.
class _ActionIconBtn extends StatelessWidget {
  const _ActionIconBtn({required this.icon, required this.label, required this.color, this.enabled = true, this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = enabled ? color : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3);
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: enabled ? c.withValues(alpha: 0.10) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.withValues(alpha: enabled ? 0.30 : 0.15)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: c),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c)),
          ]),
        ),
      ),
    );
  }
}

class _IconBtn extends StatefulWidget {
  const _IconBtn({required this.icon, required this.onTap, this.tooltip, this.color});
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color? color;
  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = widget.color ?? cs.onSurfaceVariant;
    return Tooltip(
      message: widget.tooltip ?? '',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 35, height: 35,
            decoration: BoxDecoration(
              color: _hovered ? c.withValues(alpha: 0.10) : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _hovered ? c.withValues(alpha: 0.28) : cs.outline.withValues(alpha: 0.15)),
            ),
            child: Icon(widget.icon, size: 16, color: c),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LEFT COLUMN — LEAD SUMMARY CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _LeadSummaryCard extends StatelessWidget {
  const _LeadSummaryCard({required this.loading, required this.lead});
  final bool loading;
  final LeadModel? lead;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(padding: const EdgeInsets.all(20), child: Column(children: const [
          const SkeletonBlock(height: 16, width: 200), const SizedBox(height: 10),
          const SkeletonBlock(height: 14, width: 160), const SizedBox(height: 10),
          const SkeletonBlock(height: 14, width: 220),
        ])),
      );
    }
    if (lead == null) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 8),
          const Text('Lead not found'),
        ])),
      );
    }
    final l = lead!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Contact Card ──
      _SummarySection(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _ContactInfoCard(lead: l),
          const SizedBox(height: 12),
          _SourceChannelRow(lead: l),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.calendar_today_outlined, label: 'Date added', value: _formatDate(l.createdAt)),
          if (l.campaign != null && l.campaign!.isNotEmpty) ...[const SizedBox(height: 8), _InfoRow(icon: Icons.campaign_outlined, label: 'Campaign', value: l.campaign!)],
        ]),
      ),
      const SizedBox(height: 12),
      // ── Status Card ──
      if (AuthService.instance.user?.canChangeStatus ?? false) ...[
        _SummarySection(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 0.8)),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _StatusChip(label: 'Fresh', color: const Color(0xFF2196F3), active: l.status == LeadStatus.fresh, onTap: () async => _confirmAndSetStatus(context, current: l.status, id: l.id, target: LeadStatus.fresh)),
            _StatusChip(label: 'Interested', color: AppColors.success, active: l.status == LeadStatus.interested, onTap: () async => _confirmAndSetStatus(context, current: l.status, id: l.id, target: LeadStatus.interested)),
            _StatusChip(label: 'No Answer', color: AppColors.warning, active: l.status == LeadStatus.noAnswer, onTap: () async => _confirmAndSetStatus(context, current: l.status, id: l.id, target: LeadStatus.noAnswer)),
            _StatusChip(label: 'Not Interested', color: AppColors.danger, active: l.status == LeadStatus.notInterested, onTap: () async => _confirmAndSetStatus(context, current: l.status, id: l.id, target: LeadStatus.notInterested)),
            _StatusChip(label: 'Follow-Up', color: AppColors.info, active: l.status == LeadStatus.followUp, onTap: () async => _confirmAndSetStatus(context, current: l.status, id: l.id, target: LeadStatus.followUp)),
            _StatusChip(label: 'Converted', color: const Color(0xFF9C27B0), active: l.status == LeadStatus.converted, onTap: () async => _confirmAndConvert(context, lead: l)),
            _StatusChip(label: 'Closed', color: AppColors.neutralDark, active: l.status == LeadStatus.closed, onTap: () async => _confirmAndSetStatus(context, current: l.status, id: l.id, target: LeadStatus.closed)),
          ]),
        ])),
        const SizedBox(height: 12),
      ],
      // ── Assignment Card ──
      if (AuthService.instance.user?.canEditLeads ?? false) ...[
        _SummarySection(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ASSIGNED TO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          _AssignmentSection(lead: l),
        ])),
      ],
    ]);
  }
}

/// Card-like section container for the left column.
class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.10)),
        boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 14, color: cs.primary),
      ),
      const SizedBox(width: 8),
      Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
    ]);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Icon(icon, size: 14, color: cs.onSurfaceVariant),
      const SizedBox(width: 7),
      Text('$label: ', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      Flexible(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RIGHT COLUMN — TABBED PANEL
// ═══════════════════════════════════════════════════════════════════════════════

class _TabbedRightPanel extends StatefulWidget {
  const _TabbedRightPanel({required this.lead});
  final LeadModel? lead;
  @override
  State<_TabbedRightPanel> createState() => _TabbedRightPanelState();
}

class _TabbedRightPanelState extends State<_TabbedRightPanel> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final TextEditingController _notesCtrl = TextEditingController();
  bool _notesDirty = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadNotes();
  }

  @override
  void didUpdateWidget(covariant _TabbedRightPanel old) {
    super.didUpdateWidget(old);
    if (old.lead?.id != widget.lead?.id) _loadNotes();
  }

  void _loadNotes() {
    if (widget.lead == null) return;
    final notes = ActivityService.instance.listFor(widget.lead!.id).where((a) => a.type == ActivityType.note).toList();
    _notesCtrl.text = notes.isNotEmpty ? (notes.first.text ?? '') : '';
    _notesDirty = false;
  }

  Future<void> _saveNotes() async {
    if (widget.lead == null || !_notesDirty) return;
    final text = _notesCtrl.text.trim();
    if (text.isEmpty) return;
    await ActivityService.instance.add(leadId: widget.lead!.id, type: ActivityType.note, text: text);
    setState(() => _notesDirty = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note saved'), duration: Duration(seconds: 1)));
  }

  @override
  void dispose() {
    _tab.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── COMPACT TAB BAR ──
        Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.10)))),
          child: TabBar(
            controller: _tab,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: cs.primary,
            unselectedLabelColor: cs.onSurfaceVariant,
            indicatorColor: cs.primary,
            indicatorWeight: 2.5,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
            tabs: const [
              Tab(height: 44, child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.analytics_outlined, size: 15), SizedBox(width: 5), Text('Insights')])),
              Tab(height: 44, child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.history_rounded, size: 15), SizedBox(width: 5), Text('Activity')])),
            ],
          ),
        ),
        // ── TAB CONTENT ──
        Expanded(child: TabBarView(
            controller: _tab,
            children: [
              _InsightsTab(lead: widget.lead),
              _ActivityTab(lead: widget.lead, notesCtrl: _notesCtrl, notesDirty: _notesDirty, onChanged: () { if (!_notesDirty) setState(() => _notesDirty = true); }, onSave: _saveNotes),
            ],
          )),
      ]),
    );
  }
}

// ── TAB 1: INSIGHTS ──
class _InsightsTab extends StatelessWidget {
  const _InsightsTab({required this.lead});
  final LeadModel? lead;

  String _intentLabel(LeadStatus s) => switch (s) {
    LeadStatus.fresh => 'Exploring options',
    LeadStatus.interested => 'High interest — ready to buy',
    LeadStatus.noAnswer => 'Unreachable',
    LeadStatus.followUp => 'Awaiting follow-up',
    LeadStatus.notInterested => 'Declined offer',
    LeadStatus.converted => 'Committed — converted!',
    LeadStatus.closed => 'Disengaged',
  };

  String _suggestedAction(LeadScoreResult score, LeadModel l) {
    if (l.status == LeadStatus.followUp && l.nextFollowupAt != null && l.nextFollowupAt!.isBefore(DateTime.now())) return 'Follow up NOW — send Masterclass details or call!';
    if (l.status == LeadStatus.interested) {
      final days = l.lastContactedAt != null ? DateTime.now().difference(l.lastContactedAt!).inDays : 999;
      if (days >= 1) return 'Call today — pitch the Masterclass or book a demo';
      return 'Send Masterclass pricing & next batch dates';
    }
    if (l.status == LeadStatus.noAnswer) return 'Try WhatsApp — send a Tick & Talk intro message';
    if (l.status == LeadStatus.fresh) return 'Make first contact — introduce Tick & Talk & Masterclass';
    if (l.status == LeadStatus.converted) return 'Welcome them! Share onboarding info & Speekr.ai access';
    if (l.status == LeadStatus.notInterested) return 'Try win-back — offer Speekr.ai free trial';
    if (l.status == LeadStatus.closed) return 'No action needed';
    if (score.temperature == LeadTemperature.hot) return 'Act fast — this lead is ready to enroll!';
    if (score.temperature == LeadTemperature.warm) return 'Follow up — share testimonials or Shark Tank story';
    return 'Monitor for activity';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final app = context.read<AppState>();
    if (lead == null) return const _EmptyState(icon: Icons.analytics_outlined, message: 'No lead selected');
    final score = AiExecutor.instance.leadScore(app, lead!);
    final tempColor = switch (score.temperature) {
      LeadTemperature.cold => const Color(0xFF42A5F5),
      LeadTemperature.warm => const Color(0xFFFFA726),
      LeadTemperature.hot => const Color(0xFFEF5350),
    };
    final tempLabel = switch (score.temperature) {
      LeadTemperature.cold => 'Cold Lead',
      LeadTemperature.warm => 'Warm Lead',
      LeadTemperature.hot => 'Hot Lead 🔥',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _ScoreMetricCard(score: score, tempColor: tempColor, tempLabel: tempLabel),
        const SizedBox(height: 16),
        _PremiumKeyValue(label: 'Intent', value: _intentLabel(lead!.status)),
        if (lead!.lastContactedAt != null)
          _PremiumKeyValue(label: 'Last contact', value: _relativeTime(lead!.lastContactedAt!)),
        if (lead!.nextFollowupAt != null)
          _PremiumKeyValue(label: 'Next follow-up', value: _relativeTime(lead!.nextFollowupAt!), highlight: lead!.nextFollowupAt!.isBefore(DateTime.now())),
        if (lead!.dealValue != null && lead!.dealValue! > 0)
          _PremiumKeyValue(label: 'Deal value', value: 'EGP ${lead!.dealValue!.toStringAsFixed(0)}', valueColor: const Color(0xFF2E7D32)),
        const SizedBox(height: 14),
        _ActionBanner(text: _suggestedAction(score, lead!), color: cs.primary),
        if (app.aiConnected && app.aiScoringEnabled) ...[
          const SizedBox(height: 14),
          FutureBuilder<AiScoreResult>(
            future: AiExecutor.instance.aiLeadScore(app, lead!),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const _AiLoadingChip(label: 'Getting AI analysis…');
              if (!snap.hasData || !snap.data!.isAi || snap.data!.reason == null) return const SizedBox.shrink();
              return _AiBanner(score: snap.data!.score, reason: snap.data!.reason!);
            },
          ),
        ],
        const SizedBox(height: 20),
        _FollowUpSection(lead: lead!),
      ]),
    );
  }
}

class _ScoreMetricCard extends StatelessWidget {
  const _ScoreMetricCard({required this.score, required this.tempColor, required this.tempLabel});
  final LeadScoreResult score;
  final Color tempColor;
  final String tempLabel;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [tempColor.withValues(alpha: 0.10), tempColor.withValues(alpha: 0.03)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tempColor.withValues(alpha: 0.22)),
      ),
      child: Row(children: [
        SizedBox(width: 72, height: 72, child: Stack(alignment: Alignment.center, children: [
          SizedBox(width: 72, height: 72, child: CircularProgressIndicator(value: score.score / 100, strokeWidth: 7, backgroundColor: cs.surfaceContainerHighest, color: tempColor, strokeCap: StrokeCap.round)),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${score.score}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: tempColor)),
            Text('/100', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
          ]),
        ])),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: tempColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: tempColor.withValues(alpha: 0.3))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.local_fire_department, size: 12, color: tempColor),
              const SizedBox(width: 4),
              Text(tempLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tempColor)),
            ]),
          ),
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: score.score / 100, color: tempColor, backgroundColor: cs.surfaceContainerHighest, minHeight: 5)),
          const SizedBox(height: 4),
          Text('Lead Score', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ])),
      ]),
    );
  }
}

class _PremiumKeyValue extends StatelessWidget {
  const _PremiumKeyValue({required this.label, required this.value, this.highlight = false, this.valueColor});
  final String label;
  final String value;
  final bool highlight;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(flex: 2, child: Text(label, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant))),
        Expanded(flex: 3, child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor ?? (highlight ? AppColors.danger : cs.onSurface)), overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

class _ActionBanner extends StatelessWidget {
  const _ActionBanner({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.18))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.lightbulb_outline_rounded, size: 17, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color, height: 1.5))),
      ]),
    );
  }
}

class _AiBanner extends StatelessWidget {
  const _AiBanner({required this.score, required this.reason});
  final int score;
  final String reason;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.infoBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.info.withValues(alpha: 0.2))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.auto_awesome, size: 15, color: AppColors.info),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('AI Score: $score/100', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.info)),
          const SizedBox(height: 3),
          Text(reason, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface, height: 1.4)),
        ])),
      ]),
    );
  }
}

class _AiLoadingChip extends StatelessWidget {
  const _AiLoadingChip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 1.5, color: cs.primary)),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
    ]);
  }
}

class _FollowUpSection extends StatelessWidget {
  const _FollowUpSection({required this.lead});
  final LeadModel lead;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionTitle(icon: Icons.event_available_outlined, label: 'Follow-up'),
      const SizedBox(height: 12),
      if (lead.nextFollowupAt != null) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.info.withValues(alpha: 0.2))),
          child: Row(children: [
            const Icon(Icons.event_note_outlined, size: 15, color: AppColors.info),
            const SizedBox(width: 8),
            Expanded(child: Text(_formatDate(lead.nextFollowupAt!), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.info))),
            GestureDetector(
              onTap: () async { await LeadService.instance.setNextFollowup(lead.id, null); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Follow-up cleared'))); },
              child: Icon(Icons.close, size: 14, color: cs.onSurfaceVariant),
            ),
          ]),
        ),
        const SizedBox(height: 8),
      ],
      OutlinedButton.icon(
        onPressed: () async {
          final picked = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 1)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
          if (picked == null || !context.mounted) return;
          final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
          final dt = time != null ? DateTime(picked.year, picked.month, picked.day, time.hour, time.minute) : DateTime(picked.year, picked.month, picked.day, 10, 0);
          await LeadService.instance.setNextFollowup(lead.id, dt);
          await ActivityService.instance.add(leadId: lead.id, type: ActivityType.followup, text: 'Follow-up: ${_formatDate(dt)}');
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Follow-up: ${_formatDate(dt)}')));
        },
        icon: const Icon(Icons.event_available_outlined, size: 15),
        label: Text(lead.nextFollowupAt != null ? 'Reschedule' : 'Schedule Follow-up', style: const TextStyle(fontSize: 13)),
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
      ),
    ]);
  }
}

// ── TAB 2: ACTIVITY TAB (Notes + Timeline) ──
class _ActivityTab extends StatelessWidget {
  const _ActivityTab({required this.lead, required this.notesCtrl, required this.notesDirty, required this.onChanged, required this.onSave});
  final LeadModel? lead;
  final TextEditingController notesCtrl;
  final bool notesDirty;
  final VoidCallback onChanged;
  final VoidCallback onSave;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (lead == null) return const _EmptyState(icon: Icons.history_rounded, message: 'No lead selected');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // My Notes
        Row(children: [
          Text('MY NOTES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant, letterSpacing: 0.8)),
          const Spacer(),
          if (notesDirty)
            TextButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.save_outlined, size: 13),
              label: const Text('Save', style: TextStyle(fontSize: 12)),
            ),
        ]),
        const SizedBox(height: 8),
        TextField(
          controller: notesCtrl,
          maxLines: 4,
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            hintText: 'Private notes…',
            filled: true, fillColor: cs.surfaceContainerHighest,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 16),
        Text('TEAM NOTES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant, letterSpacing: 0.8)),
        const SizedBox(height: 8),
        _TeamNotesSection(leadId: lead!.id),
        const SizedBox(height: 20),
        Text('TIMELINE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant, letterSpacing: 0.8)),
        const SizedBox(height: 12),
        ValueListenableBuilder(
          valueListenable: ActivityService.instance.byLead,
          builder: (context, _, __) {
            final activities = ActivityService.instance.listFor(lead!.id);
            return ValueListenableBuilder<List<TaskModel>>(
              valueListenable: TaskService.instance.tasks,
              builder: (context, tasks, _2) {
                final entries = <_TimelineEntry>[
                  ...activities.map((a) => _TimelineEntry.activity(a)),
                  ...tasks.where((t) => t.leadId == lead!.id).map((t) => _TimelineEntry.task(t)),
                ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
                if (entries.isEmpty) return const _EmptyState(icon: Icons.timeline, message: 'No events yet');
                final grouped = <String, List<_TimelineEntry>>{};
                for (final e in entries) grouped.putIfAbsent(_dateLabel(e.timestamp), () => []).add(e);
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: grouped.entries.map((g) => _TimelineGroup(date: g.key, entries: g.value)).toList());
              },
            );
          },
        ),
      ]),
    );
  }
}

class _TimelineGroup extends StatelessWidget {
  const _TimelineGroup({required this.date, required this.entries});
  final String date;
  final List<_TimelineEntry> entries;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
            child: Text(date, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.primary, letterSpacing: 0.4)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: cs.outline.withValues(alpha: 0.15), height: 1)),
        ]),
      ),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Connector line + dots
        Column(children: List.generate(entries.length, (i) {
          final e = entries[i];
          final isLast = i == entries.length - 1;
          final meta = e.activity != null ? _activityMeta(e.activity!) : null;
          final color = meta?.$2 ?? (e.task != null && e.task!.isOverdue ? cs.error : cs.onSurfaceVariant);
          return Column(children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                color: color, shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.35), width: 2),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 3)],
              ),
            ),
            if (!isLast) Container(width: 2, height: 52, color: cs.outline.withValues(alpha: 0.12)),
          ]);
        })),
        const SizedBox(width: 14),
        Expanded(child: Column(children: entries.map((e) {
          if (e.activity != null) {
            final meta = _activityMeta(e.activity!);
            return _TimelineCard(icon: meta.$1, iconColor: meta.$2, title: meta.$3, subtitle: null, time: _relativeTime(e.timestamp));
          }
          final t = e.task!;
          final color = t.isOverdue ? cs.error : (t.status == TaskStatus.done ? cs.primary : cs.onSurfaceVariant);
          return _TimelineCard(icon: Icons.task_alt_outlined, iconColor: color, title: t.title, subtitle: 'Due: ${t.dueDate ?? '—'} · ${t.status.label}', time: _relativeTime(e.timestamp));
        }).toList())),
      ]),
      const SizedBox(height: 16),
    ]);
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.icon, required this.iconColor, required this.title, this.subtitle, required this.time});
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String time;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: Row(children: [
        Container(width: 30, height: 30, decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 15, color: iconColor)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
          if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        const SizedBox(width: 6),
        Text(time, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.38))),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ═══════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 44, color: cs.onSurfaceVariant.withValues(alpha: 0.22)),
        const SizedBox(height: 12),
        Text(message, style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant.withValues(alpha: 0.55))),
      ]),
    ));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATUS CHIP & PILL
// ═══════════════════════════════════════════════════════════════════════════════

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color, this.active = false, this.onTap});
  final String label;
  final Color color;
  final bool active;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final bg = color.withValues(alpha: active ? 0.16 : 0.07);
    final border = color.withValues(alpha: active ? 0.4 : 0.15);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: border, width: active ? 1.5 : 1)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (active) ...[Icon(Icons.check_circle_rounded, size: 11, color: color), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
        ]),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final LeadStatus status;
  @override
  Widget build(BuildContext context) {
    final meta = _statusMeta(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: meta.$2.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: meta.$2.withValues(alpha: 0.25))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(meta.$3, size: 11, color: meta.$2),
        const SizedBox(width: 4),
        Text(meta.$1, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: meta.$2)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DIALOGS & LOGIC
// ═══════════════════════════════════════════════════════════════════════════════

Future<void> _confirmAndSetStatus(BuildContext context, {required LeadStatus current, required String id, required LeadStatus target}) async {
  if (current == target) return;
  if (current == LeadStatus.closed && target != LeadStatus.closed) {
    final proceed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Reopen lead?'),
      content: const Text('This lead is Closed. Change its status?'),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Confirm')),
      ],
    ));
    if (proceed != true) return;
  }
  await LeadService.instance.setStatus(id, target);
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status → ${_statusMeta(target).$1}'), duration: const Duration(seconds: 1)));
}

Future<void> _confirmAndConvert(BuildContext context, {required LeadModel lead}) async {
  if (lead.status == LeadStatus.converted) return;
  final dealCtrl = TextEditingController(text: lead.dealValue != null ? lead.dealValue!.toStringAsFixed(0) : '');
  final result = await showDialog<double?>(context: context, builder: (ctx) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title: const Row(children: [Icon(Icons.star, color: Color(0xFF9C27B0)), SizedBox(width: 10), Text('Convert Lead')]),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Mark "${lead.name}" as Converted.\nEnter the deal value:'),
      const SizedBox(height: 16),
      TextField(controller: dealCtrl, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Deal Value (EGP)', prefixText: 'EGP ', prefixIcon: const Icon(Icons.attach_money), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), hintText: 'e.g. 2000')),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
      FilledButton(onPressed: () { final v = double.tryParse(dealCtrl.text.trim()) ?? 0; Navigator.of(ctx).pop(v); }, child: const Text('Convert')),
    ],
  ));
  dealCtrl.dispose();
  if (result == null) return;
  await LeadService.instance.update(lead.copyWith(status: LeadStatus.converted, dealValue: result > 0 ? result : null));
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result > 0 ? 'Converted! EGP ${result.toStringAsFixed(0)}' : 'Converted'), duration: const Duration(seconds: 2)));
}

(String, Color, IconData) _statusMeta(LeadStatus s) => switch (s) {
  LeadStatus.fresh => ('Fresh', const Color(0xFF2196F3), Icons.fiber_new),
  LeadStatus.interested => ('Interested', const Color(0xFF4CAF50), Icons.thumb_up_alt_outlined),
  LeadStatus.noAnswer => ('No Answer', const Color(0xFFFF9800), Icons.phone_missed_outlined),
  LeadStatus.followUp => ('Follow-Up', const Color(0xFF03A9F4), Icons.schedule),
  LeadStatus.notInterested => ('Not Interested', const Color(0xFFF44336), Icons.thumb_down_alt_outlined),
  LeadStatus.converted => ('Converted', const Color(0xFF9C27B0), Icons.star_outline),
  LeadStatus.closed => ('Closed', const Color(0xFF607D8B), Icons.lock_outlined),
};

Future<void> _confirmDelete(BuildContext context, LeadModel lead) async {
  final cs = Theme.of(context).colorScheme;
  final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title: Row(children: [Icon(Icons.warning_amber_rounded, color: cs.error), const SizedBox(width: 10), const Text('Delete lead?')]),
    content: Text('Permanently delete "${lead.name}"? Cannot be undone.'),
    actions: [
      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.of(ctx).pop(true), style: FilledButton.styleFrom(backgroundColor: cs.error), child: const Text('Delete')),
    ],
  ));
  if (ok == true) {
    await LeadService.instance.delete(lead.id);
    if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lead deleted'))); context.go('/app/leads'); }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONTACT INFO
// ═══════════════════════════════════════════════════════════════════════════════

class _ContactInfoCard extends StatelessWidget {
  const _ContactInfoCard({required this.lead});
  final LeadModel lead;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: Column(children: [
        _ContactRow(icon: Icons.phone_outlined, value: lead.phone ?? '-', hasValue: _hasPhone(lead),
          onTap: _hasPhone(lead) ? () async => SocialLauncher.dialPhone(lead.phone!) : null,
          onCopy: _hasPhone(lead) ? () { Clipboard.setData(ClipboardData(text: lead.phone!)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone copied'), duration: Duration(seconds: 1))); } : null),
        const Divider(height: 12),
        _ContactRow(icon: Icons.email_outlined, value: lead.email ?? '-', hasValue: _hasEmail(lead),
          onTap: _hasEmail(lead) ? () async => SocialLauncher.composeEmail(to: lead.email!, subject: 'Hello ${lead.name}', body: '') : null,
          onCopy: _hasEmail(lead) ? () { Clipboard.setData(ClipboardData(text: lead.email!)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email copied'), duration: Duration(seconds: 1))); } : null),
      ]),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.value, this.hasValue = false, this.onTap, this.onCopy});
  final IconData icon;
  final String value;
  final bool hasValue;
  final VoidCallback? onTap;
  final VoidCallback? onCopy;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Icon(icon, size: 16, color: cs.onSurfaceVariant),
      const SizedBox(width: 10),
      Expanded(child: InkWell(
        onTap: onTap,
        child: Text(value, style: TextStyle(fontSize: 13, color: hasValue ? cs.primary : cs.onSurfaceVariant, decoration: hasValue ? TextDecoration.underline : null, decorationColor: hasValue ? cs.primary.withValues(alpha: 0.4) : null), overflow: TextOverflow.ellipsis),
      )),
      if (onCopy != null)
        IconButton(onPressed: onCopy, icon: Icon(Icons.copy, size: 14, color: cs.onSurfaceVariant), iconSize: 14, constraints: const BoxConstraints(minWidth: 30, minHeight: 30), tooltip: 'Copy'),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SOURCE CHANNEL
// ═══════════════════════════════════════════════════════════════════════════════

String _sourceLabel(LeadSource s) => switch (s) { LeadSource.whatsapp => 'WhatsApp', LeadSource.facebook => 'Facebook', LeadSource.instagram => 'Instagram', LeadSource.linkedin => 'LinkedIn', LeadSource.tiktok => 'TikTok', LeadSource.email => 'Email', LeadSource.phone => 'Phone', LeadSource.web => 'Website', LeadSource.manual => 'Manual', LeadSource.imported => 'Imported' };
IconData _sourceIcon(LeadSource s) => switch (s) { LeadSource.whatsapp => Icons.chat, LeadSource.facebook => Icons.facebook, LeadSource.instagram => Icons.camera_alt, LeadSource.linkedin => Icons.business, LeadSource.tiktok => Icons.music_note, LeadSource.email => Icons.email, LeadSource.phone => Icons.phone, LeadSource.web => Icons.language, LeadSource.manual => Icons.edit, LeadSource.imported => Icons.upload_file };
Color _sourceColor(LeadSource s) => switch (s) { LeadSource.whatsapp => const Color(0xFF25D366), LeadSource.facebook => const Color(0xFF1877F2), LeadSource.instagram => const Color(0xFFE1306C), LeadSource.linkedin => const Color(0xFF0077B5), LeadSource.tiktok => const Color(0xFF000000), LeadSource.email => const Color(0xFF2196F3), LeadSource.phone => const Color(0xFF4CAF50), LeadSource.web => const Color(0xFFFF9800), LeadSource.manual => const Color(0xFF607D8B), LeadSource.imported => const Color(0xFF9C27B0) };

class _SourceChannelRow extends StatelessWidget {
  const _SourceChannelRow({required this.lead});
  final LeadModel lead;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = _sourceColor(lead.source);
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withValues(alpha: 0.22))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_sourceIcon(lead.source), size: 13, color: c),
          const SizedBox(width: 5),
          Text(_sourceLabel(lead.source), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c)),
        ]),
      ),
      const SizedBox(width: 6),
      PopupMenuButton<LeadSource>(
        tooltip: 'Change channel', icon: Icon(Icons.swap_horiz, size: 15, color: cs.onSurfaceVariant),
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        onSelected: (v) async => LeadService.instance.update(lead.copyWith(source: v)),
        itemBuilder: (_) => LeadSource.values.map((s) => PopupMenuItem(value: s, child: Row(children: [
          Icon(_sourceIcon(s), size: 14, color: _sourceColor(s)),
          const SizedBox(width: 8),
          Text(_sourceLabel(s), style: const TextStyle(fontSize: 13)),
          if (s == lead.source) ...[const Spacer(), const Icon(Icons.check, size: 14)],
        ]))).toList(),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SUGGESTION TILE & TEMPLATE
// ═══════════════════════════════════════════════════════════════════════════════

class _SuggestionTile extends StatefulWidget {
  const _SuggestionTile({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;
  @override
  State<_SuggestionTile> createState() => _SuggestionTileState();
}

class _SuggestionTileState extends State<_SuggestionTile> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: _hovered ? cs.primary.withValues(alpha: 0.07) : cs.surfaceContainerHighest.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _hovered ? cs.primary.withValues(alpha: 0.3) : cs.outline.withValues(alpha: 0.10)),
            ),
            child: Row(children: [
              Expanded(child: Text(widget.text, style: const TextStyle(fontSize: 13), overflow: TextOverflow.visible, maxLines: 3)),
              const SizedBox(width: 8),
              AnimatedOpacity(opacity: _hovered ? 1.0 : 0.0, duration: const Duration(milliseconds: 150), child: Icon(Icons.north_west_rounded, size: 13, color: cs.primary)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _TemplateCategoryTile extends StatelessWidget {
  const _TemplateCategoryTile({required this.title, required this.items, required this.onPick});
  final String title;
  final List<String> items;
  final ValueChanged<String> onPick;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(border: Border.all(color: cs.outline.withValues(alpha: 0.10)), borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          children: items.map((t) => _SuggestionTile(text: t, onTap: () => onPick(t))).toList(),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EDIT LEAD DIALOG
// ═══════════════════════════════════════════════════════════════════════════════

class _EditLeadDialog extends StatefulWidget {
  const _EditLeadDialog({required this.lead});
  final LeadModel lead;
  @override
  State<_EditLeadDialog> createState() => _EditLeadDialogState();
}

class _EditLeadDialogState extends State<_EditLeadDialog> {
  late final TextEditingController _name, _phone, _email, _campaign, _dealValue;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.lead.name);
    _phone = TextEditingController(text: widget.lead.phone ?? '');
    _email = TextEditingController(text: widget.lead.email ?? '');
    _campaign = TextEditingController(text: widget.lead.campaign ?? '');
    _dealValue = TextEditingController(text: widget.lead.dealValue != null ? widget.lead.dealValue!.toStringAsFixed(0) : '');
  }

  @override
  void dispose() { _name.dispose(); _phone.dispose(); _email.dispose(); _campaign.dispose(); _dealValue.dispose(); super.dispose(); }

  Widget _field(TextEditingController c, String label, IconData icon) =>
      TextField(controller: c, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [Icon(Icons.edit_outlined, size: 20, color: cs.primary), const SizedBox(width: 10), const Text('Edit Lead')]),
      content: SingleChildScrollView(child: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        _field(_name, 'Name', Icons.person_outline), const SizedBox(height: 14),
        _field(_phone, 'Phone', Icons.phone_outlined), const SizedBox(height: 14),
        _field(_email, 'Email', Icons.email_outlined), const SizedBox(height: 14),
        _field(_campaign, 'Campaign', Icons.campaign_outlined), const SizedBox(height: 14),
        TextField(controller: _dealValue, decoration: InputDecoration(labelText: 'Deal Value (EGP)', prefixIcon: const Icon(Icons.attach_money), prefixText: 'EGP ', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check, size: 16),
          label: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name is required'))); return; }
    final email = _email.text.trim();
    if (email.isNotEmpty && !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid email'))); return; }
    setState(() => _saving = true);
    try {
      await LeadService.instance.update(widget.lead.copyWith(
        name: name, phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        email: email.isEmpty ? null : email, campaign: _campaign.text.trim().isEmpty ? null : _campaign.text.trim(),
        dealValue: double.tryParse(_dealValue.text.trim()),
      ));
      if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lead updated'), duration: Duration(seconds: 1))); Navigator.of(context).pop(true); }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ASSIGNMENT SECTION
// ═══════════════════════════════════════════════════════════════════════════════

class _AssignmentSection extends StatefulWidget {
  const _AssignmentSection({required this.lead});
  final LeadModel lead;
  @override
  State<_AssignmentSection> createState() => _AssignmentSectionState();
}

class _AssignmentSectionState extends State<_AssignmentSection> {
  List<CrmUser>? _members;
  bool _assigning = false;

  @override
  void initState() { super.initState(); _loadMembers(); }

  Future<void> _loadMembers() async {
    final users = await AuthService.instance.listUsers();
    if (mounted) setState(() => _members = users);
  }

  Future<void> _assign(String userId, String userName) async {
    setState(() => _assigning = true);
    final ok = await ApiClient.instance.assignLead(widget.lead.id, userId, userName);
    if (ok && mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Assigned to $userName'), duration: const Duration(seconds: 1))); await LeadService.instance.load(); }
    if (mounted) setState(() => _assigning = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (widget.lead.assignedToName != null && widget.lead.assignedToName!.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: cs.primary.withValues(alpha: 0.15))),
        child: Row(children: [
          Icon(Icons.person, size: 15, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.lead.assignedToName!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          if (!_assigning) TextButton(onPressed: () => _showPicker(context), child: const Text('Change', style: TextStyle(fontSize: 12))),
        ]),
      );
    }
    return OutlinedButton.icon(
      onPressed: _assigning || _members == null ? null : () => _showPicker(context),
      icon: _assigning ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.person_add_outlined, size: 15),
      label: const Text('Assign to team member', style: TextStyle(fontSize: 13)),
    );
  }

  void _showPicker(BuildContext context) {
    if (_members == null || _members!.isEmpty) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), child: Text('Assign Lead', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
          const Divider(),
          ..._members!.map((m) {
            final isSel = m.id == widget.lead.assignedTo;
            return ListTile(
              leading: CircleAvatar(child: Text(m.name.isNotEmpty ? m.name[0].toUpperCase() : '?')),
              title: Text(m.name),
              subtitle: Text(m.role == 'account_executive' ? 'Account Exec' : 'Campaign Exec'),
              trailing: isSel ? const Icon(Icons.check_circle, color: Colors.green) : null,
              onTap: isSel ? null : () { Navigator.of(ctx).pop(); _assign(m.id, m.name); },
            );
          }),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEAM NOTES
// ═══════════════════════════════════════════════════════════════════════════════

class _TeamNotesSection extends StatefulWidget {
  const _TeamNotesSection({required this.leadId});
  final String leadId;
  @override
  State<_TeamNotesSection> createState() => _TeamNotesSectionState();
}

class _TeamNotesSectionState extends State<_TeamNotesSection> {
  final TextEditingController _ctrl = TextEditingController();
  List<Map<String, dynamic>> _notes = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void didUpdateWidget(covariant _TeamNotesSection old) { super.didUpdateWidget(old); if (old.leadId != widget.leadId) _load(); }
  Future<void> _load() async {
    final res = await ApiClient.instance.getLeadTeamNotes(widget.leadId);
    if (mounted) setState(() { _notes = res ?? []; _loading = false; });
  }
  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    final ok = await ApiClient.instance.addLeadTeamNote(widget.leadId, text);
    if (ok && mounted) { _ctrl.clear(); await _load(); }
    if (mounted) setState(() => _sending = false);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final me = AuthService.instance.user?.id ?? '';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: TextField(
          controller: _ctrl,
          decoration: InputDecoration(
            hintText: 'Add a team note…',
            hintStyle: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            filled: true, fillColor: cs.surfaceContainerHighest,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          style: const TextStyle(fontSize: 13),
          onSubmitted: (_) => _send(),
        )),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: _sending ? null : _send,
          icon: _sending ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send, size: 15),
          style: IconButton.styleFrom(padding: const EdgeInsets.all(10)),
        ),
      ]),
      const SizedBox(height: 12),
      if (_loading)
        const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
      else if (_notes.isEmpty)
        Center(child: Padding(padding: const EdgeInsets.all(12), child: Text('No team notes yet', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant))))
      else
        ..._notes.take(20).map((n) {
          final author = n['author_name'] as String? ?? 'Unknown';
          final content = n['content'] as String? ?? '';
          final ts = DateTime.tryParse(n['created_at'] as String? ?? '') ?? DateTime.now();
          final isMine = n['user_id'] == me;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMine ? cs.primary.withValues(alpha: 0.05) : cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isMine ? cs.primary.withValues(alpha: 0.12) : cs.outline.withValues(alpha: 0.08)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(author, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.primary)),
                const Spacer(),
                Text(_relativeTime(ts), style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ]),
              const SizedBox(height: 4),
              Text(content, style: const TextStyle(fontSize: 13)),
            ]),
          );
        }),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

(IconData, Color, String) _activityMeta(ActivityModel a) => switch (a.type) {
  ActivityType.call => (Icons.call_made_outlined, const Color(0xFF4CAF50), a.text?.isNotEmpty == true ? a.text! : 'Call logged'),
  ActivityType.message => (Icons.mark_chat_read_outlined, const Color(0xFF2196F3), a.text?.isNotEmpty == true ? a.text! : 'Message logged'),
  ActivityType.note => (Icons.note_alt_outlined, const Color(0xFFFF9800), a.text?.isNotEmpty == true ? a.text! : 'Note added'),
  ActivityType.followup => (Icons.event_note_outlined, const Color(0xFF9C27B0), a.text?.isNotEmpty == true ? a.text! : 'Follow-up scheduled'),
};

class _TimelineEntry {
  final DateTime timestamp;
  final ActivityModel? activity;
  final TaskModel? task;
  const _TimelineEntry._({required this.timestamp, this.activity, this.task});
  factory _TimelineEntry.activity(ActivityModel a) => _TimelineEntry._(timestamp: a.createdAt, activity: a);
  factory _TimelineEntry.task(TaskModel t) => _TimelineEntry._(timestamp: DateTime.tryParse(t.dueDate ?? '') ?? t.createdAt, task: t);
}

String _dateLabel(DateTime dt) {
  final d = DateTime(dt.year, dt.month, dt.day);
  final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  if (d == today) return 'Today';
  if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return '${d.day}/${d.month}/${d.year}';
}

String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.isNegative) {
    final a = dt.difference(DateTime.now());
    if (a.inMinutes < 60) return 'in ${a.inMinutes}m';
    if (a.inHours < 24) return 'in ${a.inHours}h';
    if (a.inDays < 7) return 'in ${a.inDays}d';
    return _formatDate(dt);
  }
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return _formatDate(dt);
}

String _formatDate(DateTime dt) {
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
  final min = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'pm' : 'am';
  return '$m/$d ${h}:${min}$ampm';
}
