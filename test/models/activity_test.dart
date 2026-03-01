import 'package:flutter_test/flutter_test.dart';
import 'package:anis_crm/models/activity.dart';

void main() {
  final now = DateTime(2026, 2, 11, 10, 0);

  group('ActivityModel', () {
    final sample = ActivityModel(
      id: 'act-1',
      leadId: 'lead-1',
      type: ActivityType.call,
      text: 'Called about pricing',
      createdAt: now,
    );

    test('toJson and fromJson round-trip', () {
      final json = sample.toJson();
      final restored = ActivityModel.fromJson(json);

      expect(restored.id, sample.id);
      expect(restored.leadId, sample.leadId);
      expect(restored.type, ActivityType.call);
      expect(restored.text, sample.text);
    });

    test('fromJson defaults unknown type to note', () {
      final json = {
        'id': 'act-2',
        'lead_id': 'lead-1',
        'type': 'video_call',
        'text': 'Unknown type test',
        'created_at': now.toIso8601String(),
      };
      final activity = ActivityModel.fromJson(json);
      expect(activity.type, ActivityType.note);
    });

    test('copyWith changes specified fields only', () {
      final updated = sample.copyWith(text: 'Updated note', type: ActivityType.message);

      expect(updated.text, 'Updated note');
      expect(updated.type, ActivityType.message);
      expect(updated.id, sample.id);
      expect(updated.leadId, sample.leadId);
    });
  });
}
