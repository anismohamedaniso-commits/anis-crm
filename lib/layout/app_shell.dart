import 'package:anis_crm/theme.dart';
import 'package:anis_crm/components/notification_bell.dart';
import 'package:anis_crm/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// APP SHELL — Premium sidebar + responsive bottom bar
// ═══════════════════════════════════════════════════════════════════════════════

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.child});
  final Widget child;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _collapsed = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ── Destination groups ────────────────────────────────────────────────────
  static final _coreSection = <_NavDestination>[
    _NavDestination('Dashboard', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, '/app/dashboard'),
    _NavDestination('Leads', Icons.people_outline, Icons.people_rounded, '/app/leads'),
    _NavDestination('Pipeline', Icons.view_kanban_outlined, Icons.view_kanban_rounded, '/app/pipeline'),
    _NavDestination('Calendar', Icons.calendar_today_outlined, Icons.calendar_today_rounded, '/app/calendar'),
    _NavDestination('KPIs', Icons.track_changes_outlined, Icons.track_changes_rounded, '/app/kpis'),
    _NavDestination('Email', Icons.email_outlined, Icons.email_rounded, '/app/email-marketing'),
  ];

  static final _toolsSection = <_NavDestination>[
    _NavDestination('Reports', Icons.bar_chart_outlined, Icons.bar_chart_rounded, '/app/reports'),
    _NavDestination('Automation', Icons.auto_fix_high_outlined, Icons.auto_fix_high, '/app/automation'),
    _NavDestination('Integrations', Icons.hub_outlined, Icons.hub_rounded, '/app/integrations'),
    _NavDestination('Masterclass', Icons.school_outlined, Icons.school_rounded, '/app/masterclass'),
  ];

  static final _collabSection = <_NavDestination>[
    _NavDestination('Activity', Icons.timeline_outlined, Icons.timeline_rounded, '/app/activity'),
    _NavDestination('Tasks', Icons.task_outlined, Icons.task_rounded, '/app/tasks'),
    _NavDestination('Chat', Icons.chat_outlined, Icons.chat_rounded, '/app/chat'),
    _NavDestination('Leaderboard', Icons.leaderboard_outlined, Icons.leaderboard_rounded, '/app/leaderboard'),
  ];

  static final _adminSection = <_NavDestination>[
    _NavDestination('Custom Fields', Icons.tune_outlined, Icons.tune_rounded, '/app/custom-fields', accountExecOnly: true),
    _NavDestination('Settings', Icons.settings_outlined, Icons.settings_rounded, '/app/settings', accountExecOnly: true),
    _NavDestination('Team', Icons.group_outlined, Icons.group_rounded, '/app/team', accountExecOnly: true),
  ];

  List<_NavDestination> _flat() {
    final isAdmin = AuthService.instance.user?.isAccountExecutive ?? false;
    return [
      ..._coreSection,
      ..._toolsSection,
      ..._collabSection,
      if (isAdmin) ..._adminSection,
    ];
  }

  String _activePath(BuildContext context) => GoRouterState.of(context).uri.toString();

  void _go(BuildContext context, String path) {
    if (_activePath(context) != path) context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final cs = Theme.of(context).colorScheme;
    final dk = Theme.of(context).brightness == Brightness.dark;
    final user = AuthService.instance.user;
    final location = _activePath(context);
    final tt = Theme.of(context).textTheme;
    final isAdmin = user?.isAccountExecutive ?? false;

    // ── WIDE: premium sidebar ───────────────────────────────────────────────
    if (isWide) {
      final sideW = _collapsed ? 72.0 : 220.0;
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Row(children: [
            // Sidebar
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              width: sideW,
              decoration: BoxDecoration(
                color: dk ? const Color(0xFF141418) : const Color(0xFFFAFAFC),
                border: Border(
                  right: BorderSide(color: cs.outline.withValues(alpha: dk ? 0.08 : 0.06)),
                ),
              ),
              child: Column(children: [
                // ── Header: logo + collapse toggle ──
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: _collapsed ? 10 : 18, vertical: 18),
                  child: Row(children: [
                    if (!_collapsed) ...[
                      Expanded(
                        child: Image.asset(
                          Theme.of(context).brightness == Brightness.dark
                              ? AppBrand.logoWhiteAsset
                              : AppBrand.logoBlackAsset,
                          height: 28,
                          fit: BoxFit.contain,
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    _SidebarIconBtn(
                      icon: _collapsed ? Icons.keyboard_double_arrow_right_rounded : Icons.keyboard_double_arrow_left_rounded,
                      size: 18,
                      cs: cs,
                      tooltip: _collapsed ? 'Expand' : 'Collapse',
                      onTap: () => setState(() => _collapsed = !_collapsed),
                    ),
                  ]),
                ),

                // ── Nav sections ──
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: _collapsed ? 8 : 10, vertical: 4),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _buildSection(context, null, _coreSection, location),
                      _divider(cs),
                      _buildSection(context, _collapsed ? null : 'Tools', _toolsSection, location),
                      _divider(cs),
                      _buildSection(context, _collapsed ? null : 'Collaborate', _collabSection, location),
                      if (isAdmin) ...[
                        _divider(cs),
                        _buildSection(context, _collapsed ? null : 'Admin', _adminSection, location),
                      ],
                    ]),
                  ),
                ),

                // ── Footer: notification bell + user ──
                Container(
                  padding: EdgeInsets.symmetric(horizontal: _collapsed ? 8 : 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: cs.outline.withValues(alpha: dk ? 0.06 : 0.05))),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    // Notification bell row
                    if (!_collapsed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(children: [
                          const NotificationBell(),
                          const SizedBox(width: 10),
                          Text('Notifications',
                              style: tt.bodyMedium?.medium.withColor(cs.onSurface.withValues(alpha: 0.6))),
                        ]),
                      )
                    else
                      const Padding(padding: EdgeInsets.only(bottom: 10), child: NotificationBell()),
                    // User card
                    GestureDetector(
                      onTap: () => context.go('/app/profile'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(horizontal: _collapsed ? 6 : 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.primary.withValues(alpha: 0.08)),
                        ),
                        child: Row(children: [
                          _UserAvatarWidget(user: user, size: 32, cs: cs),
                          if (!_collapsed) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(user?.name ?? 'User',
                                    style: tt.bodyMedium?.semiBold.withColor(cs.onSurface),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(
                                  user?.role == UserRole.accountExecutive ? 'Account Executive' : 'Campaign Executive',
                                  style: tt.labelSmall?.copyWith(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.4)),
                                ),
                              ]),
                            ),
                            _SidebarIconBtn(
                              icon: Icons.logout_rounded,
                              size: 17,
                              cs: cs,
                              tooltip: 'Sign out',
                              onTap: () async {
                                await AuthService.instance.logout();
                                if (context.mounted) context.go('/login');
                              },
                            ),
                          ],
                        ]),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),

            // Content area
            Expanded(
              child: Column(children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: widget.child,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, top: 2),
                  child: Text(
                    'This App was Designed By ANIS Exclusively For Tick&Talk Sales',
                    style: tt.labelSmall?.copyWith(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.3), letterSpacing: 0.2),
                    textAlign: TextAlign.center,
                  ),
                ),
              ]),
            ),
          ]),
        ),
      );
    }

    // ── NARROW: bottom bar (5 key items) + drawer for the rest ──────────
    // Only show the 5 most important nav items on the bottom bar
    const _mobileBottomItems = <(String, IconData, IconData, String)>[
      ('Home',     Icons.space_dashboard_outlined,  Icons.space_dashboard_rounded,  '/app/dashboard'),
      ('Leads',    Icons.people_outline,            Icons.people_rounded,           '/app/leads'),
      ('Pipeline', Icons.view_kanban_outlined,      Icons.view_kanban_rounded,      '/app/pipeline'),
      ('Tasks',    Icons.task_outlined,             Icons.task_rounded,             '/app/tasks'),
      ('More',     Icons.menu_rounded,              Icons.menu_rounded,             '__drawer__'),
    ];

    final mobileSelIdx = _mobileBottomItems.indexWhere((d) => d.$4 != '__drawer__' && location.startsWith(d.$4));
    final clampedIdx = mobileSelIdx < 0 ? 4 : mobileSelIdx; // default to "More" if current page isn't in bottom 4

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: _MobileDrawer(
        sections: [
          ('Core', _coreSection),
          ('Tools', _toolsSection),
          ('Collaborate', _collabSection),
          if (isAdmin) ('Admin', _adminSection),
        ],
        location: location,
        user: user,
        cs: cs,
        tt: tt,
        dk: dk,
        onNav: (path) {
          Navigator.of(context).pop(); // close drawer
          _go(context, path);
        },
        onLogout: () async {
          Navigator.of(context).pop();
          await AuthService.instance.logout();
          if (context.mounted) context.go('/login');
        },
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: widget.child,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: clampedIdx,
        onDestinationSelected: (i) {
          if (_mobileBottomItems[i].$4 == '__drawer__') {
            _scaffoldKey.currentState?.openDrawer();
          } else {
            _go(context, _mobileBottomItems[i].$4);
          }
        },
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: _mobileBottomItems
            .map((d) => NavigationDestination(
                  icon: Icon(d.$2, size: 22),
                  selectedIcon: Icon(d.$3, size: 22),
                  label: d.$1,
                ))
            .toList(),
      ),
    );
  }

  // ── Section builder ─────────────────────────────────────────────────────
  Widget _buildSection(BuildContext context, String? label, List<_NavDestination> items, String location) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (label != null)
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 10, bottom: 6),
          child: Text(label,
              style: tt.labelSmall?.copyWith(
                  fontSize: 10, fontWeight: FontWeight.w700, color: cs.onSurface.withValues(alpha: 0.32), letterSpacing: 1.2)),
        ),
      ...items.map((d) => _NavItem(
            dest: d,
            active: location.startsWith(d.path),
            collapsed: _collapsed,
            onTap: () => _go(context, d.path),
          )),
    ]);
  }

  Widget _divider(ColorScheme cs) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Divider(height: 1, color: cs.outline.withValues(alpha: 0.05)),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// NAV ITEM — individual sidebar row with hover + active state
