/// A single KPI target definition with current progress tracking.
class KpiTarget {
  final String id;
  final String label;
  final KpiMetric metric;
  final KpiPeriod period;
  final int target;
  final int current;
  final DateTime createdAt;

  const KpiTarget({
    required this.id,
    required this.label,
    required this.metric,
    required this.period,
    required this.target,
    this.current = 0,
    required this.createdAt,
  });

  double get progress => target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
  int get remaining => (target - current).clamp(0, target);
  bool get isAchieved => current >= target;

  KpiTarget copyWith({
    String? id,
    String? label,
    KpiMetric? metric,
    KpiPeriod? period,
    int? target,
    int? current,
    DateTime? createdAt,
  }) =>
      KpiTarget(
        id: id ?? this.id,
        label: label ?? this.label,
        metric: metric ?? this.metric,
        period: period ?? this.period,
        target: target ?? this.target,
        current: current ?? this.current,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'metric': metric.name,
        'period': period.name,
        'target': target,
        'current': current,
        'created_at': createdAt.toIso8601String(),
      };

  factory KpiTarget.fromJson(Map<String, dynamic> json) => KpiTarget(
        id: json['id'] as String,
        label: json['label'] as String,
        metric: KpiMetric.values.firstWhere(
          (e) => e.name == (json['metric'] as String? ?? 'leadsCreated'),
          orElse: () => KpiMetric.leadsCreated,
        ),
        period: KpiPeriod.values.firstWhere(
          (e) => e.name == (json['period'] as String? ?? 'monthly'),
          orElse: () => KpiPeriod.monthly,
        ),
        target: json['target'] as int? ?? 0,
        current: json['current'] as int? ?? 0,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}

/// The metric a KPI tracks.
enum KpiMetric {
  leadsCreated,
  leadsConverted,
  callsMade,
  followUpsDone,
  emailsSent,
  responseRate,
}

extension KpiMetricX on KpiMetric {
  String get displayName {
    switch (this) {
      case KpiMetric.leadsCreated:
        return 'Leads Created';
      case KpiMetric.leadsConverted:
        return 'Leads Converted';
      case KpiMetric.callsMade:
        return 'Calls Made';
      case KpiMetric.followUpsDone:
        return 'Follow-ups Done';
      case KpiMetric.emailsSent:
        return 'Emails Sent';
      case KpiMetric.responseRate:
        return 'Response Rate (%)';
    }
  }

  String get icon {
    switch (this) {
      case KpiMetric.leadsCreated:
        return 'person_add';
      case KpiMetric.leadsConverted:
        return 'check_circle';
      case KpiMetric.callsMade:
        return 'phone';
      case KpiMetric.followUpsDone:
        return 'event_available';
      case KpiMetric.emailsSent:
        return 'email';
      case KpiMetric.responseRate:
        return 'speed';
    }
  }
}

/// Time period for a KPI.
enum KpiPeriod { daily, weekly, monthly, quarterly }

extension KpiPeriodX on KpiPeriod {
  String get displayName {
    switch (this) {
      case KpiPeriod.daily:
        return 'Daily';
      case KpiPeriod.weekly:
        return 'Weekly';
      case KpiPeriod.monthly:
        return 'Monthly';
      case KpiPeriod.quarterly:
        return 'Quarterly';
    }
  }
}
