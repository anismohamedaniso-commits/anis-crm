/// Campaign model for the CRM.
///
/// Each campaign has a name, description, market, budget, status, and dates.
/// Leads reference campaigns by [id] via the existing `campaign` string field.
class CampaignModel {
  final String id;
  final String name;

  /// Free-text campaign description / objective.
  final String description;

  /// Market id: 'egypt', 'saudi_arabia', or 'all'.
  final String market;

  /// Total campaign budget in the market's currency.
  final double budget;

  /// Campaign lifecycle status: active, paused, or completed.
  final String status;

  final DateTime startDate;

  /// Optional end date for campaign duration tracking.
  final DateTime? endDate;

  final DateTime createdAt;

  const CampaignModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.market,
    required this.budget,
    this.status = 'active',
    required this.startDate,
    this.endDate,
    required this.createdAt,
  });

  CampaignModel copyWith({
    String? id,
    String? name,
    String? description,
    String? market,
    double? budget,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    DateTime? createdAt,
  }) =>
      CampaignModel(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        market: market ?? this.market,
        budget: budget ?? this.budget,
        status: status ?? this.status,
        startDate: startDate ?? this.startDate,
        endDate: clearEndDate ? null : (endDate ?? this.endDate),
        createdAt: createdAt ?? this.createdAt,
      );

  /// Whether the campaign is currently running.
  bool get isActive => status == 'active';
  bool get isPaused => status == 'paused';
  bool get isCompleted => status == 'completed';

  /// Campaign duration in days (to endDate or today if still active).
  int get durationDays {
    final end = endDate ?? DateTime.now();
    return end.difference(startDate).inDays.abs();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'market': market,
        'budget': budget,
        'status': status,
        'start_date': startDate.toIso8601String(),
        if (endDate != null) 'end_date': endDate!.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  factory CampaignModel.fromJson(Map<String, dynamic> json) => CampaignModel(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        market: json['market'] as String? ?? 'egypt',
        budget: (json['budget'] as num?)?.toDouble() ?? 0,
        status: json['status'] as String? ?? 'active',
        startDate: DateTime.tryParse(json['start_date'] as String? ?? '') ?? DateTime.now(),
        endDate: json['end_date'] != null ? DateTime.tryParse(json['end_date'] as String) : null,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}
