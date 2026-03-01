// Objection & follow-up templates tailored for Tick & Talk / Speekr.ai
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
