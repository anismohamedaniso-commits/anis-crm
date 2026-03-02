import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:anis_crm/theme.dart';
import 'package:anis_crm/models/lead.dart';
import 'package:anis_crm/services/lead_service.dart';
import 'package:anis_crm/services/email_campaign_service.dart';
import 'package:provider/provider.dart';
import 'package:anis_crm/state/app_state.dart';

// =============================================================================
// CHANNEL DEFINITIONS
// =============================================================================

class _ChannelInfo {
  final String id, label;
  final IconData icon;
  final Color color;
  const _ChannelInfo(this.id, this.label, this.icon, this.color);
}

const _kChannels = <_ChannelInfo>[
  _ChannelInfo('email', 'Email', Icons.email_outlined, Color(0xFF2563EB)),
  _ChannelInfo('whatsapp', 'WhatsApp', Icons.chat_rounded, Color(0xFF25D366)),
  _ChannelInfo('instagram', 'Instagram', Icons.camera_alt_rounded, Color(0xFFE1306C)),
  _ChannelInfo('facebook', 'Facebook', Icons.facebook_rounded, Color(0xFF1877F2)),
  _ChannelInfo('web', 'Web Forms', Icons.language_rounded, Color(0xFF4A6FA5)),
];

_ChannelInfo _channelById(String id) =>
    _kChannels.firstWhere((c) => c.id == id, orElse: () => _kChannels.first);

// =============================================================================
// MAIN PAGE
// =============================================================================

class EmailMarketingPage extends StatefulWidget {
  const EmailMarketingPage({super.key});

  @override
  State<EmailMarketingPage> createState() => _EmailMarketingPageState();
}

class _EmailMarketingPageState extends State<EmailMarketingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _smtpConfig;
  bool _checkingConfig = true;
  bool _sendingTest = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    EmailCampaignService.instance.load();
    LeadService.instance.load();
    _checkConfig();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkConfig() async {
    final result = await EmailCampaignService.instance.checkSmtpConfig();
    if (mounted) setState(() { _smtpConfig = result; _checkingConfig = false; });
  }

  Future<void> _sendTestEmail() async {
    setState(() => _sendingTest = true);
    final result = await EmailCampaignService.instance.sendTestEmail();
    if (mounted) {
      setState(() => _sendingTest = false);
      final ok = result['ok'] == true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Test email sent to ${_smtpConfig?['smtp_user'] ?? 'your address'}!'
            : 'Failed: ${result['detail'] ?? result['error'] ?? 'Unknown error'}'),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        margin: const EdgeInsets.all(AppSpacing.md),
        duration: const Duration(seconds: 4),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageHeader(
            onNewCampaign: () => showDialog(
              context: context,
              builder: (_) => const _CampaignEditorDialog(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (!_checkingConfig)
            _SmtpBanner(
              config: _smtpConfig,
              sendingTest: _sendingTest,
              onSendTest: _sendTestEmail,
              onRefresh: _checkConfig,
            ),
          const SizedBox(height: AppSpacing.md),
          _StatsRow(),
          const SizedBox(height: AppSpacing.lg),
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: cs.outline.withValues(alpha: isDark ? 0.12 : 0.08),
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelStyle: tt.bodySmall?.semiBold,
              unselectedLabelStyle: tt.bodySmall?.medium,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.campaign_outlined, size: 16), SizedBox(width: 6), Text('Campaigns'),
                ])),
                Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.description_outlined, size: 16), SizedBox(width: 6), Text('Templates'),
                ])),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_CampaignsTab(), _TemplatesTab()],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PAGE HEADER
// =============================================================================

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.onNewCampaign});
  final VoidCallback onNewCampaign;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isNarrow = MediaQuery.of(context).size.width < 500;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [cs.primary, cs.primary.withValues(alpha: 0.75)],
                ),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.email_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Email Marketing',
                    style: GoogleFonts.plusJakartaSans(fontSize: isNarrow ? 18 : 22, fontWeight: FontWeight.w700, color: cs.onSurface)),
                if (!isNarrow) ...[
                  const SizedBox(height: 2),
                  Text('Create & send campaigns to your leads',
                      style: tt.bodySmall?.withColor(cs.onSurfaceVariant)),
                ],
              ]),
            ),
            if (!isNarrow)
              FilledButton.icon(
                onPressed: onNewCampaign,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New Campaign'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                ),
              ),
          ],
        ),
        if (isNarrow) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onNewCampaign,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New Campaign'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// STATS ROW
// =============================================================================

class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<EmailCampaign>>(
      valueListenable: EmailCampaignService.instance.campaigns,
      builder: (context, campaigns, _) {
        final drafts = campaigns.where((c) => c.status == CampaignStatus.draft).length;
        final sent = campaigns.where((c) => c.status == CampaignStatus.sent).length;
        final totalRecipients = campaigns.where((c) => c.status == CampaignStatus.sent)
            .fold<int>(0, (sum, c) => sum + c.recipientCount);
        return LayoutBuilder(builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 500;
          final children = [
            _StatCard(label: 'Total Campaigns', value: '${campaigns.length}',
                icon: Icons.campaign_outlined, color: AppColors.info),
            _StatCard(label: 'Drafts', value: '$drafts',
                icon: Icons.edit_note_outlined, color: AppColors.warning),
            _StatCard(label: 'Sent', value: '$sent',
                icon: Icons.check_circle_outline, color: AppColors.success),
            _StatCard(label: 'Emails Delivered', value: '$totalRecipients',
                icon: Icons.mark_email_read_outlined, color: Theme.of(context).colorScheme.primary),
          ];
          if (isNarrow) {
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: children.map((c) => SizedBox(
                width: (constraints.maxWidth - AppSpacing.sm) / 2,
                child: c,
              )).toList(),
            );
          }
          return Row(children: [
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(child: children[i]),
            ],
          ]);
        });
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});
  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outline.withValues(alpha: isDark ? 0.15 : 0.08)),
        boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: isDark ? 0.06 : 0.02), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.sm)),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, color: cs.onSurface)),
          const SizedBox(height: 2),
          Text(label, style: tt.labelSmall?.medium.withColor(cs.onSurfaceVariant),
              overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }
}

