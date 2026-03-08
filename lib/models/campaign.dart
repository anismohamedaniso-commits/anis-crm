/// Campaign model for the CRM.
///
/// Each campaign has a name, market, budget, and start date.
/// Leads reference campaigns by [id] via the existing `campaign` string field.
class CampaignModel {
  final String id;
  final String name;

  /// Market id: 'egypt', 'saudi_arabia', or 'all'.
  final String market;

  /// Total campaign budget in the market's currency.
  final double budget;

  final DateTime startDate;
  final DateTime createdAt;

  const CampaignModel({
    required this.id,
    required this.name,
    required this.market,
    required this.budget,
    required this.startDate,
    required this.createdAt,
  });

  CampaignModel copyWith({
    String? id,
    String? name,
    String? market,
    double? budget,
    DateTime? startDate,
    DateTime? createdAt,
  }) =>
      CampaignModel(
        id: id ?? this.id,
        name: name ?? this.name,
        market: market ?? this.market,
        budget: budget ?? this.budget,
        startDate: startDate ?? this.startDate,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'market': market,
        'budget': budget,
        'start_date': startDate.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  factory CampaignModel.fromJson(Map<String, dynamic> json) => CampaignModel(
        id: json['id'] as String,
        name: json['name'] as String,
        market: json['market'] as String? ?? 'egypt',
        budget: (json['budget'] as num?)?.toDouble() ?? 0,
        startDate: DateTime.tryParse(json['start_date'] as String? ?? '') ?? DateTime.now(),
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}
