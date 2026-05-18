import '../../../core/network/api_client.dart';
import '../model/weekly_off_response_model.dart';

class WeeklyOffRepository {
  final ApiClient apiClient;

  WeeklyOffRepository({required this.apiClient});

  Future<WeeklyOffResponseModel> updateWeeklyOff({
    required String weekOff,
  }) async {
    final response = await apiClient.post(
      '/MstWeeklyOff/APIMstWeeklyOff',
      data: {
        "weekOff": weekOff,
      },
    );

    return WeeklyOffResponseModel.fromJson(response);
  }
  //fetch weekly off
  Future<WeeklyOffResponseModel> showWeeklyOff() async {
    final response = await apiClient.post(
      '/MstWeeklyOff/APIMstWeeklyOff',
      data: {
        "weekOff": "",
      },
    );

    return WeeklyOffResponseModel.fromJson(response);
  }
}


