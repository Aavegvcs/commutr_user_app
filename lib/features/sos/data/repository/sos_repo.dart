import 'package:commutr_main/core/network/api_client.dart';
import 'package:flutter/foundation.dart';

class SosRepository {
  final ApiClient _apiClient;

  SosRepository(this._apiClient);

  Future<void> triggerSos({
    required int empId,
    required double lat,
    required double lng,
  }) async {
    debugPrint('[SOS_REPO] → GET /UserApp/GetSOSCall empId=$empId lat=$lat lng=$lng');

    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/UserApp/GetSOSCall',
        queryParameters: {
          'EmpID': empId,
          'Lat': lat,
          'Lng': lng,
        },
      );

      debugPrint('[SOS_REPO] ← status=${response.statusCode} data=${response.data}');

      // The API returns HTTP 200 with a body like:
      //   [{"errorCode": 0, "dB_Response": "Success"}]
      // errorCode == 0 → success; any other value is a business-level failure
      // that must surface as an error so the UI shows the SOS error popup.
      final result = _firstResult(response.data);
      final errorCode = (result?['errorCode'] as num?)?.toInt() ?? -1;
      if (errorCode != 0) {
        final dbResponse = result?['dB_Response']?.toString();
        throw Exception(
          (dbResponse != null && dbResponse.trim().isNotEmpty)
              ? dbResponse
              : 'Could not trigger SOS. Please try again.',
        );
      }
    } catch (e, st) {
      debugPrint('[SOS_REPO] ✖ exception=$e');
      debugPrint('[SOS_REPO] ✖ stack=$st');
      rethrow;
    }
  }

  /// Normalises the response body to the first result map, handling both a
  /// list payload (`[{...}]`) and a bare object (`{...}`).
  Map<String, dynamic>? _firstResult(dynamic data) {
    if (data is List) {
      final first = data.isNotEmpty ? data.first : null;
      return first is Map<String, dynamic> ? first : null;
    }
    if (data is Map<String, dynamic>) return data;
    return null;
  }
}
