import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:anis_crm/theme.dart';
import 'package:anis_crm/engine/lead_score_engine.dart';
import 'package:anis_crm/models/lead.dart';
import 'package:anis_crm/models/activity.dart';
import 'package:anis_crm/services/lead_service.dart';
import 'package:anis_crm/services/activity_service.dart';
import 'package:anis_crm/services/social_launcher.dart';
import 'package:anis_crm/services/auth_service.dart';
import 'package:anis_crm/state/app_state.dart';
import 'package:provider/provider.dart';

import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as ex;
import 'package:anis_crm/utils/simple_file_picker.dart';
import 'package:anis_crm/utils/csv_download_stub.dart'
    if (dart.library.html) 'package:anis_crm/utils/csv_download_web.dart';
import 'package:anis_crm/utils/excel_builder.dart';
import 'package:anis_crm/utils/excel_download_stub.dart'
    if (dart.library.html) 'package:anis_crm/utils/excel_download_web.dart';

// =============================================================================
// STATUS COLORS & HELPERS
// =============================================================================

const Color _kFreshColor = Color(0xFF3B82F6);
const Color _kInterestedColor = Color(0xFF22C55E);
const Color _kNoAnswerColor = Color(0xFFF59E0B);
const Color _kFollowUpColor = Color(0xFF6366F1);
const Color _kNotInterestedColor = Color(0xFFEF4444);
const Color _kConvertedColor = Color(0xFF8B5CF6);
const Color _kClosedColor = Color(0xFF64748B);

(String, Color, IconData) _statusMeta(LeadStatus s) => switch (s) {
      LeadStatus.fresh => ('Fresh', _kFreshColor, Icons.fiber_new_rounded),
      LeadStatus.interested => ('Interested', _kInterestedColor, Icons.thumb_up_alt_rounded),
      LeadStatus.noAnswer => ('No answer', _kNoAnswerColor, Icons.phone_missed_rounded),
      LeadStatus.followUp => ('Follow up', _kFollowUpColor, Icons.schedule_rounded),
      LeadStatus.notInterested => ('Not interested', _kNotInterestedColor, Icons.thumb_down_alt_rounded),
      LeadStatus.converted => ('Converted', _kConvertedColor, Icons.emoji_events_rounded),
      LeadStatus.closed => ('Closed', _kClosedColor, Icons.check_circle_rounded),
    };

String _tempLabel(LeadTemperature t) => switch (t) {
      LeadTemperature.cold => 'Cold',
      LeadTemperature.warm => 'Warm',
      LeadTemperature.hot => 'Hot',
    };

Color _tempColor(LeadTemperature t) => switch (t) {
      LeadTemperature.cold => const Color(0xFF60A5FA),
      LeadTemperature.warm => const Color(0xFFFBBF24),
      LeadTemperature.hot => const Color(0xFFF87171),
    };

IconData _tempIcon(LeadTemperature t) => switch (t) {
      LeadTemperature.cold => Icons.ac_unit_rounded,
      LeadTemperature.warm => Icons.wb_sunny_rounded,
      LeadTemperature.hot => Icons.local_fire_department_rounded,
    };

String _formatDateTime(DateTime dt) {
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final y = dt.year;
  final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
  final min = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'pm' : 'am';
  return '$m/$d/$y $h:$min$ampm';
}

String _shortDate(DateTime dt) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  return '${(diff.inDays / 30).floor()}mo ago';
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

Color _avatarColor(String name) {
  final colors = [
    const Color(0xFF3B82F6), const Color(0xFF22C55E), const Color(0xFFF59E0B),
    const Color(0xFF8B5CF6), const Color(0xFFEC4899), const Color(0xFF14B8A6),
    const Color(0xFFF97316), const Color(0xFF6366F1),
  ];
  return colors[name.hashCode.abs() % colors.length];
}


// =============================================================================
// LEADS PAGE
// =============================================================================

