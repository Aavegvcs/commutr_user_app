
import 'package:flutter/foundation.dart';

import '../../../../../core/network/api_client.dart';
import '../../model/cancel_active_trip_confirmation_response.dart';
import '../../model/trip_start/cancel_trip_start_response.dart';

class TripCancelRepository {
  final ApiClient _apiClient;

  TripCancelRepository(this._apiClient);

  Future<CancelTripResponse> cancelTrip({
    required int requestedBy,
    required int requestFor,
    required String tripDate,
    required int tripType,
    required int tripId,
  }) async {
    final jsonResponse = await _apiClient.post(
      '/UserApp/UserCancelTrip',
      data: {
        'RequestedBy': requestedBy,
        'RequestFor': requestFor,
        'TripDate': tripDate,
        'TripType': tripType,
        'TripID': tripId,
      },
    );

    final response = CancelTripResponse.fromJson(jsonResponse);

    // Check if the cancellation actually succeeded.
    // Even if isSuccess == true, the cancellation may have been rejected
    // (e.g., TAT over). We examine errorCode and the dB_Response.
    final result = response.result.isNotEmpty ? response.result.first : null;
    final errorCode = result?.errorCode ?? -1;
    final dbResponse = result?.dBResponse ?? '';

    if (errorCode != 0 ||
        dbResponse.toLowerCase().contains('not permitted') ||
        dbResponse.toLowerCase().contains('cancellation tat over')) {
      throw Exception(response.message);
    }

    return response;
  }

  /// Fetches the active-trip cancel / no-show confirmation popup config.
  ///
  /// Maps to:
  /// ```
  /// POST /UserApp/UserTripCancelConfirmation
  /// {
  ///   "RequestFor": "<empId>",
  ///   "TripType": "<tripType>",
  ///   "TripID": "<tripId>"
  /// }
  /// ```
  ///
  /// Unlike [cancelTrip], this does *not* throw when `errorCode != 0` — the
  /// caller inspects [CancelActiveTripConfirmationResponse.isSuccess] and falls
  /// back to the hardcoded dialog rather than opening the API-driven one. Only
  /// transport/parse failures are thrown (and 401 handled upstream).
  Future<CancelActiveTripConfirmationResponse> cancelTripConfirmation({
    required int requestFor,
    required int tripType,
    required int tripId,
  }) async {
    final body = {
      'RequestFor': requestFor,
      'TripType': tripType,
      'TripID': tripId,
    };

    debugPrint(
        '[CANCEL_TRIP_CONFIRMATION] → POST /UserApp/UserTripCancelConfirmation');
    debugPrint('[CANCEL_TRIP_CONFIRMATION] → body=$body');

    try {
      final jsonResponse = await _apiClient.post(
        '/UserApp/UserTripCancelConfirmation',
        data: body,
      );

      debugPrint('[CANCEL_TRIP_CONFIRMATION] ← raw=$jsonResponse');

      final parsed =
          CancelActiveTripConfirmationResponse.fromJson(jsonResponse);

      debugPrint(
        '[CANCEL_TRIP_CONFIRMATION] parsed → '
        'errorCode=${parsed.errorCode} '
        'dbResponse="${parsed.dbResponse}" '
        'popupId="${parsed.popup?.popupId}" '
        'buttons=${parsed.popup?.buttons.length ?? 0}',
      );

      return parsed;
    } catch (e, st) {
      debugPrint('[CANCEL_TRIP_CONFIRMATION] ✖ exception=$e');
      debugPrint('[CANCEL_TRIP_CONFIRMATION] ✖ stack=$st');
      rethrow;
    }
  }
}