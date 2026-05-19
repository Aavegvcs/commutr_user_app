import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../model/user_details_roaster_response.dart';

class RosterRepository {
  final ApiClient _apiClient;

  const RosterRepository(this._apiClient);

  Future<RosterUserDetails> getUserDetailsForRoster() async {
    final response = await _apiClient.dio.get<List<dynamic>>(
      '/TransRoster/UserDetailsForRoster',
    );

    final rawList = response.data ?? [];

    if (rawList.isEmpty) {
      throw Exception('Empty response from server');
    }

    final first = rawList.first;
    if (first is! Map<String, dynamic>) {
      throw Exception('Unexpected response format');
    }

    final parsed = RosterUserDetailsResponse.fromJson(first);

    if (!parsed.isSuccess) {
      throw Exception(
        'API error (code ${parsed.errorCode}): ${parsed.dbResponse}',
      );
    }

    if (parsed.details == null) {
      throw Exception('Failed to parse roster details');
    }

    return parsed.details!;
  }
}