// =============================================================================
// SMTP BANNER
// =============================================================================

class _SmtpBanner extends StatelessWidget {
  const _SmtpBanner({required this.config, required this.sendingTest, required this.onSendTest, required this.onRefresh});
  final Map<String, dynamic>? config;
  final bool sendingTest;
  final VoidCallback onSendTest, onRefresh;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final configured = config?['configured'] == true;
    final hasError = config?.containsKey('error') ?? false;
    Color bgColor, fgColor;
    IconData icon;
    String message;
    if (hasError) {
      bgColor = AppColors.dangerBg; fgColor = AppColors.danger;
      icon = Icons.cloud_off_outlined; message = 'Cannot reach email server — make sure the backend is running.';
    } else if (!configured) {
      bgColor = AppColors.warningBg; fgColor = AppColors.warning;
      icon = Icons.warning_amber_rounded; message = 'SMTP not configured — set SMTP_PASS in server/.env and restart.';
    } else {
      bgColor = AppColors.successBg; fgColor = AppColors.success;
      icon = Icons.verified_outlined; message = 'Connected as ${config?['smtp_user'] ?? 'your email'}';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: fgColor.withValues(alpha: 0.25))),
      child: Row(children: [
        Icon(icon, size: 18, color: fgColor),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: tt.labelMedium?.copyWith(fontSize: 12.5, color: fgColor, fontWeight: FontWeight.w500))),
        if (configured) ...[
          SizedBox(height: 30, child: TextButton.icon(
            onPressed: sendingTest ? null : onSendTest,
            icon: sendingTest
                ? SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: fgColor))
                : Icon(Icons.send_outlined, size: 14, color: fgColor),
            label: Text('Send Test', style: TextStyle(fontSize: 12, color: fgColor)),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), minimumSize: Size.zero),
          )),
        ],
        SizedBox(width: 30, height: 30, child: IconButton(
          onPressed: onRefresh, icon: Icon(Icons.refresh_rounded, size: 16, color: fgColor),
          padding: EdgeInsets.zero, tooltip: 'Refresh status',
        )),
      ]),
    );
  }
}

// =============================================================================
// CAMPAIGNS TAB
// =============================================================================

class _CampaignsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<EmailCampaign>>(
      valueListenable: EmailCampaignService.instance.campaigns,
      builder: (context, campaigns, _) {
        if (campaigns.isEmpty) return _EmptyCampaigns();
        final sorted = [...campaigns]..sort((a, b) {
          const order = {CampaignStatus.draft: 0, CampaignStatus.scheduled: 1, CampaignStatus.sent: 2};
          final cmp = order[a.status]!.compareTo(order[b.status]!);
          if (cmp != 0) return cmp;
          return b.createdAt.compareTo(a.createdAt);
        });
        return ListView.separated(
          padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xl),
          itemCount: sorted.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, i) => _CampaignCard(campaign: sorted[i]),
        );
      },
    );
  }
}

class _EmptyCampaigns extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [cs.primary.withValues(alpha: 0.12), cs.primary.withValues(alpha: 0.04)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(Icons.mark_email_unread_outlined, size: 36, color: cs.primary),
      ),
      const SizedBox(height: AppSpacing.lg),
      Text('No campaigns yet', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface)),
      const SizedBox(height: 6),
      Text('Create your first email campaign to reach your leads.',
          style: tt.bodySmall?.withColor(cs.onSurfaceVariant), textAlign: TextAlign.center),
      const SizedBox(height: AppSpacing.lg),
      FilledButton.icon(
        onPressed: () => showDialog(context: context, builder: (_) => const _CampaignEditorDialog()),
        icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Create Campaign'),
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm))),
      ),
    ]));
  }
}

