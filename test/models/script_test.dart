import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:anis_crm/models/script.dart';

void main() {
  final now = DateTime(2026, 2, 11, 10, 0);

  group('ScriptModel', () {
    final sample = ScriptModel(
      id: 'script-1',
      title: 'Welcome Script',
      body: 'Hi {{name}}, welcome to our service!',
      category: 'greeting',
      createdAt: now,
      updatedAt: now,
    );

    test('toJson and fromJson round-trip', () {
      final json = sample.toJson();
      final restored = ScriptModel.fromJson(json);

      expect(restored.id, sample.id);
      expect(restored.title, sample.title);
      expect(restored.body, sample.body);
      expect(restored.category, sample.category);
    });

    test('encodeList and decodeList round-trip', () {
      final scripts = [sample, sample.copyWith(id: 'script-2', title: 'Follow Up')];
      final encoded = ScriptModel.encodeList(scripts);
      final decoded = ScriptModel.decodeList(encoded);

      expect(decoded.length, 2);
      expect(decoded[0].title, 'Welcome Script');
      expect(decoded[1].title, 'Follow Up');
    });

    test('decodeList returns empty list for invalid JSON', () {
      expect(ScriptModel.decodeList('not json'), isEmpty);
      expect(ScriptModel.decodeList(''), isEmpty);
    });

    test('copyWith changes only specified fields', () {
      final updated = sample.copyWith(title: 'New Title');
      expect(updated.title, 'New Title');
      expect(updated.body, sample.body);
      expect(updated.id, sample.id);
    });
  });
}
