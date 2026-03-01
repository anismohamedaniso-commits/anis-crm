import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:anis_crm/theme.dart';
import 'package:anis_crm/state/app_state.dart';
import 'package:anis_crm/services/email_campaign_service.dart';
import 'package:anis_crm/env_config.dart';
import 'package:http/http.dart' as http;
import 'package:anis_crm/openai/openai_config.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// =============================================================================
// SETTINGS PAGE
// =============================================================================

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _PageHeader(),
        const SizedBox(height: AppSpacing.lg),

        // APPEARANCE
        _SettingsSection(
          icon: Icons.palette_outlined,
          title: 'Appearance',
          description: 'Customize the look and feel of your workspace.',
          children: [
            _ToggleTile(
              icon: Icons.dark_mode_outlined,
              label: 'Dark mode',
              helper: 'Switch to a dark color theme for low-light environments.',
              value: context.watch<AppState>().darkMode,
              onChanged: (v) => context.read<AppState>().setDarkMode(v),
            ),
            _ToggleTile(
              icon: Icons.view_compact_outlined,
              label: 'Compact layout',
              helper: 'Reduce spacing to fit more information on screen.',
              value: context.watch<AppState>().compactLayout,
              onChanged: (v) => context.read<AppState>().setCompactLayout(v),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // ── AI COMMAND CENTER ──
        const _AiCommandCenter(),
        const SizedBox(height: AppSpacing.md),

        // CHANNELS
        _SettingsSection(
          icon: Icons.hub_outlined,
          title: 'Channels',
          description: 'Choose which channels can send leads into your CRM.',
          children: [
            _ChannelTile(
              icon: Icons.chat_rounded,
              iconColor: const Color(0xFF25D366),
              label: 'WhatsApp',
              channelId: 'whatsapp',
              connected: context.watch<AppState>().whatsAppConnected,
              onChanged: (v) {
                context.read<AppState>().setWhatsAppConnected(v);
                _showChannelSnackbar(context, 'WhatsApp', v);
              },
            ),
            _ChannelTile(
              icon: Icons.camera_alt_rounded,
              iconColor: const Color(0xFFE1306C),
              label: 'Instagram',
              channelId: 'instagram',
              connected: context.watch<AppState>().instagramConnected,
              onChanged: (v) {
                context.read<AppState>().setInstagramConnected(v);
                _showChannelSnackbar(context, 'Instagram', v);
              },
            ),
            _ChannelTile(
              icon: Icons.facebook_rounded,
              iconColor: const Color(0xFF1877F2),
              label: 'Facebook',
              channelId: 'facebook',
              connected: context.watch<AppState>().facebookConnected,
              onChanged: (v) {
                context.read<AppState>().setFacebookConnected(v);
                _showChannelSnackbar(context, 'Facebook', v);
              },
            ),
            _ChannelTile(
              icon: Icons.email_outlined,
              iconColor: AppColors.info,
              label: 'Email',
              channelId: 'email',
              connected: context.watch<AppState>().emailChannelEnabled,
              onChanged: (v) {
                context.read<AppState>().setEmailChannelEnabled(v);
                _showChannelSnackbar(context, 'Email', v);
              },
            ),
            _ChannelTile(
              icon: Icons.language_rounded,
              iconColor: AppColors.accent,
              label: 'Website forms',
              channelId: 'web',
              connected: context.watch<AppState>().webFormsEnabled,
              onChanged: (v) {
                context.read<AppState>().setWebFormsEnabled(v);
                _showChannelSnackbar(context, 'Website forms', v);
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // NOTIFICATIONS
        _SettingsSection(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          description: 'Manage how you receive alerts and updates.',
          children: [
            _ToggleTile(
              icon: Icons.notifications_active_outlined,
              label: 'Desktop notifications',
              helper: 'Receive alerts for new leads and follow-ups.',
              value: context.watch<AppState>().notificationsEnabled,
              onChanged: (v) => context.read<AppState>().setNotificationsEnabled(v),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // ABOUT
        _SettingsSection(
          icon: Icons.info_outline_rounded,
          title: 'About',
          children: [
            _AboutRow(label: 'App', value: 'ANIS CRM'),
            _AboutRow(label: 'Version', value: '1.0.0'),
            _AboutRow(label: 'Engine', value: 'Flutter Web'),
            _AboutRow(label: 'Backend', value: 'FastAPI + Zoho SMTP'),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // DANGER ZONE
        _DangerZone(),
      ]),
    );
  }

  static void _showChannelSnackbar(BuildContext context, String channel, bool enabled) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(enabled ? Icons.check_circle_rounded : Icons.remove_circle_outline,
            size: 18, color: Colors.white),
        const SizedBox(width: 10),
        Text('$channel ${enabled ? "connected" : "disconnected"}'),
      ]),
      behavior: SnackBarBehavior.floating,
      backgroundColor: enabled ? AppColors.success : AppColors.neutralDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      margin: const EdgeInsets.all(AppSpacing.md),
      duration: const Duration(seconds: 2),
    ));
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
    return Row(children: [
      Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [cs.primary, cs.primary.withValues(alpha: 0.75)],
          ),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: const Icon(Icons.settings_rounded, color: Colors.white, size: 20),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Settings',
            style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: cs.onSurface)),
        const SizedBox(height: 2),
        Text('Customize your CRM experience',
            style: Theme.of(context).textTheme.bodySmall?.withColor(cs.onSurfaceVariant)),
      ])),
    ]);
  }
}

