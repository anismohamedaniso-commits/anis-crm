import 'package:flutter/material.dart';
import 'package:anis_crm/theme.dart';
import 'package:anis_crm/services/auth_service.dart';

class TeamPage extends StatefulWidget {
  const TeamPage({super.key});

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> with SingleTickerProviderStateMixin {
  List<CrmUser> _users = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  String _roleFilter = 'all'; // all | account_executive | campaign_executive
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _loadUsers();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() { _loading = true; _error = null; });
    try {
      _users = await AuthService.instance.listUsers();
      _fadeCtrl.forward(from: 0);
    } on CrmAuthException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Failed to load team members';
    }
    if (mounted) setState(() => _loading = false);
  }

  List<CrmUser> get _filtered {
    var list = _users;
    if (_roleFilter != 'all') list = list.where((u) => u.role == _roleFilter).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((u) =>
          u.name.toLowerCase().contains(q) || u.email.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Text(msg, style: Theme.of(context).textTheme.bodySmall),
      ]),
      backgroundColor:
          error ? Theme.of(context).colorScheme.error : const Color(0xFF2E7D32),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      duration: Duration(seconds: error ? 4 : 2),
    ));
  }

  // ── Dialogs ──

  void _showAdd() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String role = UserRole.campaignExecutive;
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => _StyledDialog(
          title: 'Add Team Member',
          subtitle: 'Create a new account for your team',
          icon: Icons.person_add_outlined,
          cs: Theme.of(context).colorScheme,
          isDark: Theme.of(context).brightness == Brightness.dark,
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            _DialogField(ctrl: nameCtrl, label: 'Full Name', icon: Icons.person_outlined, cs: Theme.of(context).colorScheme, isDark: Theme.of(context).brightness == Brightness.dark),
            const SizedBox(height: 14),
            _DialogField(ctrl: emailCtrl, label: 'Email Address', icon: Icons.email_outlined, cs: Theme.of(context).colorScheme, isDark: Theme.of(context).brightness == Brightness.dark),
            const SizedBox(height: 14),
            _DialogField(ctrl: passCtrl, label: 'Password', icon: Icons.lock_outlined, obscure: true, cs: Theme.of(context).colorScheme, isDark: Theme.of(context).brightness == Brightness.dark),
            const SizedBox(height: 18),
            _DialogRolePicker(current: role, onChanged: (v) => ss(() => role = v), cs: Theme.of(context).colorScheme),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty ||
                          emailCtrl.text.trim().isEmpty ||
                          passCtrl.text.isEmpty) {
                        _snack('All fields are required', error: true);
                        return;
                      }
                      ss(() => saving = true);
                      try {
                        await AuthService.instance.createUser(
                          name: nameCtrl.text.trim(),
                          email: emailCtrl.text.trim(),
                          password: passCtrl.text,
                          role: role,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        _snack('${nameCtrl.text.trim()} added to the team');
                        _loadUsers();
                      } on CrmAuthException catch (e) {
                        _snack(e.message, error: true);
                        ss(() => saving = false);
                      }
                    },
              icon: saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add, size: 18),
              label: Text(saving ? 'Adding...' : 'Add Member'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEdit(CrmUser user) {
    final nameCtrl = TextEditingController(text: user.name);
    final emailCtrl = TextEditingController(text: user.email);
    final passCtrl = TextEditingController();
    String role = user.role;
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => _StyledDialog(
          title: 'Edit Member',
          subtitle: user.email,
          icon: Icons.edit_outlined,
          cs: Theme.of(context).colorScheme,
          isDark: Theme.of(context).brightness == Brightness.dark,
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            _DialogField(ctrl: nameCtrl, label: 'Full Name', icon: Icons.person_outlined, cs: Theme.of(context).colorScheme, isDark: Theme.of(context).brightness == Brightness.dark),
            const SizedBox(height: 14),
            _DialogField(ctrl: emailCtrl, label: 'Email Address', icon: Icons.email_outlined, cs: Theme.of(context).colorScheme, isDark: Theme.of(context).brightness == Brightness.dark),
            const SizedBox(height: 14),
            _DialogField(ctrl: passCtrl, label: 'New Password (optional)', icon: Icons.lock_outlined, obscure: true, cs: Theme.of(context).colorScheme, isDark: Theme.of(context).brightness == Brightness.dark),
            const SizedBox(height: 18),
            _DialogRolePicker(current: role, onChanged: (v) => ss(() => role = v), cs: Theme.of(context).colorScheme),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      ss(() => saving = true);
                      try {
                        await AuthService.instance.updateUser(
                          user.id,
                          name: nameCtrl.text.trim(),
                          email: emailCtrl.text.trim(),
                          role: role,
                          password: passCtrl.text.isNotEmpty ? passCtrl.text : null,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        _snack('${nameCtrl.text.trim()} updated');
                        _loadUsers();
                      } on CrmAuthException catch (e) {
                        _snack(e.message, error: true);
                        ss(() => saving = false);
                      }
                    },
              icon: saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(saving ? 'Saving...' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(CrmUser user) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: cs.error.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.person_remove_outlined, color: cs.error, size: 24),
        ),
        title: Text('Remove ${user.name}?',
            style: tt.titleMedium?.semiBold),
        content: Text(
          'This will permanently delete their account and all associated data. This action cannot be undone.',
          style: tt.bodySmall?.withColor(cs.onSurface.withValues(alpha: 0.6)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await AuthService.instance.deleteUser(user.id);
                _snack('${user.name} removed from team');
                _loadUsers();
              } on CrmAuthException catch (e) {
                _snack(e.message, error: true);
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dk = Theme.of(context).brightness == Brightness.dark;
    final tt = Theme.of(context).textTheme;
    final me = AuthService.instance.user;
    final wide = MediaQuery.of(context).size.width >= 760;

    if (me == null || !me.isAccountExecutive) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_outline, size: 48, color: cs.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('Access Restricted',
              style: tt.titleMedium?.semiBold.withColor(cs.onSurface)),
          const SizedBox(height: 6),
          Text('Only Account Executives can manage the team.',
              style: tt.bodyMedium?.withColor(cs.onSurface.withValues(alpha: 0.5))),
        ]),
      );
    }

    final accountExecs = _users.where((u) => u.isAccountExecutive).length;
    final campaignExecs = _users.length - accountExecs;
    final filtered = _filtered;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Header ──
      Padding(
        padding: EdgeInsets.symmetric(horizontal: wide ? 8 : 4),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Team Management',
                  style: tt.titleLarge?.copyWith(fontSize: wide ? 24 : 20, fontWeight: FontWeight.w700, color: cs.onSurface, letterSpacing: -0.3)),
              const SizedBox(height: 4),
              Text('Manage your sales team accounts and permissions',
                  style: tt.bodySmall?.withColor(cs.onSurface.withValues(alpha: 0.45))),
            ]),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: _showAdd,
            icon: const Icon(Icons.person_add_outlined, size: 18),
            label: Text(wide ? 'Add Member' : 'Add'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              textStyle: tt.bodySmall?.semiBold,
            ),
          ),
        ]),
      ),
      const SizedBox(height: 20),

      // ── Stats Cards ──
      Padding(
        padding: EdgeInsets.symmetric(horizontal: wide ? 8 : 4),
        child: Row(children: [
          _StatCard(
              icon: Icons.groups_outlined,
              label: 'Total Members',
              value: '${_users.length}',
              color: cs.primary,
              cs: cs,
              dk: dk),
          const SizedBox(width: 12),
          _StatCard(
              icon: Icons.admin_panel_settings_outlined,
              label: 'Account Execs',
              value: '$accountExecs',
              color: cs.primary,
              cs: cs,
              dk: dk),
          const SizedBox(width: 12),
          _StatCard(
              icon: Icons.campaign_outlined,
              label: 'Campaign Execs',
              value: '$campaignExecs',
              color: cs.tertiary,
              cs: cs,
              dk: dk),
        ]),
      ),
      const SizedBox(height: 20),

      // ── Search & Filter ──
      Padding(
        padding: EdgeInsets.symmetric(horizontal: wide ? 8 : 4),
        child: Row(children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: tt.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                hintStyle: tt.bodyMedium?.withColor(cs.onSurface.withValues(alpha: 0.3)),
                prefixIcon: Icon(Icons.search, size: 20, color: cs.onSurface.withValues(alpha: 0.35)),
                filled: true,
                fillColor: dk ? cs.surface.withValues(alpha: 0.5) : cs.surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _FilterChip(
            label: 'All',
            selected: _roleFilter == 'all',
            onTap: () => setState(() => _roleFilter = 'all'),
            cs: cs,
          ),
          const SizedBox(width: 6),
          _FilterChip(
            label: 'Account',
            selected: _roleFilter == UserRole.accountExecutive,
            onTap: () => setState(() => _roleFilter = UserRole.accountExecutive),
            cs: cs,
            color: cs.primary,
          ),
          const SizedBox(width: 6),
          _FilterChip(
            label: 'Campaign',
            selected: _roleFilter == UserRole.campaignExecutive,
            onTap: () => setState(() => _roleFilter = UserRole.campaignExecutive),
            cs: cs,
            color: cs.tertiary,
          ),
        ]),
      ),
      const SizedBox(height: 16),

      // ── List ──
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _errorState(cs)
                : filtered.isEmpty
                    ? _emptyState(cs)
                    : FadeTransition(
                        opacity: _fadeCtrl,
                        child: ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: wide ? 8 : 4),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _UserCard(
                            user: filtered[i],
                            isMe: filtered[i].id == me.id,
                            cs: cs,
                            isDark: dk,
                            onEdit: () => _showEdit(filtered[i]),
                            onDelete: () => _confirmDelete(filtered[i]),
                          ),
                        ),
                      ),
      ),
    ]);
  }

  Widget _errorState(ColorScheme cs) {
    final tt = Theme.of(context).textTheme;
    return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_outlined, size: 48, color: cs.error.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(_error!, style: tt.bodyMedium?.withColor(cs.error)),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ]),
      );
  }

  Widget _emptyState(ColorScheme cs) {
    final tt = Theme.of(context).textTheme;
    return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.person_search_outlined, size: 48, color: cs.onSurface.withValues(alpha: 0.15)),
          const SizedBox(height: 16),
          Text('No members found',
              style: tt.titleSmall?.semiBold.withColor(cs.onSurface)),
          const SizedBox(height: 6),
          Text(_search.isNotEmpty ? 'Try a different search term' : 'Add your first team member to get started',
              style: tt.bodySmall?.withColor(cs.onSurface.withValues(alpha: 0.45))),
        ]),
      );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// USER CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _UserCard extends StatefulWidget {
  final CrmUser user;
  final bool isMe;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.isMe,
    required this.cs,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final cs = widget.cs;
    final dk = widget.isDark;
    final tt = Theme.of(context).textTheme;
    final roleColor = u.isAccountExecutive ? cs.primary : cs.tertiary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: _hovered
              ? (dk ? cs.surface.withValues(alpha: 0.8) : cs.surface)
              : (dk ? cs.surface.withValues(alpha: 0.5) : cs.surface.withValues(alpha: 0.8)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hovered
                ? cs.primary.withValues(alpha: 0.15)
                : cs.outline.withValues(alpha: dk ? 0.08 : 0.05),
          ),
          boxShadow: _hovered && !dk
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(children: [
          // Avatar
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [roleColor.withValues(alpha: 0.15), roleColor.withValues(alpha: 0.06)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: u.avatarUrl != null && u.avatarUrl!.isNotEmpty
                ? ClipOval(
                    child: Image.network(u.avatarUrl!, width: 46, height: 46, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _initials(u, roleColor)))
                : _initials(u, roleColor),
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(u.name,
                    style: tt.bodyMedium?.semiBold.withColor(cs.onSurface)),
                if (widget.isMe) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('You',
                        style: tt.labelSmall?.copyWith(fontSize: 10, fontWeight: FontWeight.w700, color: cs.primary)),
                  ),
                ],
              ]),
              const SizedBox(height: 3),
              Text(u.email,
                  style: tt.labelMedium?.withColor(cs.onSurface.withValues(alpha: 0.45))),
              if (u.title != null && u.title!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(u.title!,
                    style: tt.labelSmall?.withColor(cs.onSurface.withValues(alpha: 0.35))),
              ],
            ]),
          ),

          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: roleColor.withValues(alpha: 0.15)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                u.isAccountExecutive ? Icons.admin_panel_settings_outlined : Icons.campaign_outlined,
                size: 14,
                color: roleColor,
              ),
              const SizedBox(width: 5),
              Text(
                u.isAccountExecutive ? 'Account' : 'Campaign',
                style: tt.labelSmall?.semiBold.withColor(roleColor),
              ),
            ]),
          ),

          // Actions
          if (!widget.isMe) ...[
            const SizedBox(width: 8),
            AnimatedOpacity(
              opacity: _hovered ? 1 : 0.4,
              duration: const Duration(milliseconds: 200),
              child: Row(children: [
                _ActionBtn(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit',
                  color: cs.onSurface.withValues(alpha: 0.6),
                  onTap: widget.onEdit,
                ),
                const SizedBox(width: 2),
                _ActionBtn(
                  icon: Icons.delete_outline,
                  tooltip: 'Remove',
                  color: cs.error.withValues(alpha: 0.7),
                  onTap: widget.onDelete,
                ),
              ]),
            ),
          ] else
            const SizedBox(width: 80),
        ]),
      ),
    );
  }

  Widget _initials(CrmUser u, Color color) => Center(
        child: Text(
          u.name.isNotEmpty ? u.name.substring(0, 1).toUpperCase() : '?',
          style: Theme.of(context).textTheme.titleMedium?.semiBold.withColor(color),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// STAT CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final ColorScheme cs;
  final bool dk;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.cs,
    required this.dk,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: dk ? cs.surface.withValues(alpha: 0.6) : cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline.withValues(alpha: dk ? 0.1 : 0.06)),
          boxShadow: dk
              ? null
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: Theme.of(context).textTheme.titleLarge?.bold.withColor(cs.onSurface)),
            Text(label, style: Theme.of(context).textTheme.labelSmall?.withColor(cs.onSurface.withValues(alpha: 0.45))),
          ]),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FILTER CHIP