// ═══════════════════════════════════════════════════════════════════════════════

class _NavItem extends StatefulWidget {
  const _NavItem({required this.dest, required this.active, required this.collapsed, required this.onTap});
  final _NavDestination dest;
  final bool active;
  final bool collapsed;
  final VoidCallback onTap;
  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dk = Theme.of(context).brightness == Brightness.dark;
    final active = widget.active;
    final tt = Theme.of(context).textTheme;

    final bgColor = active
        ? cs.primary.withValues(alpha: dk ? 0.14 : 0.08)
        : _hovered
            ? cs.onSurface.withValues(alpha: dk ? 0.06 : 0.03)
            : Colors.transparent;

    final fgColor = active
        ? cs.primary
        : _hovered
            ? cs.onSurface.withValues(alpha: 0.8)
            : cs.onSurface.withValues(alpha: 0.55);

    final icon = active ? widget.dest.selectedIcon : widget.dest.icon;

    final content = widget.collapsed
        ? Tooltip(
            message: widget.dest.label,
            preferBelow: false,
            child: Center(child: Icon(icon, size: 20, color: fgColor)),
          )
        : Row(children: [
            const SizedBox(width: 12),
            Icon(icon, size: 19, color: fgColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(widget.dest.label,
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: fgColor,
                    letterSpacing: -0.1,
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ]);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 38,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: active ? Border.all(color: cs.primary.withValues(alpha: 0.12)) : null,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _SidebarIconBtn extends StatefulWidget {
  const _SidebarIconBtn({required this.icon, required this.size, required this.cs, required this.onTap, this.tooltip});
  final IconData icon;
  final double size;
  final ColorScheme cs;
  final VoidCallback onTap;
  final String? tooltip;
  @override
  State<_SidebarIconBtn> createState() => _SidebarIconBtnState();
}

class _SidebarIconBtnState extends State<_SidebarIconBtn> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final w = Padding(
      padding: const EdgeInsets.all(4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: _hovered ? widget.cs.onSurface.withValues(alpha: 0.06) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: Icon(widget.icon, size: widget.size, color: widget.cs.onSurface.withValues(alpha: _hovered ? 0.7 : 0.4))),
          ),
        ),
      ),
    );
    return widget.tooltip != null ? Tooltip(message: widget.tooltip!, child: w) : w;
  }
}

