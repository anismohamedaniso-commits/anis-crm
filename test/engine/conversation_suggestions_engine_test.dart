import 'package:flutter_test/flutter_test.dart';
import 'package:anis_crm/engine/conversation_suggestions_engine.dart';
import 'package:anis_crm/models/lead.dart';

void main() {
  group('ConversationSuggestionsEngine', () {
    test('returns empty list for null status', () {
      final suggestions = ConversationSuggestionsEngine.forLeadStatus(null);
      expect(suggestions, isEmpty);
    });

    test('fresh status returns 2 suggestions', () {
      final suggestions = ConversationSuggestionsEngine.forLeadStatus(LeadStatus.fresh);
      expect(suggestions.length, 2);
    });

    test('interested status returns 3 suggestions', () {
      final suggestions = ConversationSuggestionsEngine.forLeadStatus(LeadStatus.interested);
      expect(suggestions.length, 3);
    });

    test('followUp status returns 3 suggestions', () {
      final suggestions = ConversationSuggestionsEngine.forLeadStatus(LeadStatus.followUp);
      expect(suggestions.length, 3);
    });

    test('noAnswer status returns 2 suggestions', () {
      final suggestions = ConversationSuggestionsEngine.forLeadStatus(LeadStatus.noAnswer);
      expect(suggestions.length, 2);
    });

    test('notInterested status returns 1 suggestion', () {
      final suggestions = ConversationSuggestionsEngine.forLeadStatus(LeadStatus.notInterested);
      expect(suggestions.length, 1);
    });

    test('converted status returns 2 suggestions', () {
      final suggestions = ConversationSuggestionsEngine.forLeadStatus(LeadStatus.converted);
      expect(suggestions.length, 2);
    });

    test('closed status returns 1 suggestion', () {
      final suggestions = ConversationSuggestionsEngine.forLeadStatus(LeadStatus.closed);
      expect(suggestions.length, 1);
    });

    test('all suggestions have type "reply"', () {
      for (final status in LeadStatus.values) {
        final suggestions = ConversationSuggestionsEngine.forLeadStatus(status);
        for (final s in suggestions) {
          expect(s.type, SuggestionType.reply);
        }
      }
    });

    test('all suggestions have non-empty text', () {
      for (final status in LeadStatus.values) {
        final suggestions = ConversationSuggestionsEngine.forLeadStatus(status);
        for (final s in suggestions) {
          expect(s.text, isNotEmpty);
        }
      }
    });
  });
}
