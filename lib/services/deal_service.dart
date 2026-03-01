import 'package:flutter/foundation.dart';
import 'package:anis_crm/models/deal_model.dart';
import 'package:anis_crm/services/api_client.dart';

/// Service for deal / revenue pipeline management.
class DealService {
  DealService._();
  static final DealService instance = DealService._();

  final ValueNotifier<List<DealModel>> deals = ValueNotifier([]);
  bool _loading = false;
  bool get isLoading => _loading;

  // ── Computed revenue metrics ──────────────────────────────────────────
  double get totalPipelineValue =>
      deals.value.fold(0.0, (s, d) => s + d.value);

  double get doneValue =>
      deals.value.where((d) => d.stage == DealStage.done).fold(0.0, (s, d) => s + d.value);

  double get unfinishedValue =>
      deals.value.where((d) => d.stage == DealStage.unfinished).fold(0.0, (s, d) => s + d.value);

  int get doneCount => deals.value.where((d) => d.stage == DealStage.done).length;
  int get unfinishedCount => deals.value.where((d) => d.stage == DealStage.unfinished).length;

  double get completionRate {
    final total = deals.value.length;
    return total > 0 ? (doneCount / total * 100) : 0;
  }

  Map<DealStage, List<DealModel>> get byStage {
    final map = <DealStage, List<DealModel>>{
      for (final s in DealStage.values) s: [],
    };
    for (final d in deals.value) {
      map[d.stage]!.add(d);
    }
    return map;
  }

  // ── CRUD ──────────────────────────────────────────────────────────────
  Future<void> load() async {
    _loading = true;
    try {
      final data = await ApiClient.instance.getDeals();
      if (data != null) {
        deals.value = data.map((j) => DealModel.fromJson(j)).toList();
      }
    } catch (e) {
      debugPrint('DealService.load error: $e');
    }
    _loading = false;
  }

  String? lastError;

  Future<DealModel?> create({
    required String title,
    double value = 0,
    String currency = 'EGP',
    String leadId = '',
    String leadName = '',
    String ownerId = '',
    String ownerName = '',
    String? expectedCloseDate,
    String? notes,
  }) async {
    lastError = null;
    try {
      final result = await ApiClient.instance.createDeal({
        'title': title,
        'value': value,
        'currency': currency,
        'lead_id': leadId,
        'lead_name': leadName,
        'owner_id': ownerId,
        'owner_name': ownerName,
        'expected_close_date': expectedCloseDate ?? '',
        'notes': notes ?? '',
      });
      if (result != null) {
        final deal = DealModel.fromJson(result);
        deals.value = [deal, ...deals.value];
        return deal;
      }
    } catch (e) {
      debugPrint('DealService.create error: $e');
      lastError = e.toString().replaceFirst('Exception: ', '');
    }
    return null;
  }

  Future<bool> updateStage(String dealId, DealStage stage) async {
    final ok = await ApiClient.instance.updateDeal(dealId, {
      'stage': stage.apiName,
    });
    if (ok) {
      deals.value = deals.value.map((d) {
        if (d.id == dealId) return d.copyWith(stage: stage);
        return d;
      }).toList();
    }
    return ok;
  }

  Future<bool> update(String dealId, Map<String, dynamic> fields) async {
    final ok = await ApiClient.instance.updateDeal(dealId, fields);
    if (ok) await load();
    return ok;
  }

  Future<bool> delete(String dealId) async {
    final ok = await ApiClient.instance.deleteDeal(dealId);
    if (ok) {
      deals.value = deals.value.where((d) => d.id != dealId).toList();
    }
    return ok;
  }

  Future<void> refresh() => load();
}