// =============================================================================
// SETTINGS SECTION CARD
// =============================================================================

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.icon, required this.title, this.description, required this.children});
  final IconData icon;
  final String title;
  final String? description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outline.withValues(alpha: isDark ? 0.15 : 0.08)),
        boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: isDark ? 0.08 : 0.03),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Icon(icon, size: 16, color: cs.primary),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5, fontWeight: FontWeight.w700, color: cs.onSurface)),
              if (description != null) ...[
                const SizedBox(height: 2),
                Text(description!, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11.5, color: cs.onSurfaceVariant)),
              ],
            ])),
          ]),
        ),
        const SizedBox(height: 8),
        // Divider below header
        Divider(height: 1, color: cs.outline.withValues(alpha: isDark ? 0.1 : 0.06)),
        // Children
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(children: children),
        ),
      ]),
    );
  }
}

// =============================================================================
// TOGGLE TILE
// =============================================================================

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({required this.icon, required this.label, this.helper, required this.value, required this.onChanged});
  final IconData icon;
  final String label;
  final String? helper;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon, size: 18, color: value ? cs.primary : cs.onSurfaceVariant.withValues(alpha: 0.55)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600,
              color: cs.onSurface)),
          if (helper != null) ...[
            const SizedBox(height: 2),
            Text(helper!, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11.5, color: cs.onSurfaceVariant, height: 1.3)),
          ],
        ])),
        const SizedBox(width: 12),
        Switch.adaptive(value: value, onChanged: onChanged),
      ]),
    );
  }
}

// =============================================================================
// CHANNEL TILE
// =============================================================================

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({required this.icon, required this.iconColor, required this.label,
    required this.connected, required this.onChanged, this.channelId});
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? channelId;
  final bool connected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child: Icon(icon, size: 17, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600, color: cs.onSurface)),
          const SizedBox(height: 2),
          Row(children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: connected ? AppColors.success : cs.onSurfaceVariant.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(connected ? 'Connected' : 'Disconnected',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11,
                    color: connected ? AppColors.success : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500)),
            if (channelId != null) ...[
              const SizedBox(width: 10),
              ValueListenableBuilder<List<EmailCampaign>>(
                valueListenable: EmailCampaignService.instance.campaigns,
                builder: (context, campaigns, _) {
                  final count = campaigns.where((c) => c.channel == channelId).length;
                  if (count == 0) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text('$count campaign${count == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10, fontWeight: FontWeight.w600, color: iconColor)),
                  );
                },
              ),
            ],
          ]),
        ])),
        Switch.adaptive(value: connected, onChanged: onChanged),
      ]),
    );
  }
}

// =============================================================================
// AI COMMAND CENTER — Full AI settings integration
// =============================================================================

class _AiCommandCenter extends StatelessWidget {
  const _AiCommandCenter();

  @override
  Widget build(BuildContext context) {
    return Column(children: const [
      _AiStatusHero(),
      SizedBox(height: AppSpacing.md),
      _AiProviderConfig(),
      SizedBox(height: AppSpacing.md),
      _AiFeatureControls(),
      SizedBox(height: AppSpacing.md),
      _AiBehaviorTuning(),
      SizedBox(height: AppSpacing.md),
      _AiAdvancedFeatures(),
    ]);
  }
}

