import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:anis_crm/theme.dart';
import 'package:anis_crm/state/app_state.dart';
import 'package:anis_crm/services/integration_service.dart';

// =============================================================================
// INTEGRATIONS PAGE — Facebook Lead Ads, WhatsApp Cloud API & Zapier
// =============================================================================

class IntegrationsPage extends StatefulWidget {
  const IntegrationsPage({super.key});

  @override
  State<IntegrationsPage> createState() => _IntegrationsPageState();
}

class _IntegrationsPageState extends State<IntegrationsPage> {
  bool _loading = true;
  Map<String, dynamic>? _config;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _loading = true);
    await IntegrationService.instance.refreshStatus();
    final config = await IntegrationService.instance.getConfig();
    if (mounted) {
      setState(() {
        _config = config;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PageHeader(),
          const SizedBox(height: AppSpacing.lg),
          if (_loading)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator()))
          else ...[
            // STATUS OVERVIEW
            _StatusOverview(),
            const SizedBox(height: AppSpacing.lg),
            // FACEBOOK LEAD ADS
            _FacebookSection(
              config: _config?['facebook'] as Map<String, dynamic>? ?? {},
              onSaved: _loadConfig,
            ),
            const SizedBox(height: AppSpacing.md),
            // WHATSAPP CLOUD API
            _WhatsAppSection(
              config: _config?['whatsapp'] as Map<String, dynamic>? ?? {},
              onSaved: _loadConfig,
            ),
            const SizedBox(height: AppSpacing.md),
            // ZAPIER
            _ZapierSection(
              config: _config?['zapier'] as Map<String, dynamic>? ?? {},
              onSaved: _loadConfig,
            ),
            const SizedBox(height: AppSpacing.md),
            // SETUP GUIDE
            const _SetupGuide(),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// PAGE HEADER
// =============================================================================

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1877F2),
              const Color(0xFF25D366),
              const Color(0xFFFF4A00),
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: const Icon(Icons.hub_rounded, color: Colors.white, size: 20),
      ),
      const SizedBox(width: 14),
      Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Integrations',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: cs.onSurface)),
        const SizedBox(height: 2),
        Text('Connect Facebook, WhatsApp & Zapier to auto-capture leads',
            style:
                tt.bodySmall?.withColor(cs.onSurfaceVariant)),
      ])),
      IconButton(
        onPressed: () {
          IntegrationService.instance.refreshStatus();
        },
        icon: const Icon(Icons.refresh_rounded, size: 20),
        tooltip: 'Refresh status',
      ),
    ]);
  }
}

// =============================================================================
// STATUS OVERVIEW
// =============================================================================

class _StatusOverview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<IntegrationStatus>(
      valueListenable: IntegrationService.instance.status,
      builder: (context, status, _) {
        return Row(
          children: [
            Expanded(
                child: _StatusCard(
              icon: Icons.facebook_rounded,
              iconColor: const Color(0xFF1877F2),
              label: 'Facebook Lead Ads',
              connected: status.facebookConnected,
              leadsCount: status.facebookLeadsCount,
              isDark: isDark,
              cs: cs,
            )),
            const SizedBox(width: 12),
            Expanded(
                child: _StatusCard(
              icon: Icons.chat_rounded,
              iconColor: const Color(0xFF25D366),
              label: 'WhatsApp Cloud API',
              connected: status.whatsappConnected,
              leadsCount: status.whatsappLeadsCount,
              isDark: isDark,
              cs: cs,
            )),
            const SizedBox(width: 12),
            Expanded(
                child: _StatusCard(
              icon: Icons.bolt_rounded,
              iconColor: const Color(0xFFFF4A00),
              label: 'Zapier',
              connected: status.zapierConnected,
              leadsCount: status.zapierLeadsCount,
              isDark: isDark,
              cs: cs,
            )),
          ],
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.connected,
    required this.leadsCount,
    required this.isDark,
    required this.cs,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool connected;
  final int leadsCount;
  final bool isDark;
  final ColorScheme cs;

  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
            color: connected
                ? AppColors.success.withValues(alpha: 0.3)
                : cs.outline.withValues(alpha: isDark ? 0.15 : 0.08)),
        boxShadow: [
          BoxShadow(
              color: cs.shadow.withValues(alpha: isDark ? 0.08 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: connected
                  ? AppColors.success.withValues(alpha: 0.1)
                  : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: connected ? AppColors.success : cs.onSurfaceVariant.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                connected ? 'Active' : 'Inactive',
                style: (Theme.of(context).textTheme.labelSmall ?? const TextStyle()).semiBold.withColor(connected ? AppColors.success : cs.onSurfaceVariant),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Text(label,
            style: (Theme.of(context).textTheme.bodySmall ?? const TextStyle()).semiBold.withColor(cs.onSurface)),
        const SizedBox(height: 4),
        Text(
          '$leadsCount lead${leadsCount == 1 ? '' : 's'} captured',
          style: Theme.of(context).textTheme.labelMedium?.withColor(cs.onSurfaceVariant),
        ),
      ]),
    );
  }
}

