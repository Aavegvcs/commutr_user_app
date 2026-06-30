import 'dart:io';

import '../../../../core/network/api_client.dart';
import '../model/version_check_response.dart';

class VersionCheckRepository {
  final ApiClient apiClient;

  VersionCheckRepository({required this.apiClient});

  /// Calls `GET /Auth/version-check`.
  ///
  /// - [appType] `1` — Commutr user app.
  /// - [platform] `1` = iOS, `2` = Android.
  /// - [currentVersion] the running app version (e.g. `1.1.0`).
  Future<VersionCheckResponse> checkVersion({
    required int appType,
    required int platform,
    required String currentVersion,
  }) async {
    final response = await apiClient.get(
      '/Auth/version-check',
      queryParameters: {
        'appType': 2,
        'platform': Platform.isAndroid ? 1 : 2,
        'currentVersion': currentVersion,
      },
    );

    return VersionCheckResponse.fromJson(response);
  }
}
