import '../../../../core/network/api_client.dart';
import '../model/version_check_response.dart';

class VersionCheckRepository {
  final ApiClient apiClient;

  VersionCheckRepository({required this.apiClient});

  /// Calls `GET /Auth/version-check`.
  /// - [appType] `1` = DriverApp, `2` = UserApp.
  /// - [platform] `1` = Android, `2` = iOS, `3` = Web.
  /// - [currentVersion] the running app version (e.g. `1.1.0`).
  Future<VersionCheckResponse> checkVersion({
    required int appType,
    required int platform,
    required String currentVersion,
  }) async {
    final response = await apiClient.get(
      '/Auth/version-check',
      queryParameters: {
        'appType': appType,
        'platform': platform,
        'currentVersion': currentVersion,
      },
    );

    return VersionCheckResponse.fromJson(response);
  }
}