// ─── AI STATUS HERO ─────────────────────────────────────────────────────────

class _AiStatusHero extends StatelessWidget {
  const _AiStatusHero();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final app = context.watch<AppState>();
    final connected = app.aiConnected;

    // Count enabled features
    int enabledCount = 0;
    if (app.aiInsightsEnabled) enabledCount++;
    if (app.aiScoringEnabled) enabledCount++;
    if (app.aiPrioritiesEnabled) enabledCount++;
    if (app.aiConversationEnabled) enabledCount++;
    if (app.aiCallSummaryEnabled) enabledCount++;
    if (app.aiAutoSuggest) enabledCount++;
    if (app.aiDailyDigest) enabledCount++;
    if (app.aiTemplatesEnabled) enabledCount++;
    const totalFeatures = 8;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: connected
              ? [cs.primary.withValues(alpha: isDark ? 0.15 : 0.06),
                 cs.primary.withValues(alpha: isDark ? 0.05 : 0.02)]
              : [cs.surfaceContainerHighest.withValues(alpha: 0.5),
                 cs.surface],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: connected
            ? cs.primary.withValues(alpha: 0.2)
            : cs.outline.withValues(alpha: isDark ? 0.15 : 0.08)),
        boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: isDark ? 0.08 : 0.03),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            // AI Icon with animated glow
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: connected
                      ? [cs.primary, cs.primary.withValues(alpha: 0.7)]
                      : [cs.onSurfaceVariant.withValues(alpha: 0.3), cs.onSurfaceVariant.withValues(alpha: 0.15)],
                ),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                boxShadow: connected ? [
                  BoxShadow(color: cs.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
                ] : null,
              ),
              child: Icon(
                connected ? Icons.auto_awesome_rounded : Icons.auto_awesome_outlined,
                color: Colors.white, size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('AI Command Center',
                  style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: cs.onSurface)),
              const SizedBox(height: 4),
              Text('Configure and manage all AI-powered features',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(fontSize: 12.5, color: cs.onSurfaceVariant)),
            ])),
          ]),
          const SizedBox(height: 20),
          // Status pills
          Wrap(spacing: 10, runSpacing: 8, children: [
            _StatusPill(
              icon: connected ? Icons.check_circle_rounded : Icons.cancel_outlined,
              label: connected ? 'Connected' : 'Disconnected',
              color: connected ? AppColors.success : AppColors.danger,
            ),
            _StatusPill(
              icon: Icons.smart_toy_outlined,
              label: _providerLabel(app.aiProvider),
              color: cs.primary,
            ),
            _StatusPill(
              icon: Icons.memory_rounded,
              label: app.aiDefaultModel,
              color: AppColors.info,
            ),
            _StatusPill(
              icon: Icons.toggle_on_outlined,
              label: '$enabledCount / $totalFeatures features',
              color: enabledCount > 0 ? AppColors.success : cs.onSurfaceVariant,
            ),
          ]),
        ]),
      ),
    );
  }

  static String _providerLabel(String provider) {
    switch (provider) {
      case 'ollama': return 'Ollama (Local)';
      case 'openai': return 'OpenAI';
      case 'custom': return 'Custom API';
      default: return provider;
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelSmall?.semiBold.withColor(color)),
      ]),
    );
  }
}

// ─── AI PROVIDER CONFIGURATION ──────────────────────────────────────────────

class _AiProviderConfig extends StatefulWidget {
  const _AiProviderConfig();
  @override
  State<_AiProviderConfig> createState() => _AiProviderConfigState();
}

