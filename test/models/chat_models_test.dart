import 'package:flutter_test/flutter_test.dart';
import 'package:anis_crm/models/chat_models.dart';

void main() {
  group('ChatChannel', () {
    final now = DateTime(2026, 2, 11, 10, 0);

    final sampleJson = {
      'id': 'ch-1',
      'name': 'General',
      'type': 'general',
      'member_ids': ['u1', 'u2'],
      'member_names': ['Alice', 'Bob'],
      'created_by': 'u1',
      'created_at': now.toIso8601String(),
      'last_message': 'Hello!',
      'last_message_at': now.toIso8601String(),
      'last_message_by': 'Alice',
      'message_count': 5,
    };

    test('fromJson parses all fields', () {
      final ch = ChatChannel.fromJson(sampleJson);

      expect(ch.id, 'ch-1');
      expect(ch.name, 'General');
      expect(ch.type, 'general');
      expect(ch.memberIds, ['u1', 'u2']);
      expect(ch.memberNames, ['Alice', 'Bob']);
      expect(ch.createdBy, 'u1');
      expect(ch.createdAt, now);
      expect(ch.lastMessage, 'Hello!');
      expect(ch.lastMessageBy, 'Alice');
      expect(ch.messageCount, 5);
    });

    test('fromJson handles missing optional fields', () {
      final ch = ChatChannel.fromJson({'id': 'ch-2'});

      expect(ch.id, 'ch-2');
      expect(ch.name, '');
      expect(ch.type, 'direct');
      expect(ch.memberIds, isEmpty);
      expect(ch.memberNames, isEmpty);
      expect(ch.createdBy, '');
      expect(ch.lastMessage, '');
      expect(ch.messageCount, 0);
    });

    test('displayName returns "General" for general channels', () {
      final ch = ChatChannel.fromJson(sampleJson);
      expect(ch.displayName('u1'), 'General');
    });

    test('displayName returns other user name for direct channels', () {
      final ch = ChatChannel.fromJson({
        'id': 'ch-3',
        'name': 'DM',
        'type': 'direct',
        'member_ids': ['u1', 'u2'],
        'member_names': ['Alice', 'Bob'],
        'created_at': now.toIso8601String(),
      });

      // Current user is u1 → shows Bob
      expect(ch.displayName('u1'), 'Bob');
      // Current user is u2 → shows Alice
      expect(ch.displayName('u2'), 'Alice');
    });

    test('displayName falls back to channel name for group or unknown', () {
      final ch = ChatChannel.fromJson({
        'id': 'ch-4',
        'name': 'Sales Team',
        'type': 'group',
        'member_ids': ['u1', 'u2', 'u3'],
        'member_names': ['Alice', 'Bob', 'Carol'],
        'created_at': now.toIso8601String(),
      });

      expect(ch.displayName('u1'), 'Sales Team');
    });

    test('displayName joins member names when no channel name', () {
      final ch = ChatChannel.fromJson({
        'id': 'ch-5',
        'name': '',
        'type': 'group',
        'member_ids': ['u1', 'u2'],
        'member_names': ['Alice', 'Bob'],
        'created_at': now.toIso8601String(),
      });

      expect(ch.displayName('u1'), 'Alice, Bob');
    });
  });

  group('ChatMessage', () {
    final now = DateTime(2026, 2, 11, 10, 0);

    final sampleJson = {
      'id': 'msg-1',
      'channel_id': 'ch-1',
      'sender_id': 'u1',
      'sender_name': 'Alice',
      'text': 'Hello everyone!',
      'ts': now.toIso8601String(),
    };

    test('fromJson parses all fields', () {
      final msg = ChatMessage.fromJson(sampleJson);

      expect(msg.id, 'msg-1');
      expect(msg.channelId, 'ch-1');
      expect(msg.senderId, 'u1');
      expect(msg.senderName, 'Alice');
      expect(msg.text, 'Hello everyone!');
      expect(msg.ts, now);
    });

    test('fromJson handles missing fields with defaults', () {
      final msg = ChatMessage.fromJson({});

      expect(msg.id, '');
      expect(msg.channelId, '');
      expect(msg.senderId, '');
      expect(msg.senderName, '');
      expect(msg.text, '');
    });

    test('isMe returns true for matching userId', () {
      final msg = ChatMessage.fromJson(sampleJson);
      expect(msg.isMe('u1'), isTrue);
    });

    test('isMe returns false for different userId', () {
      final msg = ChatMessage.fromJson(sampleJson);
      expect(msg.isMe('u2'), isFalse);
    });
  });
}
