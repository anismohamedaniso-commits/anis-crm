import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:anis_crm/state/app_state.dart';
import 'package:anis_crm/models/lead.dart';
import 'package:anis_crm/models/activity.dart';
import 'package:anis_crm/engine/priorities_engine.dart';
import 'package:anis_crm/engine/lead_score_engine.dart';
import 'package:anis_crm/engine/conversation_suggestions_engine.dart';
import 'package:anis_crm/engine/insights_engine.dart';
import 'package:anis_crm/openai/openai_config.dart';
import 'package:anis_crm/services/ai_gateway.dart';
import 'package:anis_crm/services/ai_service.dart';
import 'package:anis_crm/services/lead_service.dart';
import 'package:anis_crm/services/activity_service.dart';

/// Centralized AI execution layer.
/// - All AI features are routed here.
/// - Toggles and connectivity are respected automatically.
/// - Safe fallbacks always apply on error/timeouts.
class AiExecutor {
  AiExecutor._();
  static final AiExecutor instance = AiExecutor._();

  final OpenAIClient _openai = const OpenAIClient();

  // Optional prefetch timer/debouncer for lead list changes
  Timer? _prefetchDebounce;

  // ── In-memory TTL cache (5 min) ──
  static const _cacheTtl = Duration(minutes: 5);
  final Map<String, _CacheEntry> _cache = {};

  T? _cacheGet<T>(String key) {
    final entry = _cache[key];
    if (entry != null && DateTime.now().difference(entry.time) < _cacheTtl) {
      return entry.value as T;
    }
    _cache.remove(key);
    return null;
  }

  void _cacheSet(String key, dynamic value) {
    _cache[key] = _CacheEntry(DateTime.now(), value);
  }

  /// Invalidate all cached AI results (call after lead mutations).
  void invalidateCache() => _cache.clear();

  Future<void> init(AppState app) async {
    try {
      final connected = await _openai.connectivityProbe();
      app.setAiConnected(connected);
    } catch (e) {
      debugPrint('AiExecutor.init probe error: $e');
      app.setAiConnected(false);
    }

    // Listen to lead list changes to auto-trigger AI where applicable.
    // This keeps behavior automatic without UI changes.
    LeadService.instance.leads.addListener(() {
      _prefetchDebounce?.cancel();
      invalidateCache(); // Clear stale AI results when leads change
      _prefetchDebounce = Timer(const Duration(milliseconds: 250), () {
        // Pre-warm priorities if enabled
        if (app.aiConnected && app.aiPrioritiesEnabled) {
          final leads = LeadService.instance.leads.value;
          // Fire and forget; UI will still use safe fallbacks.
          priorities(app, leads).catchError((_) => <LeadPriority>[]);
        }
        // Future extension: insights/scoring prefetch
      });
    });
  }

  /// PRIORITIES (Dashboard)
  Future<List<LeadPriority>> priorities(AppState app, List<LeadModel> leads) async {
    // When disabled or disconnected, return deterministic priorities.
    if (!app.aiConnected || !app.aiPrioritiesEnabled) {
      return PrioritiesEngine.generate(leads);
    }

    // Check cache first
    final cached = _cacheGet<List<LeadPriority>>('priorities');
    if (cached != null) return cached;

    // Try OpenAI first if configured
    if (_openai.isConfigured) {
      try {
        final minimal = leads
            .map((l) => {
                  'name': l.name,
                  'status': l.status.name,
                  'created_at': l.createdAt.toIso8601String(),
                  'last_contacted_at': l.lastContactedAt?.toIso8601String(),
                  'next_followup_at': l.nextFollowupAt?.toIso8601String(),
                })
            .toList();
        final items = await _openai.generatePriorities(minimal);
        final mapped = items.map(_mapPriority).whereType<LeadPriority>().toList();
        if (mapped.isNotEmpty) {
          final result = mapped.take(3).toList();
          _cacheSet('priorities', result);
          return result;
        }
      } catch (e) {
        debugPrint('AiExecutor.priorities OpenAI error: $e');
      }
    }

    // Fallback to local gateway (e.g., Ollama) if available
    try {
      final result = await AiGateway.instance.generatePrioritiesFromLocalAi(leads);
      _cacheSet('priorities', result);
      return result;
    } catch (e) {
      debugPrint('AiExecutor.priorities local error: $e');
      // Final fallback: deterministic
      return PrioritiesEngine.generate(leads);
    }
  }

