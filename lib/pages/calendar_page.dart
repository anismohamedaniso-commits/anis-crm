import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:anis_crm/theme.dart';
import 'package:anis_crm/models/lead.dart';
import 'package:anis_crm/models/task_model.dart';
import 'package:anis_crm/services/lead_service.dart';
import 'package:anis_crm/services/task_service.dart';

/// Calendar page — connected to real leads (follow-ups) and tasks (due dates).
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;
  bool _loading = true;
  _ViewMode _view = _ViewMode.month;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await TaskService.instance.load();
    if (mounted) setState(() => _loading = false);
  }

  /// Build unified calendar entries from leads + tasks
  List<_CalEntry> _buildEntries() {
    final entries = <_CalEntry>[];
    // Leads with nextFollowupAt
    for (final l in LeadService.instance.leads.value) {
      if (l.nextFollowupAt != null) {
        entries.add(_CalEntry(
          id: l.id,
          title: l.name,
          dateTime: l.nextFollowupAt!,
          type: _EntryType.followUp,
          subtitle: 'Follow-up · ${l.source.name}',
          color: _statusColor(l.status),
          leadId: l.id,
        ));
      }
    }
    // Tasks with dueDate
    for (final t in TaskService.instance.tasks.value) {
      if (t.dueDate != null && t.dueDate!.isNotEmpty) {
        final parsed = DateTime.tryParse(t.dueDate!);
        if (parsed != null) {
          entries.add(_CalEntry(
            id: t.id,
            title: t.title,
            dateTime: parsed,
            type: _EntryType.task,
            subtitle: '${t.priority.label} priority · ${t.status.label}',
            color: t.status == TaskStatus.done
                ? const Color(0xFF2E7D32)
                : t.priority == TaskPriority.high
                    ? AppColors.danger
                    : AppColors.info,
          ));
        }
      }
    }
    entries.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return entries;
  }

  List<_CalEntry> _entriesForDay(DateTime day, List<_CalEntry> all) {
    return all.where((e) => _sameDay(e.dateTime, day)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final wide = MediaQuery.of(context).size.width >= 760;

    return Scaffold(
      appBar: AppBar(title: Text('Calendar', style: tt.titleLarge?.semiBold), centerTitle: false),
      body: _loading
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.primary)),
              const SizedBox(height: 14),
              Text('Loading calendar...', style: tt.bodySmall?.withColor(cs.onSurface.withValues(alpha: 0.4))),
            ]))
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ValueListenableBuilder<List<LeadModel>>(
                valueListenable: LeadService.instance.leads,
                builder: (_, __, ___) {
                  return ValueListenableBuilder<List<TaskModel>>(
                    valueListenable: TaskService.instance.tasks,
                    builder: (_, __, ___) {
                      final entries = _buildEntries();
                      return Column(children: [
                        // Top bar
                        _buildTopBar(cs, tt, wide, entries),
                        const SizedBox(height: AppSpacing.lg),
                        // Content
                        Expanded(
                          child: entries.isEmpty
                              ? _buildEmpty(cs, tt)
                              : _view == _ViewMode.month
                                  ? _buildMonthView(cs, tt, entries)
                                  : _buildDayView(cs, tt, entries),
                        ),
                      ]);
                    },
                  );
                },
              ),
            ),
    );
  }

  Widget _buildTopBar(ColorScheme cs, TextTheme tt, bool wide, List<_CalEntry> entries) {
    final followups = entries.where((e) => e.type == _EntryType.followUp).length;
    final tasks = entries.where((e) => e.type == _EntryType.task).length;
    return Row(children: [
      // Stats
      _MiniStat(icon: Icons.calendar_today_outlined, label: '$followups follow-ups', color: AppColors.info),
      const SizedBox(width: 12),
      _MiniStat(icon: Icons.task_alt, label: '$tasks tasks', color: AppColors.success),
      const Spacer(),
      // View toggle
      SegmentedButton<_ViewMode>(
        segments: const [
          ButtonSegment(value: _ViewMode.month, label: Text('Month'), icon: Icon(Icons.calendar_view_month, size: 16)),
          ButtonSegment(value: _ViewMode.day, label: Text('Day'), icon: Icon(Icons.view_day_outlined, size: 16)),
        ],
        selected: {_view},
        onSelectionChanged: (s) => setState(() => _view = s.first),
        style: ButtonStyle(visualDensity: VisualDensity.compact),
      ),
      const SizedBox(width: 8),
      OutlinedButton.icon(
        onPressed: () => setState(() {
          _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
          _selectedDay = DateTime.now();
        }),
        icon: const Icon(Icons.today, size: 16),
        label: const Text('Today'),
      ),
    ]);
  }

  Widget _buildEmpty(ColorScheme cs, TextTheme tt) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.06), shape: BoxShape.circle),
        child: Icon(Icons.event_busy, size: 32, color: cs.onSurface.withValues(alpha: 0.2)),
      ),
      const SizedBox(height: 16),
      Text('No scheduled items', style: tt.titleMedium?.semiBold),
      const SizedBox(height: 6),
      Text('Follow-ups and task due dates will appear here',
          style: tt.bodySmall?.withColor(cs.onSurface.withValues(alpha: 0.45))),
    ]));
  }

  Widget _buildMonthView(ColorScheme cs, TextTheme tt, List<_CalEntry> entries) {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final first = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startWeekday = first.weekday % 7;
    final totalCells = startWeekday + daysInMonth;
    final rows = (totalCells / 7).ceil();
    final monthNames = ['January','February','March','April','May','June','July','August','September','October','November','December'];

    return Column(children: [
      // Month header with nav arrows
      Row(children: [
        IconButton(
          onPressed: () => setState(() => _focusedMonth = DateTime(year, month - 1)),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(child: Center(child: Text('${monthNames[month - 1]} $year', style: tt.titleLarge?.semiBold))),
        IconButton(
          onPressed: () => setState(() => _focusedMonth = DateTime(year, month + 1)),
          icon: const Icon(Icons.chevron_right),
        ),
      ]),
      const SizedBox(height: AppSpacing.sm),
      // Weekday header
      Row(children: [
        for (final l in ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
          Expanded(child: Center(child: Text(l, style: tt.labelMedium?.withColor(cs.onSurface.withValues(alpha: 0.4))))),
      ]),
      const SizedBox(height: AppSpacing.sm),
      // Grid
      Expanded(
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 6),
          itemCount: rows * 7,
          itemBuilder: (_, idx) {
            final dayNum = idx - startWeekday + 1;
            if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox.shrink();
            final date = DateTime(year, month, dayNum);
            final isToday = _sameDay(date, DateTime.now());
            final isSelected = _selectedDay != null && _sameDay(date, _selectedDay!);
            final dayEntries = _entriesForDay(date, entries);
            return _DateCell(
              date: date,
              isToday: isToday,
              isSelected: isSelected,
              entries: dayEntries,
              onTap: () => setState(() => _selectedDay = date),
            );
          },
        ),
      ),
      // Selected day detail panel
      if (_selectedDay != null) ...[
        const SizedBox(height: AppSpacing.sm),
        _DayDetailPanel(
          day: _selectedDay!,
          entries: _entriesForDay(_selectedDay!, entries),
        ),
      ],
    ]);
  }

  Widget _buildDayView(ColorScheme cs, TextTheme tt, List<_CalEntry> entries) {
    final day = _selectedDay ?? DateTime.now();
    final dayEntries = _entriesForDay(day, entries);
    final weekdays = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
    final monthNames = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

    return Column(children: [
      Row(children: [
        IconButton(
          onPressed: () => setState(() => _selectedDay = day.subtract(const Duration(days: 1))),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(child: Center(child: Text(
          '${weekdays[day.weekday % 7]}, ${monthNames[day.month - 1]} ${day.day}, ${day.year}',
          style: tt.titleLarge?.semiBold,
        ))),
        IconButton(
          onPressed: () => setState(() => _selectedDay = day.add(const Duration(days: 1))),
          icon: const Icon(Icons.chevron_right),
        ),
      ]),
      const SizedBox(height: AppSpacing.md),
      Expanded(
        child: dayEntries.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.event_available, size: 40, color: cs.onSurface.withValues(alpha: 0.15)),
                const SizedBox(height: 12),
                Text('No items for this day', style: tt.bodyMedium?.withColor(cs.onSurface.withValues(alpha: 0.4))),
              ]))
            : ListView.builder(
                itemCount: dayEntries.length,
                itemBuilder: (_, i) => _EntryCard(entry: dayEntries[i]),
              ),
      ),
    ]);
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Color _statusColor(LeadStatus s) => switch (s) {
    LeadStatus.fresh => const Color(0xFF2196F3),
    LeadStatus.interested => AppColors.success,
    LeadStatus.noAnswer => AppColors.warning,
    LeadStatus.followUp => AppColors.info,
    LeadStatus.notInterested => AppColors.danger,
    LeadStatus.converted => const Color(0xFF9C27B0),
    LeadStatus.closed => AppColors.neutralDark,
  };
}

