import 'package:anis_crm/theme.dart';
import 'package:flutter/material.dart';

/// A simple placeholder card used for upcoming features.
class PlaceholderCard extends StatelessWidget {
  const PlaceholderCard({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.hourglass_empty_outlined, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ]),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium?.withColor(Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ]),
      ),
    );
  }
}
