import 'package:flutter/foundation.dart';
import 'package:anis_crm/models/team_activity.dart';
import 'package:anis_crm/services/api_client.dart';

/// Service for the team-wide activity feed.
class TeamActivityService {
  TeamActivityService._();
  static final TeamActivityService instance = TeamActivityService._();

  final ValueNotifier<List<TeamActivity>> activities = ValueNotifier([]);
  bool _loading = false;
  bool get isLoading => _loading;

  Future<void> load({int limit = 50}) async {
    _loading = true;
    try {
      final data = await ApiClient.instance.getTeamActivities(limit: limit);
      if (data != null) {
        activities.value = data.map((j) => TeamActivity.fromJson(j)).toList();
      }
    } catch (e) {
      debugPrint('TeamActivityService.load error: $e');
    }
    _loading = false;
  }

  Future<void> refresh() => load();
}
