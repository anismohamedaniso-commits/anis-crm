import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:anis_crm/theme.dart';
import 'package:anis_crm/models/team_activity.dart';
import 'package:anis_crm/services/team_activity_service.dart';

class ActivityFeedPage extends StatefulWidget {
  const ActivityFeedPage({super.key});
  @override
  State<ActivityFeedPage> createState() => _ActivityFeedPageState();
}

class _ActivityFeedPageState extends State<ActivityFeedPage> {
  bool _loading = true;
  String _filter = 'all';

  static const _filters = <String, IconData>{
    'all': Icons.dashboard_outlined,
    'lead': Icons.person_outlined,
    'task': Icons.task_alt_outlined,
    'note': Icons.note_outlined,
    'chat': Icons.chat_outlined,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await TeamActivityService.instance.load();
    if (mounted) setState(() => _loading = false);
  }

  List<TeamActivity> _applyFilter(List<TeamActivity> all) {
    if (_filter == 'all') return all;
    return all.where((a) => a.action.contains(_filter) || a.targetType.contains(_filter)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dk = Theme.of(context).brightness == Brightness.dark;
    final wide = MediaQuery.of(context).size.width >= 760;
    final tt = Theme.of(context).textTheme;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header
      Padding(
        padding: EdgeInsets.symmetric(horizontal: wide ? 8 : 4),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Activity Feed', style: tt.headlineSmall?.semiBold),
              const SizedBox(height: 4),
              Text('See what your team has been working on',
                  style: tt.bodySmall?.withColor(cs.onSurface.withValues(alpha: 0.5))),
            ]),
          ),
          IconButton.filled(
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: 'Refresh',
            style: IconButton.styleFrom(
              backgroundColor: cs.primary.withValues(alpha: 0.08),
              foregroundColor: cs.primary,
            ),
          ),
        ]),
      ),
      const SizedBox(height: 16),

      // Filter chips
      Padding(
        padding: EdgeInsets.symmetric(horizontal: wide ? 8 : 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final e in _filters.entries) ...[
              _FilterChip(
                label: e.key[0].toUpperCase() + e.key.substring(1),
                icon: e.value,
                selected: _filter == e.key,
                onTap: () => setState(() => _filter = e.key),
              ),
              const SizedBox(width: 8),
            ],
          ]),
        ),
      ),
      const SizedBox(height: 16),

      // Feed
      Expanded(
        child: _loading
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.primary)),
                const SizedBox(height: 14),
                Text('Loading activity...', style: tt.bodySmall?.withColor(cs.onSurface.withValues(alpha: 0.4))),
              ]))
            : ValueListenableBuilder<List<TeamActivity>>(
                valueListenable: TeamActivityService.instance.activities,
                builder: (_, activities, __) {
                  final filtered = _applyFilter(activities);
                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.history_outlined, size: 32, color: cs.onSurface.withValues(alpha: 0.2)),
                        ),
                        const SizedBox(height: 16),
                        Text(_filter == 'all' ? 'No activity yet' : 'No $_filter activity',
                            style: tt.titleMedium?.semiBold),
                        const SizedBox(height: 6),
                        Text('Team actions will appear here as they happen',
                            style: tt.bodySmall?.withColor(cs.onSurface.withValues(alpha: 0.45))),
                      ]),
                    );
                  }

                  // Group by date
                  final grouped = <String, List<TeamActivity>>{};
                  for (final a in filtered) {
                    final key = _dateLabel(a.ts);
                    grouped.putIfAbsent(key, () => []).add(a);
                  }

                  return RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: wide ? 8 : 4),
                      itemCount: grouped.length,
                      itemBuilder: (_, i) {
                        final date = grouped.keys.elementAt(i);
                        final items = grouped[date]!;
                        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 12),
                            child: Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: cs.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(date,
                                    style: tt.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Divider(color: cs.outline.withValues(alpha: 0.08))),
                            ]),
                          ),
                          ...items.map((a) => _ActivityTile(activity: a, cs: cs, dk: dk)),
                        ]);
                      },
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  String _dateLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(d.year, d.month, d.day);
    if (date == today) return 'Today';
    if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${d.day}/${d.month}/${d.year}';
  }
}

class _FilterChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.icon, required this.selected, required this.onTap});
  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = widget.selected;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? cs.primary : (_hovered ? cs.primary.withValues(alpha: 0.05) : Colors.transparent),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? cs.primary : cs.outline.withValues(alpha: 0.15)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(widget.icon, size: 14, color: selected ? cs.onPrimary : cs.onSurface.withValues(alpha: 0.6)),
            const SizedBox(width: 6),
            Text(widget.label, style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected ? cs.onPrimary : cs.onSurface.withValues(alpha: 0.7),
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            )),
          ]),
        ),
      ),
    );
  }
}

class _ActivityTile extends StatefulWidget {
  final TeamActivity activity;
  final ColorScheme cs;
  final bool dk;
  const _ActivityTile({required this.activity, required this.cs, required this.dk});
  @override
  State<_ActivityTile> createState() => _ActivityTileState();
}

class _ActivityTileState extends State<_ActivityTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final dk = widget.dk;
    final a = widget.activity;
    final tt = Theme.of(context).textTheme;
    final iconData = _iconForAction(a.action);
    final color = _colorForAction(a.action, cs);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Timeline dot
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, size: 16, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: dk ? cs.surface.withValues(alpha: 0.5) : cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _hovered ? color.withValues(alpha: 0.2) : cs.outline.withValues(alpha: dk ? 0.08 : 0.05)),
                boxShadow: _hovered ? [BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 8)] : [],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                RichText(
                  text: TextSpan(
                    style: tt.bodyMedium,
                    children: [
                      TextSpan(text: a.userName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      TextSpan(text: ' ${a.description}'),
                    ],
                  ),
                ),
                if (a.detail.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(a.detail,
                      style: tt.bodySmall?.withColor(cs.onSurface.withValues(alpha: 0.45)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.access_time, size: 12, color: cs.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(width: 4),
                  Text(_timeAgo(a.ts),
                      style: tt.labelSmall?.withColor(cs.onSurface.withValues(alpha: 0.3))),
                  if (a.targetType == 'lead' && a.targetId.isNotEmpty) ...[
                    const Spacer(),
                    GestureDetector(
                      onTap: () => context.push('/app/lead/${a.targetId}'),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.open_in_new, size: 12, color: cs.primary.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Text('View Lead', style: tt.labelSmall?.copyWith(
                          color: cs.primary.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        )),
                      ]),
                    ),
                  ],
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  IconData _iconForAction(String action) {
    if (action.contains('lead')) return Icons.person_outlined;
    if (action.contains('task')) return Icons.task_alt_outlined;
    if (action.contains('note')) return Icons.note_outlined;
    if (action.contains('chat')) return Icons.chat_outlined;
    return Icons.history;
  }

  Color _colorForAction(String action, ColorScheme cs) {
    if (action.contains('assigned')) return cs.tertiary;
    if (action.contains('created')) return cs.primary;
    if (action.contains('done') || action.contains('completed')) return const Color(0xFF2E7D32);
    if (action.contains('deleted')) return cs.error;
    return cs.primary;
  }

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
