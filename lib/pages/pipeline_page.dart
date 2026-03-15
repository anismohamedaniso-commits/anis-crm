import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:anis_crm/theme.dart';
import 'package:anis_crm/engine/lead_score_engine.dart';
import 'package:anis_crm/models/lead.dart';
import 'package:anis_crm/services/lead_service.dart';
import 'package:anis_crm/state/app_state.dart';

class PipelinePage extends StatelessWidget {
  const PipelinePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final columns = _statusColumns();
    return Scaffold(
      appBar: AppBar(title: Text('Pipeline', style: context.textStyles.titleLarge?.semiBold), centerTitle: false),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ValueListenableBuilder(
          valueListenable: LeadService.instance.leads,
          builder: (context, List<LeadModel> allLeads, _) {
            final marketId = context.watch<AppState>().selectedMarketId;
            final leads = allLeads.where((l) => l.country == marketId).toList();
            final grouped = <LeadStatus, List<LeadModel>>{for (final s in LeadStatus.values) s: <LeadModel>[]};
            for (final l in leads) grouped[l.status]!.add(l);
            return isWide ? _DesktopKanban(columns: columns, data: grouped) : _MobileKanban(columns: columns, data: grouped);
          },
        ),
      ),
    );
  }

  List<_StatusColumnConfig> _statusColumns() => const [
        _StatusColumnConfig(status: LeadStatus.fresh, title: 'Fresh', color: Color(0xFF2196F3)),
        _StatusColumnConfig(status: LeadStatus.noAnswer, title: 'No Answer', color: AppColors.warning),
        _StatusColumnConfig(status: LeadStatus.interested, title: 'Interested', color: AppColors.success),
        _StatusColumnConfig(status: LeadStatus.followUp, title: 'Follow-Up', color: AppColors.info),
        _StatusColumnConfig(status: LeadStatus.notInterested, title: 'Not Interested', color: AppColors.danger),
        _StatusColumnConfig(status: LeadStatus.converted, title: 'Converted', color: Color(0xFF9C27B0)),
        _StatusColumnConfig(status: LeadStatus.closed, title: 'Closed', color: AppColors.neutralDark),
      ];
}

class _StatusColumnConfig {
  final LeadStatus status;
  final String title;
  final Color color;
  const _StatusColumnConfig({required this.status, required this.title, required this.color});
}

class _DesktopKanban extends StatelessWidget {
  const _DesktopKanban({required this.columns, required this.data});
  final List<_StatusColumnConfig> columns;
  final Map<LeadStatus, List<LeadModel>> data;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const _NoGlowBehavior(),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final c in columns)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.lg),
                  child: _KanbanColumn(status: c.status, title: c.title, color: c.color, leads: data[c.status] ?? const []),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _MobileKanban extends StatelessWidget {
  const _MobileKanban({required this.columns, required this.data});
  final List<_StatusColumnConfig> columns;
  final Map<LeadStatus, List<LeadModel>> data;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          for (int i = 0; i < columns.length; i++) ...[
            _CollapsibleSection(
              status: columns[i].status,
              title: columns[i].title,
              color: columns[i].color,
              leads: data[columns[i].status] ?? const [],
            ),
            if (i < columns.length - 1) const SizedBox(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({required this.status, required this.title, required this.color, required this.leads});
  final LeadStatus status;
  final String title;
  final Color color;
  final List<LeadModel> leads;

  @override
  Widget build(BuildContext context) {
    final headerBg = color.withValues(alpha: 0.08);
    final dotColor = color;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 300, maxWidth: 320),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(color: headerBg, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: headerBg.withValues(alpha: 0.7))),
          child: Row(children: [
            _StatusDot(color: dotColor),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.semiBold)),
            _CountBadge(count: leads.length, color: color),
          ]),
        ),
        const SizedBox(height: AppSpacing.md),
        DragTarget<LeadModel>(
          onWillAccept: (_) => true,
          onAccept: (l) {
            LeadService.instance.setStatus(l.id, status);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Lead moved to $title'), duration: Duration(milliseconds: 1200)),
            );
          },
          builder: (context, candidateData, rejectedData) {
            final isActive = candidateData.isNotEmpty;
            if (leads.isEmpty) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: isActive ? color.withValues(alpha: 0.35) : color.withValues(alpha: 0.12), width: isActive ? 2 : 1),
                  boxShadow: isActive ? [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 8)] : [],
                ),
                child: const _EmptyColumnPlaceholder(),
              );
            }
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: isActive ? color.withValues(alpha: 0.35) : Colors.transparent, width: isActive ? 2 : 0),
                boxShadow: isActive ? [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 8)] : [],
              ),
              child: Column(children: [
                for (final lead in leads)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: LongPressDraggable<LeadModel>(
                      data: lead,
                      feedback: Material(
                        color: Colors.transparent,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 260, maxWidth: 260),
                          child: _LeadCard(lead: lead, statusColor: dotColor, animate: true),
                        ),
                      ),
                      child: _LeadCard(lead: lead, statusColor: dotColor),
                    ),
                  ),
              ]),
            );
          },
        ),
      ]),
    );
  }
}

