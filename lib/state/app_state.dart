import 'package:flutter/foundation.dart';
import 'package:anis_crm/models/lead.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global app state for lightweight flags shared across the app.
/// Minimal by design: only contains connectivity flag for AI provider.
class AppState extends ChangeNotifier {
  // Connectivity to local AI provider
  bool _aiConnected = false;

  // Centralized AI feature toggles (all OFF by default)
  bool _aiPrioritiesEnabled = false;
  bool _aiScoringEnabled = false;
  bool _aiInsightsEnabled = false;
  bool _aiConversationEnabled = false;
  bool _aiCallSummaryEnabled = false;

  // AI Provider & Model configuration
  String _aiProvider = 'ollama';        // 'ollama' | 'openai' | 'custom'
  String _aiDefaultModel = 'qwen2.5:7b';
  String _aiOllamaEndpoint = 'http://localhost:11434';
  String _aiCustomEndpoint = '';
  String _aiCustomApiKey = '';
  double _aiTemperature = 0.7;
  int _aiMaxTokens = 2048;
  bool _aiStreamingEnabled = true;
  bool _aiSmartRouting = false;
  bool _aiAutoSuggest = false;
  bool _aiDailyDigest = false;
  bool _aiTemplatesEnabled = true;

  bool get aiConnected => _aiConnected;
  bool get aiPrioritiesEnabled => _aiPrioritiesEnabled;
  bool get aiScoringEnabled => _aiScoringEnabled;
  bool get aiInsightsEnabled => _aiInsightsEnabled;
  bool get aiConversationEnabled => _aiConversationEnabled;
  bool get aiCallSummaryEnabled => _aiCallSummaryEnabled;

  // AI Provider & Model getters
  String get aiProvider => _aiProvider;
  String get aiDefaultModel => _aiDefaultModel;
  String get aiOllamaEndpoint => _aiOllamaEndpoint;
  String get aiCustomEndpoint => _aiCustomEndpoint;
  String get aiCustomApiKey => _aiCustomApiKey;
  double get aiTemperature => _aiTemperature;
  int get aiMaxTokens => _aiMaxTokens;
  bool get aiStreamingEnabled => _aiStreamingEnabled;
  bool get aiSmartRouting => _aiSmartRouting;
  bool get aiAutoSuggest => _aiAutoSuggest;
  bool get aiDailyDigest => _aiDailyDigest;
  bool get aiTemplatesEnabled => _aiTemplatesEnabled;

  // In-memory Leads filters (persist during navigation only)
  LeadStatus? _filterStatus;
  Set<LeadSource> _filterSources = <LeadSource>{};
  String _filterCampaign = '';

  // Channels connectivity (placeholders, persisted)
  bool _whatsAppConnected = false;
  bool _instagramConnected = false;
  bool _facebookConnected = false;
  bool _webFormsEnabled = false;
  bool _emailChannelEnabled = false;

  // Telephony toggles (placeholders, persisted)
  bool _clickToCallEnabled = false;
  bool _callLoggingEnabled = false;
  bool _callRecordingEnabled = false;
  bool _callTranscriptionEnabled = false;

  // System preferences (placeholders, persisted)
  bool _darkMode = false;
  bool _compactLayout = false;
  bool _notificationsEnabled = false;

  // Integration keys (local dev only)
  String _whatsAppApiKey = '';
  String _telephonyApiKey = '';

  LeadStatus? get filterStatus => _filterStatus;
  Set<LeadSource> get filterSources => _filterSources;
  String get filterCampaign => _filterCampaign;

  // Channels getters
  bool get whatsAppConnected => _whatsAppConnected;
  bool get instagramConnected => _instagramConnected;
  bool get facebookConnected => _facebookConnected;
  bool get webFormsEnabled => _webFormsEnabled;
  bool get emailChannelEnabled => _emailChannelEnabled;

  // Telephony getters
  bool get clickToCallEnabled => _clickToCallEnabled;
  bool get callLoggingEnabled => _callLoggingEnabled;
  bool get callRecordingEnabled => _callRecordingEnabled;
  bool get callTranscriptionEnabled => _callTranscriptionEnabled;

