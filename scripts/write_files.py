#!/usr/bin/env python3
"""Write tailored Tick & Talk content to Flutter engine files."""
import os

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 1. Conversation Suggestions Engine
suggestions = r"""import 'package:anis_crm/models/lead.dart';

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
"""

# 2. Templates Engine
templates = r"""// Objection & follow-up templates tailored for Tick & Talk / Speekr.ai
import 'package:flutter/foundation.dart';

class TemplateCategory {
  const TemplateCategory({required this.id, required this.title, required this.templates});
  final String id;
  final String title;
  final List<String> templates;
}

class TemplatesEngine {
  static List<TemplateCategory> categories() {
    try {
      return const [
        TemplateCategory(
          id: 'price',
          title: 'Price Objection',
          templates: [
            "I totally understand. But consider this \u2014 we've trained 5000+ people and 90% of our business comes from recommendations. The ROI speaks for itself.",
            "Great question! Our Masterclass is a 3-month transformational journey, not just a workshop. The results last a lifetime.",
            "We also have Speekr.ai starting at \$23/month if you want to start with AI-powered practice first.",
          ],
        ),
        TemplateCategory(
          id: 'timing',
          title: 'Timing Objection',
          templates: [
            "No problem! Our next Masterclass batch is starting soon though and spots are limited. Can I hold a seat for you?",
            "That's fine! In the meantime, you can start with our Online Masterclass \u2014 learn at your own pace, anytime.",
            "Totally understand. When would be the best time to reconnect? I'll send you a calendar invite.",
          ],
        ),
        TemplateCategory(
          id: 'info',
          title: 'Needs More Info',
          templates: [
            "Of course! We offer: 3-month Masterclass, 2-day Corporate Accelerator, Online Masterclass, and Speekr.ai (AI practice). Which interests you?",
            "Happy to explain! Our Presentation Masterclass is a full transformational journey \u2014 not just theory. You'll practice with real audiences.",
            "Would you like me to send you details on WhatsApp? I can include testimonials from Shark Tank Egypt entrepreneurs we've trained.",
          ],
        ),
        TemplateCategory(
          id: 'nudge',
          title: 'Follow-Up Nudge',
          templates: [
            "Just checking in! Did you get a chance to review the Masterclass details I sent?",
            "Quick update \u2014 we just had another successful batch graduate. Would love to have you in the next one!",
            "Hey! Wanted to share that our recent graduates are already seeing results in their presentations. Still interested?",
          ],
        ),
        TemplateCategory(
          id: 'soft_close',
          title: 'Soft Close',
          templates: [
            "Ready to join the next Masterclass batch? I can register you right now \u2014 just need a few details.",
            "Shall we get you started? The early bird offer won't last long!",
            "Would you like to start with the full Masterclass or try Speekr.ai first to get a taste of our methodology?",
          ],
        ),
        TemplateCategory(
          id: 'corporate',
          title: 'Corporate Pitch',
          templates: [
            "We offer a 2-day Corporate Accelerator that dramatically boosts your team's presentation skills. Companies like Dell and L'Or\u00e9al trust us.",
            "For teams, we also have Speekr.ai Teams (\$48/user/month) \u2014 AI-powered practice between sessions. L'Or\u00e9al saw 2x faster communication fluency.",
            "Our corporate programs include both on-site training and ongoing AI practice via Speekr. Want me to set up a demo for your team?",
          ],
        ),
      ];
    } catch (e) {
      debugPrint('TemplatesEngine error: $e');
      return const [];
    }
  }
}
"""

# Write files
with open(os.path.join(BASE, 'lib/engine/conversation_suggestions_engine.dart'), 'w') as f:
    f.write(suggestions)
print("Wrote conversation_suggestions_engine.dart")

with open(os.path.join(BASE, 'lib/engine/templates_engine.dart'), 'w') as f:
    f.write(templates)
print("Wrote templates_engine.dart")
