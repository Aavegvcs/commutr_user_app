import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../model/team_tracking_panel_response.dart';

/// Wraps `GET /Tracking/team-tracking-panel`.
class TeamCabRepository {
  final ApiClient _apiClient;

  const TeamCabRepository(this._apiClient);

  Future<TeamTrackingPanelResponse> getTeamTrackingPanel({
    required int empId,
    required DateTime date,
  }) async {
    final dateStr = _formatDate(date);
    debugPrint(
      '[TEAM_CAB_REPO] getTeamTrackingPanel → empId=$empId date=$dateStr',
    );

    final response = await _apiClient.dio.get<dynamic>(
      '/Tracking/team-tracking-panel',
      queryParameters: {
        'empId': empId,
        'date': dateStr,
      },
    );

    Map<String, dynamic>? body;
    final raw = response.data;
    if (raw is Map<String, dynamic>) {
      body = raw;
    } else if (raw is Map) {
      body = Map<String, dynamic>.from(raw);
    }

    if (body == null) {
      throw Exception('Invalid team tracking response.');
    }

    // Return the parsed response as-is — including `isSuccess == false`
    // payloads — so the UI can surface the server's `message`. Only transport
    // failures (e.g. HTTP 500) propagate as exceptions to the bloc.
    return TeamTrackingPanelResponse.fromJson(body);
  }

  /// Formats as `yyyy-MM-dd` (e.g. `2026-06-18`).
  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