class LeadsPage extends StatefulWidget {
  const LeadsPage({super.key});
  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> {
  LeadStatus? _selectedStatus;
  String _searchQuery = '';
  String _sortBy = 'newest'; // newest, oldest, name_asc, name_desc, score
  final TextEditingController _searchCtrl = TextEditingController();

  // Bulk selection
  bool _bulkMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    LeadService.instance.load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<LeadModel> _applyFilters(List<LeadModel> leads, String marketId) {
    return leads.where((l) {
      // Country filter — driven by global market selector
      final countryOk = l.country == marketId;
      // Status filter
      final statusOk = _selectedStatus == null || l.status == _selectedStatus;
      // Search filter
      final q = _searchQuery.toLowerCase();
      final searchOk = q.isEmpty ||
          l.name.toLowerCase().contains(q) ||
          (l.phone?.toLowerCase().contains(q) ?? false) ||
          (l.email?.toLowerCase().contains(q) ?? false) ||
          (l.campaign?.toLowerCase().contains(q) ?? false);
      return countryOk && statusOk && searchOk;
    }).toList()
      ..sort((a, b) {
        switch (_sortBy) {
          case 'oldest': return a.createdAt.compareTo(b.createdAt);
          case 'name_asc': return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          case 'name_desc': return b.name.toLowerCase().compareTo(a.name.toLowerCase());
          case 'score':
            final sa = LeadScoreEngine.compute(a).score;
            final sb = LeadScoreEngine.compute(b).score;
            return sb.compareTo(sa);
          default: return b.createdAt.compareTo(a.createdAt);
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(children: [
        // ── Top bar ──
        Builder(builder: (context) {
          final market = context.watch<AppState>().selectedMarket;
          return _TopBar(
          title: '${market.flag} ${market.label} Leads',
          onExport: () => _exportExcel(context),
          onDeleteAll: () => _deleteAllLeads(context),
          onCalendar: () => context.go('/app/calendar'),
          onMenu: () => _showSortMenu(context),
          leadCount: _applyFilters(LeadService.instance.leads.value, market.id).length,
          sortBy: _sortBy,
          bulkMode: _bulkMode,
          onToggleBulk: () => setState(() { _bulkMode = !_bulkMode; _selectedIds.clear(); }),
        );
        }),
        // ── Search bar ──
        Padding(
          padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width < 500 ? 12 : 20, vertical: 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v),
            style: tt.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Search by name, phone, email or campaign...',
              hintStyle: tt.bodySmall?.withColor(cs.onSurface.withValues(alpha: 0.35)),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 12, right: 8),
                child: Icon(Icons.search_rounded, size: 20, color: cs.onSurface.withValues(alpha: 0.4)),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.4)),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.25),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.5), width: 1.5)),
            ),
          ),
        ),
        // ── Status filter pills ──
        ValueListenableBuilder(
          valueListenable: LeadService.instance.leads,
          builder: (context, List<LeadModel> allLeads, _) {
            final marketId = context.watch<AppState>().selectedMarketId;
            final marketLeads = allLeads.where((l) => l.country == marketId).toList();
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width < 500 ? 12 : 20, vertical: 4),
              child: _StatusPillFilter(
                selected: _selectedStatus,
                onChanged: (s) => setState(() => _selectedStatus = s),
                leads: marketLeads,
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        // ── Table ──
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: LeadService.instance.leads,
            builder: (context, List<LeadModel> leads, _) {
              final marketId = context.watch<AppState>().selectedMarketId;
              final filtered = _applyFilters(leads, marketId);
              if (filtered.isEmpty) {
                return _EmptyState(hasFilters: _searchQuery.isNotEmpty || _selectedStatus != null);
              }
              final isDesktop = MediaQuery.of(context).size.width > 700;
              return Stack(children: [
                isDesktop
                    ? _DesktopTable(
                        leads: filtered,
                        onRefresh: () => setState(() {}),
                        bulkMode: _bulkMode,
                        selectedIds: _selectedIds,
                        onToggle: (id) => setState(() {
                          _selectedIds.contains(id) ? _selectedIds.remove(id) : _selectedIds.add(id);
                        }),
                        onSelectAll: (all) => setState(() {
                          if (all) { _selectedIds.addAll(filtered.map((l) => l.id)); } else { _selectedIds.clear(); }
                        }),
                      )
                    : _MobileList(
                        leads: filtered,
                        onRefresh: () => setState(() {}),
                        bulkMode: _bulkMode,
                        selectedIds: _selectedIds,
                        onToggle: (id) => setState(() {
                          _selectedIds.contains(id) ? _selectedIds.remove(id) : _selectedIds.add(id);
                        }),
                      ),
                if (_bulkMode && _selectedIds.isNotEmpty)
                  Positioned(
                    left: 0, right: 0, bottom: 0,
                    child: _BulkActionBar(
                      count: _selectedIds.length,
                      onChangeStatus: _bulkChangeStatus,
                      onAssign: _bulkAssign,
                      onExport: _bulkExport,
                      onDelete: _bulkDelete,
                      onClear: () => setState(() => _selectedIds.clear()),
                    ),
                  ),
              ]);
            },
          ),
        ),
      ]),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'import',
            onPressed: () => showDialog(context: context, builder: (_) => const _ImportLeadsDialog()),
            backgroundColor: cs.surfaceContainerHighest,
            foregroundColor: cs.onSurface,
            elevation: 2,
            tooltip: 'Import CSV/Excel',
            child: const Icon(Icons.file_upload_outlined, size: 20),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'newLead',
            onPressed: () async {
              final created = await showDialog<LeadModel>(context: context, builder: (_) => const _LeadEditorDialog());
              if (created != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text('Lead "${created.name}" created'),
                ));
              }
            },
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            elevation: 3,
            icon: const Icon(Icons.person_add_rounded, size: 20),
            label: Text('New Lead', style: tt.bodySmall?.semiBold),
          ),
        ],
      ),
    );
  }

  // ── Delete All ──
  Future<void> _deleteAllLeads(BuildContext context) async {
    final count = LeadService.instance.leads.value.length;
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No leads to delete')));
      return;
    }
    final ok = await showDialog<bool>(context: context, builder: (dialogCtx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error), const SizedBox(width: 10), const Text('Delete all leads?')]),
      content: Text('This will permanently delete all $count leads. This action cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.of(dialogCtx).pop(true),
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          child: Text('Delete all $count leads'),
        ),
      ],
    ));
    if (ok == true) {
      final ids = LeadService.instance.leads.value.map((l) => l.id).toList();
      for (final id in ids) {
        await LeadService.instance.delete(id);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted $count leads')));
        setState(() {});
      }
    }
  }

  // ── Export Excel ──
  Future<void> _exportExcel(BuildContext context) async {
    final leads = _applyFilters(LeadService.instance.leads.value, context.read<AppState>().selectedMarketId);
    if (leads.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No leads to export')));
      return;
    }
    try {
      final bytes = buildLeadsExcel(leads);
      final now = DateTime.now();
      final fname = 'leads_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.xlsx';
      final ok = await downloadExcelFile(bytes, fname);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? '\u2713 Exported ${leads.length} leads \u2014 4 colored sheets'
              : 'Export not supported on this platform'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: ok
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.error,
        ));
      }
    } catch (e) {
      debugPrint('Export error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Export failed: $e'),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ── Sort menu ──
  void _showSortMenu(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final RenderBox button = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset(button.size.width, 0), ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem(value: 'newest', child: _sortItem('Newest first', Icons.arrow_downward, _sortBy == 'newest', cs)),
        PopupMenuItem(value: 'oldest', child: _sortItem('Oldest first', Icons.arrow_upward, _sortBy == 'oldest', cs)),
        PopupMenuItem(value: 'name_asc', child: _sortItem('Name A-Z', Icons.sort_by_alpha, _sortBy == 'name_asc', cs)),
        PopupMenuItem(value: 'name_desc', child: _sortItem('Name Z-A', Icons.sort_by_alpha, _sortBy == 'name_desc', cs)),
        PopupMenuItem(value: 'score', child: _sortItem('Highest score', Icons.local_fire_department, _sortBy == 'score', cs)),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'refresh', child: _sortItem('Refresh', Icons.refresh, false, cs)),
      ],
    ).then((v) {
      if (v == null) return;
      if (v == 'refresh') {
        setState(() {});
        return;
      }
      setState(() => _sortBy = v);
    });
  }

  Widget _sortItem(String label, IconData icon, bool active, ColorScheme cs) {
    final tt = Theme.of(context).textTheme;
    return Row(children: [
      Icon(icon, size: 16, color: active ? cs.primary : cs.onSurface.withValues(alpha: 0.5)),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: tt.bodySmall?.copyWith(fontWeight: active ? FontWeight.w600 : FontWeight.w400, color: active ? cs.primary : cs.onSurface))),
      if (active) Icon(Icons.check_rounded, size: 16, color: cs.primary),
    ]);
  }

  // ── Bulk actions ──
  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
  }

  Future<void> _bulkChangeStatus() async {
    final cs = Theme.of(context).colorScheme;
    final newStatus = await showDialog<LeadStatus>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Change status for ${_selectedIds.length} leads'),
        children: LeadStatus.values.map((s) {
          final (label, color, icon) = _statusMeta(s);
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, s),
            child: Row(children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 12),
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ]),
          );
        }).toList(),
      ),
    );
    if (newStatus == null) return;
    final count = await LeadService.instance.bulkSetStatus(_selectedIds.toList(), newStatus);
    _snack('Updated $count leads to ${_statusMeta(newStatus).$1}');
    setState(() => _selectedIds.clear());
  }

  Future<void> _bulkAssign() async {
    List<CrmUser> team = [];
    try { team = await AuthService.instance.listUsers(); } catch (_) {}
    if (!mounted || team.isEmpty) return;
    final user = await showDialog<CrmUser>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Assign ${_selectedIds.length} leads to'),
        children: team.map((u) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, u),
          child: Row(children: [
            CircleAvatar(radius: 14, backgroundColor: _avatarColor(u.name).withValues(alpha: 0.15),
              child: Text(_initials(u.name), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _avatarColor(u.name)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u.name, style: Theme.of(context).textTheme.bodyMedium),
              Text(u.email, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
            ])),
          ]),
        )).toList(),
      ),
    );
    if (user == null) return;
    final count = await LeadService.instance.bulkAssign(_selectedIds.toList(), user.id, user.name);
    _snack('Assigned $count leads to ${user.name}');
    setState(() => _selectedIds.clear());
  }

  Future<void> _bulkExport() async {
    final allLeads = LeadService.instance.leads.value;
    final selected = allLeads.where((l) => _selectedIds.contains(l.id)).toList();
    if (selected.isEmpty) return;
    final rows = <List<String>>[
      ['Name', 'Phone', 'Email', 'Status', 'Source', 'Campaign', 'Created', 'Last Contacted'],
      ...selected.map((l) => [
        l.name,
        l.phone ?? '',
        l.email ?? '',
        _statusMeta(l.status).$1,
        l.source.name,
        l.campaign ?? '',
        _formatDateTime(l.createdAt),
        l.lastContactedAt != null ? _formatDateTime(l.lastContactedAt!) : '',
      ]),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    try {
      final ok = await downloadCsvFile(csv, 'leads_selected_${DateTime.now().millisecondsSinceEpoch}.csv');
      if (mounted && ok) _snack('Exported ${selected.length} leads');
    } catch (e) {
      _snack('Export failed', error: true);
    }
  }

  Future<void> _bulkDelete() async {
    if (!(AuthService.instance.user?.canDeleteLeads ?? false)) {
      _snack('No permission to delete leads', error: true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 10),
          Text('Delete ${_selectedIds.length} leads?'),
        ]),
        content: const Text('This action cannot be undone. All selected leads will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: Text('Delete ${_selectedIds.length}'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final count = await LeadService.instance.bulkDelete(_selectedIds.toList());
    _snack('Deleted $count leads');
    setState(() { _selectedIds.clear(); _bulkMode = false; });
  }
}

