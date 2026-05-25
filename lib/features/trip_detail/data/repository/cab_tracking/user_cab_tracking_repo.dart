import 'package:flutter/foundation.dart';

import '../../../../../core/network/api_client.dart';
import '../../model/cab_tracking/user_cab_tracking_response.dart';

/// Wraps `GET /UserApp/GetUserCabTracking`.
class UserCabTrackingRepo {
  final ApiClient _apiClient;

  const UserCabTrackingRepo(this._apiClient);

  Future<CabTrackingData> getUserCabTracking({
    required int empId,
    required int tripId,
  }) async {
    debugPrint(
      '[CAB_TRACKING_REPO] getUserCabTracking → '
      'EmpID=$empId TripID=$tripId',
    );

    final response = await _apiClient.dio.get<dynamic>(
      '/UserApp/GetUserCabTracking',
      queryParameters: {
        'EmpID': empId,
        'TripID': tripId,
      },
    );

    Map<String, dynamic>? envelope;
    final raw = response.data;
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
      throw Exception('Invalid tracking response.');
    }

    final parsed = UserCabTrackingResponse.fromJson(envelope);
    if (!parsed.isSuccess || parsed.data == null) {
      final msg = (parsed.dbResponse ?? '').trim();
      throw Exception(
        msg.isNotEmpty ? msg : 'Unable to load cab tracking.',
      );
    }

    return parsed.data!;
  }
}
