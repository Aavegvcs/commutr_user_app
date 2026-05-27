import '../../../../core/network/api_client.dart';

class UserFeedbackRepo {
  final ApiClient _apiClient;

  UserFeedbackRepo(this._apiClient);

  Future<void> createUserFeedback({
    required int empId,
    required int tripId,
    required int rating,
    required String remarks,
  }) async {
    final response = await _apiClient.post(
      '/UserApp/CreateUserFeedback',
      data: {
        'EmpID': empId,
        'TripId': tripId,
        'Rating': rating,
        'Remarks': remarks,
      },
    );

    final errorCode = (response['ErrorCode'] ?? response['errorCode']) as int?;
    final message = ((response['Message'] ?? response['message']) as String? ?? '').trim();

    if (errorCode != null && errorCode != 0) {
      throw Exception(message.isNotEmpty ? message : 'Failed to submit feedback.');
    }
  }
}