enum _ViewMode { month, day }
enum _EntryType { followUp, task }

class _CalEntry {
  final String id;
  final String title;
  final DateTime dateTime;
  final _EntryType type;
  final String subtitle;
  final Color color;
  final String? leadId;
  const _CalEntry({required this.id, required this.title, required this.dateTime,
    required this.type, required this.subtitle, required this.color, this.leadId});
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MiniStat({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _DateCell extends StatefulWidget {
  const _DateCell({required this.date, required this.isToday, required this.isSelected, required this.entries, required this.onTap});
  final DateTime date;
  final bool isToday;
  final bool isSelected;
  final List<_CalEntry> entries;
  final VoidCallback onTap;
  @override
  State<_DateCell> createState() => _DateCellState();
}

class _DateCellState extends State<_DateCell> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = widget.isSelected
        ? cs.primary.withValues(alpha: 0.08)
        : _hovered
            ? cs.primary.withValues(alpha: 0.03)
            : cs.surface;
    final border = widget.isToday ? cs.primary : cs.outline.withValues(alpha: 0.1);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: border, width: widget.isToday ? 1.5 : 1),
          ),
          padding: const EdgeInsets.all(4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${widget.date.day}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: widget.isToday ? FontWeight.w700 : FontWeight.w400,
                color: widget.isToday ? cs.primary : cs.onSurface,
              )),
            const Spacer(),
            if (widget.entries.isNotEmpty)
              Wrap(spacing: 3, runSpacing: 2, children: [
                for (final e in widget.entries.take(4))
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: e.color, shape: BoxShape.circle)),
              ]),
          ]),
        ),
      ),
    );
  }
}