// =============================================================================
// CAMPAIGN CARD
// =============================================================================

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({required this.campaign});
  final EmailCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = _statusInfo(campaign.status, cs);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => showDialog(context: context, builder: (_) => _CampaignDetailDialog(campaign: campaign)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: cs.outline.withValues(alpha: isDark ? 0.15 : 0.08)),
            boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: isDark ? 0.08 : 0.03), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            Container(width: 4, height: 60, decoration: BoxDecoration(color: status.color, borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(campaign.name,
                    style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w700, color: cs.onSurface),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                _ChannelBadge(channel: campaign.channel),
                const SizedBox(width: 6),
                _StatusBadge(label: status.label, color: status.color, icon: status.icon),
              ]),
              const SizedBox(height: 4),
              Text(campaign.subject, style: tt.labelMedium?.copyWith(fontSize: 12.5, color: cs.onSurfaceVariant),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              Row(children: [
                _MetricPill(icon: Icons.people_outline, label: '${campaign.recipientCount} recipients'),
                const SizedBox(width: 8),
                _MetricPill(icon: Icons.calendar_today_outlined, label: _formatDate(campaign.createdAt)),
                if (campaign.sentAt != null) ...[
                  const SizedBox(width: 8),
                  _MetricPill(icon: Icons.send_rounded, label: _formatDate(campaign.sentAt!), highlighted: true),
                ],
                const Spacer(),
                if (campaign.status == CampaignStatus.draft) ...[
                  _QuickActionButton(icon: Icons.edit_outlined, tooltip: 'Edit',
                      onPressed: () => showDialog(context: context, builder: (_) => _CampaignEditorDialog(existingCampaign: campaign))),
                  const SizedBox(width: 2),
                  _QuickActionButton(icon: Icons.send_rounded, tooltip: 'Send Now', color: AppColors.success,
                      onPressed: () => _confirmAndSend(context)),
                ],
                _CampaignPopupMenu(campaign: campaign),
              ]),
            ])),
          ]),
        ),
      ),
    );
  }

  void _confirmAndSend(BuildContext context) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => _SendConfirmDialog(campaign: campaign));
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          const SizedBox(width: 12), Text('Sending "${campaign.name}"...'),
        ]),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        margin: const EdgeInsets.all(AppSpacing.md), duration: const Duration(seconds: 30),
      ));
      final result = await EmailCampaignService.instance.sendCampaign(campaign.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        final sent = result['sent'] ?? 0;
        final failed = result['failed'] ?? 0;
        final errors = (result['errors'] as List?)?.cast<String>() ?? [];
        Color bg; String msg;
        if (failed == 0 && sent > 0) { bg = AppColors.success; msg = 'Successfully sent to $sent recipient(s)!'; }
        else if (sent > 0) { bg = AppColors.warning; msg = 'Sent $sent, failed $failed. ${errors.isNotEmpty ? errors.first : ""}'; }
        else { bg = AppColors.danger; msg = 'Failed to send. ${errors.isNotEmpty ? errors.first : "Check SMTP config."}'; }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg), backgroundColor: bg, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          margin: const EdgeInsets.all(AppSpacing.md), duration: const Duration(seconds: 5),
        ));
      }
    }
  }

  _StatusDisplayInfo _statusInfo(CampaignStatus s, ColorScheme cs) => switch (s) {
    CampaignStatus.draft => _StatusDisplayInfo('Draft', Icons.edit_note_outlined, cs.onSurfaceVariant),
    CampaignStatus.scheduled => _StatusDisplayInfo('Scheduled', Icons.schedule_outlined, AppColors.info),
    CampaignStatus.sent => _StatusDisplayInfo('Sent', Icons.check_circle_rounded, AppColors.success),
  };

  String _formatDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }
}

class _StatusDisplayInfo {
  final String label;
  final IconData icon;
  final Color color;
  const _StatusDisplayInfo(this.label, this.icon, this.color);
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color, required this.icon});
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color), const SizedBox(width: 4),
        Text(label, style: tt.labelSmall?.semiBold.withColor(color)),
      ]),
    );
  }
}

class _ChannelBadge extends StatelessWidget {
  const _ChannelBadge({required this.channel});
  final String channel;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final ch = _channelById(channel);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: ch.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ch.icon, size: 11, color: ch.color),
        const SizedBox(width: 4),
        Text(ch.label, style: tt.labelSmall?.copyWith(fontSize: 10, fontWeight: FontWeight.w600, color: ch.color)),
      ]),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.icon, required this.label, this.highlighted = false});
  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final color = highlighted ? AppColors.success : cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (highlighted ? AppColors.success : cs.onSurfaceVariant).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color.withValues(alpha: 0.7)), const SizedBox(width: 5),
        Text(label, style: tt.labelSmall?.medium.withColor(color)),
      ]),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.icon, required this.tooltip, required this.onPressed, this.color});
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Tooltip(message: tooltip, child: InkWell(
      borderRadius: BorderRadius.circular(AppRadius.xs), onTap: onPressed,
      child: Padding(padding: const EdgeInsets.all(6), child: Icon(icon, size: 16, color: c)),
    ));
  }
}

// =============================================================================
// SEND CONFIRM DIALOG
// =============================================================================

class _SendConfirmDialog extends StatelessWidget {
  const _SendConfirmDialog({required this.campaign});
  final EmailCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      icon: Container(width: 56, height: 56,
        decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.md)),
        child: const Icon(Icons.send_rounded, size: 28, color: AppColors.success)),
      title: Text('Send Campaign', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('This will send real emails from your configured address to ${campaign.recipientCount} recipient(s).',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.5), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(AppRadius.sm)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _InfoRow(label: 'Campaign', value: campaign.name),
            const SizedBox(height: 8),
            _InfoRow(label: 'Subject', value: campaign.subject),
            const SizedBox(height: 8),
            _InfoRow(label: 'Channel', value: _channelById(campaign.channel).label),
            const SizedBox(height: 8),
            _InfoRow(label: 'Recipients', value: '${campaign.recipientCount}'),
          ]),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton.icon(onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.send_rounded, size: 16), label: const Text('Send Now'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.success,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)))),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(children: [
      SizedBox(width: 80, child: Text(label,
          style: tt.labelSmall?.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant))),
      Expanded(child: Text(value, style: tt.labelMedium?.copyWith(fontSize: 12.5, color: cs.onSurface, fontWeight: FontWeight.w500),
          maxLines: 1, overflow: TextOverflow.ellipsis)),
    ]);
  }
}

// =============================================================================
// CAMPAIGN POPUP MENU
// =============================================================================