// ═══════════════════════════════════════════════════════════════════════════════

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.cs,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? cs.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? c.withValues(alpha: 0.3) : cs.outline.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? c : cs.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACTION BUTTON
// ═══════════════════════════════════════════════════════════════════════════════

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.tooltip, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STYLED DIALOG
// ═══════════════════════════════════════════════════════════════════════════════

class _StyledDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final ColorScheme cs;
  final bool isDark;
  final Widget content;
  final List<Widget> actions;

  const _StyledDialog({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.cs,
    required this.isDark,
    required this.content,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: isDark ? cs.surface : cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: cs.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium?.semiBold.withColor(cs.onSurface)),
                  Text(subtitle,
                      style: Theme.of(context).textTheme.labelMedium?.withColor(cs.onSurface.withValues(alpha: 0.45)),
                      overflow: TextOverflow.ellipsis),
                ]),
              ),
            ]),
            const SizedBox(height: 24),
            content,
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              for (int i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                actions[i],
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DIALOG FIELD
// ═══════════════════════════════════════════════════════════════════════════════

class _DialogField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool obscure;
  final ColorScheme cs;
  final bool isDark;

  const _DialogField({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.obscure = false,
    required this.cs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: Theme.of(context).textTheme.bodySmall?.withColor(cs.onSurface.withValues(alpha: 0.5)),
        prefixIcon: Icon(icon, size: 20, color: cs.onSurface.withValues(alpha: 0.35)),
        filled: true,
        fillColor: isDark ? cs.surface.withValues(alpha: 0.3) : cs.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DIALOG ROLE PICKER
// ═══════════════════════════════════════════════════════════════════════════════

class _DialogRolePicker extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  final ColorScheme cs;

  const _DialogRolePicker({required this.current, required this.onChanged, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Role',
            style: Theme.of(context).textTheme.labelMedium?.medium.withColor(cs.onSurface.withValues(alpha: 0.5))),
        const SizedBox(height: 8),
        Row(children: [
          _roleOption(context, 'Account Executive', UserRole.accountExecutive, cs.primary),
          const SizedBox(width: 10),
          _roleOption(context, 'Campaign Executive', UserRole.campaignExecutive, cs.tertiary),
        ]),
      ],
    );
  }

  Widget _roleOption(BuildContext context, String label, String value, Color color) {
    final sel = current == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel ? color.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sel ? color.withValues(alpha: 0.4) : cs.outline.withValues(alpha: 0.15),
              width: sel ? 1.5 : 1,
            ),
          ),
          child: Column(children: [
            Icon(
              value == UserRole.accountExecutive
                  ? Icons.admin_panel_settings_outlined
                  : Icons.campaign_outlined,
              size: 22,
              color: sel ? color : cs.onSurface.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                color: sel ? color : cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
