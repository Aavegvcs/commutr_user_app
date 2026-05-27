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
    } catch (e, st) {
      debugPrint('[SOS_REPO] ✖ exception=$e');
      debugPrint('[SOS_REPO] ✖ stack=$st');
      rethrow;
    }
  }
}
