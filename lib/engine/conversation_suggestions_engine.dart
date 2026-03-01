import 'package:anis_crm/models/lead.dart';

/// Rule-based suggestion engine. Tailored for Tick & Talk / Speekr.ai sales.
class ConversationSuggestionsEngine {
  static List<Suggestion> forLeadStatus(LeadStatus? status) {
    if (status == null) return const [];
    switch (status) {
      case LeadStatus.fresh:
        return const [
          Suggestion(text: "Hi! This is [Name] from Tick & Talk. We've trained 5000+ people in presentation skills \u2014 are you interested in our Masterclass?", type: SuggestionType.reply),
          Suggestion(text: "Thanks for your interest! We're Shark Tank Egypt's official partner. Would you like to know more about our Presentation Masterclass?", type: SuggestionType.reply),
        ];
      case LeadStatus.interested:
        return const [
          Suggestion(text: "Great to hear! Our 3-month Presentation Masterclass starts soon \u2014 limited spots. Can we schedule a quick call?", type: SuggestionType.reply),
          Suggestion(text: "Awesome! Would you prefer our on-site Masterclass or the Online Masterclass (learn at your own pace)?", type: SuggestionType.reply),
          Suggestion(text: "Glad you're interested! We're Shark Tank Egypt's casting partner. I can walk you through how we'll transform your skills.", type: SuggestionType.reply),
        ];
      case LeadStatus.followUp:
        return const [
          Suggestion(text: "Hi! Just following up \u2014 did you check the Masterclass details? Happy to answer any questions.", type: SuggestionType.reply),
          Suggestion(text: "Quick update! Our next batch is filling up. Want me to reserve your spot?", type: SuggestionType.reply),
          Suggestion(text: "Hey! 90% of our clients come through recommendations. Here's what recent graduates say.", type: SuggestionType.reply),
        ];
      case LeadStatus.noAnswer:
        return const [
          Suggestion(text: "Hi! I tried reaching you earlier. Whenever you're free, I'd love to tell you about Tick & Talk's Presentation Masterclass.", type: SuggestionType.reply),
          Suggestion(text: "Hey! We have a special offer for our upcoming Masterclass. Interested in the details?", type: SuggestionType.reply),
        ];
      case LeadStatus.notInterested:
        return const [
          Suggestion(text: "Totally understand! If you ever want to sharpen your presentation skills, we're here. Also check out Speekr.ai \u2014 free AI practice trial!", type: SuggestionType.reply),
        ];
      case LeadStatus.converted:
        return const [
          Suggestion(text: "Welcome to the Tick & Talk family! You're joining 5000+ graduates. Here's what to expect next.", type: SuggestionType.reply),
          Suggestion(text: "So excited to have you on board. Your presentation transformation starts now!", type: SuggestionType.reply),
        ];
      case LeadStatus.closed:
        return const [
          Suggestion(text: "Thanks for your time! If anything changes, we'd love to help you become a confident presenter.", type: SuggestionType.reply),
        ];
    }
  }
}

class SuggestionType {
  static const String reply = 'reply';
}

class Suggestion {
  final String text;
  final String type;
  const Suggestion({required this.text, required this.type});
}