// =============================================================================
// TOP BAR
// =============================================================================

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onExport;
  final VoidCallback onDeleteAll;
  final VoidCallback onCalendar;
  final VoidCallback onMenu;
  final int leadCount;
  final String sortBy;
  final bool bulkMode;
  final VoidCallback onToggleBulk;
  const _TopBar({this.title = 'Leads', required this.onExport, required this.onDeleteAll, required this.onCalendar, required this.onMenu, this.leadCount = 0, this.sortBy = 'newest', this.bulkMode = false, required this.onToggleBulk});

  String get _sortLabel => switch (sortBy) {
    'oldest' => 'Oldest',
    'name_asc' => 'A → Z',
    'name_desc' => 'Z → A',
    'score' => 'Score',
    _ => 'Newest',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isNarrow = MediaQuery.of(context).size.width < 500;
    return Padding(
      padding: EdgeInsets.fromLTRB(isNarrow ? 12 : 24, isNarrow ? 12 : 20, isNarrow ? 8 : 16, 4),
      child: Row(children: [
        // Title section
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(title, style: tt.headlineSmall?.bold.withColor(cs.onSurface).copyWith(letterSpacing: -0.5, fontSize: isNarrow ? 20 : null))),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$leadCount', style: tt.labelMedium?.bold.withColor(cs.primary)),
            ),
          ]),
          const SizedBox(height: 2),
          Text(
            'Sorted by $_sortLabel',
            style: tt.labelMedium?.withColor(cs.onSurface.withValues(alpha: 0.4)),
          ),
        ])),
        // Bulk toggle
        _BarButton(
          icon: bulkMode ? Icons.close_rounded : Icons.checklist_rounded,
          label: bulkMode ? 'Cancel Select' : 'Select',
          onTap: onToggleBulk,
        ),
        if (!isNarrow) ...[
          const SizedBox(width: 4),
          _BarButton(icon: Icons.download_rounded, label: 'Export', onTap: onExport),
          const SizedBox(width: 4),
          _BarButton(icon: Icons.calendar_today_rounded, label: 'Calendar', onTap: onCalendar),
        ],
        const SizedBox(width: 4),
        _BarButton(icon: Icons.sort_rounded, label: 'Sort', onTap: onMenu),
        if (isNarrow) ...[
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, size: 19, color: cs.onSurface.withValues(alpha: 0.55)),
            tooltip: 'More actions',
            onSelected: (v) {
              if (v == 'export') onExport();
              if (v == 'calendar') onCalendar();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'export', child: Text('Export')),
              const PopupMenuItem(value: 'calendar', child: Text('Calendar')),
            ],
          ),
        ],
      ]),
    );
  }
}

