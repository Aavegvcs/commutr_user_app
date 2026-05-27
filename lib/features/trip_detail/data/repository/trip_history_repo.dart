import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../model/trip_history_response.dart';

class TripHistoryRepo {
  final ApiClient _apiClient;

  const TripHistoryRepo(this._apiClient);

  Future<List<TripHistoryItem>> getTripHistory({
    required int empId,
    required String fromDate,
    required String toDate,
    String searchBy = 'All',
  }) async {
    debugPrint(
      '[TRIP_HISTORY_REPO] getTripHistory → POST /UserApp/UserTripHistory '
      'empId=$empId fromDate=$fromDate toDate=$toDate searchBy=$searchBy',
    );

    final response = await _apiClient.dio.post<dynamic>(
      '/UserApp/UserTripHistory',
      data: {
        'Empid': empId,
        'FromDate': fromDate,
        'ToDate': toDate,
        'SearchBy': searchBy,
      },
    );

    debugPrint(
      '[TRIP_HISTORY_REPO] ← status=${response.statusCode} '
      'dataType=${response.data.runtimeType}',
    );

    final raw = response.data;
    Map<String, dynamic>? root;

    if (raw is Map<String, dynamic>) {
      root = raw;
    } else if (raw is Map) {
      root = Map<String, dynamic>.from(raw);
    } else if (raw is List && raw.isNotEmpty) {
      // Legacy: body is directly the envelope array.
      final first = raw.first;
      if (first is Map<String, dynamic>) {
        return _parseEnvelope(first, empId);
      }
      if (first is Map) {
        return _parseEnvelope(Map<String, dynamic>.from(first), empId);
      }
    }

    if (root == null) {
      debugPrint('[TRIP_HISTORY_REPO] ✖ unrecognized response shape');
      return const [];
    }

    final apiResponse = UserTripHistoryApiResponse.fromJson(root);
    debugPrint(
      '[TRIP_HISTORY_REPO] outer → isSuccess=${apiResponse.isSuccess} '
      'message="${apiResponse.message}" envelopes=${apiResponse.envelopes.length}',
    );

    if (!apiResponse.isSuccess) {
      debugPrint('[TRIP_HISTORY_REPO] outer isSuccess=false — returning empty');
      return const [];
    }

    final envelope = apiResponse.firstEnvelope;
    if (envelope == null) {
      debugPrint('[TRIP_HISTORY_REPO] ✖ no envelope in result');
      return const [];
    }

    return _parseEnvelopeFromTrips(envelope, empId);
  }

  List<TripHistoryItem> _parseEnvelope(
    Map<String, dynamic> envelopeJson,
    int empId,
  ) {
    final envelope = TripHistoryEnvelope.fromJson(envelopeJson);
    return _parseEnvelopeFromTrips(envelope, empId);
  }

  List<TripHistoryItem> _parseEnvelopeFromTrips(
    TripHistoryEnvelope envelope,
    int empId,
  ) {
    debugPrint(
      '[TRIP_HISTORY_REPO] envelope → errorCode=${envelope.errorCode} '
      'dbResponse="${envelope.dbResponse}" trips=${envelope.trips.length}',
    );

    if (!envelope.isSuccess) {
      debugPrint('[TRIP_HISTORY_REPO] envelope not success — returning empty');
      return const [];
    }

    final items = TripHistoryItem.flattenForEmployee(envelope.trips, empId);
    debugPrint(
      '[TRIP_HISTORY_REPO] flattened → empId=$empId items=${items.length}',
    );
    return items;
  }
}
