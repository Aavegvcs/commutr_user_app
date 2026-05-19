import 'package:commutr_main/core/network/api_client.dart';
import 'package:commutr_main/features/trip_detail/data/model/roaster_shifts_response.dart';
import 'package:commutr_main/features/trip_detail/data/model/update_schedules_response.dart';
import 'package:flutter/foundation.dart';

class RoasterShiftRepo {
  final ApiClient _apiClient;

  RoasterShiftRepo(this._apiClient);

  Future<ShiftResult> getRoasterShiftDetail({
    required int locCode,
    required int empId,
  }) async {
    debugPrint(
      '[ROASTER_SHIFT_REPO] getRoasterShiftDetail → locCode=$locCode empId=$empId',
    );

    final response = await _apiClient.dio.get<List<dynamic>>(
      '/TransRoster/GetUserFilterData',
      queryParameters: {
        'LocCode': locCode,
        'EmpId': empId,
      },
    );

    debugPrint(
      '[ROASTER_SHIFT_REPO] getRoasterShiftDetail ← status=${response.statusCode} '
      'rows=${response.data?.length ?? 0}',
    );

    final rawList = response.data ?? [];

    if (rawList.isEmpty) {
      debugPrint('[ROASTER_SHIFT_REPO] getRoasterShiftDetail: empty response');
      throw Exception('Empty response from server');
    }
    final first = rawList.first;

    if (first is! Map<String, dynamic>) {
      debugPrint(
        '[ROASTER_SHIFT_REPO] getRoasterShiftDetail: unexpected type=${first.runtimeType}',
      );
      throw Exception('Unexpected response format');
    }

    final parsed = RoasterShiftResponse.fromJson(first);

    debugPrint(
      '[ROASTER_SHIFT_REPO] getRoasterShiftDetail: parsed '
      'pickShifts=${parsed.result.pickShifts.length} '
      'dropShifts=${parsed.result.dropShifts.length} '
      'empId=${parsed.result.empId}',
    );

    return parsed.result;
  }

  Future<UpdateSchedulesResponse> updateSchedules({
    required int locCode,
    required String fromDate,
    required String toDate,
    required String shiftStart,
    required String shiftEnd,
    required String weekOffs,
    required String userEmpIds,
    String scheduleUpdateVersion = 'APP',
  }) async {
    final body = {
      'scheduleUpdateVersion': scheduleUpdateVersion,
      'locCode': locCode,
      'fromDate': fromDate,
      'toDate': toDate,
      'shiftStart': shiftStart,
      'shiftEnd': shiftEnd,
      'weekOffs': weekOffs,
      'User_Empids': userEmpIds,
    };

    debugPrint('[UPDATE_SCHEDULES] → POST /TransRoster/UpdateSchedules');
    debugPrint('[UPDATE_SCHEDULES] → body=$body');

    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/TransRoster/UpdateSchedules',
        data: body,
      );

      debugPrint(
        '[UPDATE_SCHEDULES] ← status=${response.statusCode} '
        'dataType=${response.data.runtimeType}',
      );
      debugPrint('[UPDATE_SCHEDULES] ← raw=${response.data}');

      final raw = response.data;

      Map<String, dynamic>? payload;
      if (raw is Map<String, dynamic>) {
        payload = raw;
      } else if (raw is List &&
          raw.isNotEmpty &&
          raw.first is Map<String, dynamic>) {
        payload = raw.first as Map<String, dynamic>;
      }

      if (payload == null) {
        debugPrint('[UPDATE_SCHEDULES] ✖ payload is null/unrecognized');
        throw Exception('Unexpected response format');
      }

      final parsed = UpdateSchedulesResponse.fromJson(payload);

      debugPrint(
        '[UPDATE_SCHEDULES] parsed → '
        'envelopeSuccess=${parsed.envelopeSuccess} '
        'message="${parsed.message}" '
        'errorCode=${parsed.errorCode} '
        'dbResponse="${parsed.dbResponse}" '
        'isSuccess=${parsed.isSuccess}',
      );

      if (!parsed.isSuccess) {
        throw Exception(
          parsed.displayMessage.isNotEmpty
              ? parsed.displayMessage
              : 'Failed to update schedules',
        );
      }

      return parsed;
    } catch (e, st) {
      debugPrint('[UPDATE_SCHEDULES] ✖ exception=$e');
      debugPrint('[UPDATE_SCHEDULES] ✖ stack=$st');
      rethrow;
    }
  }
}
