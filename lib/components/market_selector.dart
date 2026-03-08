import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:anis_crm/models/market.dart';
import 'package:anis_crm/state/app_state.dart';

// ═════════════════════════════════════════════════════════════════════════════
// MARKET SELECTOR — Global market / country picker
// ═════════════════════════════════════════════════════════════════════════════

/// A compact, polished dropdown that lets the user switch markets.
///
/// Use [collapsed] = true in collapsed sidebar mode (icon-only).
class MarketSelector extends StatelessWidget {
  const MarketSelector({super.key, this.collapsed = false});
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final market = app.selectedMarket;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final dk = Theme.of(context).brightness == Brightness.dark;

    if (collapsed) {
      return Tooltip(
        message: '${market.flag} ${market.label}',
        child: _PopupSelector(
          market: market,
          cs: cs,
          dk: dk,
          onChanged: (m) => app.setSelectedMarket(m.id),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: dk ? 0.12 : 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.primary.withValues(alpha: 0.12)),
            ),
            child: Center(
              child: Text(market.flag, style: const TextStyle(fontSize: 18)),
            ),
          ),
        ),
      );
    }

    return _PopupSelector(
      market: market,
      cs: cs,
      dk: dk,
      onChanged: (m) => app.setSelectedMarket(m.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: dk ? 0.10 : 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.primary.withValues(alpha: 0.10)),
        ),
        child: Row(children: [
          Text(market.flag, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  market.label,
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  market.currency,
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.45),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.unfold_more_rounded,
            size: 16,
            color: cs.onSurface.withValues(alpha: 0.4),
          ),
        ]),
      ),
    );
  }
}

/// Wrap a child widget to open the market popup on tap.
class _PopupSelector extends StatelessWidget {
  const _PopupSelector({
    required this.market,
    required this.cs,
    required this.dk,
    required this.onChanged,
    required this.child,
  });

  final Market market;
  final ColorScheme cs;
  final bool dk;
  final ValueChanged<Market> onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Market>(
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: dk ? const Color(0xFF1E1E24) : Colors.white,
      elevation: 6,
      onSelected: onChanged,
      itemBuilder: (_) => Market.all.map((m) {
        final isActive = m.id == market.id;
        return PopupMenuItem<Market>(
          value: m,
          height: 48,
          child: Row(children: [
            Text(m.flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                m.label,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? cs.primary : cs.onSurface,
                ),
              ),
            ),
            Text(
              m.currency,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.45),
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_rounded, size: 18, color: cs.primary),
            ],
          ]),
        );
      }).toList(),
      child: child,
    );
  }
}

/// Compact inline market selector for mobile bottom bar / headers.
class MarketSelectorCompact extends StatelessWidget {
  const MarketSelectorCompact({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final market = app.selectedMarket;
    final cs = Theme.of(context).colorScheme;
    final dk = Theme.of(context).brightness == Brightness.dark;

    return _PopupSelector(
      market: market,
      cs: cs,
      dk: dk,
      onChanged: (m) => app.setSelectedMarket(m.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: dk ? 0.12 : 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.primary.withValues(alpha: 0.10)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(market.flag, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            market.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(width: 2),
          Icon(Icons.arrow_drop_down_rounded, size: 16, color: cs.onSurface.withValues(alpha: 0.5)),
        ]),
      ),
    );
  }
}
