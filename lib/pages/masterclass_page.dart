import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';

// ─────────────────────────────────────────────────────────────
//  Tick & Talk — Presentation Masterclass Page
//  Packages · About · Contact · Pitching Scripts
//  English UI, Arabic script bodies only
// ─────────────────────────────────────────────────────────────

class MasterclassPage extends StatefulWidget {
  const MasterclassPage({super.key});
  @override
  State<MasterclassPage> createState() => _MasterclassPageState();
}

class _MasterclassPageState extends State<MasterclassPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  // Script filters
  _Audience? _audienceFilter;
  _Channel? _channelFilter;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // Arabic text helper – uses Cairo for Arabic script bodies only
  TextStyle _arabic(
    BuildContext context,
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) {
    final cs = Theme.of(context).colorScheme;
    return GoogleFonts.cairo(
      fontSize: size,
      fontWeight: weight,
      color: color ?? cs.onSurface,
      height: 1.6,
    );
  }

  void _copyAndNotify(String text, [String label = 'Copied']) {
    Clipboard.setData(ClipboardData(text: text));
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label ✓', style: TextStyle(color: cs.onPrimary)),
        backgroundColor: cs.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Presentation Masterclass',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.tonalIcon(
              onPressed: () => _copyAndNotify('+201060365021', 'Phone copied'),
              icon: const Icon(Icons.content_copy_rounded, size: 16),
              label: const Text('Copy Phone'),
            ),
          ),
          const SizedBox(width: 12),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.inventory_2_outlined, size: 18),
                SizedBox(width: 6),
                Text('Packages'),
              ]),
            ),
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.info_outline_rounded, size: 18),
                SizedBox(width: 6),
                Text('About'),
              ]),
            ),
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.contact_phone_outlined, size: 18),
                SizedBox(width: 6),
                Text('Contact'),
              ]),
            ),
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.description_outlined, size: 18),
                SizedBox(width: 6),
                Text('Sales Scripts'),
              ]),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildPackagesTab(context),
          _buildAboutTab(context),
          _buildContactTab(context),
          _buildScriptsTab(context),
        ],
      ),
    );
  }

  // ──────────────────── 1. Packages Tab ────────────────────
  Widget _buildPackagesTab(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // Intro card
        Card(
          child: Padding(
            padding: AppSpacing.paddingLg,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(Icons.school_rounded, color: cs.primary, size: 24),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('tick & talk®',
                          style: context.textStyles.labelLarge
                              ?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        'Develop your presentation skills with certified coaches',
                        style: context.textStyles.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Packages – responsive
        LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth > 700;
          final isSA = context.watch<AppState>().selectedMarket.id == 'saudi_arabia';
          final packages = [
            _PackageData(
              title: 'Student Plan',
              price: isSA ? '1,499 SAR' : '2,000 EGP',
              features: const [
                '3 months access to Speekr.ai platform',
                '2 on-ground coaching sessions',
                'Recorded sessions',
                'AI Roleplays',
              ],
            ),
            _PackageData(
              title: 'Professional Plan',
              price: isSA ? '1,999 SAR' : '3,000 EGP',
              badge: 'Most Popular',
              features: const [
                '3 months access to Speekr.ai platform',
                '6 on-ground coaching sessions',
                'Recorded sessions',
                'AI Roleplays',
              ],
            ),
            _PackageData(
              title: 'Team Plan',
              price: 'Custom Pricing',
              features: const [
                '3 months access to Speekr.ai platform',
                'Live sessions',
                'Recorded sessions',
                'Requires 10+ users',
              ],
            ),
          ];

          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _packageCard(context, packages[0])),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _packageCard(context, packages[1])),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _packageCard(context, packages[2])),
              ],
            );
          }
          return Column(
            children: packages
                .map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _packageCard(context, p),
                    ))
                .toList(),
          );
        }),
      ],
    );
  }

  Widget _packageCard(BuildContext context, _PackageData pkg) {
    final cs = Theme.of(context).colorScheme;
    final isFeatured = pkg.badge != null;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: isFeatured ? cs.primary : cs.outline.withValues(alpha: 0.4),
          width: isFeatured ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isFeatured)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.lg - 1),
                  topRight: Radius.circular(AppRadius.lg - 1),
                ),
              ),
              child: Center(
                child: Text(pkg.badge!,
                    style: context.textStyles.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w700, color: cs.onPrimary)),
              ),
            ),
          Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pkg.title,
                    style: context.textStyles.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.md),
                Text(pkg.price,
                    style: context.textStyles.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800, color: cs.primary)),
                const SizedBox(height: AppSpacing.lg),
                ...pkg.features.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: cs.primary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(f,
                                  style: context.textStyles.bodyMedium
                                      ?.copyWith(color: cs.onSurface))),
                        ],
                      ),
                    )),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: isFeatured
                      ? FilledButton.icon(
                          onPressed: () => _copyAndNotify(
                              '${pkg.title} — ${pkg.price}\n${pkg.features.join('\n')}',
                              'Package details copied'),
                          icon: const Icon(Icons.content_copy_rounded, size: 16),
                          label: const Text('Copy Details'),
                        )
                      : OutlinedButton.icon(
                          onPressed: () => _copyAndNotify(
                              '${pkg.title} — ${pkg.price}\n${pkg.features.join('\n')}',
                              'Package details copied'),
                          icon: const Icon(Icons.content_copy_rounded, size: 16),
                          label: const Text('Copy Details'),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────── 2. About Tab ────────────────────
  Widget _buildAboutTab(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSA = context.watch<AppState>().selectedMarket.id == 'saudi_arabia';

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _sectionHeader(context, 'About the Program', Icons.info_outline_rounded),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              children: [
                _infoRow(context, isSA ? Icons.videocam_outlined : Icons.location_on_outlined,
                    isSA ? 'Live online coaching via Zoom, led by certified coaches' : 'On-ground coaching at our private studio, led by certified coaches'),
                _infoRow(context, Icons.feedback_outlined,
                    'Personalized feedback after every session'),
                _infoRow(context, Icons.schedule_outlined,
                    'Fully self-paced course — learn at your own speed'),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        _sectionHeader(context,
            isSA ? 'Session Format' : 'Studio Location',
            isSA ? Icons.videocam_outlined : Icons.apartment_outlined),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: InkWell(
            onTap: () => _copyAndNotify(
                isSA ? 'Online coaching via Zoom' : 'https://maps.app.goo.gl/SN7t4JFLegifyHss9',
                isSA ? 'Info copied' : 'Location link copied'),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
            padding: AppSpacing.paddingLg,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(isSA ? Icons.videocam_rounded : Icons.location_on_rounded,
                      color: cs.primary, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isSA ? 'Online / Virtual Sessions' : 'Maadi — Al-Zainy Tower',
                          style: context.textStyles.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(isSA ? 'Live coaching via Zoom  ·  Tap to copy' : 'Maadi, Cairo  ·  Tap to copy Maps link',
                          style: context.textStyles.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                Icon(Icons.content_copy_rounded,
                    color: cs.onSurfaceVariant, size: 18),
              ],
            ),
          ),
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        _sectionHeader(context, 'Why tick & talk?', Icons.star_outline_rounded),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              children: [
                _whyRow(context, Icons.verified_outlined,
                    'Professional certified coaches'),
                _whyRow(context, Icons.smart_toy_outlined,
                    'AI Roleplays for smart practice'),
                _whyRow(context, Icons.devices_outlined,
                    'Advanced Speekr.ai platform'),
                _whyRow(context, Icons.person_outline_rounded,
                    'Personalized feedback for every trainee'),
                _whyRow(
                    context, Icons.access_time_rounded, 'Full flexibility — learn anytime',
                    isLast: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String text, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(width: AppSpacing.sm),
        Text(text, style: context.textStyles.titleSmall
            ?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String text) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cs.onSurfaceVariant, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
              child: Text(text,
                  style: context.textStyles.bodyMedium
                      ?.copyWith(color: cs.onSurface))),
        ],
      ),
    );
  }

  Widget _whyRow(BuildContext context, IconData icon, String text,
      {bool isLast = false}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Icon(icon, color: cs.primary, size: 16),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
              child: Text(text,
                  style: context.textStyles.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500, color: cs.onSurface))),
        ],
      ),
    );
  }

  // ──────────────────── 3. Contact Tab ────────────────────
  Widget _buildContactTab(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSA = context.watch<AppState>().selectedMarket.id == 'saudi_arabia';

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _sectionHeader(context, 'Get in Touch', Icons.contacts_outlined),
        const SizedBox(height: AppSpacing.md),

        _contactCard(
          context,
          icon: Icons.phone_rounded,
          label: 'WhatsApp',
          value: '+20 1060365021',
          onTap: () => _copyAndNotify('+201060365021', 'Phone copied'),
        ),
        const SizedBox(height: AppSpacing.sm),

        _contactCard(
          context,
          icon: isSA ? Icons.videocam_rounded : Icons.location_on_rounded,
          label: isSA ? 'Session Format' : 'Studio Location',
          value: isSA ? 'Online / Virtual Sessions' : 'Maadi — Al-Zainy Tower',
          onTap: () => _copyAndNotify(
              isSA ? 'Online coaching via Zoom' : 'https://maps.app.goo.gl/SN7t4JFLegifyHss9',
              isSA ? 'Info copied' : 'Location link copied'),
        ),
        const SizedBox(height: AppSpacing.sm),

        _contactCard(
          context,
          icon: Icons.language_rounded,
          label: 'Website',
          value: 'www.tickandtalk.com',
          onTap: () => _copyAndNotify('www.tickandtalk.com', 'URL copied'),
        ),

        const SizedBox(height: AppSpacing.xl),

        // CTA card
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(color: cs.primary.withValues(alpha: 0.3)),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              gradient: LinearGradient(
                colors: [
                  cs.primary.withValues(alpha: 0.06),
                  cs.surface,
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
            padding: AppSpacing.paddingLg,
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child:
                      Icon(Icons.headset_mic_rounded, color: cs.primary, size: 28),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Contact us to help you pick the best plan for you',
                  style: context.textStyles.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: () => _copyAndNotify('+201060365021', 'Phone copied'),
                  icon: const Icon(Icons.content_copy_rounded, size: 18),
                  label: const Text('Copy Phone Number'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _contactCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: cs.primary, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: context.textStyles.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                    Text(value,
                        style: context.textStyles.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Icon(Icons.content_copy_rounded,
                  color: cs.onSurfaceVariant, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────── 4. Scripts Tab ────────────────────
  Widget _buildScriptsTab(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scripts = context.watch<AppState>().selectedMarket.id == 'saudi_arabia' ? _allScriptsSA : _allScripts;
    final filtered = scripts.where((s) {
      if (_audienceFilter != null && s.audience != _audienceFilter) return false;
      if (_channelFilter != null && s.channel != _channelFilter) return false;
      return true;
    }).toList();

    return Column(
      children: [
        // Filter chips
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text('Audience:',
                    style: context.textStyles.labelSmall
                        ?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                const SizedBox(width: AppSpacing.xs),
                _audienceChip(context, 'All', null, Icons.people_outline_rounded),
                _audienceChip(context, 'Student', _Audience.student, Icons.school_outlined),
                _audienceChip(context, 'Professional', _Audience.professional, Icons.work_outline_rounded),
                _audienceChip(context, 'Team', _Audience.team, Icons.groups_outlined),
                const SizedBox(width: AppSpacing.lg),
                Text('Channel:',
                    style: context.textStyles.labelSmall
                        ?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                const SizedBox(width: AppSpacing.xs),
                _channelChip(context, 'All', null, Icons.swap_horiz_rounded),
                _channelChip(context, 'Call', _Channel.salesCall, Icons.phone_outlined),
                _channelChip(context, 'WhatsApp', _Channel.whatsapp, Icons.chat_outlined),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: cs.outline.withValues(alpha: 0.4)),

        // Script cards
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.filter_list_off_rounded,
                          size: 48,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                      const SizedBox(height: AppSpacing.md),
                      Text('No scripts match this filter',
                          style: context.textStyles.bodyMedium
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) => _scriptCard(context, filtered[i]),
                ),
        ),
      ],
    );
  }

  Widget _audienceChip(BuildContext context, String label, _Audience? value, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    final selected = _audienceFilter == value;
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: ChoiceChip(
        avatar: Icon(icon, size: 15, color: selected ? cs.onPrimary : cs.onSurfaceVariant),
        label: Text(label,
            style: context.textStyles.labelSmall
                ?.copyWith(fontWeight: FontWeight.w600,
                    color: selected ? cs.onPrimary : cs.onSurface)),
        selected: selected,
        selectedColor: cs.primary,
        backgroundColor: cs.surface,
        side: BorderSide(
            color: selected ? cs.primary : cs.outline.withValues(alpha: 0.4)),
        onSelected: (_) => setState(() => _audienceFilter = value),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xs)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _channelChip(BuildContext context, String label, _Channel? value, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    final selected = _channelFilter == value;
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: ChoiceChip(
        avatar: Icon(icon, size: 15, color: selected ? cs.onPrimary : cs.onSurfaceVariant),
        label: Text(label,
            style: context.textStyles.labelSmall
                ?.copyWith(fontWeight: FontWeight.w600,
                    color: selected ? cs.onPrimary : cs.onSurface)),
        selected: selected,
        selectedColor: cs.primary,
        backgroundColor: cs.surface,
        side: BorderSide(
            color: selected ? cs.primary : cs.outline.withValues(alpha: 0.4)),
        onSelected: (_) => setState(() => _channelFilter = value),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xs)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _scriptCard(BuildContext context, _Script s) {
    final cs = Theme.of(context).colorScheme;
    final channelIcon = s.channel == _Channel.salesCall
        ? Icons.phone_outlined
        : Icons.chat_outlined;
    final channelLabel =
        s.channel == _Channel.salesCall ? 'Sales Call' : 'WhatsApp Message';
    final audienceIcon = switch (s.audience) {
      _Audience.student => Icons.school_outlined,
      _Audience.professional => Icons.work_outline_rounded,
      _Audience.team => Icons.groups_outlined,
    };
    final audienceLabel = switch (s.audience) {
      _Audience.student => 'Student',
      _Audience.professional => 'Professional',
      _Audience.team => 'Team / Corporate',
    };

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.md - 1),
                topRight: Radius.circular(AppRadius.md - 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(channelIcon, size: 14, color: cs.primary),
                    const SizedBox(width: 4),
                    Text(channelLabel,
                        style: context.textStyles.labelSmall
                            ?.copyWith(fontWeight: FontWeight.w600, color: cs.primary)),
                  ]),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(audienceIcon, size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(audienceLabel,
                        style: context.textStyles.labelSmall
                            ?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface)),
                  ]),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Text(s.tone,
                      style: context.textStyles.labelSmall
                          ?.copyWith(fontWeight: FontWeight.w500,
                              color: cs.onSurfaceVariant)),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.copy_rounded,
                      size: 18, color: cs.onSurfaceVariant),
                  tooltip: 'Copy script',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _copyAndNotify(s.body, 'Script copied'),
                ),
              ],
            ),
          ),
          // Body – Arabic script text, rendered RTL
          Directionality(
            textDirection: TextDirection.rtl,
            child: Padding(
              padding: AppSpacing.paddingLg,
              child: Text(s.body,
                  style: _arabic(context, 13.5, color: cs.onSurface)),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────── Data Models ────────────────────

class _PackageData {
  final String title;
  final String price;
  final String? badge;
  final List<String> features;
  _PackageData({
    required this.title,
    required this.price,
    this.badge,
    required this.features,
  });
}

enum _Audience { student, professional, team }

enum _Channel { salesCall, whatsapp }

class _Script {
  final _Audience audience;
  final _Channel channel;
  final String tone;
  final String body;
  const _Script(this.audience, this.channel, this.tone, this.body);
}

const _allScripts = <_Script>[
  // ── Sales Call Scripts ──
  _Script(
    _Audience.student,
    _Channel.salesCall,
    'Friendly & Casual',
    'ياسلام عليك! بتدور على حاجة تخليك تتميز في البريزنتيشن؟ عندنا في Tick & Talk ماستركلاس هتعلمك إزاي تعمل بريزنتيشن يفضل في دماغ الناس. بلان الطالب بـ٢٠٠٠ جنيه بس، هتاخد كوتشينج، سيشنز مسجلة، وAI Roleplays. إيه رأيك نتكلم أكتر؟',
  ),
  _Script(
    _Audience.student,
    _Channel.salesCall,
    'Energetic',
    'يلا بينا! لو عايز تبقى الشخص اللي كل ما يتكلم الكل يسمعه — ده وقتك! Tick & Talk Presentation Masterclass موجودة عشانك. بلان الطالب هتتدرب مع كوتشيز محترفين، هتعمل AI Roleplays، وهتخرج منها شخص تاني خالص. كلها بـ٢٠٠٠ جنيه!',
  ),
  _Script(
    _Audience.professional,
    _Channel.salesCall,
    'Formal & Professional',
    'أهلاً، معايا دقيقتين من وقتك؟ بنقدم في Tick & Talk برنامج Presentation Masterclass المتخصص في تطوير مهارات العرض والتقديم. البلان البروفيشنال بـ٣٠٠٠ جنيه بيشمل ٦ سيشنز كوتشينج أون جراوند، سيشنز مسجلة، و AI Roleplays.',
  ),
  _Script(
    _Audience.professional,
    _Channel.salesCall,
    'Inspiring & Emotional',
    'فكر معايا ثانية — كام مرة حسيت إن عندك أفكار عظيمة بس مش قادر توصلها صح؟ ده اللي Tick & Talk موجودين عشانه. مش بس بنعلمك تتكلم، بنعلمك تأثر. والكوتشيز عندنا هيساعدوك تلاقي صوتك الحقيقي.',
  ),
  _Script(
    _Audience.team,
    _Channel.salesCall,
    'Formal & Professional',
    'أهلاً، بتواصل معاك من Tick & Talk. بنقدم Team Plan مخصص للشركات اللي عايزة تطور مهارات التقديم عند فريقها. البلان مناسب لـ١٠+ موظفين، بيشمل Live Sessions، Recorded Sessions، وبرايسينج custom على حسب احتياجاتكم. ممكن نحدد وقت نتكلم فيه أكتر؟',
  ),
  _Script(
    _Audience.team,
    _Channel.salesCall,
    'Energetic',
    'تخيل إن كل واحد في فريقك يقدر يبيع الفكرة، يقنع العميل، ويكسب الرووم! ده بالظبط اللي Team Plan بتاعنا بيعمله. مش كورس عادي، ده استثمار حقيقي في فريقك!',
  ),

  // ── WhatsApp Message Scripts ──
  _Script(
    _Audience.student,
    _Channel.whatsapp,
    'Friendly & Casual',
    'هاي! 👋 عارف إن أكتر حاجة بتفرق في انترفيوز وبريزنتيشنز هي إزاي بتتكلم؟ 🎤 Tick & Talk عندها Presentation Masterclass للطلاب بـ٢٠٠٠ جنيه بس! كوتشينج، سيشنز مسجلة، وAI Roleplays. ابعتلي وقادر تعرف أكتر 😊',
  ),
  _Script(
    _Audience.student,
    _Channel.whatsapp,
    'Inspiring & Emotional',
    'في ناس بتتكلم وكلها بتسمع... وفي ناس بتتكلم ومحدش بيسمع 💭 الفرق مش في الأفكار، الفرق في إزاي بتوصلها. Tick & Talk هتساعدك تبقى الأول. 🚀 البلان الطلابي بـ٢٠٠٠ جنيه — محتاج تعرف أكتر؟',
  ),
  _Script(
    _Audience.professional,
    _Channel.whatsapp,
    'Formal & Professional',
    'أهلاً، أتمنى تكون بخير. 🙏 بتواصل معاك للتعريف ببرنامج Presentation Masterclass من Tick & Talk، المتخصص في تطوير مهارات التقديم والتواصل المهني. البلان البروفيشنال متاح بـ٣٠٠٠ جنيه ويشمل ٦ سيشنز كوتشينج مع متخصصين معتمدين. هل تسمح أشاركك التفاصيل؟',
  ),
  _Script(
    _Audience.professional,
    _Channel.whatsapp,
    'Energetic',
    'جاهز تاخد كاريرك للمستوى الجاي؟ 🔥 Tick & Talk Masterclass مش بس كورس — دي تجربة بتغيرك! ٦ سيشنز كوتشينج، AI Roleplays، وفيدباك شخصي. كلها بـ٣٠٠٠ جنيه. 💪 يلا نتكلم!',
  ),
  _Script(
    _Audience.team,
    _Channel.whatsapp,
    'Formal & Professional',
    'أهلاً، أتمنى تكونوا بخير. 🙏 Tick & Talk بتقدم Team Plan مخصص للمؤسسات اللي عايزة ترفع مستوى مهارات التقديم عند فريقها. البرنامج مرن وبيتصمم على حسب احتياجات شركتكم لـ١٠+ أفراد. هل يناسبكم نحدد وقت نتناقش فيه؟',
  ),
  _Script(
    _Audience.team,
    _Channel.whatsapp,
    'Inspiring & Emotional',
    'أقوى asset في شركتك مش المنتج — هو الناس اللي بتقدمه. 🧠✨ Tick & Talk بتساعد فريقك يتكلم بثقة، يقنع بسهولة، ويفرق في كل رووم يدخله. Team Plan على حسب احتياجكم. كلمونا نعمل حاجة مميزة لفريقكم! 💼',
  ),
];

// ──────────────────── Saudi Arabia Scripts (SAR pricing) ────────────────────
const _allScriptsSA = <_Script>[
  // ── Sales Call Scripts ──
  _Script(
    _Audience.student,
    _Channel.salesCall,
    'Friendly & Casual',
    'ياسلام عليك! بتدور على حاجة تخليك تتميز في البريزنتيشن؟ عندنا في Tick & Talk ماستركلاس هتعلمك إزاي تعمل بريزنتيشن يفضل في دماغ الناس. بلان الطالب بـ١٤٩٩ ريال بس، هتاخد كوتشينج، سيشنز مسجلة، وAI Roleplays. إيه رأيك نتكلم أكتر؟',
  ),
  _Script(
    _Audience.student,
    _Channel.salesCall,
    'Energetic',
    'يلا بينا! لو عايز تبقى الشخص اللي كل ما يتكلم الكل يسمعه — ده وقتك! Tick & Talk Presentation Masterclass موجودة عشانك. بلان الطالب هتتدرب مع كوتشيز محترفين، هتعمل AI Roleplays، وهتخرج منها شخص تاني خالص. كلها بـ١٤٩٩ ريال!',
  ),
  _Script(
    _Audience.professional,
    _Channel.salesCall,
    'Formal & Professional',
    'أهلاً، معايا دقيقتين من وقتك؟ بنقدم في Tick & Talk برنامج Presentation Masterclass المتخصص في تطوير مهارات العرض والتقديم. البلان البروفيشنال بـ١٩٩٩ ريال بيشمل ٦ سيشنز كوتشينج أون جراوند، سيشنز مسجلة، و AI Roleplays.',
  ),
  _Script(
    _Audience.professional,
    _Channel.salesCall,
    'Inspiring & Emotional',
    'فكر معايا ثانية — كام مرة حسيت إن عندك أفكار عظيمة بس مش قادر توصلها صح؟ ده اللي Tick & Talk موجودين عشانه. مش بس بنعلمك تتكلم، بنعلمك تأثر. والكوتشيز عندنا هيساعدوك تلاقي صوتك الحقيقي.',
  ),
  _Script(
    _Audience.team,
    _Channel.salesCall,
    'Formal & Professional',
    'أهلاً، بتواصل معاك من Tick & Talk. بنقدم Team Plan مخصص للشركات اللي عايزة تطور مهارات التقديم عند فريقها. البلان مناسب لـ١٠+ موظفين، بيشمل Live Sessions، Recorded Sessions، وبرايسينج custom على حسب احتياجاتكم. ممكن نحدد وقت نتكلم فيه أكتر؟',
  ),
  _Script(
    _Audience.team,
    _Channel.salesCall,
    'Energetic',
    'تخيل إن كل واحد في فريقك يقدر يبيع الفكرة، يقنع العميل، ويكسب الرووم! ده بالظبط اللي Team Plan بتاعنا بيعمله. مش كورس عادي، ده استثمار حقيقي في فريقك!',
  ),

  // ── WhatsApp Message Scripts ──
  _Script(
    _Audience.student,
    _Channel.whatsapp,
    'Friendly & Casual',
    'هاي! 👋 عارف إن أكتر حاجة بتفرق في انترفيوز وبريزنتيشنز هي إزاي بتتكلم؟ 🎤 Tick & Talk عندها Presentation Masterclass للطلاب بـ١٤٩٩ ريال بس! كوتشينج، سيشنز مسجلة، وAI Roleplays. ابعتلي وقادر تعرف أكتر 😊',
  ),
  _Script(
    _Audience.student,
    _Channel.whatsapp,
    'Inspiring & Emotional',
    'في ناس بتتكلم وكلها بتسمع... وفي ناس بتتكلم ومحدش بيسمع 💭 الفرق مش في الأفكار، الفرق في إزاي بتوصلها. Tick & Talk هتساعدك تبقى الأول. 🚀 البلان الطلابي بـ١٤٩٩ ريال — محتاج تعرف أكتر؟',
  ),
  _Script(
    _Audience.professional,
    _Channel.whatsapp,
    'Formal & Professional',
    'أهلاً، أتمنى تكون بخير. 🙏 بتواصل معاك للتعريف ببرنامج Presentation Masterclass من Tick & Talk، المتخصص في تطوير مهارات التقديم والتواصل المهني. البلان البروفيشنال متاح بـ١٩٩٩ ريال ويشمل ٦ سيشنز كوتشينج مع متخصصين معتمدين. هل تسمح أشاركك التفاصيل؟',
  ),
  _Script(
    _Audience.professional,
    _Channel.whatsapp,
    'Energetic',
    'جاهز تاخد كاريرك للمستوى الجاي؟ 🔥 Tick & Talk Masterclass مش بس كورس — دي تجربة بتغيرك! ٦ سيشنز كوتشينج، AI Roleplays، وفيدباك شخصي. كلها بـ١٩٩٩ ريال. 💪 يلا نتكلم!',
  ),
  _Script(
    _Audience.team,
    _Channel.whatsapp,
    'Formal & Professional',
    'أهلاً، أتمنى تكونوا بخير. 🙏 Tick & Talk بتقدم Team Plan مخصص للمؤسسات اللي عايزة ترفع مستوى مهارات التقديم عند فريقها. البرنامج مرن وبيتصمم على حسب احتياجات شركتكم لـ١٠+ أفراد. هل يناسبكم نحدد وقت نتناقش فيه؟',
  ),
  _Script(
    _Audience.team,
    _Channel.whatsapp,
    'Inspiring & Emotional',
    'أقوى asset في شركتك مش المنتج — هو الناس اللي بتقدمه. 🧠✨ Tick & Talk بتساعد فريقك يتكلم بثقة، يقنع بسهولة، ويفرق في كل رووم يدخله. Team Plan على حسب احتياجكم. كلمونا نعمل حاجة مميزة لفريقكم! 💼',
  ),
];
