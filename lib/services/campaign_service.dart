import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/campaign.dart';

/// Client-side campaign CRUD persisted via SharedPreferences.
///
/// Campaigns are lightweight metadata objects — the lead–campaign link
/// is stored in the existing `lead.campaign` string field (matched by
/// campaign [id]).
class CampaignService {
  static const _prefsKey = 'campaigns_v1';
  static final CampaignService instance = CampaignService._();
  CampaignService._();

  final ValueNotifier<List<CampaignModel>> campaigns =
      ValueNotifier<List<CampaignModel>>(<CampaignModel>[]);

  bool _loaded = false;

  // ─── Load ─────────────────────────────────────────────────────────────

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        campaigns.value = list.map((m) => CampaignModel.fromJson(m)).toList();
      }
    } catch (e) {
      debugPrint('CampaignService.load error: $e');
    } finally {
      _loaded = true;
    }
  }

  // ─── Persist ──────────────────────────────────────────────────────────

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = campaigns.value.map((c) => c.toJson()).toList();
      await prefs.setString(_prefsKey, jsonEncode(json));
    } catch (e) {
      debugPrint('CampaignService._save error: $e');
    }
  }

  // ─── CRUD ─────────────────────────────────────────────────────────────

  Future<CampaignModel> create({
    required String name,
    required String market,
    required double budget,
    required DateTime startDate,
  }) async {
    final now = DateTime.now();
    final c = CampaignModel(
      id: const Uuid().v4(),
      name: name,
      market: market,
      budget: budget,
      startDate: startDate,
      createdAt: now,
    );
    campaigns.value = [...campaigns.value, c];
    await _save();
    return c;
  }

  Future<void> update(CampaignModel updated) async {
    campaigns.value = campaigns.value
        .map((c) => c.id == updated.id ? updated : c)
        .toList();
    await _save();
  }

  Future<void> delete(String id) async {
    campaigns.value = campaigns.value.where((c) => c.id != id).toList();
    await _save();
  }

  CampaignModel? byId(String id) {
    try {
      return campaigns.value.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// All campaigns visible for a given market id.
  /// Includes campaigns with market == 'all'.
  List<CampaignModel> forMarket(String marketId) {
    return campaigns.value
        .where((c) => c.market == marketId || c.market == 'all')
        .toList();
  }
}