class _BarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _BarButton({required this.icon, required this.label, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = danger ? cs.error : cs.onSurface.withValues(alpha: 0.55);
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Icon(icon, size: 19, color: c),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// STATUS DOT FILTER
// =============================================================================

class _StatusPillFilter extends StatelessWidget {
  final LeadStatus? selected;
  final ValueChanged<LeadStatus?> onChanged;
  final List<LeadModel> leads;
  const _StatusPillFilter({required this.selected, required this.onChanged, required this.leads});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Count leads per status
    final counts = <LeadStatus, int>{};
    for (final l in leads) {
      counts[l.status] = (counts[l.status] ?? 0) + 1;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // "All" pill
          _buildPill(context, cs, null, 'All', null, leads.length, counts),
          const SizedBox(width: 6),
          ...LeadStatus.values.map((s) {
            final (label, color, icon) = _statusMeta(s);
            final count = counts[s] ?? 0;
            if (count == 0 && selected != s) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _buildPill(context, cs, s, label, color, count, counts),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPill(BuildContext context, ColorScheme cs, LeadStatus? status, String label, Color? color, int count, Map<LeadStatus, int> counts) {
    final isAll = status == null;
    final isSelected = selected == status;
    final pillColor = color ?? cs.primary;
    final tt = Theme.of(context).textTheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Material(
        color: isSelected
            ? pillColor.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => onChanged(isSelected && !isAll ? null : status),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? pillColor.withValues(alpha: 0.4) : cs.outline.withValues(alpha: 0.15),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (!isAll) ...[  
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: pillColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: tt.labelMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? pillColor : cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? pillColor.withValues(alpha: 0.15) : cs.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: tt.labelSmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? pillColor : cs.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}



// =============================================================================
// DESKTOP TABLE
// =============================================================================

class _DesktopTable extends StatelessWidget {
  final List<LeadModel> leads;
  final VoidCallback? onRefresh;
  final bool bulkMode;
  final Set<String> selectedIds;
  final ValueChanged<String>? onToggle;
  final ValueChanged<bool>? onSelectAll;
  const _DesktopTable({required this.leads, this.onRefresh, this.bulkMode = false, this.selectedIds = const {}, this.onToggle, this.onSelectAll});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final headerStyle = tt.labelSmall?.semiBold.withColor(cs.onSurface.withValues(alpha: 0.4)).copyWith(letterSpacing: 0.5);
    final allSelected = leads.isNotEmpty && leads.every((l) => selectedIds.contains(l.id));

    return Column(children: [
      // Header row
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.1))),
        ),
        child: Row(children: [
          if (bulkMode) ...[
            SizedBox(width: 40, child: Checkbox(
              value: allSelected,
              onChanged: (v) => onSelectAll?.call(v ?? false),
              visualDensity: VisualDensity.compact,
            )),
          ],
          const SizedBox(width: 48), // avatar space
          _hCell('NAME', flex: 3, style: headerStyle),
          _hCell('SOURCE', flex: 2, style: headerStyle),
          _hCell('DATE', flex: 15, style: headerStyle),
          _hCell('STATUS', flex: 2, style: headerStyle),
          _hCell('SCORE', flex: 2, style: headerStyle),
          _hCell('LAST ACTIVITY', flex: 2, style: headerStyle),
          _hCell('', flex: 1, style: headerStyle),
        ]),
      ),
      // Rows
      Expanded(
        child: ListView.builder(
          itemCount: leads.length,
          itemBuilder: (context, i) => _LeadRow(
            lead: leads[i],
            onRefresh: onRefresh,
            isEven: i.isEven,
            bulkMode: bulkMode,
            selected: selectedIds.contains(leads[i].id),
            onToggle: () => onToggle?.call(leads[i].id),
          ),
        ),
      ),
    ]);
  }

  Widget _hCell(String text, {double flex = 1, TextStyle? style}) => Expanded(
        flex: (flex * 100).round(),
        child: Text(text, style: style),
      );
}

// =============================================================================
// LEAD ROW
// =============================================================================

class _LeadRow extends StatefulWidget {
  final LeadModel lead;
  final VoidCallback? onRefresh;
  final bool isEven;
  final bool bulkMode;
  final bool selected;
  final VoidCallback? onToggle;
  const _LeadRow({required this.lead, this.onRefresh, this.isEven = false, this.bulkMode = false, this.selected = false, this.onToggle});
  @override
  State<_LeadRow> createState() => _LeadRowState();
}

class _LeadRowState extends State<_LeadRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final lead = widget.lead;
    final score = LeadScoreEngine.compute(lead);
    final (statusLabel, statusColor, _) = _statusMeta(lead.status);
    final initial = _initials(lead.name);
    final avatarBg = _avatarColor(lead.name);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: widget.selected
            ? cs.primary.withValues(alpha: 0.08)
            : _hovered
                ? cs.primary.withValues(alpha: 0.04)
                : widget.isEven
                    ? cs.surface
                    : cs.surfaceContainerHighest.withValues(alpha: 0.06),
        child: InkWell(
          onTap: widget.bulkMode ? widget.onToggle : () => context.push('/app/lead/${lead.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Row(children: [
              // Bulk checkbox
              if (widget.bulkMode) ...[
                SizedBox(width: 40, child: Checkbox(
                  value: widget.selected,
                  onChanged: (_) => widget.onToggle?.call(),
                  visualDensity: VisualDensity.compact,
                )),
              ],
              // Avatar
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: avatarBg.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(initial, style: tt.bodySmall?.bold.withColor(avatarBg)),
                ),
              ),
              const SizedBox(width: 12),
              // Name + contact info
              Expanded(
                flex: 300,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      lead.name,
                      style: tt.bodySmall?.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600, color: cs.onSurface),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      lead.email ?? lead.phone ?? 'No contact info',
                      style: tt.labelSmall?.copyWith(fontSize: 11.5, color: cs.onSurface.withValues(alpha: 0.4)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Source + Campaign
              Expanded(
                flex: 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_sourceIcon(lead.source), size: 13, color: cs.onSurface.withValues(alpha: 0.4)),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          lead.campaign ?? lead.source.name,
                          style: tt.labelMedium?.medium.withColor(cs.onSurface.withValues(alpha: 0.6)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
              // Lead date
              Expanded(
                flex: 150,
                child: Text(
                  _shortDate(lead.createdAt),
                  style: tt.labelSmall?.copyWith(fontSize: 11.5, color: cs.onSurface.withValues(alpha: 0.4)),
                ),
              ),
              // Status chip
              Expanded(
                flex: 200,
                child: _InlineStatusChip(leadId: lead.id, label: statusLabel, color: statusColor, currentStatus: lead.status),
              ),
              // Score badge
              Expanded(
                flex: 200,
                child: _ScoreBadge(score: score),
              ),
              // Last activity
              Expanded(
                flex: 200,
                child: Text(
                  lead.lastContactedAt != null
                      ? _relativeTime(lead.lastContactedAt!)
                      : _relativeTime(lead.createdAt),
                  style: tt.labelMedium?.withColor(cs.onSurface.withValues(alpha: 0.4)),
                ),
              ),
              // Actions
              Expanded(
                flex: 100,
                child: AnimatedOpacity(
                  opacity: _hovered ? 1.0 : 0.3,
                  duration: const Duration(milliseconds: 150),
                  child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (lead.phone != null && lead.phone!.isNotEmpty)
                      _ActionIcon(icon: Icons.call_rounded, tooltip: 'Call ${lead.name}', color: _kInterestedColor, onTap: () async {
                        final ok = await SocialLauncher.dialPhone(lead.phone!);
                        await ActivityService.instance.add(leadId: lead.id, type: ActivityType.call, text: ok ? 'Phone call launched' : 'Phone call failed');
                        await LeadService.instance.setLastContacted(lead.id, DateTime.now());
                      }),
                    if (AuthService.instance.user?.canDeleteLeads ?? false)
                      _ActionIcon(icon: Icons.delete_outline_rounded, tooltip: 'Delete', color: cs.onSurface.withValues(alpha: 0.4), onTap: () => _confirmDelete(context, lead)),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  IconData _sourceIcon(LeadSource s) => switch (s) {
    LeadSource.whatsapp => Icons.chat_rounded,
    LeadSource.facebook => Icons.facebook_rounded,
    LeadSource.instagram => Icons.camera_alt_rounded,
    LeadSource.linkedin => Icons.work_rounded,
    LeadSource.email => Icons.email_rounded,
    LeadSource.phone => Icons.phone_rounded,
    LeadSource.web => Icons.language_rounded,
    LeadSource.tiktok => Icons.music_note_rounded,
    _ => Icons.person_rounded,
  };

  Future<void> _confirmDelete(BuildContext context, LeadModel lead) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Delete ${lead.name}?'),
        content: const Text('This action cannot be undone. All associated activities will also be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _kNotInterestedColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await LeadService.instance.delete(lead.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('"${lead.name}" deleted'),
        ));
      }
    }
  }
}

// =============================================================================
// STATUS CHIP
// =============================================================================

/// Inline status chip with popup to change status directly from lead list
class _InlineStatusChip extends StatelessWidget {
  final String leadId;
  final String label;
  final Color color;
  final LeadStatus currentStatus;
  const _InlineStatusChip({required this.leadId, required this.label, required this.color, required this.currentStatus});

  @override
  Widget build(BuildContext context) {
    final canChange = AuthService.instance.user?.canChangeStatus ?? false;
    final tt = Theme.of(context).textTheme;

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: tt.labelMedium?.medium.withColor(color)),
        if (canChange) ...[
          const SizedBox(width: 3),
          Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: color.withValues(alpha: 0.7)),
        ],
      ]),
    );

    if (!canChange) return chip;

    return PopupMenuButton<LeadStatus>(
      onSelected: (newStatus) async {
        if (newStatus == currentStatus) return;
        if (currentStatus == LeadStatus.closed) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (dialogCtx) => AlertDialog(
              title: const Text('Reopen lead?'),
              content: const Text('This lead is currently Closed. Change its status?'),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.of(dialogCtx).pop(true), child: const Text('Confirm')),
              ],
            ),
          );
          if (proceed != true) return;
        }
        await LeadService.instance.setStatus(leadId, newStatus);
        if (context.mounted) {
          final (newLabel, _, __) = _statusMeta(newStatus);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Status → $newLabel'),
            duration: const Duration(seconds: 1),
          ));
        }
      },
      itemBuilder: (_) => LeadStatus.values.map((s) {
        final (sLabel, sColor, sIcon) = _statusMeta(s);
        return PopupMenuItem<LeadStatus>(
          value: s,
          child: Row(children: [
            Icon(sIcon, size: 15, color: sColor),
            const SizedBox(width: 8),
            Expanded(child: Text(sLabel, style: tt.bodySmall?.copyWith(fontWeight: s == currentStatus ? FontWeight.w600 : FontWeight.w400))),
            if (s == currentStatus) Icon(Icons.check_rounded, size: 16, color: sColor),
          ]),
        );
      }).toList(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      offset: const Offset(0, 32),
      child: chip,
    );
  }
}

