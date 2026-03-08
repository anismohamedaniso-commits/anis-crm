/// Represents a regional market / country the CRM operates in.
///
/// Add new markets here — the rest of the app picks them up automatically.
class Market {
  const Market({
    required this.id,
    required this.label,
    required this.flag,
    required this.currency,
    required this.currencySymbol,
  });

  /// Unique identifier stored in DB `country` column & SharedPreferences.
  final String id;

  /// Human-friendly name shown in UI.
  final String label;

  /// Flag emoji.
  final String flag;

  /// ISO currency code for display.
  final String currency;

  /// Short symbol / prefix used in input fields & KPIs.
  final String currencySymbol;

  // ─── Built-in markets ─────────────────────────────────────────────────

  static const egypt = Market(
    id: 'egypt',
    label: 'Egypt',
    flag: '🇪🇬',
    currency: 'EGP',
    currencySymbol: 'EGP',
  );

  static const saudiArabia = Market(
    id: 'saudi_arabia',
    label: 'Saudi Arabia',
    flag: '🇸🇦',
    currency: 'SAR',
    currencySymbol: 'SAR',
  );

  /// All available markets — add new entries here.
  static const List<Market> all = [egypt, saudiArabia];

  /// Look up by [id], falling back to Egypt if unknown.
  static Market byId(String id) =>
      all.firstWhere((m) => m.id == id, orElse: () => egypt);

  /// Format a revenue value using this market's currency.
  String fmtRevenue(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M $currency';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K $currency';
    return '${v.toStringAsFixed(0)} $currency';
  }

  @override
  bool operator ==(Object other) => other is Market && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