  LeadPriority? _mapPriority(Map<String, dynamic> m) {
    try {
      final title = (m['title'] ?? '').toString();
      final reason = (m['reason'] ?? '').toString();
      final actionStr = (m['action'] ?? '').toString().toLowerCase();
      final action = switch (actionStr) {
        'call' => PriorityAction.call,
        'message' => PriorityAction.message,
        'open lead' || 'open_lead' || 'openlead' => PriorityAction.openLead,
        _ => PriorityAction.openLead,
      };
      if (title.isEmpty || reason.isEmpty) return null;
      // Try to resolve a lead from the title for contact info
      final leads = LeadService.instance.leads.value;
      LeadModel? matched;
      for (final l in leads) {
        if (title.toLowerCase().contains(l.name.toLowerCase())) {
          matched = l;
          break;
        }
      }
      return LeadPriority(title: title, reason: reason, action: action, leadId: matched?.id, phone: matched?.phone, email: matched?.email);
    } catch (_) {
      return null;
    }
  }

  /// LEAD SCORING (Lead Detail)
  /// When AI scoring is enabled + connected, calls the LLM for a richer score.
  /// Falls back to deterministic scoring on error or when disabled.
  LeadScoreResult leadScore(AppState app, LeadModel lead) {
    // Always return deterministic immediately; AI scoring is async supplement
    return LeadScoreEngine.compute(lead);
  }

  /// Async AI-powered lead scoring. Returns a richer result with an AI reason.
  /// Callers should show the deterministic score immediately, then update if this returns.
  Future<AiScoreResult> aiLeadScore(AppState app, LeadModel lead) async {
    final deterministic = LeadScoreEngine.compute(lead);
    if (!app.aiConnected || !app.aiScoringEnabled) {
      return AiScoreResult(score: deterministic.score, temperature: deterministic.temperature, reason: null, isAi: false);
    }

    try {
      // Gather activity context
      final activities = ActivityService.instance.byLead.value[lead.id] ?? [];
      final activitySummary = activities.take(10).map((a) => '${a.type.name}: ${a.text ?? "(no note)"}').join('\n');

      final prompt = 'You are a sales lead scoring AI for Tick & Talk (presentation training) and Speekr.ai (AI communication training SaaS).\n'
          'Score this lead 0-100 based on how likely they are to enroll in a Masterclass or subscribe to Speekr.\n'
          'Consider: status, recency of contact, follow-up urgency, and engagement signals.\n\n'
          'Lead: ${lead.name}\n'
          'Status: ${lead.status.name}\n'
          'Source: ${lead.source.name}\n'
          'Created: ${lead.createdAt.toIso8601String()}\n'
          'Last contacted: ${lead.lastContactedAt?.toIso8601String() ?? "never"}\n'
          'Next follow-up: ${lead.nextFollowupAt?.toIso8601String() ?? "none"}\n'
          'Campaign: ${lead.campaign ?? "none"}\n'
          '\nRecent activities:\n${activitySummary.isEmpty ? "None" : activitySummary}\n'
          '\nRespond ONLY with JSON: {"score": <int 0-100>, "reason": "<one sentence about their likelihood to convert for Tick & Talk>"}';

      final resp = await AiService.instance.chat([{'role': 'user', 'content': prompt}]);
      // Parse JSON from response
      final cleaned = resp.replaceAll('```json', '').replaceAll('```', '').trim();
      // Try to find JSON object in the response
      final match = RegExp(r'\{[^}]+\}').firstMatch(cleaned);
      if (match != null) {
        final js = jsonDecode(match.group(0)!) as Map<String, dynamic>;
        final aiScore = (js['score'] as num?)?.toInt() ?? deterministic.score;
        final reason = js['reason'] as String?;
        final clamped = aiScore.clamp(0, 100);
        return AiScoreResult(
          score: clamped,
          temperature: clamped >= 60 ? LeadTemperature.hot : (clamped >= 30 ? LeadTemperature.warm : LeadTemperature.cold),
          reason: reason,
          isAi: true,
        );
      }
    } catch (e) {
      debugPrint('AiExecutor.aiLeadScore error: $e');
    }
    return AiScoreResult(score: deterministic.score, temperature: deterministic.temperature, reason: null, isAi: false);
  }