// =============================================================================
// FACEBOOK SECTION
// =============================================================================

class _FacebookSection extends StatefulWidget {
  const _FacebookSection({required this.config, required this.onSaved});
  final Map<String, dynamic> config;
  final VoidCallback onSaved;

  @override
  State<_FacebookSection> createState() => _FacebookSectionState();
}

class _FacebookSectionState extends State<_FacebookSection> {
  late TextEditingController _verifyTokenCtrl;
  late TextEditingController _pageAccessTokenCtrl;
  bool _saving = false;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _verifyTokenCtrl = TextEditingController(
        text: widget.config['verify_token'] as String? ?? '');
    _pageAccessTokenCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _verifyTokenCtrl.dispose();
    _pageAccessTokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await IntegrationService.instance.saveFacebookConfig(
      verifyToken: _verifyTokenCtrl.text.trim(),
      pageAccessToken: _pageAccessTokenCtrl.text.trim(),
    );
    if (mounted) {
      setState(() => _saving = false);
      if (ok) {
        _pageAccessTokenCtrl.clear();
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
            SizedBox(width: 10),
            Text('Facebook config saved'),
          ]),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm)),
          margin: const EdgeInsets.all(AppSpacing.md),
          duration: const Duration(seconds: 2),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.error_outline, size: 18, color: Colors.white),
            SizedBox(width: 10),
            Text('Failed to save — is the server running?'),
          ]),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.danger,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm)),
          margin: const EdgeInsets.all(AppSpacing.md),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tt = Theme.of(context).textTheme;
    final configured = widget.config['configured'] == true;
    final webhookUrl = widget.config['webhook_url'] as String? ?? '/api/webhooks/facebook';
    final maskedToken = widget.config['page_access_token'] as String? ?? '';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
            color: cs.outline.withValues(alpha: isDark ? 0.15 : 0.08)),
        boxShadow: [
          BoxShadow(
              color: cs.shadow.withValues(alpha: isDark ? 0.08 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF1877F2).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: const Icon(Icons.facebook_rounded,
                    size: 18, color: Color(0xFF1877F2)),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Facebook Lead Ads',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface)),
                    const SizedBox(height: 2),
                    Text(
                        'Auto-capture leads from Facebook ad forms',
                        style: tt.labelSmall?.copyWith(fontSize: 11.5, color: cs.onSurfaceVariant)),
                  ])),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: configured
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  configured ? 'Connected' : 'Not configured',
                  style: tt.labelSmall?.semiBold.withColor(configured ? AppColors.success : AppColors.warning),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
            ]),
          ),
        ),

        if (_expanded) ...[
          Divider(
              height: 1,
              color: cs.outline.withValues(alpha: isDark ? 0.1 : 0.06)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Webhook URL
                _InfoRow(
                  label: 'Webhook URL',
                  value: webhookUrl,
                  helperText:
                      'Set this as your Callback URL in Meta Developer portal → Webhooks',
                  copyable: true,
                ),
                const SizedBox(height: 14),

                // Verify Token
                Text('Verify Token',
                    style: tt.labelMedium?.semiBold.withColor(cs.onSurface)),
                const SizedBox(height: 6),
                TextField(
                  controller: _verifyTokenCtrl,
                  style: GoogleFonts.jetBrainsMono(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g. anis_crm_verify_token',
                    hintStyle: tt.labelMedium?.copyWith(fontSize: 12.5, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm)),
                  ),
                ),
                const SizedBox(height: 14),

                // Page Access Token
                Text('Page Access Token',
                    style: tt.labelMedium?.semiBold.withColor(cs.onSurface)),
                const SizedBox(height: 4),
                if (maskedToken.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('Current: $maskedToken',
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 11, color: cs.onSurfaceVariant)),
                  ),
                TextField(
                  controller: _pageAccessTokenCtrl,
                  style: GoogleFonts.jetBrainsMono(fontSize: 13),
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Paste your Page Access Token',
                    hintStyle: tt.labelMedium?.copyWith(fontSize: 12.5, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Generate at Meta Business Suite → Page Settings → Page Access Token. Needs leads_retrieval permission.',
                  style: tt.labelSmall?.withColor(cs.onSurfaceVariant).copyWith(height: 1.4),
                ),
                const SizedBox(height: 16),

                // Save button
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: cs.onPrimary))
                        : const Icon(Icons.save_rounded, size: 16),
                    label: Text(_saving ? 'Saving...' : 'Save Facebook Config',
                        style: tt.labelMedium?.copyWith(fontSize: 12.5)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1877F2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ]),
    );
  }
}