class _CollapsibleSection extends StatefulWidget {
  const _CollapsibleSection({required this.status, required this.title, required this.color, required this.leads});
  final LeadStatus status;
  final String title;
  final Color color;
  final List<LeadModel> leads;

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _expanded = true;
  @override
  Widget build(BuildContext context) {
    final headerBg = widget.color.withValues(alpha: 0.08);
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15)), borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(color: headerBg, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Row(children: [
              Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Theme.of(context).colorScheme.onSurface),
              const SizedBox(width: AppSpacing.sm),
              _StatusDot(color: widget.color),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(widget.title, style: Theme.of(context).textTheme.titleMedium?.semiBold)),
              _CountBadge(count: widget.leads.length, color: widget.color),
            ]),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: DragTarget<LeadModel>(
              onAccept: (l) {
                LeadService.instance.setStatus(l.id, widget.status);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lead moved to ${widget.title}'), duration: Duration(milliseconds: 1200)),
                );
              },
              builder: (context, candidateData, rejectedData) {
                final isActive = candidateData.isNotEmpty;
                if (widget.leads.isEmpty) {
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: isActive ? widget.color.withValues(alpha: 0.35) : widget.color.withValues(alpha: 0.12), width: isActive ? 2 : 1),
                      boxShadow: isActive ? [BoxShadow(color: widget.color.withValues(alpha: 0.08), blurRadius: 8)] : [],
                    ),
                    child: const _EmptyColumnPlaceholder(),
                  );
                }
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: isActive ? widget.color.withValues(alpha: 0.35) : Colors.transparent, width: isActive ? 2 : 0),
                    boxShadow: isActive ? [BoxShadow(color: widget.color.withValues(alpha: 0.08), blurRadius: 8)] : [],
                  ),
                  child: Column(children: [
                    for (final l in widget.leads)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: LongPressDraggable<LeadModel>(
                          data: l,
                          feedback: Material(
                            color: Colors.transparent,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 260, maxWidth: 260),
                              child: _LeadCard(lead: l, statusColor: widget.color, animate: true),
                            ),
                          ),
                          child: _LeadCard(lead: l, statusColor: widget.color),
                        ),
                      ),
                  ]),
                );
              },
            ),
          ),
      ]),
    );
  }
}

class _LeadCard extends StatefulWidget {
  const _LeadCard({required this.lead, required this.statusColor, this.animate = false});
  final LeadModel lead;
  final Color statusColor;
  final bool animate;
  @override
  State<_LeadCard> createState() => _LeadCardState();
}

