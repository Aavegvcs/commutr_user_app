
import '../../../../../core/network/api_client.dart';
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
}