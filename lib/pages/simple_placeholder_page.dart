import 'package:flutter/material.dart';

/// Generic page that shows a title and a simple placeholder message.
class SimplePlaceholderPage extends StatelessWidget {
  const SimplePlaceholderPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 8),
      Text('This page will be built in the next step.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]);
  }
}
