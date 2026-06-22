import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../model/app_control_settings_response.dart';

class AppControlRepository {
  final ApiClient _apiClient;

  const AppControlRepository(this._apiClient);

  Future<AppControlSettings> getAppControlSettingsByLocCode(int locCode) async {
    debugPrint(
      '[APP_CONTROL_REPO] → GET '
      '/AppControl/GetAppControlSettingsByLocCode/$locCode',
    );

    final response = await _apiClient.dio.get<dynamic>(
      '/AppControl/GetAppControlSettingsByLocCode/$locCode',
    );

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('Unexpected response format');
    }

    return AppControlSettings.fromJson(data);
  }
}
