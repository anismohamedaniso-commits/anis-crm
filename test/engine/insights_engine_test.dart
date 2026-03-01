import 'package:flutter_test/flutter_test.dart';
import 'package:anis_crm/engine/insights_engine.dart';
import 'package:anis_crm/models/lead.dart';

void main() {
  final now = DateTime(2026, 2, 11, 10, 0);

  LeadModel _makeLead({
    String id = 'lead-1',
    LeadStatus status = LeadStatus.fresh,
    DateTime? createdAt,
    DateTime? lastContactedAt,
    DateTime? nextFollowupAt,
  }) {
    return LeadModel(
      id: id,
      name: 'Test',
      status: status,
      createdAt: createdAt ?? now,
      updatedAt: now,
      lastContactedAt: lastContactedAt,
      nextFollowupAt: nextFollowupAt,
    );
  }

  group('InsightsEngine', () {
    test('returns empty list for empty leads', () {
      final insights = InsightsEngine.generate([], now: now);
      expect(insights, isEmpty);
    });

    test('returns at most 2 insights', () {
      // Create a scenario that could trigger many insights
      final leads = [
        _makeLead(id: '1', status: LeadStatus.followUp, nextFollowupAt: now.subtract(const Duration(days: 1))),
        _makeLead(id: '2', status: LeadStatus.fresh, createdAt: now),
        _makeLead(id: '3', status: LeadStatus.noAnswer),
        _makeLead(id: '4', status: LeadStatus.noAnswer),
        _makeLead(id: '5', status: LeadStatus.noAnswer),
      ];
      final insights = InsightsEngine.generate(leads, now: now);
      expect(insights.length, lessThanOrEqualTo(2));
    });

    test('detects overdue follow-ups', () {
      final leads = [
        _makeLead(
          status: LeadStatus.followUp,
          nextFollowupAt: now.subtract(const Duration(days: 2)),
        ),
      ];
      final insights = InsightsEngine.generate(leads, now: now);
      expect(insights, isNotEmpty);
      expect(insights.any((i) => i.text.toLowerCase().contains('follow')), isTrue);
    });

    test('detects new leads today', () {
      final leads = [
        _makeLead(status: LeadStatus.fresh, createdAt: now),
        _makeLead(id: '2', status: LeadStatus.fresh, createdAt: now),
        _makeLead(id: '3', status: LeadStatus.fresh, createdAt: now),
      ];
      final insights = InsightsEngine.generate(leads, now: now);
      expect(insights, isNotEmpty);
    });

    test('each insight has non-empty text', () {
      final leads = [
        _makeLead(status: LeadStatus.interested, lastContactedAt: now.subtract(const Duration(days: 2))),
      ];
      final insights = InsightsEngine.generate(leads, now: now);
      for (final insight in insights) {
        expect(insight.text, isNotEmpty);
      }
    });
  });
}
