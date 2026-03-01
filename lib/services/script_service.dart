import 'dart:async';
import 'package:anis_crm/models/script.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class ScriptService {
  ScriptService._();
  static final instance = ScriptService._();

  static const _prefsKey = 'scripts_v1';

  final ValueNotifier<List<ScriptModel>> scripts = ValueNotifier<List<ScriptModel>>([]);
  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) {
        final samples = _sampleScripts();
        scripts.value = samples;
        await _saveInternal(samples);
      } else {
        final list = ScriptModel.decodeList(raw);
        // Sanitize: drop malformed entries
        final clean = list.where((s) => s.id.isNotEmpty && s.title.isNotEmpty).toList();
        scripts.value = clean;
        if (clean.length != list.length) await _saveInternal(clean);
      }
    } catch (e) {
      debugPrint('ScriptService load failed: $e');
      // fallback to samples
      final samples = _sampleScripts();
      scripts.value = samples;
    } finally {
      _loaded = true;
    }
  }

  Future<void> _save() async => _saveInternal(scripts.value);

  Future<void> _saveInternal(List<ScriptModel> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, ScriptModel.encodeList(list));
    } catch (e) {
      debugPrint('ScriptService save failed: $e');
    }
  }

  Future<void> addScript({required String title, required String body, String? category}) async {
    await ensureLoaded();
    final now = DateTime.now();
    final s = ScriptModel(id: const Uuid().v4(), title: title, body: body, category: category, createdAt: now, updatedAt: now);
    scripts.value = [...scripts.value, s];
    await _save();
  }

  Future<void> updateScript(ScriptModel script) async {
    await ensureLoaded();
    final list = scripts.value.map((s) => s.id == script.id ? script.copyWith(updatedAt: DateTime.now()) : s).toList();
    scripts.value = list;
    await _save();
  }

  Future<void> deleteScript(String id) async {
    await ensureLoaded();
    scripts.value = scripts.value.where((s) => s.id != id).toList();
    await _save();
  }

  Future<void> resetToSamples() async {
    final samples = _sampleScripts();
    scripts.value = samples;
    await _saveInternal(samples);
  }

  List<ScriptModel> _sampleScripts() {
    final now = DateTime.now();
    return [
      ScriptModel(
        id: const Uuid().v4(),
        title: 'Quick Intro (30s)',
        category: 'Opening',
        body: 'Hi [Name], this is [Your Name] from [Company]. Do you have 30 seconds?\n'
            'We help [ICP] get [Outcome] without [Pain]. If it sounds useful, I can share a 2‑minute overview.',
        createdAt: now,
        updatedAt: now,
      ),
      ScriptModel(
        id: const Uuid().v4(),
        title: 'Discovery Core',
        category: 'Discovery',
        body: '1) What prompted you to look into this now?\n'
            '2) How are you handling [Problem] today?\n'
            '3) What would a successful outcome look like in 90 days?\n'
            '4) Who else is involved in the decision?',
        createdAt: now,
        updatedAt: now,
      ),
      ScriptModel(
        id: const Uuid().v4(),
        title: 'Objection: Too Expensive',
        category: 'Objections',
        body: "Totally fair. Many customers felt that too—until they saw the ROI. If we could show a path to [Desired Outcome] worth 5–10x the cost, would it be worth exploring?",
        createdAt: now,
        updatedAt: now,
      ),
      ScriptModel(
        id: const Uuid().v4(),
        title: 'Closing Next Steps',
        category: 'Closing',
        body: 'Sounds good. Let’s lock next steps: I’ll send a summary and a short proposal. Does [Day/Time] work to review and finalize?',
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}
