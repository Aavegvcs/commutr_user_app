/// Response model for `GET /Auth/version-check`.
///
/// ```json
/// {
///   "success": true,
///   "data": {
///     "isForceUpdate": false,
///     "isOptionalUpdate": true,
///     "latestVersion": "1.2.0",
///     "minimumVersion": "1.0.0"
///   }
/// }
/// ```
class VersionCheckResponse {
  final bool success;
  final VersionCheckData? data;

  const VersionCheckResponse({required this.success, this.data});

  factory VersionCheckResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return VersionCheckResponse(
      success: json['success'] == true,
      data: rawData is Map<String, dynamic>
          ? VersionCheckData.fromJson(rawData)
          : null,
    );
  }
}

class VersionCheckData {
  final bool isForceUpdate;
  final bool isOptionalUpdate;
  final String? latestVersion;
  final String? minimumVersion;

  const VersionCheckData({
    required this.isForceUpdate,
    required this.isOptionalUpdate,
    this.latestVersion,
    this.minimumVersion,
  });

  factory VersionCheckData.fromJson(Map<String, dynamic> json) {
    return VersionCheckData(
      isForceUpdate: json['isForceUpdate'] == true,
      isOptionalUpdate: json['isOptionalUpdate'] == true,
      latestVersion: json['latestVersion']?.toString(),
      minimumVersion: json['minimumVersion']?.toString(),
    );
  }
}