class _DayDetailPanel extends StatelessWidget {
  final DateTime day;
  final List<_CalEntry> entries;
  const _DayDetailPanel({required this.day, required this.entries});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: entries.isEmpty
          ? Center(child: Text('No items for this date', style: tt.bodySmall?.withColor(cs.onSurface.withValues(alpha: 0.4))))
          : ListView(shrinkWrap: true, children: [
              for (final e in entries) _EntryCard(entry: e),
            ]),
    );
  }
}

class _EntryCard extends StatefulWidget {
  final _CalEntry entry;
  const _EntryCard({required this.entry});
  @override
  State<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<_EntryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final e = widget.entry;
    final isOverdue = e.dateTime.isBefore(DateTime.now());
    final icon = e.type == _EntryType.followUp ? Icons.phone_callback_outlined : Icons.task_alt_outlined;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _hovered ? e.color.withValues(alpha: 0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isOverdue ? AppColors.danger.withValues(alpha: 0.3) : e.color.withValues(alpha: 0.15)),
        ),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: e.color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: e.color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.title, style: tt.titleSmall?.semiBold, overflow: TextOverflow.ellipsis),
            Text(e.subtitle, style: tt.bodySmall?.withColor(cs.onSurface.withValues(alpha: 0.45))),
          ])),
          if (isOverdue)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Text('Overdue', style: tt.labelSmall?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 10)),
            ),
          if (e.leadId != null) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => context.push('/app/lead/${e.leadId}'),
              icon: Icon(Icons.open_in_new, size: 16, color: cs.primary),
              tooltip: 'Open lead',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ]),
      ),
    );
  }
}