class _LeadCardState extends State<_LeadCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final borderColor = _hovered ? widget.statusColor.withValues(alpha: 0.35) : cs.outline.withValues(alpha: 0.12);
    final score = LeadScoreEngine.compute(widget.lead);
    final temp = switch (score.temperature) { LeadTemperature.cold => 'Cold', LeadTemperature.warm => 'Warm', LeadTemperature.hot => 'Hot' };
    final tempColor = switch (score.temperature) { LeadTemperature.hot => AppColors.danger, LeadTemperature.warm => AppColors.warning, LeadTemperature.cold => AppColors.info };
    final muted = cs.onSurface.withValues(alpha: 0.55);
    final lead = widget.lead;
    final daysSince = DateTime.now().difference(lead.updatedAt).inDays;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: widget.animate ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 180),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: borderColor),
            boxShadow: _hovered ? [BoxShadow(color: widget.statusColor.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))] : [],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => context.push('/app/lead/${lead.id}'),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Name row
                Row(children: [
                  _StatusDot(color: widget.statusColor),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(lead.name, style: Theme.of(context).textTheme.titleSmall?.semiBold, overflow: TextOverflow.ellipsis)),
                  const Icon(Icons.drag_indicator, size: 18),
                ]),
                const SizedBox(height: 8),
                // Contact info
                if (lead.phone != null && lead.phone!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      Icon(Icons.phone_outlined, size: 14, color: muted),
                      const SizedBox(width: 6),
                      Expanded(child: Text(lead.phone!, style: Theme.of(context).textTheme.bodySmall?.withColor(muted), overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
                if (lead.email != null && lead.email!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      Icon(Icons.email_outlined, size: 14, color: muted),
                      const SizedBox(width: 6),
                      Expanded(child: Text(lead.email!, style: Theme.of(context).textTheme.bodySmall?.withColor(muted), overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
                const SizedBox(height: 6),
                // Footer: source + score + last activity
                Row(children: [
                  _SourceIcon(source: lead.source),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: tempColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text('${score.score} $temp', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tempColor, fontWeight: FontWeight.w600, fontSize: 10)),
                  ),
                  const Spacer(),
                  if (daysSince >= 0)
                    Text(daysSince == 0 ? 'Today' : '${daysSince}d ago', style: Theme.of(context).textTheme.labelSmall?.withColor(muted)),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.color});
  final int count;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final bg = color.withValues(alpha: 0.12);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)), child: Text('$count', style: Theme.of(context).textTheme.labelSmall?.withColor(color).medium));
  }
}

class _EmptyColumnPlaceholder extends StatelessWidget {
  const _EmptyColumnPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1))),
      child: Row(children: [
        Icon(Icons.inbox_outlined, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text('No leads in this stage yet', style: Theme.of(context).textTheme.bodyMedium?.withColor(Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)))),
      ]),
    );
  }
}

class _NoGlowBehavior extends ScrollBehavior {
  const _NoGlowBehavior();
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
}

class _SourceIcon extends StatelessWidget {
  const _SourceIcon({required this.source});
  final LeadSource source;
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    IconData icon;
    switch (source) {
      case LeadSource.manual:
        icon = Icons.edit_note;
        break;
      case LeadSource.whatsapp:
        icon = Icons.chat_bubble_outline;
        break;
      case LeadSource.email:
        icon = Icons.mail_outline;
        break;
      case LeadSource.phone:
        icon = Icons.call_outlined;
        break;
      case LeadSource.web:
        icon = Icons.public;
        break;
      case LeadSource.facebook:
        icon = Icons.facebook;
        break;
      case LeadSource.instagram:
        icon = Icons.camera_alt_outlined;
        break;
      case LeadSource.linkedin:
        icon = Icons.work_outline;
        break;
      case LeadSource.tiktok:
        icon = Icons.videocam_outlined;
        break;
      case LeadSource.imported:
        icon = Icons.archive_outlined;
        break;
      case LeadSource.zapier:
        icon = Icons.bolt_outlined;
        break;
    }
    return Icon(icon, size: 18, color: color);
  }
}

String _tempLabel(String s) => s;