// =============================================================================
// SCORE BADGE
// =============================================================================

class _ScoreBadge extends StatelessWidget {
  final LeadScoreResult score;
  const _ScoreBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final color = _tempColor(score.temperature);
    final label = _tempLabel(score.temperature);
    final icon = _tempIcon(score.temperature);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text('${score.score}', style: tt.labelMedium?.bold.withColor(color)),
          const SizedBox(width: 2),
          Text(label, style: tt.labelSmall?.withColor(color.withValues(alpha: 0.7))),
        ]),
      ),
    ]);
  }
}

// =============================================================================
// ACTION ICON
// =============================================================================

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? tooltip;
  const _ActionIcon({required this.icon, required this.color, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final child = InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 18, color: color),
      ),
    );
    if (tooltip != null) return Tooltip(message: tooltip!, child: child);
    return child;
  }
}

// =============================================================================
// MOBILE LIST
// =============================================================================

class _MobileList extends StatelessWidget {
  final List<LeadModel> leads;
  final VoidCallback? onRefresh;
  final bool bulkMode;
  final Set<String> selectedIds;
  final ValueChanged<String>? onToggle;
  const _MobileList({required this.leads, this.onRefresh, this.bulkMode = false, this.selectedIds = const {}, this.onToggle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: leads.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final lead = leads[i];
        final score = LeadScoreEngine.compute(lead);
        final (statusLabel, statusColor, _) = _statusMeta(lead.status);
        final avatarBg = _avatarColor(lead.name);

        final isSel = selectedIds.contains(lead.id);

        return InkWell(
          onTap: bulkMode ? () => onToggle?.call(lead.id) : () => context.push('/app/lead/${lead.id}'),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSel ? cs.primary.withValues(alpha: 0.08) : cs.surfaceContainerHighest.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isSel ? cs.primary.withValues(alpha: 0.3) : cs.outline.withValues(alpha: 0.08)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header: Avatar + Name + Score
              Row(children: [
                if (bulkMode) ...[
                  Checkbox(
                    value: isSel,
                    onChanged: (_) => onToggle?.call(lead.id),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                ],
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: avatarBg.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(_initials(lead.name), style: tt.bodyMedium?.bold.withColor(avatarBg)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(lead.name, style: tt.titleSmall?.semiBold.withColor(cs.onSurface)),
                    if (lead.email != null || lead.phone != null)
                      Text(
                        lead.email ?? lead.phone ?? '',
                        style: tt.labelMedium?.withColor(cs.onSurface.withValues(alpha: 0.4)),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ]),
                ),
                _ScoreBadge(score: score),
              ]),
              const SizedBox(height: 10),
              // Status + source + date
              Row(children: [
                _InlineStatusChip(leadId: lead.id, label: statusLabel, color: statusColor, currentStatus: lead.status),
                const SizedBox(width: 8),
                Text(_shortDate(lead.createdAt), style: tt.labelSmall?.withColor(cs.onSurface.withValues(alpha: 0.35))),
                const SizedBox(width: 8),
                if (lead.campaign != null && lead.campaign!.isNotEmpty)
                  Expanded(
                    child: Text(lead.campaign!, style: tt.labelMedium?.withColor(cs.onSurface.withValues(alpha: 0.4)), overflow: TextOverflow.ellipsis),
                  )
                else
                  const Spacer(),
                // Quick actions
                if (lead.phone != null && lead.phone!.isNotEmpty)
                  _ActionIcon(icon: Icons.call_rounded, tooltip: 'Call', color: _kInterestedColor, onTap: () async {
                    final ok = await SocialLauncher.dialPhone(lead.phone!);
                    await ActivityService.instance.add(leadId: lead.id, type: ActivityType.call, text: ok ? 'Phone call launched' : 'Phone call failed');
                    await LeadService.instance.setLastContacted(lead.id, DateTime.now());
                  }),
                if (AuthService.instance.user?.canDeleteLeads ?? false)
                  _ActionIcon(icon: Icons.delete_outline_rounded, tooltip: 'Delete', color: cs.onSurface.withValues(alpha: 0.3), onTap: () async {
                  final ok = await showDialog<bool>(context: context, builder: (dialogCtx) => AlertDialog(
                    title: Text('Delete ${lead.name}?'),
                    content: const Text('This action cannot be undone.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Cancel')),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        style: FilledButton.styleFrom(backgroundColor: _kNotInterestedColor),
                        child: const Text('Delete'),
                      ),
                    ],
                  ));
                  if (ok == true) {
                    await LeadService.instance.delete(lead.id);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text('"${lead.name}" deleted')));
                  }
                }),
              ]),
            ]),
          ),
        );
      },
    );
  }
}