class _CampaignPopupMenu extends StatelessWidget {
  const _CampaignPopupMenu({required this.campaign});
  final EmailCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz_rounded, size: 18, color: cs.onSurfaceVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'duplicate', child: Row(children: [
          Icon(Icons.copy_outlined, size: 16), SizedBox(width: 8), Text('Duplicate'),
        ])),
        const PopupMenuItem(value: 'delete', child: Row(children: [
          Icon(Icons.delete_outline, size: 16, color: Colors.red), SizedBox(width: 8),
          Text('Delete', style: TextStyle(color: Colors.red)),
        ])),
      ],
      onSelected: (v) async {
        switch (v) {
          case 'duplicate':
            await EmailCampaignService.instance.duplicateCampaign(campaign.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Campaign duplicated'), behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                margin: const EdgeInsets.all(AppSpacing.md)));
            }
            break;
          case 'delete':
            final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              title: const Text('Delete Campaign'),
              content: Text('Delete "${campaign.name}"? This cannot be undone.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
              ],
            ));
            if (ok == true) await EmailCampaignService.instance.deleteCampaign(campaign.id);
            break;
        }
      },
    );
  }
}

// =============================================================================
// CAMPAIGN DETAIL DIALOG
// =============================================================================

class _CampaignDetailDialog extends StatelessWidget {
  const _CampaignDetailDialog({required this.campaign});
  final EmailCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final leads = LeadService.instance.leads.value;
    final recipients = leads.where((l) => campaign.recipientLeadIds.contains(l.id)).toList();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 620),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            width: double.infinity, padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
            decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.04),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
            child: Row(children: [
              Container(width: 40, height: 40,
                decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: Icon(Icons.campaign_outlined, size: 20, color: cs.primary)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(campaign.name, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface))),
                  const SizedBox(width: 8),
                  _ChannelBadge(channel: campaign.channel),
                ]),
                const SizedBox(height: 2),
                Text(campaign.subject, style: tt.bodySmall?.withColor(cs.onSurfaceVariant)),
              ])),
              IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant)),
            ]),
          ),
          // Body
          Flexible(child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('EMAIL BODY', style: tt.labelSmall?.copyWith(fontSize: 10.5, fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant, letterSpacing: 0.8)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity, padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: cs.outline.withValues(alpha: 0.1))),
                child: SelectableText(campaign.body.isEmpty ? '(empty)' : campaign.body,
                    style: tt.bodySmall?.copyWith(height: 1.65, color: cs.onSurface)),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Text('RECIPIENTS', style: tt.labelSmall?.copyWith(fontSize: 10.5, fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant, letterSpacing: 0.8)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.pill)),
                  child: Text('${recipients.length}', style: tt.labelSmall?.bold.withColor(cs.primary)),
                ),
              ]),
              const SizedBox(height: 10),
              if (recipients.isEmpty)
                Text('No recipients selected.', style: tt.labelMedium?.copyWith(fontSize: 12.5, color: cs.onSurfaceVariant))
              else
                ...recipients.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    CircleAvatar(radius: 15, backgroundColor: cs.primary.withValues(alpha: 0.08),
                      child: Text(_initials(r.name), style: tt.labelSmall?.copyWith(fontSize: 10.5, fontWeight: FontWeight.w700, color: cs.primary))),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.name, style: tt.bodySmall?.semiBold),
                      if (r.email != null && r.email!.isNotEmpty)
                        Text(r.email!, style: tt.labelSmall?.copyWith(fontSize: 11.5, color: cs.onSurfaceVariant)),
                    ])),
                  ]),
                )),
            ]),
          )),
          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.1)))),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (campaign.status == CampaignStatus.draft) ...[
                OutlinedButton.icon(
                  onPressed: () { Navigator.pop(context);
                    showDialog(context: context, builder: (_) => _CampaignEditorDialog(existingCampaign: campaign)); },
                  icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)))),
                const SizedBox(width: 8),
              ],
              FilledButton(onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm))),
                child: const Text('Close')),
            ]),
          ),
        ]),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

// =============================================================================
// CAMPAIGN EDITOR DIALOG
// =============================================================================

class _CampaignEditorDialog extends StatefulWidget {
  const _CampaignEditorDialog({this.existingCampaign});
  final EmailCampaign? existingCampaign;

  @override
  State<_CampaignEditorDialog> createState() => _CampaignEditorDialogState();
}

