import 'package:commutr_main/core/network/api_client.dart';
import 'package:commutr_main/features/adhoc/data/model/adhoc_response.dart';
import 'package:flutter/foundation.dart';

class AdhocRepository {
  final ApiClient _apiClient;

  AdhocRepository(this._apiClient);

  Future<AdhocRequestResponse> submitAdhocRequest({
    required int locCode,
    required String tripDate,
    required int tripType,
    required int shiftId,
    required int reqBy,
    required String reqFor,
    required String remarks,
  }) async {
    final body = {
      'LocCode': locCode,
      'TripDate': tripDate,
      'TripType': tripType,
      'ShiftId': shiftId,
      'ReqBy': reqBy,
      'ReqFor': reqFor,
      'Remarks': remarks,
    };

    debugPrint('[ADHOC_REPO] → POST /UserApp/UserAdhocRequest');
    debugPrint('[ADHOC_REPO] → body=$body');

    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/UserApp/UserAdhocRequest',
        data: body,
      );

      debugPrint(
        '[ADHOC_REPO] ← status=${response.statusCode} '
        'dataType=${response.data.runtimeType}',
      );
      debugPrint('[ADHOC_REPO] ← raw=${response.data}');

      final raw = response.data;

      Map<String, dynamic>? payload;
      if (raw is Map<String, dynamic>) {
        payload = raw;
      } else if (raw is Map) {
        payload = Map<String, dynamic>.from(raw);
      } else if (raw is List &&
          raw.isNotEmpty &&
          raw.first is Map<String, dynamic>) {
        payload = raw.first as Map<String, dynamic>;
      } else if (raw is List && raw.isNotEmpty && raw.first is Map) {
        payload = Map<String, dynamic>.from(raw.first as Map);
      }

      if (payload == null) {
        debugPrint('[ADHOC_REPO] ✖ payload is null/unrecognized');
        throw Exception('Unexpected response format');
      }

      final parsed = AdhocRequestResponse.fromJson(payload);

      debugPrint(
        '[ADHOC_REPO] parsed → '
        'isSuccess=${parsed.isSuccess} '
        'message="${parsed.message}" '
        'dbResponse="${parsed.dbResponse}"',
      );

      if (!parsed.isSuccess) {
        throw Exception(
          parsed.message.isNotEmpty ? parsed.message : 'Failed to submit adhoc request',
        );
      }

      return parsed;
    } catch (e, st) {
      debugPrint('[ADHOC_REPO] ✖ exception=$e');
      debugPrint('[ADHOC_REPO] ✖ stack=$st');
      rethrow;
    }
  }
}