class _AiProviderConfigState extends State<_AiProviderConfig> {
  bool _connecting = false;
  bool _loadingModels = false;
  List<String> _availableModels = [];
  late TextEditingController _endpointCtrl;
  late TextEditingController _customEndpointCtrl;
  late TextEditingController _customApiKeyCtrl;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _endpointCtrl = TextEditingController(text: app.aiOllamaEndpoint);
    _customEndpointCtrl = TextEditingController(text: app.aiCustomEndpoint);
    _customApiKeyCtrl = TextEditingController(text: app.aiCustomApiKey);
  }

  @override
  void dispose() {
    _endpointCtrl.dispose();
    _customEndpointCtrl.dispose();
    _customApiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() => _connecting = true);
    final connected = await _testAiConnection();
    if (mounted) {
      context.read<AppState>().setAiConnected(connected);
      setState(() => _connecting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          Icon(connected ? Icons.check_circle_rounded : Icons.error_outline,
              size: 18, color: Colors.white),
          const SizedBox(width: 10),
          Text(connected ? 'AI provider connected successfully!' : 'Connection failed — check your configuration'),
        ]),
        behavior: SnackBarBehavior.floating,
        backgroundColor: connected ? AppColors.success : AppColors.danger,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        margin: const EdgeInsets.all(AppSpacing.md),
        duration: const Duration(seconds: 3),
      ));
      if (connected) _fetchModels();
    }
  }

  Future<void> _fetchModels() async {
    setState(() => _loadingModels = true);
    try {
      final app = context.read<AppState>();
      final endpoint = app.aiProvider == 'ollama' ? app.aiOllamaEndpoint : EnvConfig.apiBaseUrl;
      final resp = await http.get(Uri.parse('$endpoint/api/tags')).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final models = (data['models'] as List?)
            ?.map((m) => (m['name'] ?? '').toString())
            .where((n) => n.isNotEmpty)
            .toList() ?? [];
        if (mounted) setState(() => _availableModels = models);
      }
    } catch (e) {
      debugPrint('Failed to fetch models: $e');
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final app = context.watch<AppState>();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outline.withValues(alpha: isDark ? 0.15 : 0.08)),
        boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: isDark ? 0.08 : 0.03),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Icon(Icons.dns_outlined, size: 16, color: cs.primary),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('AI Provider', style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5, fontWeight: FontWeight.w700, color: cs.onSurface)),
              const SizedBox(height: 2),
              Text('Configure your AI backend and model preferences.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11.5, color: cs.onSurfaceVariant)),
            ])),
          ]),
        ),
        const SizedBox(height: 8),
        Divider(height: 1, color: cs.outline.withValues(alpha: isDark ? 0.1 : 0.06)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Provider selector
            Text('Provider', style: Theme.of(context).textTheme.labelMedium?.semiBold.withColor(cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(children: [
              _ProviderChip(label: 'Ollama', icon: Icons.computer_rounded,
                  selected: app.aiProvider == 'ollama',
                  onTap: () => context.read<AppState>().setAiProvider('ollama')),
              const SizedBox(width: 8),
              _ProviderChip(label: 'OpenAI', icon: Icons.cloud_outlined,
                  selected: app.aiProvider == 'openai',
                  onTap: () => context.read<AppState>().setAiProvider('openai')),
              const SizedBox(width: 8),
              _ProviderChip(label: 'Custom', icon: Icons.api_rounded,
                  selected: app.aiProvider == 'custom',
                  onTap: () => context.read<AppState>().setAiProvider('custom')),
            ]),
            const SizedBox(height: 16),

            // Provider-specific config
            if (app.aiProvider == 'ollama') ...[
              _ConfigTextField(
                label: 'Ollama Endpoint',
                hint: 'http://localhost:11434',
                controller: _endpointCtrl,
                onSubmitted: (v) => context.read<AppState>().setAiOllamaEndpoint(v),
              ),
            ] else if (app.aiProvider == 'openai') ...[
              _ConfigInfoRow(
                icon: Icons.info_outline,
                text: 'OpenAI is configured via --dart-define build flags (OPENAI_PROXY_API_KEY, OPENAI_PROXY_ENDPOINT).',
              ),
            ] else if (app.aiProvider == 'custom') ...[
              _ConfigTextField(
                label: 'API Endpoint',
                hint: 'https://api.example.com/v1/chat/completions',
                controller: _customEndpointCtrl,
                onSubmitted: (v) => context.read<AppState>().setAiCustomEndpoint(v),
              ),
              const SizedBox(height: 10),
              _ConfigTextField(
                label: 'API Key',
                hint: 'sk-...',
                controller: _customApiKeyCtrl,
                obscure: true,
                onSubmitted: (v) => context.read<AppState>().setAiCustomApiKey(v),
              ),
            ],
            const SizedBox(height: 16),

            // Model selector
            Text('Default Model', style: Theme.of(context).textTheme.labelMedium?.semiBold.withColor(cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.5 : 0.4),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _availableModels.contains(app.aiDefaultModel) ? app.aiDefaultModel : null,
                      hint: Text(app.aiDefaultModel, style: Theme.of(context).textTheme.bodySmall?.withColor(cs.onSurface)),
                      isExpanded: true,
                      icon: Icon(Icons.unfold_more_rounded, size: 18, color: cs.onSurfaceVariant),
                      style: Theme.of(context).textTheme.bodySmall?.withColor(cs.onSurface),
                      dropdownColor: cs.surface,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      items: _availableModels.map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(m, style: Theme.of(context).textTheme.bodySmall),
                      )).toList(),
                      onChanged: (v) { if (v != null) context.read<AppState>().setAiDefaultModel(v); },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SmallIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh models',
                loading: _loadingModels,
                onTap: _fetchModels,
              ),
            ]),
            const SizedBox(height: 20),

            // Connection actions
            Row(children: [
              Expanded(
                child: _connecting
                    ? Container(
                        height: 40,
                        alignment: Alignment.center,
                        child: SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)),
                      )
                    : FilledButton.icon(
                        onPressed: _testConnection,
                        icon: Icon(app.aiConnected ? Icons.refresh_rounded : Icons.power_rounded, size: 16),
                        label: Text(app.aiConnected ? 'Re-test Connection' : 'Test Connection',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                        ),
                      ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _ProviderChip extends StatelessWidget {
  const _ProviderChip({required this.label, required this.icon, required this.selected, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withValues(alpha: isDark ? 0.15 : 0.08)
                : cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.3 : 0.4),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: selected ? cs.primary.withValues(alpha: 0.4) : cs.outline.withValues(alpha: 0.12),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20, color: selected ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 11.5, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? cs.primary : cs.onSurfaceVariant,
            )),
          ]),
        ),
      ),
    );
  }
}

