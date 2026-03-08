// Profile Page — Premium UX with animations, stats, and micro-interactions.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:anis_crm/theme.dart';
import 'package:anis_crm/services/auth_service.dart';
import 'package:anis_crm/services/lead_service.dart';
import 'package:anis_crm/state/app_state.dart';
import 'package:anis_crm/models/lead.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _titleCtrl;
  late TextEditingController _leadTargetCtrl;
  late TextEditingController _dealTargetCtrl;
  late TextEditingController _revenueTargetCtrl;

  late AnimationController _saveAnim;
  late AnimationController _entranceAnim;
  late AnimationController _pulseAnim;
  late AnimationController _completionAnim;

  bool _saving = false;
  bool _uploadingAvatar = false;
  bool _avatarHover = false;
  bool _hasChanges = false;
  bool _statsLoaded = false;

  // Live stats
  int _totalLeads = 0;
  int _convertedLeads = 0;
  double _conversionRate = 0;
  double _totalRevenue = 0;

  final FocusNode _keyboardFocus = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _saveAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _entranceAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _pulseAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _completionAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _initControllers();
    AuthService.instance.addListener(_onAuth);
    _entranceAnim.forward();
    _loadStats();
  }

  void _initControllers() {
    final u = AuthService.instance.user;
    _nameCtrl = TextEditingController(text: u?.name ?? '');
    _phoneCtrl = TextEditingController(text: u?.phone ?? '');
    _titleCtrl = TextEditingController(text: u?.title ?? '');
    _leadTargetCtrl = TextEditingController(
        text: u != null && u.monthlyLeadTarget > 0
            ? u.monthlyLeadTarget.toString()
            : '');
    _dealTargetCtrl = TextEditingController(
        text: u != null && u.monthlyDealTarget > 0
            ? u.monthlyDealTarget.toString()
            : '');
    _revenueTargetCtrl = TextEditingController(
        text: u != null && u.monthlyRevenueTarget > 0
            ? u.monthlyRevenueTarget.toStringAsFixed(0)
            : '');
    for (final c in [
      _nameCtrl, _phoneCtrl, _titleCtrl,
      _leadTargetCtrl, _dealTargetCtrl, _revenueTargetCtrl,
    ]) {
      c.addListener(_dirty);
    }
  }

  Future<void> _loadStats() async {
    await LeadService.instance.load();
    final leads = LeadService.instance.leads.value
        .where((l) => l.country == context.read<AppState>().selectedMarketId).toList();
    if (mounted) {
      setState(() {
        _totalLeads = leads.length;
        _convertedLeads =
            leads.where((l) => l.status == LeadStatus.converted).length;
        _conversionRate =
            _totalLeads > 0 ? (_convertedLeads / _totalLeads * 100) : 0;
        _totalRevenue = leads
            .where((l) => l.status == LeadStatus.converted && l.dealValue != null)
            .fold(0.0, (sum, l) => sum + l.dealValue!);
        _statsLoaded = true;
      });
      _completionAnim.forward();
    }
  }

  void _dirty() {
    if (!_hasChanges && mounted) setState(() => _hasChanges = true);
  }

  void _onAuth() {
    if (mounted) setState(() {});
  }

  double get _profileCompletion {
    final u = AuthService.instance.user;
    if (u == null) return 0;
    int filled = 0;
    int total = 6;
    if (u.name.isNotEmpty) filled++;
    if (u.phone != null && u.phone!.isNotEmpty) filled++;
    if (u.title != null && u.title!.isNotEmpty) filled++;
    if (u.avatarUrl != null && u.avatarUrl!.isNotEmpty) filled++;
    if (u.monthlyLeadTarget > 0) filled++;
    if (u.monthlyRevenueTarget > 0) filled++;
    return filled / total;
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_onAuth);
    _saveAnim.dispose();
    _entranceAnim.dispose();
    _pulseAnim.dispose();
    _completionAnim.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _titleCtrl.dispose();
    _leadTargetCtrl.dispose();
    _dealTargetCtrl.dispose();
    _revenueTargetCtrl.dispose();
    _keyboardFocus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Actions ──

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _snack('Name is required', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await AuthService.instance.updateProfile(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        title: _titleCtrl.text.trim(),
        monthlyLeadTarget: int.tryParse(_leadTargetCtrl.text.trim()) ?? 0,
        monthlyDealTarget: int.tryParse(_dealTargetCtrl.text.trim()) ?? 0,
        monthlyRevenueTarget:
            double.tryParse(_revenueTargetCtrl.text.trim()) ?? 0,
      );
      _hasChanges = false;
      _saveAnim.forward().then((_) => Future.delayed(
              const Duration(milliseconds: 1000), () {
            if (mounted) _saveAnim.reverse();
          }));
      _snack('Profile saved successfully');
    } on CrmAuthException catch (e) {
      _snack(e.message, error: true);
    } catch (_) {
      _snack('Failed to save profile', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.image, allowMultiple: false, withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;
      setState(() => _uploadingAvatar = true);
      await AuthService.instance.uploadAvatar(file.bytes!, file.name);
      if (mounted) {
        setState(() => _uploadingAvatar = false);
        _snack('Profile picture updated');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
        _snack('Failed to upload picture', error: true);
      }
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(
            child: Text(msg,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500))),
      ]),
      backgroundColor: error
          ? Theme.of(context).colorScheme.error
          : const Color(0xFF2E7D32),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: Duration(seconds: error ? 4 : 2),
    ));
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dk = Theme.of(context).brightness == Brightness.dark;
    final user = AuthService.instance.user;
    final wide = MediaQuery.of(context).size.width >= 760;

    return KeyboardListener(
      focusNode: _keyboardFocus,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyS &&
            (HardwareKeyboard.instance.isMetaPressed ||
                HardwareKeyboard.instance.isControlPressed)) {
          _save();
        }
      },
      child: Stack(children: [
        SelectionArea(
          child: CustomScrollView(
            controller: _scrollCtrl,
            slivers: [
              // Hero banner
              SliverToBoxAdapter(child: _heroBanner(cs, dk, user, wide)),
              // Content
              SliverPadding(
                padding: EdgeInsets.symmetric(
                    horizontal: wide ? 40 : 16, vertical: 0),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 28),

                            // Quick Stats
                            _staggerChild(0, _quickStats(cs, dk, user, wide)),
                            const SizedBox(height: 32),

                            // Personal Info
                            _staggerChild(
                                1,
                                _sectionHeader(
                                    cs,
                                    Icons.person_outlined,
                                    'Personal Information',
                                    'Your basic profile details')),
                            const SizedBox(height: 14),
                            _staggerChild(
                                1, _infoCard(cs, dk, user, wide)),
                            const SizedBox(height: 32),

                            // Monthly Targets
                            _staggerChild(
                                2,
                                _sectionHeader(
                                    cs,
                                    Icons.track_changes_outlined,
                                    'Monthly Targets',
                                    'Set goals to track your performance')),
                            const SizedBox(height: 14),
                            _staggerChild(2, _targets(cs, dk, wide)),
                            const SizedBox(height: 32),

                            // Preferences
                            _staggerChild(
                                3,
                                _sectionHeader(
                                    cs,
                                    Icons.palette_outlined,
                                    'Preferences',
                                    'Customize your experience')),
                            const SizedBox(height: 14),
                            _staggerChild(3, _preferences(cs, dk)),
                            const SizedBox(height: 32),

                            // Account
                            _staggerChild(
                                4,
                                _sectionHeader(cs, Icons.shield_outlined,
                                    'Account', 'Security and account details')),
                            const SizedBox(height: 14),
                            _staggerChild(4, _account(cs, dk, user)),
                            const SizedBox(height: 100),
                          ]),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Floating save bar
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _floatingSaveBar(cs, dk, wide),
        ),
      ]),
    );
  }

  // ─── Stagger animation wrapper ───

  Widget _staggerChild(int index, Widget child) {
    final begin = (index * 0.12).clamp(0.0, 0.6);
    final end = (begin + 0.4).clamp(0.0, 1.0);
    final curve = CurvedAnimation(
      parent: _entranceAnim,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (context, _) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - curve.value)),
          child: child,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HERO BANNER — Animated gradient + avatar with completion ring
  // ═══════════════════════════════════════════════════════════════════════════

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _heroBanner(ColorScheme cs, bool dk, CrmUser? user, bool wide) {
    final bannerH = wide ? 220.0 : 190.0;
    final avatarR = wide ? 48.0 : 38.0;
    final overflowH = wide ? 90.0 : 80.0;
    return SizedBox(
      height: bannerH + overflowH,
      child: Stack(clipBehavior: Clip.none, children: [
        // Animated gradient background
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (context, _) => ClipRect(
            child: Container(
            width: double.infinity,
            height: bannerH,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(cs.primary, cs.tertiary, _pulseAnim.value * 0.15)!,
                  cs.primary.withValues(alpha: 0.65),
                  Color.lerp(cs.tertiary.withValues(alpha: 0.5),
                      cs.secondary.withValues(alpha: 0.4), _pulseAnim.value)!,
                ],
              ),
            ),
          )),
        ),
        // Decorative circles
        Positioned(
            right: -50,
            top: -50,
            child: _decorCircle(220, Colors.white.withValues(alpha: 0.05))),
        Positioned(
            left: -30,
            bottom: 10,
            child: _decorCircle(150, Colors.white.withValues(alpha: 0.04))),
        Positioned(
            right: wide ? 120 : 60,
            top: 20,
            child: _decorCircle(70, Colors.white.withValues(alpha: 0.03))),
        Positioned(
            left: wide ? 200 : 100,
            top: -20,
            child: _decorCircle(100, Colors.white.withValues(alpha: 0.025))),

        // Banner text
        Positioned(
          left: wide ? 40 : 16,
          top: wide ? 32 : 24,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('My Profile',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5)),
                const SizedBox(height: 6),
                Text('Manage your identity and preferences',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w400)),
                const SizedBox(height: 12),
                // Keyboard hint
                if (wide)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.keyboard_outlined,
                          size: 13,
                          color: Colors.white.withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      Text('\u2318S to save',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                    ]),
                  ),
              ]),
        ),

        // Avatar with completion ring
        Positioned(
          left: wide ? 40 : 16,
          bottom: 0,
          child: _avatarWithRing(cs, dk, user, avatarR),
        ),

        // Name + role badges
        Positioned(
          left: wide ? (40 + avatarR * 2 + 28) : (16 + avatarR * 2 + 20),
          bottom: wide ? 8 : 4,
          right: wide ? 40 : 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Greeting line
              Text(
                _greeting(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.3),
              ),
              const SizedBox(height: 2),
              // Name — large and bold
              Text(user?.name ?? 'User',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: wide ? 24 : 18,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                      letterSpacing: -0.5,
                      height: 1.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _rolePill(
                    user?.isAccountExecutive == true
                        ? 'Account Executive'
                        : 'Campaign Executive',
                    user?.isAccountExecutive == true
                        ? cs.primary
                        : cs.tertiary),
                if (user?.title != null && user!.title!.isNotEmpty)
                  _rolePill(user.title!, cs.secondary),
                _completionPill(cs),
              ]),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _avatarWithRing(
      ColorScheme cs, bool dk, CrmUser? user, double radius) {
    return MouseRegion(
      onEnter: (_) => setState(() => _avatarHover = true),
      onExit: (_) => setState(() => _avatarHover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _uploadingAvatar ? null : _pickAvatar,
        child: SizedBox(
          width: radius * 2 + 12,
          height: radius * 2 + 12,
          child: Stack(alignment: Alignment.center, children: [
            // Completion ring
            AnimatedBuilder(
              animation: _completionAnim,
              builder: (context, _) => SizedBox(
                width: radius * 2 + 12,
                height: radius * 2 + 12,
                child: CustomPaint(
                  painter: _CompletionRingPainter(
                    progress: _profileCompletion *
                        CurvedAnimation(
                                parent: _completionAnim,
                                curve: Curves.easeOutCubic)
                            .value,
                    color: _profileCompletion >= 1.0
                        ? const Color(0xFF2E7D32)
                        : cs.primary,
                    trackColor: dk
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    strokeWidth: 3.0,
                  ),
                ),
              ),
            ),
            // Avatar
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: dk ? const Color(0xFF1E2028) : Colors.white,
                    width: 3.5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black
                          .withValues(alpha: _avatarHover ? 0.2 : 0.08),
                      blurRadius: _avatarHover ? 20 : 8,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Stack(children: [
                CircleAvatar(
                  radius: radius,
                  backgroundColor: cs.primary.withValues(alpha: 0.1),
                  backgroundImage:
                      user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                          ? NetworkImage(user.avatarUrl!)
                          : null,
                  child: (user?.avatarUrl == null || user!.avatarUrl!.isEmpty)
                      ? Text(
                          (user?.name ?? 'U').substring(0, 1).toUpperCase(),
                          style: TextStyle(
                              fontSize: radius * 0.55,
                              fontWeight: FontWeight.w700,
                              color: cs.primary))
                      : null,
                ),
                // Hover overlay
                AnimatedOpacity(
                  opacity: _avatarHover || _uploadingAvatar ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: CircleAvatar(
                    radius: radius,
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    child: _uploadingAvatar
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                                Icon(Icons.camera_alt_outlined,
                                    color: Colors.white, size: 20),
                                SizedBox(height: 2),
                                Text('Change',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500)),
                              ]),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _completionPill(ColorScheme cs) {
    final pct = (_profileCompletion * 100).round();
    final complete = pct >= 100;
    final color = complete ? const Color(0xFF2E7D32) : const Color(0xFFFF9800);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(complete ? Icons.verified_rounded : Icons.pie_chart_outline,
            size: 12, color: color),
        const SizedBox(width: 4),
        Text(complete ? 'Complete' : '$pct% complete',
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // QUICK STATS ROW
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _quickStats(ColorScheme cs, bool dk, CrmUser? user, bool wide) {
    return AnimatedOpacity(
      opacity: _statsLoaded ? 1 : 0.3,
      duration: const Duration(milliseconds: 400),
      child: Container(
        padding: EdgeInsets.all(wide ? 20 : 16),
        decoration: BoxDecoration(
          color: dk ? cs.surface.withValues(alpha: 0.6) : cs.surface,
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: cs.outline.withValues(alpha: dk ? 0.1 : 0.06)),
          boxShadow: dk
              ? null
              : [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4)),
                ],
        ),
        child: Row(children: [
          Expanded(
              child: _statItem(
                  cs,
                  dk,
                  Icons.people_outline,
                  '$_totalLeads',
                  'Total Leads',
                  cs.primary)),
          _statDivider(cs, dk),
          Expanded(
              child: _statItem(
                  cs,
                  dk,
                  Icons.trending_up_rounded,
                  '${_conversionRate.toStringAsFixed(1)}%',
                  'Conversion',
                  const Color(0xFF2E7D32))),
          _statDivider(cs, dk),
          Expanded(
              child: _statItem(
                  cs,
                  dk,
                  Icons.star_outline_rounded,
                  '$_convertedLeads',
                  'Converted',
                  const Color(0xFF9C27B0))),
          _statDivider(cs, dk),
          Expanded(
              child: _statItem(
                  cs,
                  dk,
                  Icons.workspace_premium_outlined,
                  user?.isAccountExecutive == true ? 'Full' : 'Limited',
                  'Access',
                  cs.tertiary)),
        ]),
      ),
    );
  }

  Widget _statItem(ColorScheme cs, bool dk, IconData icon, String value,
      String label, Color color) {
    return Column(children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: dk ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
      const SizedBox(height: 10),
      Text(value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700, color: cs.onSurface)),
      const SizedBox(height: 2),
      Text(label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.45),
              fontWeight: FontWeight.w400)),
    ]);
  }

  Widget _statDivider(ColorScheme cs, bool dk) {
    return Container(
      width: 1,
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: cs.outline.withValues(alpha: dk ? 0.08 : 0.06),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PERSONAL INFO CARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _infoCard(ColorScheme cs, bool dk, CrmUser? user, bool wide) {
    return _card(cs, dk,
        child: Column(children: [
          if (wide)
            Row(children: [
              Expanded(child: _textField(cs, dk, 'Full Name', _nameCtrl,
                  Icons.person_outlined)),
              const SizedBox(width: 20),
              Expanded(child: _textField(cs, dk, 'Job Title', _titleCtrl,
                  Icons.work_outline, hint: 'e.g. Senior AE')),
            ])
          else ...[
            _textField(cs, dk, 'Full Name', _nameCtrl, Icons.person_outlined),
            const SizedBox(height: 18),
            _textField(cs, dk, 'Job Title', _titleCtrl, Icons.work_outline,
                hint: 'e.g. Senior AE'),
          ],
          const SizedBox(height: 18),
          if (wide)
            Row(children: [
              Expanded(
                  child: _textField(cs, dk, 'Phone', _phoneCtrl,
                      Icons.phone_outlined,
                      hint: '+20 xxx xxx xxxx',
                      keyboard: TextInputType.phone)),
              const SizedBox(width: 20),
              Expanded(
                  child: _readOnlyField(cs, dk, 'Email',
                      user?.email ?? '', Icons.email_outlined)),
            ])
          else ...[
            _textField(cs, dk, 'Phone', _phoneCtrl, Icons.phone_outlined,
                hint: '+20 xxx xxx xxxx', keyboard: TextInputType.phone),
            const SizedBox(height: 18),
            _readOnlyField(
                cs, dk, 'Email', user?.email ?? '', Icons.email_outlined),
          ],
        ]));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TARGET CARDS — Visual goal cards with progress indicators
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _targets(ColorScheme cs, bool dk, bool wide) {
    final user = AuthService.instance.user;
    final items = [
      _TargetData(
        'Lead Target',
        _leadTargetCtrl,
        Icons.people_outline,
        'leads / mo',
        cs.primary,
        _totalLeads,
        user?.monthlyLeadTarget ?? 0,
      ),
      _TargetData(
        'Conversion Target',
        _dealTargetCtrl,
        Icons.trending_up,
        'conversions / mo',
        const Color(0xFF9C27B0),
        _convertedLeads,
        user?.monthlyDealTarget ?? 0,
      ),
      _TargetData(
        'Revenue Target',
        _revenueTargetCtrl,
        Icons.attach_money_rounded,
        'EGP / mo',
        const Color(0xFF2E7D32),
        _totalRevenue.toInt(),
        (user?.monthlyRevenueTarget ?? 0).toInt(),
      ),
    ];
    if (wide) {
      return Row(children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(child: _targetCard(cs, dk, items[i])),
        ],
      ]);
    }
    return Column(children: [
      for (int i = 0; i < items.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        _targetCard(cs, dk, items[i]),
      ],
    ]);
  }

  Widget _targetCard(ColorScheme cs, bool dk, _TargetData t) {
    final progress = t.target > 0 ? (t.current / t.target).clamp(0.0, 1.0) : 0.0;
    final hasTarget = t.target > 0;
    return _card(cs, dk,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            // Icon badge
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    t.color.withValues(alpha: dk ? 0.2 : 0.12),
                    t.color.withValues(alpha: dk ? 0.08 : 0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(t.icon, size: 21, color: t.color),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(t.label,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.semiBold
                          .withColor(cs.onSurface)),
                  Text(t.suffix,
                      style: Theme.of(context).textTheme.labelSmall?.withColor(
                          cs.onSurface.withValues(alpha: 0.35))),
                ])),
          ]),
          const SizedBox(height: 16),

          // Input
          TextField(
            controller: t.ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700, color: cs.onSurface),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface.withValues(alpha: 0.1)),
              filled: true,
              fillColor:
                  dk ? cs.surface.withValues(alpha: 0.35) : cs.surfaceContainerLow,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: t.color, width: 2)),
            ),
          ),

          // Progress bar (only if target set)
          if (hasTarget) ...[
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: t.color.withValues(alpha: dk ? 0.12 : 0.08),
                    valueColor: AlwaysStoppedAnimation(
                        progress >= 1.0 ? const Color(0xFF2E7D32) : t.color),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${t.current}/${t.target}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: progress >= 1.0
                        ? const Color(0xFF2E7D32)
                        : cs.onSurface.withValues(alpha: 0.45)),
              ),
            ]),
            if (progress >= 1.0) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.emoji_events_rounded,
                    size: 13, color: Color(0xFF2E7D32)),
                const SizedBox(width: 4),
                Text('Target reached!',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2E7D32).withValues(alpha: 0.8))),
              ]),
            ],
          ],
        ]));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PREFERENCES SECTION
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _preferences(ColorScheme cs, bool dk) {
    final state = context.watch<AppState>();
    return _card(cs, dk,
        child: Column(children: [
          _prefRow(
            cs,
            dk,
            icon: Icons.dark_mode_outlined,
            label: 'Dark Mode',
            subtitle: 'Switch between light and dark themes',
            trailing: Switch.adaptive(
              value: state.darkMode,
              onChanged: (v) => setState(() => state.setDarkMode(v)),
              activeColor: cs.primary,
            ),
          ),
          Divider(height: 1, color: cs.outline.withValues(alpha: 0.06)),
          _prefRow(
            cs,
            dk,
            icon: Icons.view_compact_outlined,
            label: 'Compact Layout',
            subtitle: 'Reduce white space in tables and lists',
            trailing: Switch.adaptive(
              value: state.compactLayout,
              onChanged: (v) => setState(() => state.setCompactLayout(v)),
              activeColor: cs.primary,
            ),
          ),
          Divider(height: 1, color: cs.outline.withValues(alpha: 0.06)),
          _prefRow(
            cs,
            dk,
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            subtitle: 'Enable in-app notifications',
            trailing: Switch.adaptive(
              value: state.notificationsEnabled,
              onChanged: (v) =>
                  setState(() => state.setNotificationsEnabled(v)),
              activeColor: cs.primary,
            ),
          ),
        ]));
  }

  Widget _prefRow(ColorScheme cs, bool dk,
      {required IconData icon,
      required String label,
      required String subtitle,
      required Widget trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: dk ? 0.12 : 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child:
              Icon(icon, size: 19, color: cs.primary.withValues(alpha: 0.7)),
        ),
        const SizedBox(width: 14),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500)),
              const SizedBox(height: 1),
              Text(subtitle,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.4))),
            ])),
        trailing,
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCOUNT SECTION — with danger zone
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _account(ColorScheme cs, bool dk, CrmUser? user) {
    return Column(children: [
      _card(cs, dk,
          child: Column(children: [
            _accountRow(
                cs, dk, Icons.fingerprint, 'User ID', user?.id ?? '\u2014',
                copyable: true),
            Divider(height: 1, color: cs.outline.withValues(alpha: 0.06)),
            _accountRow(
                cs, dk, Icons.email_outlined, 'Email', user?.email ?? '\u2014'),
            Divider(height: 1, color: cs.outline.withValues(alpha: 0.06)),
            _accountRow(
                cs,
                dk,
                Icons.security_outlined,
                'Role',
                user?.isAccountExecutive == true
                    ? 'Account Executive (full access)'
                    : 'Campaign Executive'),
          ])),
      const SizedBox(height: 16),
      // Danger zone
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.error.withValues(alpha: dk ? 0.08 : 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.error.withValues(alpha: dk ? 0.18 : 0.1)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.warning_amber_rounded,
                size: 18, color: cs.error.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            Text('Danger Zone',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.error.withValues(alpha: 0.8))),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: Icon(Icons.logout_rounded,
                  size: 18, color: cs.error),
              label: Text('Sign Out',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: cs.error)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: cs.error.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _accountRow(
      ColorScheme cs, bool dk, IconData icon, String label, String value,
      {bool copyable = false}) {
    return InkWell(
      onTap: copyable
          ? () {
              Clipboard.setData(ClipboardData(text: value));
              _snack('Copied to clipboard');
            }
          : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: dk ? 0.08 : 0.04),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon,
                size: 17, color: cs.onSurface.withValues(alpha: 0.4)),
          ),
          const SizedBox(width: 14),
          SizedBox(
              width: 68,
              child: Text(label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface.withValues(alpha: 0.5)))),
          Expanded(
              child: Text(value,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.75)),
                  overflow: TextOverflow.ellipsis)),
          if (copyable)
            Icon(Icons.copy_outlined,
                size: 14, color: cs.onSurface.withValues(alpha: 0.2)),
        ]),
      ),
    );
  }

  Future<void> _logout() async {
    final cs = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: cs.error.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.logout_rounded, color: cs.error, size: 28),
        ),
        title: Text('Sign Out?',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        content: const Text(
          'You will be returned to the login page.\nAny unsaved changes will be lost.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              child: const Text('Cancel')),
          const SizedBox(width: 8),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: cs.error,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign Out')),
        ],
      ),
    );
    if (ok == true) await AuthService.instance.logout();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FLOATING SAVE BAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _floatingSaveBar(ColorScheme cs, bool dk, bool wide) {
    return AnimatedSlide(
      offset: _hasChanges || _saving || _saveAnim.value > 0
          ? Offset.zero
          : const Offset(0, 1.5),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      child: Container(
        padding: EdgeInsets.fromLTRB(
            wide ? 40 : 16, 12, wide ? 40 : 16, 20 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: (dk ? const Color(0xFF1a1c22) : Colors.white)
              .withValues(alpha: 0.92),
          border: Border(
              top: BorderSide(
                  color: cs.outline.withValues(alpha: dk ? 0.1 : 0.06))),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, -4)),
          ],
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Row(children: [
              // Unsaved indicator
              AnimatedOpacity(
                opacity: _hasChanges ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color:
                              const Color(0xFFFF9800).withValues(alpha: 0.4),
                          blurRadius: 6),
                    ],
                  ),
                ),
              ),
              if (_hasChanges)
                Expanded(
                    child: Text('You have unsaved changes',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w500)))
              else
                const Spacer(),
              const SizedBox(width: 16),
              // Save button
              AnimatedBuilder(
                animation: _saveAnim,
                builder: (context, _) => SizedBox(
                  height: 46,
                  width: wide ? 180 : 140,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: _saveAnim.value > 0
                          ? Color.lerp(cs.primary, const Color(0xFF2E7D32),
                              _saveAnim.value)
                          : cs.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_saving)
                            const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                          else if (_saveAnim.value > 0.5)
                            const Icon(Icons.check_rounded, size: 20)
                          else
                            const Icon(Icons.save_outlined, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _saving
                                ? 'Saving...'
                                : _saveAnim.value > 0.5
                                    ? 'Saved!'
                                    : 'Save',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARED HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _sectionHeader(
      ColorScheme cs, IconData icon, String title, String sub) {
    return Row(children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.primary.withValues(alpha: 0.12),
                cs.primary.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: cs.primary),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.semiBold
                .withColor(cs.onSurface)),
        Text(sub,
            style: Theme.of(context).textTheme.labelMedium?.withColor(
                cs.onSurface.withValues(alpha: 0.4))),
      ]),
    ]);
  }

  Widget _card(ColorScheme cs, bool dk, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: dk ? cs.surface.withValues(alpha: 0.6) : cs.surface,
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: cs.outline.withValues(alpha: dk ? 0.1 : 0.06)),
        boxShadow: dk
            ? null
            : [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 3)),
              ],
      ),
      child: child,
    );
  }

  Widget _rolePill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.15))),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _decorCircle(double size, Color color) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color));

  Widget _textField(ColorScheme cs, bool dk, String label,
      TextEditingController ctrl, IconData icon,
      {String? hint, TextInputType keyboard = TextInputType.text}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: cs.onSurface.withValues(alpha: 0.5))),
      const SizedBox(height: 7),
      TextField(
        controller: ctrl,
        keyboardType: keyboard,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.withColor(cs.onSurface),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: Theme.of(context).textTheme.bodyMedium?.withColor(
              cs.onSurface.withValues(alpha: 0.2)),
          prefixIcon: Icon(icon,
              size: 20, color: cs.onSurface.withValues(alpha: 0.3)),
          filled: true,
          fillColor:
              dk ? cs.surface.withValues(alpha: 0.3) : cs.surfaceContainerLow,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cs.primary, width: 1.5)),
        ),
      ),
    ]);
  }

  Widget _readOnlyField(
      ColorScheme cs, bool dk, String label, String value, IconData icon) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: cs.onSurface.withValues(alpha: 0.5))),
      const SizedBox(height: 7),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: dk
              ? cs.surface.withValues(alpha: 0.15)
              : cs.surfaceContainerLow.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(icon,
              size: 20, color: cs.onSurface.withValues(alpha: 0.25)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(value,
                  style: Theme.of(context).textTheme.bodyMedium?.withColor(
                      cs.onSurface.withValues(alpha: 0.4)))),
          Icon(Icons.lock_outline,
              size: 14, color: cs.onSurface.withValues(alpha: 0.15)),
        ]),
      ),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// DATA MODELS
// ═════════════════════════════════════════════════════════════════════════════

class _TargetData {
  final String label;
  final TextEditingController ctrl;
  final IconData icon;
  final String suffix;
  final Color color;
  final int current;
  final int target;
  _TargetData(this.label, this.ctrl, this.icon, this.suffix, this.color,
      this.current, this.target);
}

// ═════════════════════════════════════════════════════════════════════════════
// CUSTOM PAINTERS
// ═════════════════════════════════════════════════════════════════════════════

class _CompletionRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  _CompletionRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    if (progress > 0) {
      final arcPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CompletionRingPainter old) =>
      old.progress != progress || old.color != color;
}

// ═════════════════════════════════════════════════════════════════════════════
// ANIMATION HELPER
// ═════════════════════════════════════════════════════════════════════════════

class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;
  const AnimatedBuilder(
      {super.key,
      required Animation<double> animation,
      required this.builder,
      this.child})
      : super(listenable: animation);
  @override
  Widget build(BuildContext context) => builder(context, child);
}