class _CampaignEditorDialogState extends State<_CampaignEditorDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _subjectCtrl;
  late final TextEditingController _bodyCtrl;
  final Set<String> _selectedLeadIds = {};
  Set<LeadStatus> _statusFilter = {}; // empty = all statuses
  bool _saving = false;
  String _searchQuery = '';
  int _step = 0;
  String _selectedChannel = 'email';

  bool get _isEditing => widget.existingCampaign != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existingCampaign;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _subjectCtrl = TextEditingController(text: e?.subject ?? '');
    _bodyCtrl = TextEditingController(text: e?.body ?? '');
    if (e != null) {
      _selectedLeadIds.addAll(e.recipientLeadIds);
      _selectedChannel = e.channel;
    }
  }

  @override
  void dispose() { _nameCtrl.dispose(); _subjectCtrl.dispose(); _bodyCtrl.dispose(); super.dispose(); }

  void _applyTemplate(EmailTemplate tmpl) {
    setState(() { _subjectCtrl.text = tmpl.subject; _bodyCtrl.text = tmpl.body; });
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _subjectCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Name and subject are required'), behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        margin: const EdgeInsets.all(AppSpacing.md)));
      return;
    }
    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await EmailCampaignService.instance.updateCampaign(widget.existingCampaign!.copyWith(
          name: _nameCtrl.text.trim(), subject: _subjectCtrl.text.trim(),
          body: _bodyCtrl.text.trim(), recipientLeadIds: _selectedLeadIds.toList(),
          channel: _selectedChannel));
      } else {
        await EmailCampaignService.instance.createCampaign(
          name: _nameCtrl.text.trim(), subject: _subjectCtrl.text.trim(),
          body: _bodyCtrl.text.trim(), recipientLeadIds: _selectedLeadIds.toList(),
          channel: _selectedChannel);
      }
      if (mounted) Navigator.pop(context);
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isWide = MediaQuery.of(context).size.width > 800;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isWide ? 680 : 520, maxHeight: 700),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.1)))),
            child: Row(children: [
              Container(width: 38, height: 38,
                decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.xs)),
                child: Icon(_isEditing ? Icons.edit_rounded : Icons.add_circle_outline_rounded, size: 18, color: cs.primary)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_isEditing ? 'Edit Campaign' : 'New Campaign',
                    style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(_step == 0 ? 'Compose your email' : 'Select recipients',
                    style: tt.labelMedium?.withColor(cs.onSurfaceVariant)),
              ])),
              IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant)),
            ]),
          ),
          // Step indicator
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
            child: Row(children: [
              _StepDot(label: 'Compose', active: _step == 0, onTap: () => setState(() => _step = 0)),
              Expanded(child: Container(height: 1.5, margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: _step >= 1 ? cs.primary.withValues(alpha: 0.3) : cs.outline.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(1)))),
              _StepDot(label: 'Recipients', active: _step == 1, onTap: () => setState(() => _step = 1)),
            ]),
          ),
          // Content
          Flexible(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: _step == 0 ? _buildComposeStep(cs) : _buildRecipientsStep(cs),
          )),
          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.1)))),
            child: Row(children: [
              // Channel badge
              Builder(builder: (_) {
                final ch = _channelById(_selectedChannel);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: ch.color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppRadius.pill)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(ch.icon, size: 14, color: ch.color), const SizedBox(width: 5),
                    Text(ch.label, style: tt.labelMedium?.semiBold.withColor(ch.color)),
                  ]),
                );
              }),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.people_outline, size: 14, color: cs.primary), const SizedBox(width: 5),
                  Text('${_selectedLeadIds.length} recipient(s)',
                      style: tt.labelMedium?.semiBold.withColor(cs.primary)),
                ]),
              ),
              const Spacer(),
              if (_step == 0) ...[
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton(onPressed: () => setState(() => _step = 1),
                  style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm))),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Next'), SizedBox(width: 4), Icon(Icons.arrow_forward_rounded, size: 16),
                  ])),
              ] else ...[
                TextButton.icon(onPressed: () => setState(() => _step = 0),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16), label: const Text('Back')),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_rounded, size: 16),
                  label: Text(_isEditing ? 'Update' : 'Create'),
                  style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)))),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildComposeStep(ColorScheme cs) {
    final tt = Theme.of(context).textTheme;
    // Get enabled channels from settings
    final appState = context.watch<AppState>();
    final enabledChannels = _kChannels.where((ch) {
      switch (ch.id) {
        case 'email': return appState.emailChannelEnabled;
        case 'whatsapp': return appState.whatsAppConnected;
        case 'instagram': return appState.instagramConnected;
        case 'facebook': return appState.facebookConnected;
        case 'web': return appState.webFormsEnabled;
        default: return false;
      }
    }).toList();
    // Always include email as fallback
    if (enabledChannels.isEmpty || !enabledChannels.any((c) => c.id == _selectedChannel)) {
      if (enabledChannels.isEmpty) enabledChannels.add(_kChannels.first);
      _selectedChannel = enabledChannels.first.id;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      // Channel selector
      Text('CHANNEL', style: tt.labelSmall?.copyWith(fontSize: 10.5, fontWeight: FontWeight.w700,
          color: cs.onSurfaceVariant, letterSpacing: 0.6)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: enabledChannels.map((ch) {
        final selected = _selectedChannel == ch.id;
        return InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: () => setState(() => _selectedChannel = ch.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? ch.color.withValues(alpha: 0.1) : cs.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: selected ? ch.color.withValues(alpha: 0.5) : cs.outline.withValues(alpha: 0.1),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(ch.icon, size: 16, color: selected ? ch.color : cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(ch.label, style: tt.labelMedium?.copyWith(fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? ch.color : cs.onSurfaceVariant)),
              if (selected) ...[
                const SizedBox(width: 6),
                Icon(Icons.check_circle_rounded, size: 14, color: ch.color),
              ],
            ]),
          ),
        );
      }).toList()),
      const SizedBox(height: AppSpacing.md),
      _TemplatePicker(onSelect: _applyTemplate),
      const SizedBox(height: AppSpacing.md),
      Text('CAMPAIGN NAME', style: tt.labelSmall?.copyWith(fontSize: 10.5, fontWeight: FontWeight.w700,
          color: cs.onSurfaceVariant, letterSpacing: 0.6)),
      const SizedBox(height: 6),
      TextField(controller: _nameCtrl, decoration: InputDecoration(hintText: 'e.g. January Newsletter',
          prefixIcon: Icon(Icons.campaign_outlined, size: 18, color: cs.onSurfaceVariant))),
      const SizedBox(height: AppSpacing.md),
      Text('SUBJECT LINE', style: tt.labelSmall?.copyWith(fontSize: 10.5, fontWeight: FontWeight.w700,
          color: cs.onSurfaceVariant, letterSpacing: 0.6)),
      const SizedBox(height: 6),
      TextField(controller: _subjectCtrl, decoration: InputDecoration(hintText: 'e.g. Exciting updates!',
          prefixIcon: Icon(Icons.subject_outlined, size: 18, color: cs.onSurfaceVariant))),
      const SizedBox(height: AppSpacing.md),
      Row(children: [
        Text('EMAIL BODY', style: tt.labelSmall?.copyWith(fontSize: 10.5, fontWeight: FontWeight.w700,
            color: cs.onSurfaceVariant, letterSpacing: 0.6)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppRadius.pill)),
          child: Text('{{name}}  {{company}}  {{sender}}',
              style: tt.labelSmall?.copyWith(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.6))),
        ),
      ]),
      const SizedBox(height: 6),
      TextField(controller: _bodyCtrl, maxLines: 8,
          decoration: const InputDecoration(hintText: 'Write your email content here...', alignLabelWithHint: true)),
      const SizedBox(height: AppSpacing.md),
    ]);
  }

  Widget _buildRecipientsStep(ColorScheme cs) {
    final tt = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text('Choose which leads receive this campaign.',
          style: tt.labelMedium?.copyWith(fontSize: 12.5, color: cs.onSurfaceVariant)),
      const SizedBox(height: AppSpacing.md),
      _RecipientSelector(
        selectedIds: _selectedLeadIds, searchQuery: _searchQuery,
        statusFilter: _statusFilter,
        onStatusFilterChanged: (s) => setState(() {
          _statusFilter = s;
          // Clear selections that no longer match the new filter
          if (s.isNotEmpty) {
            // keep only selected leads that pass the new filter — handled in selector
          }
        }),
        onSearchChanged: (q) => setState(() => _searchQuery = q),
        onToggle: (id) { setState(() { _selectedLeadIds.contains(id) ? _selectedLeadIds.remove(id) : _selectedLeadIds.add(id); }); },
        onSelectAll: (ids) => setState(() => _selectedLeadIds.addAll(ids)),
        onDeselectAll: () => setState(() => _selectedLeadIds.clear()),
      ),
      const SizedBox(height: AppSpacing.md),
    ]);
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.pill), onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 24, height: 24,
            decoration: BoxDecoration(
              color: active ? cs.primary : cs.surfaceContainerHighest, shape: BoxShape.circle,
              border: active ? null : Border.all(color: cs.outline.withValues(alpha: 0.2))),
            child: Icon(active ? Icons.circle : Icons.circle_outlined, size: 10,
                color: active ? Colors.white : cs.onSurfaceVariant.withValues(alpha: 0.4))),
          const SizedBox(width: 6),
          Text(label, style: tt.labelMedium?.copyWith(fontSize: 12.5,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: active ? cs.primary : cs.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

// =============================================================================
// TEMPLATE PICKER
// =============================================================================

class _TemplatePicker extends StatelessWidget {
  const _TemplatePicker({required this.onSelect});
  final ValueChanged<EmailTemplate> onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ValueListenableBuilder<List<EmailTemplate>>(
      valueListenable: EmailCampaignService.instance.templates,
      builder: (context, templates, _) {
        if (templates.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('START FROM TEMPLATE', style: tt.labelSmall?.copyWith(fontSize: 10.5, fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant, letterSpacing: 0.6)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: templates.map((t) => ActionChip(
            avatar: Icon(Icons.auto_awesome_outlined, size: 14, color: cs.primary),
            label: Text(t.name, style: tt.labelMedium),
            labelPadding: const EdgeInsets.symmetric(horizontal: 2),
            onPressed: () => onSelect(t),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill),
                side: BorderSide(color: cs.outline.withValues(alpha: 0.15))),
            backgroundColor: cs.surface,
          )).toList()),
        ]);
      },
    );
  }
}