class _ConfigTextField extends StatelessWidget {
  const _ConfigTextField({required this.label, required this.hint,
    required this.controller, this.obscure = false, required this.onSubmitted});
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscure;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11.5, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant)),
      const SizedBox(height: 5),
      TextField(
        controller: controller,
        obscureText: obscure,
        style: Theme.of(context).textTheme.bodySmall?.withColor(cs.onSurface),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        onSubmitted: onSubmitted,
        onEditingComplete: () => onSubmitted(controller.text),
      ),
    ]);
  }
}

class _ConfigInfoRow extends StatelessWidget {
  const _ConfigInfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.15)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 15, color: AppColors.info),
        const SizedBox(width: 8),
        Expanded(child: Text(text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11.5, color: cs.onSurfaceVariant, height: 1.4))),
      ]),
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  const _SmallIconButton({required this.icon, required this.tooltip,
    this.loading = false, required this.onTap});
  final IconData icon;
  final String tooltip;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
          ),
          child: loading
              ? Center(child: SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)))
              : Icon(icon, size: 18, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

// ─── AI FEATURE CONTROLS ────────────────────────────────────────────────────

class _AiFeatureControls extends StatelessWidget {
  const _AiFeatureControls();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final app = context.watch<AppState>();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outline.withValues(alpha: isDark ? 0.15 : 0.08)),
        boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: isDark ? 0.08 : 0.03),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Icon(Icons.auto_awesome_outlined, size: 16, color: cs.primary),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('AI Features', style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5, fontWeight: FontWeight.w700, color: cs.onSurface)),
              const SizedBox(height: 2),
              Text('Toggle individual AI capabilities on or off.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11.5, color: cs.onSurfaceVariant)),
            ])),
            // Master toggle
            _AiMasterToggle(),
          ]),
        ),
        const SizedBox(height: 8),
        Divider(height: 1, color: cs.outline.withValues(alpha: isDark ? 0.1 : 0.06)),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(children: [
            _AiFeatureCard(
              icon: Icons.insights_rounded,
              iconColor: const Color(0xFF7C3AED),
              title: 'AI Insights',
              description: 'Analyze lead intent, pipeline health, and surface actionable insights from your data.',
              enabled: app.aiInsightsEnabled,
              onChanged: (v) => context.read<AppState>().setAiInsightsEnabled(v),
            ),
            _AiFeatureCard(
              icon: Icons.star_rounded,
              iconColor: const Color(0xFFEAB308),
              title: 'AI Lead Scoring',
              description: 'Automatically score and rank leads based on engagement signals, recency, and behavior.',
              enabled: app.aiScoringEnabled,
              onChanged: (v) => context.read<AppState>().setAiScoringEnabled(v),
            ),
            _AiFeatureCard(
              icon: Icons.lightbulb_rounded,
              iconColor: const Color(0xFFF97316),
              title: 'Smart Priorities',
              description: 'Get AI-generated suggestions for which leads to contact next and what action to take.',
              enabled: app.aiPrioritiesEnabled,
              onChanged: (v) => context.read<AppState>().setAiPrioritiesEnabled(v),
            ),
            _AiFeatureCard(
              icon: Icons.chat_bubble_rounded,
              iconColor: const Color(0xFF06B6D4),
              title: 'Conversation AI',
              description: 'Draft replies, summarize conversations, and get real-time messaging assistance.',
              enabled: app.aiConversationEnabled,
              onChanged: (v) => context.read<AppState>().setAiConversationEnabled(v),
            ),
            _AiFeatureCard(
              icon: Icons.phone_in_talk_rounded,
              iconColor: const Color(0xFF10B981),
              title: 'Call Summaries',
              description: 'Automatically summarize call notes and extract action items after each conversation.',
              enabled: app.aiCallSummaryEnabled,
              onChanged: (v) => context.read<AppState>().setAiCallSummaryEnabled(v),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _AiMasterToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final anyEnabled = app.aiInsightsEnabled || app.aiScoringEnabled ||
        app.aiPrioritiesEnabled || app.aiConversationEnabled || app.aiCallSummaryEnabled;

    return TextButton.icon(
      onPressed: () {
        final newValue = !anyEnabled;
        final state = context.read<AppState>();
        state.setAiInsightsEnabled(newValue);
        state.setAiScoringEnabled(newValue);
        state.setAiPrioritiesEnabled(newValue);
        state.setAiConversationEnabled(newValue);
        state.setAiCallSummaryEnabled(newValue);
      },
      icon: Icon(anyEnabled ? Icons.toggle_on_rounded : Icons.toggle_off_outlined, size: 18),
      label: Text(anyEnabled ? 'All On' : 'All Off',
          style: Theme.of(context).textTheme.labelSmall?.semiBold),
    );
  }
}

class _AiFeatureCard extends StatelessWidget {
  const _AiFeatureCard({
    required this.icon, required this.iconColor, required this.title,
    required this.description, required this.enabled, required this.onChanged,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: enabled
              ? iconColor.withValues(alpha: isDark ? 0.08 : 0.04)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: enabled
                ? iconColor.withValues(alpha: isDark ? 0.2 : 0.12)
                : cs.outline.withValues(alpha: isDark ? 0.06 : 0.04),
          ),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: enabled ? 0.12 : 0.06),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Icon(icon, size: 18,
                color: enabled ? iconColor : iconColor.withValues(alpha: 0.4)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600,
                color: enabled ? cs.onSurface : cs.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text(description, style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 11, color: cs.onSurfaceVariant.withValues(alpha: 0.8), height: 1.3)),
          ])),
          const SizedBox(width: 8),
          Switch.adaptive(value: enabled, onChanged: onChanged),
        ]),
      ),
    );
  }
}

