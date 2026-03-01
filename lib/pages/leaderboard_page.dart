import 'package:flutter/material.dart';
import 'package:anis_crm/theme.dart';
import 'package:anis_crm/services/api_client.dart';
import 'package:anis_crm/services/auth_service.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});
  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _data = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await ApiClient.instance.getLeaderboard();
    if (result != null && mounted) {
      setState(() {
        _data = result;
        _loading = false;
      });
    } else if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dk = Theme.of(context).brightness == Brightness.dark;
    final wide = MediaQuery.of(context).size.width >= 760;
    final tt = Theme.of(context).textTheme;
    final me = AuthService.instance.user;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: EdgeInsets.symmetric(horizontal: wide ? 8 : 4),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Leaderboard', style: tt.headlineSmall?.semiBold),
              const SizedBox(height: 4),
              Text('Track team performance and achievements',
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
      const SizedBox(height: 20),

      // Top 3 podium — only show when we have at least 2 entries
      if (!_loading && _data.length >= 2) ...[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: wide ? 8 : 4),
          child: _Podium(data: _data.take(3).toList(), cs: cs, dk: dk, myId: me?.id ?? ''),
        ),
        const SizedBox(height: 24),
      ],

      // Full rankings
      Expanded(
        child: _loading
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.primary)),
                const SizedBox(height: 14),
                Text('Loading rankings...', style: tt.bodySmall?.withColor(cs.onSurface.withValues(alpha: 0.4))),
              ]))
            : _data.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.emoji_events_outlined, size: 32, color: cs.onSurface.withValues(alpha: 0.2)),
                      ),
                      const SizedBox(height: 16),
                      Text('No data yet', style: tt.titleMedium?.semiBold),
                      const SizedBox(height: 6),
                      Text('Start working to see rankings',
                          style: tt.bodySmall?.withColor(cs.onSurface.withValues(alpha: 0.45))),
                    ]),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: wide ? 8 : 4),
                      itemCount: _data.length,
                      itemBuilder: (_, i) => _RankCard(
                        data: _data[i],
                        cs: cs,
                        dk: dk,
                        isMe: _data[i]['id'] == me?.id,
                      ),
                    ),
                  ),
      ),
    ]);
  }
}

class _Podium extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final ColorScheme cs;
  final bool dk;
  final String myId;
  const _Podium({required this.data, required this.cs, required this.dk, required this.myId});

  @override
  Widget build(BuildContext context) {
    final medals = [
      const Color(0xFFFFD700),
      const Color(0xFFC0C0C0),
      const Color(0xFFCD7F32),
    ];
    final tt = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (data.length > 1) _podiumItem(data[1], 2, medals[1], 90, tt),
        if (data.isNotEmpty) _podiumItem(data[0], 1, medals[0], 110, tt),
        if (data.length > 2) _podiumItem(data[2], 3, medals[2], 80, tt),
      ],
    );
  }

  Widget _podiumItem(Map<String, dynamic> d, int rank, Color medal, double height, TextTheme tt) {
    final name = d['name'] as String? ?? '';
    final score = d['score'] as int? ?? 0;

    return Expanded(
      child: Column(children: [
        Stack(alignment: Alignment.bottomCenter, children: [
          CircleAvatar(
            radius: rank == 1 ? 32 : 26,
            backgroundColor: medal.withValues(alpha: 0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: tt.headlineSmall?.copyWith(
                fontSize: rank == 1 ? 22 : 18,
                fontWeight: FontWeight.w700,
                color: medal,
              ),
            ),
          ),
          Positioned(
            bottom: -2,
            child: Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: medal,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: medal.withValues(alpha: 0.3), blurRadius: 6)],
              ),
              child: Center(
                child: Text('$rank',
                    style: tt.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 11)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Text(name,
            style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        Text('$score pts',
            style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w500, color: medal)),
        const SizedBox(height: 8),
        Container(
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [medal.withValues(alpha: 0.25), medal.withValues(alpha: 0.08)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
        ),
      ]),
    );
  }
}

class _RankCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final ColorScheme cs;
  final bool dk;
  final bool isMe;
  const _RankCard({required this.data, required this.cs, required this.dk, required this.isMe});
  @override
  State<_RankCard> createState() => _RankCardState();
}

class _RankCardState extends State<_RankCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final dk = widget.dk;
    final isMe = widget.isMe;
    final tt = Theme.of(context).textTheme;
    final d = widget.data;
    final rank = d['rank'] as int? ?? 0;
    final name = d['name'] as String? ?? '';
    final email = d['email'] as String? ?? '';
    final role = d['role'] as String? ?? '';
    final score = d['score'] as int? ?? 0;
    final assigned = d['assigned_leads'] as int? ?? 0;
    final converted = d['converted_leads'] as int? ?? 0;
    final activities = d['activities_count'] as int? ?? 0;
    final completedTasks = d['completed_tasks'] as int? ?? 0;

    Color rankColor;
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700);
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0);
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32);
    } else {
      rankColor = cs.onSurface.withValues(alpha: 0.4);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isMe
              ? cs.primary.withValues(alpha: 0.04)
              : dk ? cs.surface.withValues(alpha: 0.5) : cs.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hovered
                ? cs.primary.withValues(alpha: 0.2)
                : isMe
                    ? cs.primary.withValues(alpha: 0.2)
                    : cs.outline.withValues(alpha: dk ? 0.08 : 0.05),
          ),
          boxShadow: _hovered ? [BoxShadow(color: cs.primary.withValues(alpha: 0.05), blurRadius: 8)] : [],
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: rankColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: rank <= 3
                  ? Icon(Icons.emoji_events, size: 18, color: rankColor)
                  : Text('#$rank', style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: rankColor)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(name, style: tt.titleSmall?.semiBold),
                if (isMe) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text('You', style: tt.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: cs.primary, fontSize: 10)),
                  ),
                ],
              ]),
              const SizedBox(height: 2),
              Text('${role == 'account_executive' ? 'Account Exec' : 'Campaign Exec'} · $email',
                  style: tt.bodySmall?.withColor(cs.onSurface.withValues(alpha: 0.4))),
              const SizedBox(height: 8),
              Wrap(spacing: 10, children: [
                _MiniStat(icon: Icons.people_outlined, label: '$assigned leads', cs: cs),
                _MiniStat(icon: Icons.trending_up, label: '$converted converted', cs: cs),
                _MiniStat(icon: Icons.history, label: '$activities activities', cs: cs),
                _MiniStat(icon: Icons.task_alt, label: '$completedTasks tasks done', cs: cs),
              ]),
            ]),
          ),
          Column(children: [
            Text('$score', style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: cs.primary)),
            Text('pts', style: tt.labelSmall?.withColor(cs.onSurface.withValues(alpha: 0.4))),
          ]),
        ]),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme cs;
  const _MiniStat({required this.icon, required this.label, required this.cs});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: cs.onSurface.withValues(alpha: 0.35)),
        const SizedBox(width: 3),
        Text(label, style: Theme.of(context).textTheme.labelSmall?.withColor(cs.onSurface.withValues(alpha: 0.5))),
      ]);
}