// =============================================================================
// RECIPIENT SELECTOR
// =============================================================================

// Status chip config for recipient filter
class _StatusChipConfig {
  final LeadStatus status;
  final String label;
  final Color color;
  const _StatusChipConfig({required this.status, required this.label, required this.color});
}

const _kStatusChips = [
  _StatusChipConfig(status: LeadStatus.fresh,         label: 'Fresh',          color: Color(0xFF2196F3)),
  _StatusChipConfig(status: LeadStatus.interested,    label: 'Interested',     color: Color(0xFF4CAF50)),
  _StatusChipConfig(status: LeadStatus.followUp,      label: 'Follow-Up',      color: Color(0xFF00BCD4)),
  _StatusChipConfig(status: LeadStatus.noAnswer,      label: 'No Answer',      color: Color(0xFFFF9800)),
  _StatusChipConfig(status: LeadStatus.notInterested, label: 'Not Interested', color: Color(0xFFF44336)),
  _StatusChipConfig(status: LeadStatus.converted,     label: 'Converted',      color: Color(0xFF9C27B0)),
  _StatusChipConfig(status: LeadStatus.closed,        label: 'Closed',         color: Color(0xFF607D8B)),
];

class _RecipientSelector extends StatelessWidget {
  const _RecipientSelector({
    required this.selectedIds, required this.searchQuery, required this.onSearchChanged,
    required this.onToggle, required this.onSelectAll, required this.onDeselectAll,
    required this.statusFilter, required this.onStatusFilterChanged,
  });
  final Set<String> selectedIds;
  final String searchQuery;
  final Set<LeadStatus> statusFilter;
  final ValueChanged<Set<LeadStatus>> onStatusFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onToggle;
  final ValueChanged<List<String>> onSelectAll;
  final VoidCallback onDeselectAll;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<List<LeadModel>>(
      valueListenable: LeadService.instance.leads,
      builder: (context, allLeads, _) {
        // Apply status filter first (empty = all statuses)
        final statusFiltered = statusFilter.isEmpty
            ? allLeads
            : allLeads.where((l) => statusFilter.contains(l.status)).toList();
        final leadsWithEmail = statusFiltered.where((l) => l.email != null && l.email!.isNotEmpty).toList();
        final filtered = searchQuery.isEmpty ? leadsWithEmail : leadsWithEmail.where((l) {
          final q = searchQuery.toLowerCase();
          return l.name.toLowerCase().contains(q) || (l.email?.toLowerCase().contains(q) ?? false)
              || (l.campaign?.toLowerCase().contains(q) ?? false);
        }).toList();
        final allFilteredIds = filtered.map((l) => l.id).toList();

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Status filter chips
          Wrap(spacing: 6, runSpacing: 6, children: _kStatusChips.map((cfg) {
            final active = statusFilter.contains(cfg.status);
            return InkWell(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              onTap: () {
                final next = Set<LeadStatus>.from(statusFilter);
                active ? next.remove(cfg.status) : next.add(cfg.status);
                onStatusFilterChanged(next);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: active ? cfg.color.withValues(alpha: 0.12) : cs.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: active ? cfg.color.withValues(alpha: 0.55) : cs.outline.withValues(alpha: 0.12),
                    width: active ? 1.5 : 1,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 7, height: 7,
                    decoration: BoxDecoration(color: cfg.color, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(cfg.label, style: tt.labelSmall?.copyWith(
                      fontSize: 11.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? cfg.color : cs.onSurfaceVariant)),
                ]),
              ),
            );
          }).toList()),
          if (statusFilter.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Showing all statuses — tap chips to filter',
                  style: tt.labelSmall?.copyWith(fontSize: 10.5, color: cs.onSurfaceVariant.withValues(alpha: 0.5))),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                Text('${leadsWithEmail.length} lead${leadsWithEmail.length == 1 ? '' : 's'} match — ',
                    style: tt.labelSmall?.copyWith(fontSize: 10.5, color: cs.onSurfaceVariant.withValues(alpha: 0.6))),
                InkWell(
                  onTap: () => onStatusFilterChanged({}),
                  child: Text('clear filter', style: tt.labelSmall?.copyWith(
                      fontSize: 10.5, color: cs.primary, decoration: TextDecoration.underline)),
                ),
              ]),
            ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(
              decoration: InputDecoration(hintText: 'Search leads by name or email...', 
                  prefixIcon: Icon(Icons.search_rounded, size: 18, color: cs.onSurfaceVariant),
                  isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              onChanged: onSearchChanged, style: tt.bodySmall,
            )),
            const SizedBox(width: 8),
            TextButton(onPressed: () => onSelectAll(allFilteredIds),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), minimumSize: const Size(0, 34)),
                child: Text('Select All', style: tt.labelMedium)),
            TextButton(onPressed: onDeselectAll,
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), minimumSize: const Size(0, 34)),
                child: Text('Clear', style: tt.labelMedium)),
          ]),
          const SizedBox(height: 10),
          if (leadsWithEmail.isEmpty)
            Container(
              width: double.infinity, padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Column(children: [
                Icon(Icons.people_outline, size: 28, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                const SizedBox(height: 8),
                Text('No leads with email addresses found.',
                    style: tt.labelMedium?.copyWith(fontSize: 12.5, color: cs.onSurfaceVariant)),
              ]),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                border: Border.all(color: cs.outline.withValues(alpha: isDark ? 0.15 : 0.1)),
                borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: ListView.separated(
                  shrinkWrap: true, itemCount: filtered.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: cs.outline.withValues(alpha: 0.06)),
                  itemBuilder: (context, i) {
                    final lead = filtered[i];
                    final selected = selectedIds.contains(lead.id);
                    return Material(
                      color: selected ? cs.primary.withValues(alpha: 0.04) : Colors.transparent,
                      child: InkWell(onTap: () => onToggle(lead.id), child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(children: [
                          SizedBox(width: 20, height: 20, child: Checkbox(
                            value: selected, onChanged: (_) => onToggle(lead.id),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)))),
                          const SizedBox(width: 10),
                          CircleAvatar(radius: 15,
                            backgroundColor: selected ? cs.primary.withValues(alpha: 0.1) : cs.surfaceContainerHighest,
                            child: Text(_initials(lead.name), style: tt.labelSmall?.copyWith(
                                fontSize: 10.5, fontWeight: FontWeight.w700,
                                color: selected ? cs.primary : cs.onSurfaceVariant))),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(lead.name, style: tt.labelMedium?.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600, color: cs.onSurface)),
                            Text(lead.email ?? '', style: tt.labelSmall?.copyWith(fontSize: 11.5, color: cs.onSurfaceVariant)),
                          ])),
                          // Status badge
                          Builder(builder: (_) {
                            final cfg = _kStatusChips.firstWhere(
                              (c) => c.status == lead.status,
                              orElse: () => _kStatusChips.first,
                            );
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: cfg.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                                border: Border.all(color: cfg.color.withValues(alpha: 0.3)),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Container(width: 5, height: 5, decoration: BoxDecoration(color: cfg.color, shape: BoxShape.circle)),
                                const SizedBox(width: 4),
                                Text(cfg.label, style: tt.labelSmall?.copyWith(fontSize: 9.5, color: cfg.color, fontWeight: FontWeight.w600)),
                              ]),
                            );
                          }),
                        ]),
                      )),
                    );
                  },
                ),
              ),
            ),
        ]);
      },
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