// ─── AI BEHAVIOR TUNING ─────────────────────────────────────────────────────

class _AiBehaviorTuning extends StatelessWidget {
  const _AiBehaviorTuning();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final app = context.watch<AppState>();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outline.withValues(alpha: isDark ? 0.15 : 0.08)),
        boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: isDark ? 0.08 : 0.03),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Icon(Icons.tune_rounded, size: 16, color: cs.primary),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('AI Behavior', style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5, fontWeight: FontWeight.w700, color: cs.onSurface)),
              const SizedBox(height: 2),
              Text('Fine-tune how the AI responds and processes data.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11.5, color: cs.onSurfaceVariant)),
            ])),
          ]),
        ),
        const SizedBox(height: 8),
        Divider(height: 1, color: cs.outline.withValues(alpha: isDark ? 0.1 : 0.06)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Temperature slider
            _SliderSetting(
              icon: Icons.thermostat_rounded,
              label: 'Temperature',
              description: _temperatureDescription(app.aiTemperature),
              value: app.aiTemperature,
              min: 0.0, max: 1.0, divisions: 10,
              valueLabel: app.aiTemperature.toStringAsFixed(1),
              onChanged: (v) => context.read<AppState>().setAiTemperature(double.parse(v.toStringAsFixed(1))),
            ),
            const SizedBox(height: 16),

            // Max tokens slider
            _SliderSetting(
              icon: Icons.data_array_rounded,
              label: 'Max Response Length',
              description: '${app.aiMaxTokens} tokens (~${(app.aiMaxTokens * 0.75).round()} words)',
              value: app.aiMaxTokens.toDouble(),
              min: 256, max: 8192, divisions: 31,
              valueLabel: '${app.aiMaxTokens}',
              onChanged: (v) => context.read<AppState>().setAiMaxTokens(v.round()),
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: cs.outline.withValues(alpha: isDark ? 0.08 : 0.05)),
            const SizedBox(height: 12),

            // Streaming toggle
            _ToggleTile(
              icon: Icons.stream_rounded,
              label: 'Streaming responses',
              helper: 'Show AI responses as they are generated for faster feedback.',
              value: app.aiStreamingEnabled,
              onChanged: (v) => context.read<AppState>().setAiStreamingEnabled(v),
            ),
            _ToggleTile(
              icon: Icons.alt_route_rounded,
              label: 'Smart routing',
              helper: 'Automatically pick the best model for each task based on complexity.',
              value: app.aiSmartRouting,
              onChanged: (v) => context.read<AppState>().setAiSmartRouting(v),
            ),
          ]),
        ),
      ]),
    );
  }

  static String _temperatureDescription(double t) {
    if (t <= 0.2) return 'Very precise and deterministic — best for data extraction.';
    if (t <= 0.5) return 'Balanced and focused — good for most CRM tasks.';
    if (t <= 0.7) return 'Moderately creative — natural-sounding responses.';
    return 'Highly creative — more varied and exploratory output.';
  }
}