  // Preferences getters
  bool get darkMode => _darkMode;
  bool get compactLayout => _compactLayout;
  bool get notificationsEnabled => _notificationsEnabled;

  // Keys getters
  String get whatsAppApiKey => _whatsAppApiKey;
  String get telephonyApiKey => _telephonyApiKey;

  void setFilterStatus(LeadStatus? s) {
    _filterStatus = s;
    notifyListeners();
  }

  void toggleFilterSource(LeadSource s) {
    if (_filterSources.contains(s)) {
      _filterSources = {..._filterSources}..remove(s);
    } else {
      _filterSources = {..._filterSources, s};
    }
    notifyListeners();
  }

  void clearFilterSources() {
    _filterSources = <LeadSource>{};
    notifyListeners();
  }

  void setFilterCampaign(String v) {
    _filterCampaign = v;
    notifyListeners();
  }

  void clearFilters() {
    _filterStatus = null;
    _filterSources = <LeadSource>{};
    _filterCampaign = '';
    notifyListeners();
  }

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _aiConnected = prefs.getBool('ai_connected') ?? false;
      _aiPrioritiesEnabled = prefs.getBool('ai_priorities_enabled') ?? false;
      _aiScoringEnabled = prefs.getBool('ai_scoring_enabled') ?? false;
      _aiInsightsEnabled = prefs.getBool('ai_insights_enabled') ?? false;
      _aiConversationEnabled = prefs.getBool('ai_conversation_enabled') ?? false;
      _aiCallSummaryEnabled = prefs.getBool('ai_call_summary_enabled') ?? false;

      // AI Provider & Model
      _aiProvider = prefs.getString('ai_provider') ?? 'ollama';
      _aiDefaultModel = prefs.getString('ai_default_model') ?? 'qwen2.5:7b';
      _aiOllamaEndpoint = prefs.getString('ai_ollama_endpoint') ?? 'http://localhost:11434';
      _aiCustomEndpoint = prefs.getString('ai_custom_endpoint') ?? '';
      _aiCustomApiKey = prefs.getString('ai_custom_api_key') ?? '';
      _aiTemperature = prefs.getDouble('ai_temperature') ?? 0.7;
      _aiMaxTokens = prefs.getInt('ai_max_tokens') ?? 2048;
      _aiStreamingEnabled = prefs.getBool('ai_streaming_enabled') ?? true;
      _aiSmartRouting = prefs.getBool('ai_smart_routing') ?? false;
      _aiAutoSuggest = prefs.getBool('ai_auto_suggest') ?? false;
      _aiDailyDigest = prefs.getBool('ai_daily_digest') ?? false;
      _aiTemplatesEnabled = prefs.getBool('ai_templates_enabled') ?? true;

      // Channels
      _whatsAppConnected = prefs.getBool('ch_whatsapp') ?? false;
      _instagramConnected = prefs.getBool('ch_instagram') ?? false;
      _facebookConnected = prefs.getBool('ch_facebook') ?? false;
      _webFormsEnabled = prefs.getBool('ch_webforms') ?? false;
      _emailChannelEnabled = prefs.getBool('ch_email') ?? false;

      // Telephony
      _clickToCallEnabled = prefs.getBool('tel_click_to_call') ?? false;
      _callLoggingEnabled = prefs.getBool('tel_call_logging') ?? false;
      _callRecordingEnabled = prefs.getBool('tel_call_recording') ?? false;
      _callTranscriptionEnabled = prefs.getBool('tel_call_transcription') ?? false;

      // Preferences
      _darkMode = prefs.getBool('pref_dark_mode') ?? false;
      _compactLayout = prefs.getBool('pref_compact_layout') ?? false;
      _notificationsEnabled = prefs.getBool('pref_notifications') ?? false;

