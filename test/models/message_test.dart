import 'package:flutter_test/flutter_test.dart';
import 'package:anis_crm/models/message.dart';

void main() {
  final now = DateTime(2026, 2, 11, 10, 0);

  group('MessageModel', () {
    final sample = MessageModel(
      id: 'msg-1',
      leadId: 'lead-1',
      phone: '+1234567890',
      channel: 'whatsapp',
      direction: MessageDirection.outgoing,
      text: 'Hello!',
      status: MessageStatus.sent,
      createdAt: now,
      updatedAt: now,
    );

    test('toJson and fromJson round-trip', () {
      final json = sample.toJson();
      final restored = MessageModel.fromJson(json);

      expect(restored.id, sample.id);
      expect(restored.leadId, sample.leadId);
      expect(restored.phone, sample.phone);
      expect(restored.channel, 'whatsapp');
      expect(restored.direction, MessageDirection.outgoing);
      expect(restored.text, sample.text);
      expect(restored.status, MessageStatus.sent);
    });

    test('fromJson accepts "out" as outgoing direction', () {
      final json = {
        'id': 'msg-2',
        'lead_id': 'lead-1',
        'phone': '+1234567890',
        'channel': 'WhatsApp',
        'direction': 'out',
        'text': 'Test',
        'status': 'sent',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };
      final msg = MessageModel.fromJson(json);
      expect(msg.direction, MessageDirection.outgoing);
      expect(msg.channel, 'whatsapp'); // should be lowercased
    });

    test('copyWith changes specified fields', () {
      final updated = sample.copyWith(
        text: 'Updated message',
        status: MessageStatus.delivered,
      );
      expect(updated.text, 'Updated message');
      expect(updated.status, MessageStatus.delivered);
      expect(updated.id, sample.id);
    });
  });
}