class _SliderSetting extends StatelessWidget {
  const _SliderSetting({
    required this.icon, required this.label, required this.description,
    required this.value, required this.min, required this.max,
    required this.divisions, required this.valueLabel, required this.onChanged,
  });
  final IconData icon;
  final String label;
  final String description;
  final double value;
  final double min, max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 16, color: cs.primary),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.semiBold.withColor(cs.onSurface)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(valueLabel, style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 11.5, fontWeight: FontWeight.w700, color: cs.primary)),
        ),
      ]),
      const SizedBox(height: 4),
      Text(description, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11, color: cs.onSurfaceVariant, height: 1.3)),
      SliderTheme(
        data: SliderThemeData(
          trackHeight: 4,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          activeTrackColor: cs.primary,
          inactiveTrackColor: cs.outline.withValues(alpha: 0.15),
          thumbColor: cs.primary,
          overlayColor: cs.primary.withValues(alpha: 0.1),
        ),
        child: Slider(
          value: value, min: min, max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ),
    ]);
  }
}

// ─── AI ADVANCED FEATURES ───────────────────────────────────────────────────

class _AiAdvancedFeatures extends StatelessWidget {
  const _AiAdvancedFeatures();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final app = context.watch<AppState>();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outline.withValues(alpha: isDark ? 0.15 : 0.08)),
        boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: isDark ? 0.08 : 0.03),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Icon(Icons.science_outlined, size: 16, color: cs.primary),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Advanced AI', style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5, fontWeight: FontWeight.w700, color: cs.onSurface)),
              const SizedBox(height: 2),
              Text('Experimental and automation features.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11.5, color: cs.onSurfaceVariant)),
            ])),
          ]),
        ),
        const SizedBox(height: 8),
        Divider(height: 1, color: cs.outline.withValues(alpha: isDark ? 0.1 : 0.06)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(children: [
            _ToggleTile(
              icon: Icons.edit_note_rounded,
              label: 'Auto-suggest replies',
              helper: 'Automatically draft reply suggestions when viewing a conversation.',
              value: app.aiAutoSuggest,
              onChanged: (v) => context.read<AppState>().setAiAutoSuggest(v),
            ),
            _ToggleTile(
              icon: Icons.article_outlined,
              label: 'AI response templates',
              helper: 'Use AI to generate context-aware objection handling and follow-up templates.',
              value: app.aiTemplatesEnabled,
              onChanged: (v) => context.read<AppState>().setAiTemplatesEnabled(v),
            ),
            _ToggleTile(
              icon: Icons.summarize_outlined,
              label: 'Daily AI digest',
              helper: 'Receive a daily summary of pipeline changes, hot leads, and suggested actions.',
              value: app.aiDailyDigest,
              onChanged: (v) => context.read<AppState>().setAiDailyDigest(v),
            ),
          ]),
        ),
      ]),
    );
  }
}