class _UserAvatarWidget extends StatelessWidget {
  const _UserAvatarWidget({required this.user, required this.size, required this.cs});
  final CrmUser? user;
  final double size;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: cs.primary.withValues(alpha: 0.15), width: 1.5),
      ),
      child: user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
          ? ClipOval(
              child: Image.network(
                user!.avatarUrl!,
                width: size, height: size, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(user!.name.substring(0, 1).toUpperCase(),
                      style: tt.labelLarge?.copyWith(fontSize: size * 0.4, fontWeight: FontWeight.w700, color: cs.primary)),
                ),
              ),
            )
          : Center(
              child: Text((user?.name ?? 'U').substring(0, 1).toUpperCase(),
                  style: tt.labelLarge?.copyWith(fontSize: size * 0.4, fontWeight: FontWeight.w700, color: cs.primary)),
            ),
    );
  }
}

class _NavDestination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;
  final bool accountExecOnly;
  const _NavDestination(this.label, this.icon, this.selectedIcon, this.path, {this.accountExecOnly = false});
}

// ═══════════════════════════════════════════════════════════════════════════════
// MOBILE DRAWER — full nav for narrow screens
// ═══════════════════════════════════════════════════════════════════════════════

class _MobileDrawer extends StatelessWidget {
  const _MobileDrawer({
    required this.sections,
    required this.location,
    required this.user,
    required this.cs,
    required this.tt,
    required this.dk,
    required this.onNav,
    required this.onLogout,
  });
  final List<(String, List<_NavDestination>)> sections;
  final String location;
  final CrmUser? user;
  final ColorScheme cs;
  final TextTheme tt;
  final bool dk;
  final ValueChanged<String> onNav;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: dk ? const Color(0xFF141418) : const Color(0xFFFAFAFC),
      child: SafeArea(
        child: Column(children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Row(children: [
              Expanded(
                child: Image.asset(
                  dk ? AppBrand.logoWhiteAsset : AppBrand.logoBlackAsset,
                  height: 28,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, size: 20, color: cs.onSurface.withValues(alpha: 0.5)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]),
          ),

          // ── Nav sections ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final (label, items) in sections) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 14, bottom: 6),
                    child: Text(label,
                        style: tt.labelSmall?.copyWith(
                            fontSize: 10, fontWeight: FontWeight.w700, color: cs.onSurface.withValues(alpha: 0.32), letterSpacing: 1.2)),
                  ),
                  ...items.map((d) => _DrawerNavItem(
                        dest: d,
                        active: location.startsWith(d.path),
                        onTap: () => onNav(d.path),
                      )),
                ],
              ]),
            ),
          ),

          // ── Footer: user ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: cs.outline.withValues(alpha: dk ? 0.06 : 0.05))),
            ),
            child: Row(children: [
              _UserAvatarWidget(user: user, size: 32, cs: cs),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user?.name ?? 'User',
                      style: tt.bodyMedium?.semiBold.withColor(cs.onSurface),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    user?.role == UserRole.accountExecutive ? 'Account Executive' : 'Campaign Executive',
                    style: tt.labelSmall?.copyWith(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.4)),
                  ),
                ]),
              ),
              IconButton(
                icon: Icon(Icons.logout_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.4)),
                tooltip: 'Sign out',
                onPressed: onLogout,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _DrawerNavItem extends StatelessWidget {
  const _DrawerNavItem({required this.dest, required this.active, required this.onTap});
  final _NavDestination dest;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dk = Theme.of(context).brightness == Brightness.dark;
    final tt = Theme.of(context).textTheme;

    final bgColor = active
        ? cs.primary.withValues(alpha: dk ? 0.14 : 0.08)
        : Colors.transparent;
    final fgColor = active
        ? cs.primary
        : cs.onSurface.withValues(alpha: 0.55);

    final icon = active ? dest.selectedIcon : dest.icon;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: active ? Border.all(color: cs.primary.withValues(alpha: 0.12)) : null,
          ),
          child: Row(children: [
            const SizedBox(width: 12),
            Icon(icon, size: 20, color: fgColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(dest.label,
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: fgColor,
                    letterSpacing: -0.1,
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
      ),
    );
  }
}