// =============================================================================
// EMPTY STATE
// =============================================================================

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  const _EmptyState({this.hasFilters = false});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              hasFilters ? Icons.filter_list_off_rounded : Icons.people_outline_rounded,
              size: 40,
              color: cs.primary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            hasFilters ? 'No matching leads' : 'No leads yet',
            style: tt.titleMedium?.semiBold.withColor(cs.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilters
                ? 'Try changing your search or filters.'
                : 'Add your first lead to get started.',
            style: tt.bodyMedium?.withColor(cs.onSurface.withValues(alpha: 0.45)),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }
}

// =============================================================================
// LEAD EDITOR DIALOG
// =============================================================================

class _LeadEditorDialog extends StatefulWidget {
  const _LeadEditorDialog();
  @override
  State<_LeadEditorDialog> createState() => _LeadEditorDialogState();
}

class _LeadEditorDialogState extends State<_LeadEditorDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _campaign = TextEditingController();
  final _dealValue = TextEditingController();
  LeadSource _source = LeadSource.whatsapp;
  LeadStatus _status = LeadStatus.fresh;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _campaign.dispose();
    _dealValue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Lead'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
          TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
          TextField(controller: _campaign, decoration: const InputDecoration(labelText: 'Campaign')),
          const SizedBox(height: 8),
          TextField(
            controller: _dealValue,
            decoration: InputDecoration(
              labelText: 'Deal Value (${context.read<AppState>().selectedMarket.currency})',
              prefixText: '${context.read<AppState>().selectedMarket.currencySymbol} ',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Source:'),
            const SizedBox(width: 8),
            Flexible(child: DropdownButton<LeadSource>(
              value: _source,
              isExpanded: true,
              items: LeadSource.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
              onChanged: (v) => setState(() => _source = v ?? _source),
            )),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Status:'),
            const SizedBox(width: 8),
            Flexible(child: DropdownButton<LeadStatus>(
              value: _status,
              isExpanded: true,
              items: LeadStatus.values.map((s) {
                final (label, color, _) = _statusMeta(s);
                return DropdownMenuItem(value: s, child: Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(label),
                ]));
              }).toList(),
              onChanged: (v) => setState(() => _status = v ?? _status),
            )),
          ]),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }
    if (email.isNotEmpty && !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid email address')));
      return;
    }
    final normalizedPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (phone.isNotEmpty && normalizedPhone.length < 7) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid phone number')));
      return;
    }
    setState(() => _saving = true);
    try {
      final created = await LeadService.instance.create(
        name: name,
        phone: phone.isEmpty ? null : phone,
        email: email.isEmpty ? null : email,
        campaign: _campaign.text.trim().isEmpty ? null : _campaign.text.trim(),
        source: _source,
        status: _status,
        dealValue: double.tryParse(_dealValue.text.trim()),
        country: context.read<AppState>().selectedMarketId,
      );
      if (context.mounted) Navigator.of(context).pop(created);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create lead: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// =============================================================================
// IMPORT LEADS DIALOG
// =============================================================================

class _ImportLeadsDialog extends StatefulWidget {
  const _ImportLeadsDialog();
  @override
  State<_ImportLeadsDialog> createState() => _ImportLeadsDialogState();
}

class _ImportLeadsDialogState extends State<_ImportLeadsDialog> {
  List<List<dynamic>> _rows = [];
  List<String> _headers = [];
  bool _loading = false;
  String? _error;
  final Map<String, int?> _map = {
    'Name': null,
    'Phone': null,
    'Email': null,
    'Source': null,
    'Date': null,
  };
  String _dupPolicy = 'skip';

  /// Auto-detect column mappings from header names
  void _autoMapHeaders() {
    for (int i = 0; i < _headers.length; i++) {
      final h = _headers[i].toLowerCase().trim();
      if (_map['Name'] == null && (h == 'name' || h == 'full name' || h == 'fullname' || h == 'lead name' || h == 'contact' || h == 'contact name')) {
        _map['Name'] = i;
      } else if (_map['Phone'] == null && (h == 'phone' || h == 'phone number' || h == 'mobile' || h == 'cell' || h == 'tel' || h == 'telephone' || h == 'whatsapp')) {
        _map['Phone'] = i;
      } else if (_map['Email'] == null && (h == 'email' || h == 'e-mail' || h == 'email address' || h == 'mail')) {
        _map['Email'] = i;
      } else if (_map['Source'] == null && (h == 'source' || h == 'channel' || h == 'source/channel' || h == 'lead source' || h == 'platform' || h == 'origin')) {
        _map['Source'] = i;
      } else if (_map['Date'] == null && (h == 'date' || h == 'created' || h == 'created_at' || h == 'createdat' || h == 'created at' || h == 'timestamp' || h == 'time' || h == 'added' || h == 'date added' || h == 'registration date' || h == 'signup date' || h == 'joined')) {
        _map['Date'] = i;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mapped = _map.values.where((v) => v != null).length;
    final nameOk = _map['Name'] != null;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        Icon(Icons.upload_file_outlined, color: cs.primary),
        const SizedBox(width: 10),
        const Text('Import Leads'),
      ]),
      content: SizedBox(
        width: 720,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: cs.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [Icon(Icons.error_outline, size: 18, color: cs.error), const SizedBox(width: 8), Expanded(child: Text(_error!, style: TextStyle(color: cs.error)))]),
          )),
          Row(children: [
            FilledButton.icon(onPressed: _loading ? null : _pickFile, icon: const Icon(Icons.upload_file, size: 18), label: const Text('Choose CSV/XLS/XLSX')),
            const SizedBox(width: 12),
            if (_rows.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('${_rows.length} rows', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600, color: cs.primary)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('$mapped/5 mapped', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600, color: cs.primary)),
              ),
            ],
          ]),
          if (_rows.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Column Mapping', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Columns were auto-detected from your file headers. Adjust if needed.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 10),
            Wrap(spacing: 16, runSpacing: 10, children: _map.keys.map((k) => _mappingDropdown(k)).toList()),
            const SizedBox(height: 14),
            Row(children: [
              Text('Duplicates:', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              ChoiceChip(label: const Text('Skip'), selected: _dupPolicy == 'skip', onSelected: (v) => setState(() => _dupPolicy = 'skip')),
              const SizedBox(width: 8),
              ChoiceChip(label: const Text('Update existing'), selected: _dupPolicy == 'update', onSelected: (v) => setState(() => _dupPolicy = 'update')),
            ]),
            const SizedBox(height: 14),
            Text('Preview', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(height: 200, child: _previewTable()),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _rows.isEmpty || _loading || !nameOk ? null : _import,
          icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.download_done, size: 18),
          label: Text(_loading ? 'Importing...' : 'Import ${_rows.length} leads'),
        ),
      ],
    );
  }

  Widget _mappingDropdown(String field) {
    final cs = Theme.of(context).colorScheme;
    final isMapped = _map[field] != null;
    final isRequired = field == 'Name';
    return SizedBox(
      width: 320,
      child: Row(children: [
        SizedBox(width: 60, child: Row(children: [
          Text(field, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
          if (isRequired) Text(' *', style: TextStyle(color: cs.error, fontWeight: FontWeight.w700)),
        ])),
        const SizedBox(width: 8),
        Expanded(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isMapped ? cs.primary.withValues(alpha: 0.4) : cs.outline.withValues(alpha: 0.2)),
            color: isMapped ? cs.primary.withValues(alpha: 0.06) : Colors.transparent,
          ),
          child: DropdownButtonHideUnderline(child: DropdownButton<int?>(
            value: _map[field],
            isExpanded: true,
            style: Theme.of(context).textTheme.bodyMedium,
            items: [
              DropdownMenuItem<int?>(value: null, child: Text('Not mapped', style: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.5)))),
              ...List.generate(_headers.length, (i) => DropdownMenuItem<int?>(
                value: i,
                child: Row(children: [
                  if (_map.values.contains(i)) Icon(Icons.check_circle, size: 14, color: cs.primary) else Icon(Icons.circle_outlined, size: 14, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
                  const SizedBox(width: 6),
                  Text(_headers[i]),
                ]),
              )),
            ],
            onChanged: (v) => setState(() => _map[field] = v),
          )),
        )),
      ]),
    );
  }

  Widget _previewTable() {
    final cols = _rows.isNotEmpty ? _rows.first.length : 0;
    final preview = _rows.take(10).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: List.generate(cols, (i) => DataColumn(label: Text(_headers.isNotEmpty && i < _headers.length ? _headers[i] : 'Col ${i + 1}'))),
        rows: [for (final r in preview) DataRow(cells: [for (final c in r) DataCell(Text('${c ?? ''}'))])],
      ),
    );
  }

  Future<void> _pickFile() async {
    setState(() { _loading = true; _error = null; });
    try {
      final picker = getSimpleFilePicker();
      final picked = await picker.pick(allowedExtensions: ['csv', 'xls', 'xlsx']);
      if (picked == null) { setState(() => _loading = false); return; }
      final name = picked.name.toLowerCase();
      final bytes = picked.bytes;
      if (bytes.isEmpty) { setState(() { _error = 'Failed to read file bytes'; _loading = false; }); return; }
      if (name.endsWith('.csv')) {
        final rawText = utf8.decode(bytes, allowMalformed: true);
        final text = rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
        final lines = text.split('\n').where((l) => l.trim().isNotEmpty).take(2).toList();
        final sample = lines.isNotEmpty ? lines.first : '';
        final commaCount = RegExp(',').allMatches(sample).length;
        final semiCount = RegExp(';').allMatches(sample).length;
        final delim = semiCount > commaCount ? ';' : ',';
        final rows = const CsvToListConverter(eol: '\n').convert(text, fieldDelimiter: delim);
        final cleaned = rows.where((r) => r.any((c) => (c?.toString().trim().isNotEmpty ?? false))).toList();
        _rows = cleaned;
        _headers = cleaned.isNotEmpty && cleaned.first.every((c) => c is String) ? cleaned.first.cast<String>() : List.generate(cleaned.isEmpty ? 0 : cleaned.first.length, (i) => 'Column ${i + 1}');
        if (cleaned.isNotEmpty && cleaned.first.every((c) => c is String)) _rows = cleaned.skip(1).toList();
        _autoMapHeaders();
      } else if (name.endsWith('.xlsx')) {
        final book = ex.Excel.decodeBytes(bytes);
        final sheet = book.tables.values.first;
        final rows = sheet.rows.map((r) => r.map((c) => c?.value).toList()).toList();
        _rows = rows;
        _headers = rows.isNotEmpty && rows.first.every((c) => c is String) ? rows.first.cast<String>() : List.generate(rows.isEmpty ? 0 : rows.first.length, (i) => 'Column ${i + 1}');
        if (rows.isNotEmpty && rows.first.every((c) => c is String)) _rows = rows.skip(1).toList();
        _autoMapHeaders();
      } else if (name.endsWith('.xls')) {
        _error = 'XLS (legacy) is not supported in web preview. Please upload CSV or XLSX.';
      } else {
        _error = 'Unsupported file type';
      }
    } catch (e) {
      _error = 'Failed to parse file: $e';
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _import() async {
    setState(() => _loading = true);
    int total = _rows.length, ok = 0, skipped = 0, failed = 0, updated = 0;
    for (final row in _rows) {
      try {
        String? name = _val(row, _map['Name']);
        final phone = _val(row, _map['Phone']);
        final email = _val(row, _map['Email']);
        final sourceStr = _val(row, _map['Source']);
        final dateStr = _val(row, _map['Date']);
        if (name == null || name.trim().isEmpty) { skipped++; continue; }
        final source = _sourceFrom(sourceStr) ?? LeadSource.imported;
        final createdAt = _parseDate(dateStr);
        final dup = _findDuplicate(email, phone);
        if (dup != null) {
          if (_dupPolicy == 'update') {
            await LeadService.instance.update(dup.copyWith(
              name: name,
              email: (email?.isNotEmpty == true) ? email : dup.email,
              phone: (phone?.isNotEmpty == true) ? phone : dup.phone,
              source: source,
              createdAt: createdAt ?? dup.createdAt,
              updatedAt: DateTime.now(),
            ));
            updated++;
          } else { skipped++; }
        } else {
          await LeadService.instance.create(
            name: name,
            phone: phone?.isEmpty == true ? null : phone,
            email: email?.isEmpty == true ? null : email,
            source: source,
            createdAt: createdAt,
            country: context.read<AppState>().selectedMarketId,
          );
          ok++;
        }
      } catch (_) { failed++; }
    }
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import complete • Total: $total  Imported: $ok  Updated: $updated  Skipped: $skipped  Failed: $failed')));
    Navigator.of(context).pop();
  }

  String? _val(List<dynamic> row, int? idx) {
    if (idx == null || idx < 0 || idx >= row.length) return null;
    return row[idx]?.toString();
  }

  /// Parse various date formats from CSV: ISO 8601, MM/DD/YYYY, DD-MM-YYYY,
  /// "02/10/2026 1:18pm", etc.
  DateTime? _parseDate(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    final v = s.trim();

    // Try ISO 8601 first (2024-01-15, 2024-01-15T10:30:00)
    final iso = DateTime.tryParse(v);
    if (iso != null) return iso;

    // Handle "MM/DD/YYYY h:mm(am|pm)" — strip time, parse date, add time back
    final dateTimeParts = v.split(RegExp(r'\s+'));
    final datePart = dateTimeParts[0]; // e.g. 02/10/2026
    int extraHours = 0, extraMinutes = 0;
    if (dateTimeParts.length >= 2) {
      // Parse time like "1:18pm" or "12:55pm"
      final timeStr = dateTimeParts.sublist(1).join('').toLowerCase();
      final isPm = timeStr.contains('pm');
      final isAm = timeStr.contains('am');
      final cleaned = timeStr.replaceAll(RegExp(r'[ap]m'), '');
      final timeParts = cleaned.split(':');
      if (timeParts.isNotEmpty) {
        var h = int.tryParse(timeParts[0]) ?? 0;
        final m = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
        if (isPm && h < 12) h += 12;
        if (isAm && h == 12) h = 0;
        extraHours = h;
        extraMinutes = m;
      }
    }

    // Try common formats: MM/DD/YYYY, DD/MM/YYYY, DD-MM-YYYY, MM-DD-YYYY
    final parts = datePart.split(RegExp(r'[/\-\.]'));
    if (parts.length >= 3) {
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);
      final c = int.tryParse(parts[2]);
      if (a != null && b != null && c != null) {
        DateTime? result;
        // If first part is 4 digits, assume YYYY-MM-DD
        if (parts[0].length == 4) {
          result = DateTime.tryParse('$a-${b.toString().padLeft(2, '0')}-${c.toString().padLeft(2, '0')}');
        }
        // If last part is 4 digits → MM/DD/YYYY or DD/MM/YYYY
        else if (parts[2].length == 4) {
          if (a > 12 && b <= 12) {
            result = DateTime.tryParse('$c-${b.toString().padLeft(2, '0')}-${a.toString().padLeft(2, '0')}');
          } else {
            result = DateTime.tryParse('$c-${a.toString().padLeft(2, '0')}-${b.toString().padLeft(2, '0')}');
          }
        }
        // 2-digit year: assume 20xx
        else if (parts[2].length == 2) {
          final year = 2000 + c;
          if (a > 12 && b <= 12) {
            result = DateTime.tryParse('$year-${b.toString().padLeft(2, '0')}-${a.toString().padLeft(2, '0')}');
          } else {
            result = DateTime.tryParse('$year-${a.toString().padLeft(2, '0')}-${b.toString().padLeft(2, '0')}');
          }
        }
        if (result != null && (extraHours > 0 || extraMinutes > 0)) {
          result = result.add(Duration(hours: extraHours, minutes: extraMinutes));
        }
        return result;
      }
    }

    // Try Unix timestamp (seconds)
    final ts = int.tryParse(v);
    if (ts != null && ts > 946684800 && ts < 4102444800) return DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    return null;
  }

  LeadSource? _sourceFrom(String? s) {
    final v = (s ?? '').toLowerCase().trim();
    if (v.isEmpty) return null;
    if (v.contains('manual')) return LeadSource.manual;
    if (v.contains('whats')) return LeadSource.whatsapp;
    if (v.contains('mail') || v == 'email') return LeadSource.email;
    if (v.contains('phone') || v == 'call') return LeadSource.phone;
    if (v.contains('web') || v.contains('site') || v.contains('form')) return LeadSource.web;
    if (v.contains('facebook') || v == 'fb') return LeadSource.facebook;
    if (v.contains('insta')) return LeadSource.instagram;
    if (v.contains('link')) return LeadSource.linkedin;
    if (v.contains('tiktok') || v == 'tt') return LeadSource.tiktok;
    if (v.contains('import')) return LeadSource.imported;
    return null;
  }

  LeadModel? _findDuplicate(String? email, String? phone) {
    final leads = LeadService.instance.leads.value;
    for (final l in leads) {
      if (email != null && email.isNotEmpty && l.email == email) return l;
      if (phone != null && phone.isNotEmpty && l.phone == phone) return l;
    }
    return null;
  }
}