// =============================================================================
// WHATSAPP SECTION
// =============================================================================

class _WhatsAppSection extends StatefulWidget {
  const _WhatsAppSection({required this.config, required this.onSaved});
  final Map<String, dynamic> config;
  final VoidCallback onSaved;

  @override
  State<_WhatsAppSection> createState() => _WhatsAppSectionState();
}

class _WhatsAppSectionState extends State<_WhatsAppSection> {
  late TextEditingController _verifyTokenCtrl;
  late TextEditingController _phoneNumberIdCtrl;
  late TextEditingController _accessTokenCtrl;
  bool _saving = false;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _verifyTokenCtrl = TextEditingController(
        text: widget.config['verify_token'] as String? ?? '');
    _phoneNumberIdCtrl = TextEditingController(
        text: widget.config['phone_number_id'] as String? ?? '');
    _accessTokenCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _verifyTokenCtrl.dispose();
    _phoneNumberIdCtrl.dispose();
    _accessTokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await IntegrationService.instance.saveWhatsAppConfig(
      verifyToken: _verifyTokenCtrl.text.trim(),
      phoneNumberId: _phoneNumberIdCtrl.text.trim(),
      accessToken: _accessTokenCtrl.text.trim(),
    );
    if (mounted) {
      setState(() => _saving = false);
      if (ok) {
        _accessTokenCtrl.clear();
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
            SizedBox(width: 10),
            Text('WhatsApp config saved'),
          ]),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm)),
          margin: const EdgeInsets.all(AppSpacing.md),
          duration: const Duration(seconds: 2),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.error_outline, size: 18, color: Colors.white),
            SizedBox(width: 10),
            Text('Failed to save — is the server running?'),
          ]),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.danger,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm)),
          margin: const EdgeInsets.all(AppSpacing.md),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tt = Theme.of(context).textTheme;
    final configured = widget.config['configured'] == true;
    final webhookUrl = widget.config['webhook_url'] as String? ?? '/api/webhooks/whatsapp';
    final maskedToken = widget.config['access_token'] as String? ?? '';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
            color: cs.outline.withValues(alpha: isDark ? 0.15 : 0.08)),
        boxShadow: [
          BoxShadow(
              color: cs.shadow.withValues(alpha: isDark ? 0.08 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: const Icon(Icons.chat_rounded,
                    size: 18, color: Color(0xFF25D366)),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('WhatsApp Cloud API',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface)),
                    const SizedBox(height: 2),
                    Text(
                        'Auto-capture leads from WhatsApp messages',
                        style: tt.labelSmall?.copyWith(fontSize: 11.5, color: cs.onSurfaceVariant)),
                  ])),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: configured
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  configured ? 'Connected' : 'Not configured',
                  style: tt.labelSmall?.semiBold.withColor(configured ? AppColors.success : AppColors.warning),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
            ]),
          ),
        ),

        if (_expanded) ...[
          Divider(
              height: 1,
              color: cs.outline.withValues(alpha: isDark ? 0.1 : 0.06)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Webhook URL
                _InfoRow(
                  label: 'Webhook URL',
                  value: webhookUrl,
                  helperText:
                      'Set this as your Callback URL in Meta Developer portal → WhatsApp → Configuration',
                  copyable: true,
                ),
                const SizedBox(height: 14),

                // Verify Token
                Text('Verify Token',
                    style: tt.labelMedium?.semiBold.withColor(cs.onSurface)),
                const SizedBox(height: 6),
                TextField(
                  controller: _verifyTokenCtrl,
                  style: GoogleFonts.jetBrainsMono(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g. anis_crm_wa_verify',
                    hintStyle: tt.labelMedium?.copyWith(fontSize: 12.5, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm)),
                  ),
                ),
                const SizedBox(height: 14),

                // Phone Number ID
                Text('Phone Number ID',
                    style: tt.labelMedium?.semiBold.withColor(cs.onSurface)),
                const SizedBox(height: 6),
                TextField(
                  controller: _phoneNumberIdCtrl,
                  style: GoogleFonts.jetBrainsMono(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g. 123456789012345',
                    hintStyle: tt.labelMedium?.copyWith(fontSize: 12.5, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm)),
                  ),
                ),
                const SizedBox(height: 14),

                // Access Token
                Text('Permanent Access Token',
                    style: tt.labelMedium?.semiBold.withColor(cs.onSurface)),
                const SizedBox(height: 4),
                if (maskedToken.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('Current: $maskedToken',
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 11, color: cs.onSurfaceVariant)),
                  ),
                TextField(
                  controller: _accessTokenCtrl,
                  style: GoogleFonts.jetBrainsMono(fontSize: 13),
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Paste your permanent access token',
                    hintStyle: tt.labelMedium?.copyWith(fontSize: 12.5, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Get from Meta Developer portal → WhatsApp → API Setup. Generate a permanent system user token.',
                  style: tt.labelSmall?.withColor(cs.onSurfaceVariant).copyWith(height: 1.4),
                ),
                const SizedBox(height: 16),

                // Save button
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: cs.onPrimary))
                        : const Icon(Icons.save_rounded, size: 16),
                    label: Text(
                        _saving ? 'Saving...' : 'Save WhatsApp Config',
                        style: tt.labelMedium?.copyWith(fontSize: 12.5)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ]),
    );
  }
}