  /// CONVERSATION SUGGESTIONS (Lead Detail)
  /// When AI is enabled, generates personalized suggestions via LLM.
  List<Suggestion> suggestions(AppState app, LeadStatus? status) {
    // Return deterministic immediately; AI version is async
    return ConversationSuggestionsEngine.forLeadStatus(status);
  }

  /// Async AI-powered conversation suggestions.
  Future<List<Suggestion>> aiSuggestions(AppState app, LeadModel lead) async {
    if (!app.aiConnected || !app.aiConversationEnabled) {
      return ConversationSuggestionsEngine.forLeadStatus(lead.status);
    }

    try {
      final activities = ActivityService.instance.byLead.value[lead.id] ?? [];
      final recentMessages = activities
          .where((a) => a.type == ActivityType.message || a.type == ActivityType.note)
          .take(5)
          .map((a) => a.text ?? '')
          .where((t) => t.isNotEmpty)
          .join('\n');

      final prompt = 'You are a sales assistant for Tick & Talk (presentation training company, Shark Tank Egypt partner, 5000+ trained) and Speekr.ai (AI communication training SaaS).\n'
          'Generate 3 short, copy-paste ready WhatsApp message suggestions for this lead.\n'
          'Tailor messages to our products: Presentation Masterclass (3-month), Corporate Accelerator (2-day), Online Masterclass, or Speekr.ai.\n'
          'Use the lead name for personalization. Mix English with occasional Arabic phrases.\n\n'
          'Lead: ${lead.name}\n'
          'Status: ${lead.status.name}\n'
          'Source: ${lead.source.name}\n'
          'Last contacted: ${lead.lastContactedAt?.toIso8601String() ?? "never"}\n'
          '\nRecent conversation:\n${recentMessages.isEmpty ? "No messages yet" : recentMessages}\n'
          '\nRespond ONLY with a JSON array of 3 strings. Each should mention Tick & Talk or Speekr by name.';

      final resp = await AiService.instance.chat([{'role': 'user', 'content': prompt}]);
      final cleaned = resp.replaceAll('```json', '').replaceAll('```', '').trim();
      final match = RegExp(r'\[[\s\S]*\]').firstMatch(cleaned);
      if (match != null) {
        final list = (jsonDecode(match.group(0)!) as List).cast<String>();
        if (list.isNotEmpty) {
          return list.map((t) => Suggestion(text: t, type: SuggestionType.reply)).toList();
        }
      }
    } catch (e) {
      debugPrint('AiExecutor.aiSuggestions error: $e');
    }
    return ConversationSuggestionsEngine.forLeadStatus(lead.status);
  }

  /// INSIGHTS (Dashboard)
  /// When AI is enabled, calls dailyInsights for richer analysis.
  List<Insight> insights(AppState app, List<LeadModel> leads) {
    // Return deterministic immediately; AI version is async
    return InsightsEngine.generate(leads);
  }

  /// Async AI-powered daily insights.
  Future<String> aiDailyInsights(AppState app, List<LeadModel> leads) async {
    if (!app.aiConnected || !app.aiInsightsEnabled) {
      // Return deterministic as text
      final det = InsightsEngine.generate(leads);
      return det.map((i) => '• ${i.text}').join('\n');
    }

    // Check cache first
    final cached = _cacheGet<String>('daily_insights');
    if (cached != null) return cached;

    try {
      final result = await AiService.instance.dailyInsights(leads);
      _cacheSet('daily_insights', result);
      return result;
    } catch (e) {
      debugPrint('AiExecutor.aiDailyInsights error: $e');
      final det = InsightsEngine.generate(leads);
      return det.map((i) => '• ${i.text}').join('\n');
    }
  }
}

/// Extended score result with optional AI reasoning.
class AiScoreResult {
  final int score;
  final LeadTemperature temperature;
  final String? reason;
  final bool isAi;
  const AiScoreResult({required this.score, required this.temperature, this.reason, this.isAi = false});
}

/// Simple cache entry with timestamp.
class _CacheEntry {
  final DateTime time;
  final dynamic value;
  const _CacheEntry(this.time, this.value);
}
