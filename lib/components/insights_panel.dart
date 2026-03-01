import 'package:anis_crm/theme.dart';
import 'package:flutter/material.dart';

import 'package:anis_crm/engine/insights_engine.dart';

class InsightsPanel extends StatelessWidget {
  final List<Insight> insights;
  const InsightsPanel({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.auto_awesome, color: cs.primary, size: 20),
            const SizedBox(width: 8),
            Text('AI Insights', style: Theme.of(context).textTheme.titleLarge),
          ]),
          const SizedBox(height: 8),
          Text('Short observations about your pipeline and follow-ups.',
              style: Theme.of(context).textTheme.bodyMedium?.withColor(cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          if (insights.isEmpty)
            Container(
              padding: AppSpacing.paddingMd,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text('No notable patterns detected today.',
                  style: Theme.of(context).textTheme.bodyMedium),
            )
          else
            Column(
              children: insights
                  .map((i) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Icon(Icons.circle, size: 6, color: Colors.black54),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(i.text, style: Theme.of(context).textTheme.bodyMedium)),
                        ]),
                      ))
                  .toList(),
            ),
        ]),
      ),
    );
  }
}
