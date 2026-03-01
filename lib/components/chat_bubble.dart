import 'package:flutter/material.dart';
import 'package:anis_crm/theme.dart';

/// Simple chat bubble supporting incoming (left) and outgoing (right) styles.
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.text, required this.timestamp, this.isOutgoing = false});

  final String text;
  final String timestamp;
  final bool isOutgoing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = isOutgoing ? colorScheme.primaryContainer : colorScheme.surface;
    final fg = isOutgoing ? colorScheme.onPrimaryContainer : colorScheme.onSurface;
    final align = isOutgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(AppRadius.lg),
      topRight: const Radius.circular(AppRadius.lg),
      bottomLeft: Radius.circular(isOutgoing ? AppRadius.lg : AppRadius.sm),
      bottomRight: Radius.circular(isOutgoing ? AppRadius.sm : AppRadius.lg),
    );

    return Column(
      crossAxisAlignment: align,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(color: bg, borderRadius: radius, border: Border.all(color: colorScheme.outline.withValues(alpha: 0.15))),
          child: Text(text, style: Theme.of(context).textTheme.bodyLarge?.withColor(fg)),
        ),
        const SizedBox(height: 4),
        Text(timestamp, style: Theme.of(context).textTheme.labelSmall?.withColor(colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
