import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../model/trip_home_response.dart';

/// Wraps `GET /UserApp/GetTripHomePage`.
class TripHomeRepo {
  final ApiClient _apiClient;

  const TripHomeRepo(this._apiClient);

  Future<List<TripDayGroup>> getTripHomePage() async {
    debugPrint('[TRIP_HOME_REPO] getTripHomePage → GET /UserApp/GetTripHomePage');

    final response = await _apiClient.dio.get<dynamic>(
      '/UserApp/GetTripHomePage',
    );

    debugPrint(
      '[TRIP_HOME_REPO] ← status=${response.statusCode} '
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
      debugPrint('[TRIP_HOME_REPO] ✖ envelope null/unrecognized');
      return const [];
    }

    final parsed = TripHomeResponse.fromJson(envelope);

    debugPrint(
      '[TRIP_HOME_REPO] parsed → errorCode=${parsed.errorCode} '
      'dbResponse="${parsed.dbResponse}" groups=${parsed.groups.length}',
    );

    if (!parsed.isSuccess) {
      debugPrint('[TRIP_HOME_REPO] non-success envelope — returning empty groups');
      return parsed.groups;
    }

    return parsed.groups;
  }
}
