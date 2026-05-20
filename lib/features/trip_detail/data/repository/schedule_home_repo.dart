import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../model/schedule_home_response.dart';

/// Wraps `GET /UserApp/GetScheduleHomePage`.
///
/// The endpoint returns a single-element list whose only entry envelopes the
/// real payload (`errorCode`, `dB_Response`, `result`). `result` is itself a
/// JSON-encoded string — see [ScheduleHomeResponse] for the parsing details.
class ScheduleHomeRepo {
  final ApiClient _apiClient;

  const ScheduleHomeRepo(this._apiClient);

  Future<List<ScheduleDateGroup>> getScheduleHomePage() async {
    debugPrint('[SCHEDULE_HOME_REPO] getScheduleHomePage → GET /UserApp/GetScheduleHomePage');

    final response = await _apiClient.dio.get<dynamic>(
      '/UserApp/GetScheduleHomePage',
    );

    debugPrint(
      '[SCHEDULE_HOME_REPO] ← status=${response.statusCode} '
      'dataType=${response.data.runtimeType}',
    );

    final raw = response.data;

    Map<String, dynamic>? envelope;
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is Map<String, dynamic>) {
        envelope = first;
      } else if (first is Map) {
        envelope = Map<String, dynamic>.from(first);
      }
    } else if (raw is Map<String, dynamic>) {
      envelope = raw;
    } else if (raw is Map) {
      envelope = Map<String, dynamic>.from(raw);
    }

    if (envelope == null) {
      debugPrint('[SCHEDULE_HOME_REPO] ✖ envelope null/unrecognized');
      return const [];
    }

    final parsed = ScheduleHomeResponse.fromJson(envelope);

    debugPrint(
      '[SCHEDULE_HOME_REPO] parsed → errorCode=${parsed.errorCode} '
      'dbResponse="${parsed.dbResponse}" groups=${parsed.groups.length}',
    );

    if (!parsed.isSuccess) {
      // Some success-shaped responses carry an empty result; treat as no data
      // instead of an exception so the UI can show an empty state.
      debugPrint('[SCHEDULE_HOME_REPO] non-success envelope — returning empty groups');
      return parsed.groups;
    }

    return parsed.groups;
  }
}
