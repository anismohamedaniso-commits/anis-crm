import 'package:anis_crm/engine/priorities_engine.dart';
import 'package:anis_crm/services/social_launcher.dart';
import 'package:anis_crm/state/app_state.dart';
import 'package:anis_crm/theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class PrioritiesPanel extends StatelessWidget {
  final List<LeadPriority> priorities;
  final String? note;
  const PrioritiesPanel({super.key, required this.priorities, this.note});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.auto_awesome, color: AppColors.accent),
            const SizedBox(width: AppSpacing.sm),
            Text('AI Priorities', style: text.titleLarge),
            const Spacer(),
            _ModeChip(),
          ]),
          const SizedBox(height: AppSpacing.md),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(note!, style: text.labelSmall!.withColor(Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          if (priorities.isEmpty)
            Text('No priorities right now', style: text.bodyMedium!.withColor(onSurface.withValues(alpha: 0.7)))
          else
            ...priorities.map((p) => _PriorityTile(p)).toList(),
        ]),
      ),
    );
  }
}

class _PriorityTile extends StatelessWidget {
  final LeadPriority p;
  const _PriorityTile(this.p);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final icon = switch (p.action) {
      PriorityAction.call => Icons.call,
      PriorityAction.message => Icons.chat_bubble_outline,
      PriorityAction.openLead => Icons.open_in_new,
      PriorityAction.review => Icons.check_circle_outline,
    };
    final actionLabel = switch (p.action) {
      PriorityAction.call => 'Call',
      PriorityAction.message => 'Message',
      PriorityAction.openLead => 'Open Lead',
      PriorityAction.review => 'Review',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(width: 2),
        const Icon(Icons.bolt, color: AppColors.accent, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.title, style: text.titleMedium),
            const SizedBox(height: 4),
            Text(p.reason, style: text.bodyMedium!.withColor(Colors.grey.shade700)),
          ]),
        ),
        const SizedBox(width: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: () => _onAction(context, p),
          icon: Icon(icon),
          label: Text(actionLabel),
        ),
      ]),
    );
  }

  void _onAction(BuildContext context, LeadPriority p) {
    switch (p.action) {
      case PriorityAction.call:
        if (p.phone != null && p.phone!.isNotEmpty) {
          SocialLauncher.dialPhone(p.phone!);
        } else if (p.leadId != null) {
          context.push('/app/lead/${p.leadId}');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No phone number available')));
        }
      case PriorityAction.message:
        if (p.phone != null && p.phone!.isNotEmpty) {
          SocialLauncher.openWhatsApp(phone: p.phone!);
        } else if (p.leadId != null) {
          context.push('/app/lead/${p.leadId}');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No phone number available')));
        }
      case PriorityAction.openLead:
      case PriorityAction.review:
        if (p.leadId != null) {
          context.push('/app/lead/${p.leadId}');
        } else {
          context.go('/app/leads');
        }
    }
  }
}

class _ModeChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final state = context.watch<AppState>();
    final useAi = state.aiConnected && state.aiPrioritiesEnabled;
    final bg = useAi ? Colors.blue.shade50 : Colors.green.shade50;
    final bd = useAi ? Colors.blue.shade200 : Colors.green.shade200;
    final fg = useAi ? Colors.blue.shade700 : Colors.green.shade700;
    final label = useAi ? 'AI (local)' : 'Rule-based';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bd),
      ),
      child: Text(label, style: text.labelMedium!.withColor(fg)),
    );
  }
}