      // Keys
      _whatsAppApiKey = prefs.getString('key_whatsapp') ?? '';
      _telephonyApiKey = prefs.getString('key_telephony') ?? '';
    } catch (e) {
      debugPrint('AppState.init failed to load preferences: $e');
      // keep defaults
    }
  }

  void setAiConnected(bool value) {
    if (_aiConnected == value) return;
    _aiConnected = value;
    _persist('ai_connected', value);
    notifyListeners();
  }

  void setAiPrioritiesEnabled(bool value) {
    if (_aiPrioritiesEnabled == value) return;
    _aiPrioritiesEnabled = value;
    _persist('ai_priorities_enabled', value);
    notifyListeners();
  }

  void setAiScoringEnabled(bool value) {
    if (_aiScoringEnabled == value) return;
    _aiScoringEnabled = value;
    _persist('ai_scoring_enabled', value);
    notifyListeners();
  }

  void setAiInsightsEnabled(bool value) {
    if (_aiInsightsEnabled == value) return;
    _aiInsightsEnabled = value;
    _persist('ai_insights_enabled', value);
    notifyListeners();
  }

  void setAiConversationEnabled(bool value) {
    if (_aiConversationEnabled == value) return;
    _aiConversationEnabled = value;
    _persist('ai_conversation_enabled', value);
    notifyListeners();
  }

  void setAiCallSummaryEnabled(bool value) {
    if (_aiCallSummaryEnabled == value) return;
    _aiCallSummaryEnabled = value;
    _persist('ai_call_summary_enabled', value);
    notifyListeners();
  }

  // AI Provider & Model setters
  Future<void> setAiProvider(String v) async {
    if (_aiProvider == v) return;
    _aiProvider = v;
    try { final p = await SharedPreferences.getInstance(); await p.setString('ai_provider', v); } catch (e) { debugPrint('AppState persist ai_provider error: $e'); }
    notifyListeners();
  }

  Future<void> setAiDefaultModel(String v) async {
    if (_aiDefaultModel == v) return;
    _aiDefaultModel = v;
    try { final p = await SharedPreferences.getInstance(); await p.setString('ai_default_model', v); } catch (e) { debugPrint('AppState persist ai_default_model error: $e'); }
    notifyListeners();
  }

  Future<void> setAiOllamaEndpoint(String v) async {
    if (_aiOllamaEndpoint == v) return;
    _aiOllamaEndpoint = v;
    try { final p = await SharedPreferences.getInstance(); await p.setString('ai_ollama_endpoint', v); } catch (e) { debugPrint('AppState persist ai_ollama_endpoint error: $e'); }
    notifyListeners();
  }

  Future<void> setAiCustomEndpoint(String v) async {
    if (_aiCustomEndpoint == v) return;
    _aiCustomEndpoint = v;
    try { final p = await SharedPreferences.getInstance(); await p.setString('ai_custom_endpoint', v); } catch (e) { debugPrint('AppState persist ai_custom_endpoint error: $e'); }
    notifyListeners();
  }

  Future<void> setAiCustomApiKey(String v) async {
    if (_aiCustomApiKey == v) return;
    _aiCustomApiKey = v;
    try { final p = await SharedPreferences.getInstance(); await p.setString('ai_custom_api_key', v); } catch (e) { debugPrint('AppState persist ai_custom_api_key error: $e'); }
    notifyListeners();
  }

  Future<void> setAiTemperature(double v) async {
    if (_aiTemperature == v) return;
    _aiTemperature = v;
    try { final p = await SharedPreferences.getInstance(); await p.setDouble('ai_temperature', v); } catch (e) { debugPrint('AppState persist ai_temperature error: $e'); }
    notifyListeners();
  }

  Future<void> setAiMaxTokens(int v) async {
    if (_aiMaxTokens == v) return;
    _aiMaxTokens = v;
    try { final p = await SharedPreferences.getInstance(); await p.setInt('ai_max_tokens', v); } catch (e) { debugPrint('AppState persist ai_max_tokens error: $e'); }
    notifyListeners();
  }

  void setAiStreamingEnabled(bool v) {
    if (_aiStreamingEnabled == v) return;
    _aiStreamingEnabled = v;
    _persist('ai_streaming_enabled', v);
    notifyListeners();
  }

  void setAiSmartRouting(bool v) {
    if (_aiSmartRouting == v) return;
    _aiSmartRouting = v;
    _persist('ai_smart_routing', v);
    notifyListeners();
  }

  void setAiAutoSuggest(bool v) {
    if (_aiAutoSuggest == v) return;
    _aiAutoSuggest = v;
    _persist('ai_auto_suggest', v);
    notifyListeners();
  }

  void setAiDailyDigest(bool v) {
    if (_aiDailyDigest == v) return;
    _aiDailyDigest = v;
    _persist('ai_daily_digest', v);
    notifyListeners();
  }

  void setAiTemplatesEnabled(bool v) {
    if (_aiTemplatesEnabled == v) return;
    _aiTemplatesEnabled = v;
    _persist('ai_templates_enabled', v);
    notifyListeners();
  }

   // Channels setters
  void setWhatsAppConnected(bool v) {
    if (_whatsAppConnected == v) return;
    _whatsAppConnected = v;
    _persist('ch_whatsapp', v);
    notifyListeners();
  }

  void setInstagramConnected(bool v) {
    if (_instagramConnected == v) return;
    _instagramConnected = v;
    _persist('ch_instagram', v);
    notifyListeners();
  }

  void setFacebookConnected(bool v) {
    if (_facebookConnected == v) return;
    _facebookConnected = v;
    _persist('ch_facebook', v);
    notifyListeners();
  }

  void setWebFormsEnabled(bool v) {
    if (_webFormsEnabled == v) return;
    _webFormsEnabled = v;
    _persist('ch_webforms', v);
    notifyListeners();
  }

  void setEmailChannelEnabled(bool v) {
    if (_emailChannelEnabled == v) return;
    _emailChannelEnabled = v;
    _persist('ch_email', v);
    notifyListeners();
  }

  // Telephony setters
  void setClickToCallEnabled(bool v) {
    if (_clickToCallEnabled == v) return;
    _clickToCallEnabled = v;
    _persist('tel_click_to_call', v);
    notifyListeners();
  }

  void setCallLoggingEnabled(bool v) {
    if (_callLoggingEnabled == v) return;
    _callLoggingEnabled = v;
    _persist('tel_call_logging', v);
    notifyListeners();
  }

  void setCallRecordingEnabled(bool v) {
    if (_callRecordingEnabled == v) return;
    _callRecordingEnabled = v;
    _persist('tel_call_recording', v);
    notifyListeners();
  }

  void setCallTranscriptionEnabled(bool v) {
    if (_callTranscriptionEnabled == v) return;
    _callTranscriptionEnabled = v;
    _persist('tel_call_transcription', v);
    notifyListeners();
  }

  // Preferences setters
  void setDarkMode(bool v) {
    if (_darkMode == v) return;
    _darkMode = v;
    _persist('pref_dark_mode', v);
    notifyListeners();
  }

  void setCompactLayout(bool v) {
    if (_compactLayout == v) return;
    _compactLayout = v;
    _persist('pref_compact_layout', v);
    notifyListeners();
  }

  void setNotificationsEnabled(bool v) {
    if (_notificationsEnabled == v) return;
    _notificationsEnabled = v;
    _persist('pref_notifications', v);
    notifyListeners();
  }

  // Keys setters
  Future<void> setWhatsAppApiKey(String v) async {
    _whatsAppApiKey = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('key_whatsapp', v);
    } catch (e) {
      debugPrint('AppState persist key_whatsapp error: $e');
    }
    notifyListeners();
  }

  Future<void> setTelephonyApiKey(String v) async {
    _telephonyApiKey = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('key_telephony', v);
    } catch (e) {
      debugPrint('AppState persist key_telephony error: $e');
    }
    notifyListeners();
  }

  Future<void> _persist(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      debugPrint('AppState._persist($key) error: $e');
    }
  }
}
