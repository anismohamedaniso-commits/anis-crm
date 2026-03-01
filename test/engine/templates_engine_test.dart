import 'package:flutter_test/flutter_test.dart';
import 'package:anis_crm/engine/templates_engine.dart';

void main() {
  group('TemplatesEngine', () {
    test('returns 6 categories', () {
      final categories = TemplatesEngine.categories();
      expect(categories.length, 6);
    });

    test('each category has id, title, and non-empty templates', () {
      final categories = TemplatesEngine.categories();
      for (final cat in categories) {
        expect(cat.id, isNotEmpty);
        expect(cat.title, isNotEmpty);
        expect(cat.templates, isNotEmpty);
        for (final t in cat.templates) {
          expect(t, isNotEmpty);
        }
      }
    });

    test('category ids are unique', () {
      final categories = TemplatesEngine.categories();
      final ids = categories.map((c) => c.id).toSet();
      expect(ids.length, categories.length);
    });

    test('each category has 3 templates', () {
      final categories = TemplatesEngine.categories();
      for (final cat in categories) {
        expect(cat.templates.length, 3);
      }
    });

    test('expected category ids are present', () {
      final categories = TemplatesEngine.categories();
      final ids = categories.map((c) => c.id).toSet();
      expect(ids, containsAll(['price', 'timing', 'info', 'nudge', 'soft_close', 'corporate']));
    });
  });
}
