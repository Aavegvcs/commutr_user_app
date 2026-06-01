import 'package:commutr_main/core/network/api_client.dart';
import 'package:commutr_main/features/share_cab/data/model/call_driver_ivr_response.dart';
import 'package:flutter/foundation.dart';

class CallDriverIvrRepository {
  final ApiClient _apiClient;

  CallDriverIvrRepository(this._apiClient);

  Future<CallDriverIvrResponse> callToDriverIvr({
    required int empId,
    required String userMobileNo,
    required int tripId,
  }) async {
    debugPrint(
      '[CALL_IVR] → POST /UserApp/CallToDriverIVR '
      'empId=$empId tripId=$tripId',
    );

    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/UserApp/CallToDriverIVR',
        data: {
          'EmpID': empId,
          'UserMobileNo': userMobileNo,
          'TripID': tripId,
        },
      );

      debugPrint(
          '[CALL_IVR] ← status=${response.statusCode} data=${response.data}');

      final json = response.data as Map<String, dynamic>;
      return CallDriverIvrResponse.fromJson(json);
    } catch (e, st) {
      debugPrint('[CALL_IVR] ✖ exception=$e');
      debugPrint('[CALL_IVR] ✖ stack=$st');
      rethrow;
    }
  }
}
