import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../model/ivr_initiate_response.dart';

/// Wraps `POST /Ivr/initiate` — initiates an IVR (masked) call and returns the
/// virtual number the user should dial.
class IvrCallRepo {
  final ApiClient _apiClient;

  const IvrCallRepo(this._apiClient);

  Future<IvrInitiateResponse> initiate({
    required int dsId,
    required int empId,
    required String phoneNo,
    String callerType = 'E',
  }) async {
    debugPrint(
      '[IVR] → POST /Ivr/initiate dsId=$dsId empId=$empId '
      'phoneNo=$phoneNo callerType=$callerType',
    );

    final response = await _apiClient.dio.post<dynamic>(
      '/Ivr/initiate',
      data: {
        'dsId': dsId,
        'empId': empId,
        'phoneNo': phoneNo,
        'callerType': callerType,
      },
    );

    debugPrint('[IVR] ← status=${response.statusCode} data=${response.data}');

    Map<String, dynamic>? body;
    final raw = response.data;
    if (raw is Map<String, dynamic>) {
      body = raw;
    } else if (raw is Map) {
      body = Map<String, dynamic>.from(raw);
    }

    if (body == null) {
      throw Exception('Invalid IVR initiate response.');
    }

    return IvrInitiateResponse.fromJson(body);
  }
}
