import 'package:anis_crm/models/lead.dart';

enum LeadTemperature { cold, warm, hot }

class LeadScoreResult {
  final int score; // 0-100
  final LeadTemperature temperature;
  const LeadScoreResult({required this.score, required this.temperature});
}

class LeadScoreEngine {
  /// Pure, deterministic scoring based on explicit rules.
  /// Safe to swap out later with real AI without changing callers.
  static LeadScoreResult compute(LeadModel lead, {DateTime? now}) {
    final DateTime current = now ?? DateTime.now();
    final DateTime today = DateTime(current.year, current.month, current.day);

    int score = 0;

    // 1) STATUS SCORE
    switch (lead.status) {
      case LeadStatus.fresh:
        score += 35;
        break;
      case LeadStatus.interested:
        score += 40;
        break;
      case LeadStatus.followUp:
        score += 30;
        break;
      case LeadStatus.noAnswer:
        score += 15;
        break;
      case LeadStatus.notInterested:
        score += 5;
        break;
      case LeadStatus.converted:
        score += 50;
        break;
      case LeadStatus.closed:
        score += 0;
        break;
    }

    // 2) RECENCY SCORE
    final DateTime createdD = DateTime(lead.createdAt.year, lead.createdAt.month, lead.createdAt.day);
    final int daysSinceCreated = today.difference(createdD).inDays;
    if (daysSinceCreated == 0) {
      score += 20; // today
    } else if (daysSinceCreated <= 3) {
      score += 10; // last 3 days
    }

    // 3) CONTACT ACTIVITY SCORE
    if (lead.lastContactedAt != null) {
      final DateTime lastD = DateTime(lead.lastContactedAt!.year, lead.lastContactedAt!.month, lead.lastContactedAt!.day);
      final int daysSinceContact = today.difference(lastD).inDays;
      if (daysSinceContact == 0) {
        score += 10; // contacted today
      } else if (daysSinceContact <= 2) {
        score += 5; // in last 2 days
      }
    }

    // 4) FOLLOW-UP URGENCY SCORE
    if (lead.status == LeadStatus.followUp && lead.nextFollowupAt != null) {
      final DateTime nextD = DateTime(lead.nextFollowupAt!.year, lead.nextFollowupAt!.month, lead.nextFollowupAt!.day);
      if (!nextD.isAfter(today)) {
        score += 20; // due today or overdue
      }
    }

    // Clamp 0..100
    if (score < 0) score = 0;
    if (score > 100) score = 100;

    return LeadScoreResult(score: score, temperature: _labelFor(score));
  }

  static LeadTemperature _labelFor(int score) {
    if (score >= 60) return LeadTemperature.hot;
    if (score >= 30) return LeadTemperature.warm;
    return LeadTemperature.cold;
  }
}