// =============================================================================
// TEMPLATES TAB
// =============================================================================

class _TemplatesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ValueListenableBuilder<List<EmailTemplate>>(
      valueListenable: EmailCampaignService.instance.templates,
      builder: (context, templates, _) {
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 32, height: 32,
                decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.xs)),
                child: Icon(Icons.auto_awesome_outlined, size: 16, color: cs.primary)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Email Templates', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700)),
                Text('Templates pre-fill subject & body when creating campaigns.',
                    style: tt.labelSmall?.copyWith(fontSize: 11.5, color: cs.onSurfaceVariant)),
              ])),
              OutlinedButton.icon(
                onPressed: () => showDialog(context: context, builder: (_) => const _TemplateEditorDialog()),
                icon: const Icon(Icons.add_rounded, size: 16), label: const Text('New Template'),
                style: OutlinedButton.styleFrom(
                  textStyle: tt.labelMedium?.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10))),
            ]),
            const SizedBox(height: AppSpacing.md),
            if (templates.isEmpty)
              Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 64, height: 64,
                  decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(16)),
                  child: Icon(Icons.description_outlined, size: 28, color: cs.onSurfaceVariant.withValues(alpha: 0.35))),
                const SizedBox(height: 12),
                Text('No templates yet', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface)),
                const SizedBox(height: 4),
                Text('Create reusable templates for quick campaign setup.',
                    style: tt.labelMedium?.copyWith(fontSize: 12.5, color: cs.onSurfaceVariant)),
              ])))
            else
              Expanded(child: ListView.separated(
                itemCount: templates.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) => _TemplateCard(template: templates[i]),
              )),
          ]),
        );
      },
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template});
  final EmailTemplate template;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface, borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outline.withValues(alpha: isDark ? 0.15 : 0.08)),
        boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: isDark ? 0.06 : 0.02), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [cs.primary.withValues(alpha: 0.12), cs.primary.withValues(alpha: 0.04)]),
            borderRadius: BorderRadius.circular(AppRadius.sm)),
          child: Icon(Icons.description_outlined, size: 18, color: cs.primary)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(template.name, style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(template.subject, style: tt.labelMedium?.withColor(cs.onSurfaceVariant),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(template.body, style: tt.labelSmall?.copyWith(fontSize: 11.5, color: cs.onSurfaceVariant.withValues(alpha: 0.55), height: 1.4),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ])),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(Icons.delete_outline, size: 16, color: cs.onSurfaceVariant.withValues(alpha: 0.45)),
          tooltip: 'Delete template',
          onPressed: () async {
            final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              title: const Text('Delete Template'), content: Text('Delete "${template.name}"?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
              ]));
            if (ok == true) await EmailCampaignService.instance.deleteTemplate(template.id);
          }),
      ]),
    );
  }
}