// =============================================================================
// BULK ACTION BAR
// =============================================================================

class _BulkActionBar extends StatelessWidget {
  final int count;
  final VoidCallback onChangeStatus;
  final VoidCallback onAssign;
  final VoidCallback onExport;
  final VoidCallback onDelete;
  final VoidCallback onClear;
  const _BulkActionBar({required this.count, required this.onChangeStatus, required this.onAssign, required this.onExport, required this.onDelete, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: cs.inverseSurface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        // Count badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(10)),
          child: Text('$count', style: tt.labelMedium?.bold.withColor(cs.onPrimary)),
        ),
        const SizedBox(width: 10),
        Text('selected', style: tt.bodySmall?.withColor(cs.onInverseSurface.withValues(alpha: 0.7))),
        const Spacer(),
        _BulkBtn(icon: Icons.flag_rounded, label: 'Status', onTap: onChangeStatus, color: cs.onInverseSurface),
        const SizedBox(width: 6),
        _BulkBtn(icon: Icons.person_add_alt_1_rounded, label: 'Assign', onTap: onAssign, color: cs.onInverseSurface),
        const SizedBox(width: 6),
        _BulkBtn(icon: Icons.download_rounded, label: 'Export', onTap: onExport, color: cs.onInverseSurface),
        const SizedBox(width: 6),
        if (AuthService.instance.user?.canDeleteLeads ?? false) ...[
          _BulkBtn(icon: Icons.delete_rounded, label: 'Delete', onTap: onDelete, color: cs.errorContainer),
          const SizedBox(width: 6),
        ],
        // Clear
        IconButton(
          onPressed: onClear,
          icon: Icon(Icons.close_rounded, size: 18, color: cs.onInverseSurface.withValues(alpha: 0.6)),
          tooltip: 'Clear selection',
          visualDensity: VisualDensity.compact,
        ),
      ]),
    );
  }
}

class _BulkBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _BulkBtn({required this.icon, required this.label, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
            ]),
          ),
        ),
      ),
    );
  }
}
