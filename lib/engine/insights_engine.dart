import 'package:anis_crm/engine/lead_score_engine.dart';
import 'package:anis_crm/models/lead.dart';

class Insight {
  final String text;
  const Insight(this.text);
}

class InsightsEngine {
  /// Generates up to 2 short insights based on the collection of leads.
  /// Pure, deterministic and UI-ready. Safe to swap with real AI later.
  static List<Insight> generate(List<LeadModel> leads, {DateTime? now}) {
    final DateTime current = now ?? DateTime.now();
    final DateTime today = DateTime(current.year, current.month, current.day);

    // Precompute score/temperature for relevant rules
    final scored = leads
        .map((l) => (
              lead: l,
              score: LeadScoreEngine.compute(l, now: current),
            ))
        .toList();

    final List<Insight> insights = [];

    // 1) Hot Leads Not Contacted Today
    final int hotNotContacted = scored
        .where((e) {
          final temp = e.score.temperature;
          final last = e.lead.lastContactedAt;
          final bool notToday = last == null || DateTime(last.year, last.month, last.day) != today;
          return temp == LeadTemperature.hot && notToday;
        })
        .length;
    if (hotNotContacted >= 1) {
      insights.add(Insight("You have $hotNotContacted hot leads that haven’t been contacted today."));
    }

    // 2) Overdue Follow-Ups
    final int overdueFollowUps = leads
        .where((l) {
          if (l.status != LeadStatus.followUp || l.nextFollowupAt == null) return false;
          final d = DateTime(l.nextFollowupAt!.year, l.nextFollowupAt!.month, l.nextFollowupAt!.day);
          return d.isBefore(today);
        })
        .length;
    if (insights.length < 2 && overdueFollowUps >= 1) {
      insights.add(Insight("$overdueFollowUps follow-ups are overdue and need attention."));
    }

    // 3) New Leads Today
    final int newToday = leads
        .where((l) => DateTime(l.createdAt.year, l.createdAt.month, l.createdAt.day) == today)
        .length;
    if (insights.length < 2 && newToday >= 1) {
      insights.add(const Insight("New leads arrived today. Early contact improves response rate."));
    }

    // 4) Leads Stuck in No Answer (backlog)
    final int noAnswerCount = leads.where((l) => l.status == LeadStatus.noAnswer).length;
    if (insights.length < 2 && noAnswerCount >= 3) {
      insights.add(const Insight("Several leads are stuck in 'No Answer'. Consider a second follow-up."));
    }

    // 5) Cold Pipeline Warning (≥60%)
    if (insights.length < 2 && leads.isNotEmpty) {
      final int coldCount = scored.where((e) => e.score.temperature == LeadTemperature.cold).length;
      final double pct = (coldCount / leads.length) * 100.0;
      if (pct >= 60) {
        insights.add(const Insight("Most of your pipeline is cold. Focus on warming interested leads."));
      }
    }

    // Limit to max 2 insights
    return insights.take(2).toList();
  }
}