// =============================================================================
// TEMPLATE EDITOR DIALOG
// =============================================================================

class _TemplateEditorDialog extends StatefulWidget {
  const _TemplateEditorDialog();
  @override
  State<_TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends State<_TemplateEditorDialog> {
  final _nameCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() { _nameCtrl.dispose(); _subjectCtrl.dispose(); _bodyCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Template name is required'), behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        margin: const EdgeInsets.all(AppSpacing.md)));
      return;
    }
    setState(() => _saving = true);
    try {
      await EmailCampaignService.instance.createTemplate(
          name: _nameCtrl.text.trim(), subject: _subjectCtrl.text.trim(), body: _bodyCtrl.text.trim());
      if (mounted) Navigator.pop(context);
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.xs)),
                child: Icon(Icons.auto_awesome_outlined, size: 18, color: cs.primary)),
              const SizedBox(width: 10),
              Text('New Template', style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant)),
            ]),
            const SizedBox(height: AppSpacing.lg),
            Text('TEMPLATE NAME', style: tt.labelSmall?.copyWith(fontSize: 10.5, fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant, letterSpacing: 0.6)),
            const SizedBox(height: 6),
            TextField(controller: _nameCtrl, decoration: InputDecoration(hintText: 'e.g. Welcome Series #1',
                prefixIcon: Icon(Icons.label_outline, size: 18, color: cs.onSurfaceVariant))),
            const SizedBox(height: AppSpacing.md),
            Text('SUBJECT LINE', style: tt.labelSmall?.copyWith(fontSize: 10.5, fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant, letterSpacing: 0.6)),
            const SizedBox(height: 6),
            TextField(controller: _subjectCtrl, decoration: InputDecoration(hintText: 'e.g. Welcome, {{name}}!',
                prefixIcon: Icon(Icons.subject_outlined, size: 18, color: cs.onSurfaceVariant))),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              Text('BODY', style: tt.labelSmall?.copyWith(fontSize: 10.5, fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant, letterSpacing: 0.6)),
              const Spacer(),
              Text('{{name}}  {{company}}  {{sender}}',
                  style: tt.labelSmall?.copyWith(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.5))),
            ]),
            const SizedBox(height: 6),
            TextField(controller: _bodyCtrl, maxLines: 6,
                decoration: const InputDecoration(hintText: 'Write your template body here...', alignLabelWithHint: true)),
            const SizedBox(height: AppSpacing.lg),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, size: 16),
                label: const Text('Save Template'),
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)))),
            ]),
          ]),
        ),
      ),
    );
  }
}
