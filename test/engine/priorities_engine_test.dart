import 'package:flutter_test/flutter_test.dart';
import 'package:anis_crm/engine/priorities_engine.dart';
import 'package:anis_crm/models/lead.dart';

void main() {
  final now = DateTime(2026, 2, 11, 10, 0);

  LeadModel _makeLead({
    String id = 'lead-1',
    String name = 'Test',
    LeadStatus status = LeadStatus.fresh,
    DateTime? createdAt,
    DateTime? lastContactedAt,
    DateTime? nextFollowupAt,
    String? phone,
  }) {
    return LeadModel(
      id: id,
      name: name,
      status: status,
      phone: phone,
      createdAt: createdAt ?? now.subtract(const Duration(days: 5)),
      updatedAt: now,
      lastContactedAt: lastContactedAt,
      nextFollowupAt: nextFollowupAt,
    );
  }

  group('PrioritiesEngine', () {
    test('returns "on track" fallback for empty leads', () {
      final priorities = PrioritiesEngine.generate([], now: now);
      expect(priorities.length, 1);
      expect(priorities.first.title.toLowerCase(), contains('track'));
    });

    test('returns at most 3 priorities', () {
      final leads = List.generate(10, (i) => _makeLead(
        id: 'lead-$i',
        status: LeadStatus.followUp,
        nextFollowupAt: now.subtract(Duration(days: i + 1)),
      ));
      final priorities = PrioritiesEngine.generate(leads, now: now);
      expect(priorities.length, lessThanOrEqualTo(3));
    });

    test('detects overdue follow-ups with openLead action', () {
      final leads = [
        _makeLead(
          status: LeadStatus.followUp,
          nextFollowupAt: now.subtract(const Duration(days: 1)),
        ),
      ];
      final priorities = PrioritiesEngine.generate(leads, now: now);
      expect(priorities, isNotEmpty);
      expect(priorities.first.action, PriorityAction.openLead);
    });

    test('suggests call for interested leads not contacted today', () {
      final leads = [
        _makeLead(
          status: LeadStatus.interested,
          lastContactedAt: now.subtract(const Duration(days: 2)),
          phone: '+1234567890',
        ),
      ];
      final priorities = PrioritiesEngine.generate(leads, now: now);
      expect(priorities, isNotEmpty);
      expect(priorities.any((p) => p.action == PriorityAction.call), isTrue);
    });

    test('detects new leads today', () {
      final leads = [
        _makeLead(
          status: LeadStatus.fresh,
          createdAt: now,
        ),
      ];
      final priorities = PrioritiesEngine.generate(leads, now: now);
      expect(priorities, isNotEmpty);
    });

    test('all priorities have non-empty title and reason', () {
      final leads = [
        _makeLead(
          status: LeadStatus.followUp,
          nextFollowupAt: now.subtract(const Duration(days: 1)),
        ),
        _makeLead(
          id: 'lead-2',
          status: LeadStatus.interested,
          lastContactedAt: now.subtract(const Duration(days: 1)),
        ),
      ];
      final priorities = PrioritiesEngine.generate(leads, now: now);
      for (final p in priorities) {
        expect(p.title, isNotEmpty);
        expect(p.reason, isNotEmpty);
      }
    });
  });
}
