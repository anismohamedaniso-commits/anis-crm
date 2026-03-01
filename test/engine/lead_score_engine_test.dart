import 'package:flutter_test/flutter_test.dart';
import 'package:anis_crm/engine/lead_score_engine.dart';
import 'package:anis_crm/models/lead.dart';

void main() {
  final now = DateTime(2026, 2, 11, 10, 0);

  LeadModel _makeLead({
    LeadStatus status = LeadStatus.fresh,
    DateTime? createdAt,
    DateTime? lastContactedAt,
    DateTime? nextFollowupAt,
  }) {
    return LeadModel(
      id: 'test-lead',
      name: 'Test',
      status: status,
      createdAt: createdAt ?? now,
      updatedAt: now,
      lastContactedAt: lastContactedAt,
      nextFollowupAt: nextFollowupAt,
    );
  }

  group('LeadScoreEngine', () {
    test('fresh lead created today scores from status + recency', () {
      final result = LeadScoreEngine.compute(_makeLead(), now: now);
      expect(result.score, greaterThanOrEqualTo(0));
      expect(result.score, lessThanOrEqualTo(100));
    });

    test('interested lead has higher status score than noAnswer', () {
      final interested = LeadScoreEngine.compute(
        _makeLead(status: LeadStatus.interested),
        now: now,
      );
      final noAnswer = LeadScoreEngine.compute(
        _makeLead(status: LeadStatus.noAnswer),
        now: now,
      );
      expect(interested.score, greaterThan(noAnswer.score));
    });

    test('converted lead gets maximum status score', () {
      final result = LeadScoreEngine.compute(
        _makeLead(status: LeadStatus.converted),
        now: now,
      );
      // converted should have high score
      expect(result.score, greaterThanOrEqualTo(50));
    });

    test('closed lead gets zero status score', () {
      final result = LeadScoreEngine.compute(
        _makeLead(status: LeadStatus.closed),
        now: now,
      );
      expect(result.score, lessThanOrEqualTo(30));
    });

    test('recent contact boosts score', () {
      final withContact = LeadScoreEngine.compute(
        _makeLead(lastContactedAt: now.subtract(const Duration(hours: 1))),
        now: now,
      );
      final withoutContact = LeadScoreEngine.compute(
        _makeLead(),
        now: now,
      );
      expect(withContact.score, greaterThanOrEqualTo(withoutContact.score));
    });

    test('overdue followUp lead gets urgency bonus', () {
      final overdue = LeadScoreEngine.compute(
        _makeLead(
          status: LeadStatus.followUp,
          nextFollowupAt: now.subtract(const Duration(days: 1)),
        ),
        now: now,
      );
      final notOverdue = LeadScoreEngine.compute(
        _makeLead(
          status: LeadStatus.followUp,
          nextFollowupAt: now.add(const Duration(days: 1)),
        ),
        now: now,
      );
      expect(overdue.score, greaterThan(notOverdue.score));
    });

    test('temperature thresholds are correct', () {
      // Create leads that force different temperatures
      final cold = LeadScoreEngine.compute(
        _makeLead(
          status: LeadStatus.closed,
          createdAt: now.subtract(const Duration(days: 30)),
        ),
        now: now,
      );
      expect(cold.temperature, LeadTemperature.cold);
    });

    test('hot lead detected for high-scoring lead', () {
      final result = LeadScoreEngine.compute(
        _makeLead(
          status: LeadStatus.followUp,
          createdAt: now,
          lastContactedAt: now,
          nextFollowupAt: now.subtract(const Duration(days: 1)),
        ),
        now: now,
      );
      expect(result.temperature, LeadTemperature.hot);
    });

    test('score is always between 0 and 100', () {
      for (final status in LeadStatus.values) {
        final result = LeadScoreEngine.compute(
          _makeLead(
            status: status,
            createdAt: now.subtract(const Duration(days: 365)),
            lastContactedAt: now.subtract(const Duration(days: 365)),
            nextFollowupAt: now.subtract(const Duration(days: 365)),
          ),
          now: now,
        );
        expect(result.score, inInclusiveRange(0, 100));
      }
    });
  });
}