// =============================================================================
// ZAPIER SECTION
// =============================================================================

class _ZapierSection extends StatefulWidget {
  const _ZapierSection({required this.config, required this.onSaved});
  final Map<String, dynamic> config;
  final VoidCallback onSaved;

  @override
  State<_ZapierSection> createState() => _ZapierSectionState();
}

class _ZapierSectionState extends State<_ZapierSection> {
  late TextEditingController _apiKeyCtrl;
  bool _saving = false;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _apiKeyCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await IntegrationService.instance.saveZapierConfig(
      apiKey: _apiKeyCtrl.text.trim(),
    );
    if (mounted) {
      setState(() => _saving = false);
      if (ok) {
        _apiKeyCtrl.clear();
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
            SizedBox(width: 10),
            Text('Zapier config saved'),
          ]),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm)),
          margin: const EdgeInsets.all(AppSpacing.md),
          duration: const Duration(seconds: 2),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.error_outline, size: 18, color: Colors.white),
            SizedBox(width: 10),
            Text('Failed to save — is the server running?'),
          ]),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.danger,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm)),
          margin: const EdgeInsets.all(AppSpacing.md),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tt = Theme.of(context).textTheme;
    final configured = widget.config['configured'] == true;
    final webhookUrl = widget.config['webhook_url'] as String? ?? '/api/webhooks/zapier';
    final maskedKey = widget.config['api_key'] as String? ?? '';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
            color: cs.outline.withValues(alpha: isDark ? 0.15 : 0.08)),
        boxShadow: [
          BoxShadow(
              color: cs.shadow.withValues(alpha: isDark ? 0.08 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4A00).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: const Icon(Icons.bolt_rounded,
                    size: 18, color: Color(0xFFFF4A00)),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Zapier',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface)),
                    const SizedBox(height: 2),
                    Text(
                        'Auto-capture leads & sync campaigns from 5000+ apps via Zapier',
                        style: tt.labelSmall?.copyWith(fontSize: 11.5, color: cs.onSurfaceVariant)),
                  ])),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: configured
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  configured ? 'Connected' : 'Not configured',
                  style: tt.labelSmall?.semiBold.withColor(configured ? AppColors.success : AppColors.warning),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
            ]),
          ),
        ),

        if (_expanded) ...[
          Divider(
              height: 1,
              color: cs.outline.withValues(alpha: isDark ? 0.1 : 0.06)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Webhook URLs
                _InfoRow(
                  label: 'Leads Webhook URL',
                  value: 'https://anis-crm-api-production.up.railway.app/api/webhooks/zapier',
                  helperText: 'Use for lead capture — POST lead data from any Zapier trigger',
                  copyable: true,
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  label: 'Campaigns Webhook URL',
                  value: 'https://anis-crm-api-production.up.railway.app/api/webhooks/zapier/campaign',
                  helperText: 'Use to create/update campaigns — POST campaign data from Google Sheets, Notion, etc.',
                  copyable: true,
                ),
                const SizedBox(height: 14),

                // API Key
                Text('API Key',
                    style: tt.labelMedium?.semiBold.withColor(cs.onSurface)),
                const SizedBox(height: 4),
                if (maskedKey.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('Current: $maskedKey',
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 11, color: cs.onSurfaceVariant)),
                  ),
                TextField(
                  controller: _apiKeyCtrl,
                  style: GoogleFonts.jetBrainsMono(fontSize: 13),
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Enter an API key for Zapier authentication',
                    hintStyle: tt.labelMedium?.copyWith(fontSize: 12.5, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Set any secret string as API key. Zapier will send it in the X-API-Key header to authenticate requests.',
                  style: tt.labelSmall?.withColor(cs.onSurfaceVariant).copyWith(height: 1.4),
                ),
                const SizedBox(height: 16),

                // Save button
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: cs.onPrimary))
                        : const Icon(Icons.save_rounded, size: 16),
                    label: Text(_saving ? 'Saving...' : 'Save Zapier Config',
                        style: tt.labelMedium?.copyWith(fontSize: 12.5)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4A00),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ]),
    );
  }
}

