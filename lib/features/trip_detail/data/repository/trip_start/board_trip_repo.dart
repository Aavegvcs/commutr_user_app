import '../../../../../core/network/api_client.dart';
import '../../model/trip_start/user_board_deboard_response.dart';

class BoardTripRepository {
  final ApiClient _apiClient;

  BoardTripRepository(this._apiClient);

  Future<UserBoardDeboardResponse> userBoardDeboard({
    required int empId,
    required int tripId,
    required int tripType,
    required double empLat,
    required double empLng,
    required String boardingType,
  }) async {
    final jsonResponse = await _apiClient.post(
      '/UserApp/UserBoardDeboard',
      data: {
        'EmpId': empId,
        'TripID': tripId,
        'TripType': tripType,
        'EmpLat': empLat,
        'EmpLng': empLng,
        'BoardingType': boardingType,
      },
    );

    final response = UserBoardDeboardResponse.fromJson(jsonResponse);
    final result = response.result.isNotEmpty ? response.result.first : null;
    final errorCode = result?.errorCode ?? -1;
    final dbResponse = result?.dbResponse ?? '';

    if (!response.isSuccess || errorCode != 0) {
      final msg = dbResponse.isNotEmpty
          ? dbResponse
          : (response.message.isNotEmpty
              ? response.message
              : 'Boarding failed. Please try again.');
      throw Exception(msg);
    }

    return response;
  }
}
