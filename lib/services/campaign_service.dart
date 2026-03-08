import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/campaign.dart';
import 'api_client.dart';

/// Server-backed campaign CRUD — shared across all users.
///
/// Campaigns are lightweight metadata objects — the lead–campaign link
/// is stored in the existing `lead.campaign` string field (matched by
/// campaign [id]).
class CampaignService {
  static final CampaignService instance = CampaignService._();
  CampaignService._();

  final ValueNotifier<List<CampaignModel>> campaigns =
      ValueNotifier<List<CampaignModel>>(<CampaignModel>[]);

  bool _loaded = false;

  // ─── Load ─────────────────────────────────────────────────────────────

  /// Fetch all campaigns from the server API.
  /// Safe to call multiple times — skips if already loaded.
  /// Call [reload] to force a fresh fetch.
  Future<void> load() async {
    if (_loaded) return;
    await reload();
    _loaded = true;
  }

  /// Force-fetch campaigns from the server, bypassing the _loaded guard.
  Future<void> reload() async {
    try {
      final list = await ApiClient.instance.getCampaigns();
      if (list != null) {
        campaigns.value =
            list.map((m) => CampaignModel.fromJson(m)).toList();
      }
    } catch (e) {
      debugPrint('CampaignService.load error: $e');
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

    final result = await ApiClient.instance.createCampaign(c.toJson());
    final saved = result != null ? CampaignModel.fromJson(result) : c;

    campaigns.value = [...campaigns.value, saved];
    return saved;
  }

  Future<void> update(CampaignModel updated) async {
    await ApiClient.instance.updateCampaign(updated.id, updated.toJson());
    campaigns.value = campaigns.value
        .map((c) => c.id == updated.id ? updated : c)
        .toList();
  }

  Future<void> delete(String id) async {
    await ApiClient.instance.deleteCampaign(id);
    campaigns.value = campaigns.value.where((c) => c.id != id).toList();
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
