import 'package:commutr_main/core/network/api_client.dart';
import 'package:commutr_main/features/adhoc/data/model/adhoc_list_response.dart';
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

      final parsed = AdhocRequestResponse.fromEnvelopeJson(payload);

      debugPrint(
        '[ADHOC_REPO] parsed → errorCode=${parsed.errorCode} '
        'isSuccess=${parsed.isSuccess} message="${parsed.displayMessage}"',
      );

      return parsed;
    } catch (e, st) {
      debugPrint('[ADHOC_REPO] ✖ exception=$e');
      debugPrint('[ADHOC_REPO] ✖ stack=$st');
      rethrow;
    }
  }

  Future<void> cancelAdhocRequest({required int reqId, required int empId}) async {
    final body = {'ReqId': reqId, 'EmpID': empId};
    debugPrint('[ADHOC_REPO] → POST /UserApp/UserCancelAdhocRequest body=$body');
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/UserApp/UserCancelAdhocRequest',
        data: body,
      );
      debugPrint('[ADHOC_REPO] ← status=${response.statusCode} raw=${response.data}');

      final raw = response.data;
      Map<String, dynamic>? payload;
      if (raw is Map<String, dynamic>) {
        payload = raw;
      } else if (raw is Map) {
        payload = Map<String, dynamic>.from(raw);
      } else if (raw is List && raw.isNotEmpty && raw.first is Map<String, dynamic>) {
        payload = raw.first as Map<String, dynamic>;
      } else if (raw is List && raw.isNotEmpty && raw.first is Map) {
        payload = Map<String, dynamic>.from(raw.first as Map);
      }

      final isSuccess = payload?['isSuccess'] == true ||
          (payload?['result'] is List &&
              (payload!['result'] as List).isNotEmpty &&
              ((payload['result'] as List).first as Map)['errorCode'] == 0);

      if (!isSuccess) {
        final msg = payload?['message']?.toString() ?? 'Failed to cancel request';
        throw Exception(msg);
      }
    } catch (e, st) {
      debugPrint('[ADHOC_REPO] ✖ cancelAdhocRequest exception=$e');
      debugPrint('[ADHOC_REPO] ✖ stack=$st');
      rethrow;
    }
  }

  Future<AdhocListResponse> fetchAdhocList({required int empId}) async {
    debugPrint('[ADHOC_REPO] → GET /UserApp/UserAdhocRequestList?EmpID=$empId');
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/UserApp/UserAdhocRequestList',
        queryParameters: {'EmpID': empId},
      );

      debugPrint('[ADHOC_REPO] ← status=${response.statusCode}');
      debugPrint('[ADHOC_REPO] ← raw=${response.data}');

      final raw = response.data;

      Map<String, dynamic>? payload;
      if (raw is Map<String, dynamic>) {
        payload = raw;
      } else if (raw is Map) {
        payload = Map<String, dynamic>.from(raw);
      } else if (raw is List && raw.isNotEmpty && raw.first is Map<String, dynamic>) {
        payload = raw.first as Map<String, dynamic>;
      } else if (raw is List && raw.isNotEmpty && raw.first is Map) {
        payload = Map<String, dynamic>.from(raw.first as Map);
      }

      if (payload == null) {
        debugPrint('[ADHOC_REPO] ✖ payload is null/unrecognized');
        throw Exception('Unexpected response format');
      }

      final parsed = AdhocListResponse.fromJson(payload);
      debugPrint('[ADHOC_REPO] parsed → isSuccess=${parsed.isSuccess} count=${parsed.items.length}');

      if (!parsed.isSuccess) {
        throw Exception('Failed to fetch adhoc requests');
      }

      return parsed;
    } catch (e, st) {
      debugPrint('[ADHOC_REPO] ✖ fetchAdhocList exception=$e');
      debugPrint('[ADHOC_REPO] ✖ stack=$st');
      rethrow;
    }
  }
}
