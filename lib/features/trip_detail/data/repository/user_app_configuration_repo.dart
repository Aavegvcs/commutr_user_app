import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../model/user_app_configuration_response.dart';

class UserAppConfigurationRepository {
  final ApiClient _apiClient;

  const UserAppConfigurationRepository(this._apiClient);

  Future<UserAppConfiguration> getUserAppConfigurationByLocCode(
    int locCode,
  ) async {
    debugPrint(
      '[USER_APP_CONFIG_REPO] → GET '
      '/UserAppConfiguration/GetUserAppConfigurationByLocCode?locCode=$locCode',
    );

    final response = await _apiClient.dio.get<dynamic>(
      '/UserAppConfiguration/GetUserAppConfigurationByLocCode',
      queryParameters: {'locCode': locCode},
    );

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('Unexpected response format');
    }

    // The payload is delivered as a JSON *string* under `result`.
    final result = data['result'];
    final Map<String, dynamic> configJson;
    if (result is String) {
      final decoded = jsonDecode(result);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Unexpected result format');
      }
      configJson = decoded;
    } else if (result is Map<String, dynamic>) {
      configJson = result;
    } else {
      throw Exception('Missing result in response');
    }

    return UserAppConfiguration.fromJson(configJson);
  }
}