// =============================================================================
// OLD AI PROVIDER CARD — replaced by AI Command Center above
// =============================================================================

/// Test connectivity to the configured AI provider.
Future<bool> _testAiConnection() async {
  // Try OpenAI first
  try {
    const openai = OpenAIClient();
    if (openai.isConfigured) {
      final ok = await openai.connectivityProbe();
      if (ok) return true;
    }
  } catch (e) {
    debugPrint('OpenAI probe error: $e');
  }
  // Fallback: Ollama local
  try {
    final uri = Uri.parse('http://localhost:11434/api/chat');
    final resp = await http.post(uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': 'qwen2.5:7b', 'format': 'json', 'stream': false,
        'messages': [{'role': 'user', 'content': 'Return {"connected": true}'}],
      }),
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(utf8.decode(resp.bodyBytes));
      // /api/chat returns {"message": {"role": "assistant", "content": "..."}}
      if (data is Map && data['message'] is Map) {
        final content = (data['message'] as Map)['content'];
        if (content is String) {
          try {
            final nested = jsonDecode(content);
            if (nested is Map && nested['connected'] == true) return true;
          } catch (_) {}
        }
      }
      if (data is Map && data['connected'] == true) return true;
      if (data is Map && data['response'] is String) {
        try {
          final nested = jsonDecode(data['response'] as String);
          if (nested is Map && nested['connected'] == true) return true;
        } catch (_) {}
      }
    }
  } catch (e) {
    debugPrint('Ollama probe error: $e');
  }
  return false;
}

// =============================================================================
// ABOUT ROW
// =============================================================================

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(width: 90, child: Text(label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(fontSize: 12.5, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant))),
        Expanded(child: Text(value,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600, color: cs.onSurface))),
      ]),
    );
  }
}

// =============================================================================
// DANGER ZONE
// =============================================================================

class _DangerZone extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: isDark ? 0.06 : 0.03),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.danger.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Text('Danger Zone', style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.danger)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Reset all settings', style: Theme.of(context).textTheme.bodySmall?.semiBold.withColor(cs.onSurface)),
            const SizedBox(height: 2),
            Text('Restore all toggles and preferences to their defaults.',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11.5, color: cs.onSurfaceVariant)),
          ])),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () => _confirmReset(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: BorderSide(color: AppColors.danger.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: Text('Reset', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ]),
      ]),
    );
  }

  void _confirmReset(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        icon: Container(width: 52, height: 52,
          decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.md)),
          child: const Icon(Icons.restart_alt_rounded, size: 26, color: AppColors.danger)),
        title: Text('Reset Settings', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Text(
          'This will reset all toggles and preferences to their default values. Your leads and campaigns will not be affected.',
          style: Theme.of(context).textTheme.bodySmall?.withColor(cs.onSurfaceVariant).copyWith(height: 1.5),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset All'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final state = context.read<AppState>();
      state.setDarkMode(false);
      state.setCompactLayout(false);
      state.setNotificationsEnabled(false);
      state.setAiInsightsEnabled(false);
      state.setAiScoringEnabled(false);
      state.setAiPrioritiesEnabled(false);
      state.setAiConversationEnabled(false);
      state.setAiCallSummaryEnabled(false);
      state.setAiStreamingEnabled(true);
      state.setAiSmartRouting(false);
      state.setAiAutoSuggest(false);
      state.setAiDailyDigest(false);
      state.setAiTemplatesEnabled(true);
      state.setAiTemperature(0.7);
      state.setAiMaxTokens(2048);
      state.setAiProvider('ollama');
      state.setAiDefaultModel('qwen2.5:7b');
      state.setAiOllamaEndpoint('http://localhost:11434');
      state.setAiCustomEndpoint('');
      state.setAiCustomApiKey('');
      state.setWhatsAppConnected(false);
      state.setInstagramConnected(false);
      state.setFacebookConnected(false);
      state.setEmailChannelEnabled(false);
      state.setWebFormsEnabled(false);
      state.setAiConnected(false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
          SizedBox(width: 10), Text('All settings reset to defaults'),
        ]),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        margin: const EdgeInsets.all(AppSpacing.md),
      ));
    }
  }
}
