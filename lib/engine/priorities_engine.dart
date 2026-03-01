import 'package:anis_crm/models/lead.dart';

enum PriorityAction { call, message, openLead, review }

class LeadPriority {
  final String title;
  final String reason;
  final PriorityAction action;
  final String? leadId;
  final String? phone;
  final String? email;
  const LeadPriority({required this.title, required this.reason, required this.action, this.leadId, this.phone, this.email});
}

class PrioritiesEngine {
  /// Generates up to 3 priorities using deterministic rules.
  /// Isolated pure function so it can be swapped with real AI later.
  static List<LeadPriority> generate(List<LeadModel> leads, {DateTime? now}) {
    final DateTime today = _dateOnly(now ?? DateTime.now());
    final List<LeadPriority> results = [];
    final Set<String> used = {};

    bool addOnce(LeadModel l, LeadPriority p) {
      if (used.contains(l.id)) return false;
      results.add(p);
      used.add(l.id);
      return results.length >= 3;
    }

    // 1) Overdue Follow-Ups
    for (final l in leads) {
      if (l.status == LeadStatus.followUp && l.nextFollowupAt != null) {
        if (!_isAfter(_dateOnly(l.nextFollowupAt!), today)) {
          if (addOnce(
            l,
            LeadPriority(
              title: 'Follow up with ${l.name}',
              reason: 'This lead is overdue for a follow-up.',
              action: PriorityAction.openLead,
              leadId: l.id,
              phone: l.phone,
              email: l.email,
            ),
          )) return results;
        }
      }
    }

    // 2) Interested but Untouched today
    for (final l in leads) {
      if (l.status == LeadStatus.interested) {
        final last = l.lastContactedAt == null ? null : _dateOnly(l.lastContactedAt!);
        final notToday = last == null || last != today;
        if (notToday) {
          if (addOnce(
            l,
            LeadPriority(
              title: 'Contact interested lead ${l.name}',
              reason: 'This lead showed interest but hasn\'t been contacted today.',
              action: PriorityAction.call,
              leadId: l.id,
              phone: l.phone,
              email: l.email,
            ),
          )) return results;
        }
      }
    }

    // 3) New Leads Today
    for (final l in leads) {
      if (_dateOnly(l.createdAt) == today) {
        if (addOnce(
          l,
          LeadPriority(
            title: 'Review new lead ${l.name}',
            reason: 'A new lead was added today.',
            action: PriorityAction.openLead,
            leadId: l.id,
            phone: l.phone,
            email: l.email,
          ),
        )) return results;
      }
    }

    // 4) No Answer follow-up (>24h)
    for (final l in leads) {
      if (l.status == LeadStatus.noAnswer && l.lastContactedAt != null) {
        final diff = (now ?? DateTime.now()).difference(l.lastContactedAt!);
        if (diff.inHours > 24) {
          if (addOnce(
            l,
            LeadPriority(
              title: 'Retry contact with ${l.name}',
              reason: 'This lead has not responded after initial contact.',
              action: PriorityAction.message,
              leadId: l.id,
              phone: l.phone,
              email: l.email,
            ),
          )) return results;
        }
      }
    }

    if (results.isEmpty) {
      return const [
        LeadPriority(
          title: "You're on track",
          reason: 'There are no urgent leads requiring action.',
          action: PriorityAction.review,
        )
      ];
    }
    return results;
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
  static bool _isAfter(DateTime a, DateTime b) => a.isAfter(b);
}