// =============================================================================
// SETUP GUIDE
// =============================================================================

class _SetupGuide extends StatelessWidget {
  const _SetupGuide();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tt = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
            color: cs.outline.withValues(alpha: isDark ? 0.15 : 0.08)),
        boxShadow: [
          BoxShadow(
              color: cs.shadow.withValues(alpha: isDark ? 0.08 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Icon(Icons.menu_book_rounded,
                  size: 16, color: cs.primary),
            ),
            const SizedBox(width: 10),
            Text('Quick Setup Guide',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface)),
          ]),
          const SizedBox(height: 16),
          Divider(
              height: 1,
              color: cs.outline.withValues(alpha: isDark ? 0.1 : 0.06)),
          const SizedBox(height: 16),

          // Facebook steps
          Text('Facebook Lead Ads',
              style: tt.bodySmall?.bold.withColor(const Color(0xFF1877F2))),
          const SizedBox(height: 8),
          _StepTile(number: '1', text: 'Go to developers.facebook.com and create/select an app'),
          _StepTile(number: '2', text: 'Add the "Webhooks" product and subscribe to the "Page" object'),
          _StepTile(number: '3', text: 'Set Callback URL to: https://<your-domain>/api/webhooks/facebook'),
          _StepTile(number: '4', text: 'Subscribe to the "leadgen" field'),
          _StepTile(number: '5', text: 'Generate a Page Access Token with "leads_retrieval" permission'),
          _StepTile(number: '6', text: 'Paste the token above and click Save'),

          const SizedBox(height: 20),

          // WhatsApp steps
          Text('WhatsApp Cloud API',
              style: tt.bodySmall?.bold.withColor(const Color(0xFF25D366))),
          const SizedBox(height: 8),
          _StepTile(number: '1', text: 'Go to developers.facebook.com → your app → WhatsApp → Configuration'),
          _StepTile(number: '2', text: 'Set Callback URL to: https://<your-domain>/api/webhooks/whatsapp'),
          _StepTile(number: '3', text: 'Enter the same Verify Token you saved above'),
          _StepTile(number: '4', text: 'Subscribe to the "messages" webhook field'),
          _StepTile(number: '5', text: 'Copy your Phone Number ID from WhatsApp → API Setup'),
          _StepTile(number: '6', text: 'Generate a permanent System User token and paste above'),

          const SizedBox(height: 20),

          // Zapier steps
          Text('Zapier — Lead Capture',
              style: tt.bodySmall?.bold.withColor(const Color(0xFFFF4A00))),
          const SizedBox(height: 8),
          _StepTile(number: '1', text: 'Go to zapier.com and create a new Zap'),
          _StepTile(number: '2', text: 'Choose your trigger app (Google Sheets, Typeform, HubSpot, etc.)'),
          _StepTile(number: '3', text: 'For the action, choose "Webhooks by Zapier" → "POST"'),
          _StepTile(number: '4', text: 'Set URL to: https://anis-crm-api-production.up.railway.app/api/webhooks/zapier'),
          _StepTile(number: '5', text: 'Add header: X-API-Key with the API key you saved above'),
          _StepTile(number: '6', text: 'Map fields: name, email, phone, campaign, source, company'),

          const SizedBox(height: 16),

          Text('Zapier — Campaign Automation',
              style: tt.bodySmall?.bold.withColor(const Color(0xFFFF4A00))),
          const SizedBox(height: 8),
          _StepTile(number: '1', text: 'Create a new Zap with your campaign data source (Google Sheets, Notion, Airtable, etc.)'),
          _StepTile(number: '2', text: 'For the action, choose "Webhooks by Zapier" → "POST"'),
          _StepTile(number: '3', text: 'Set URL to: https://anis-crm-api-production.up.railway.app/api/webhooks/zapier/campaign'),
          _StepTile(number: '4', text: 'Add header: X-API-Key with the same API key'),
          _StepTile(number: '5', text: 'Map fields: name (required), description, market, budget, status, start_date, end_date'),
          _StepTile(number: '6', text: 'To update an existing campaign, include its "id" field in the payload'),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: isDark ? 0.08 : 0.04),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.15)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded,
                  size: 16, color: AppColors.info),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'For local development, use a tunnel like ngrok to expose your server: ngrok http 3000. Use the generated HTTPS URL as your webhook callback.',
                  style: tt.labelSmall?.copyWith(fontSize: 11.5, color: cs.onSurfaceVariant, height: 1.4),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.number, required this.text});
  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(number,
              style: tt.labelSmall?.bold.withColor(cs.primary)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: tt.labelMedium?.withColor(cs.onSurface).copyWith(height: 1.4)),
        ),
      ]),
    );
  }
}

// =============================================================================
// INFO ROW (label + value with copy button)
// =============================================================================

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.helperText,
    this.copyable = false,
  });
  final String label;
  final String value;
  final String? helperText;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: tt.labelMedium?.semiBold.withColor(cs.onSurface)),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        child: Row(children: [
          Expanded(
            child: Text(value,
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 12.5, color: cs.onSurface)),
          ),
          if (copyable)
            IconButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Copied: $value'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm)),
                  margin: const EdgeInsets.all(AppSpacing.md),
                ));
              },
              icon: Icon(Icons.copy_rounded, size: 15, color: cs.primary),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
              tooltip: 'Copy',
            ),
        ]),
      ),
      if (helperText != null) ...[
        const SizedBox(height: 4),
        Text(helperText!,
            style: tt.labelSmall?.withColor(cs.onSurfaceVariant).copyWith(height: 1.4)),
      ],
    ]);
  }
}
