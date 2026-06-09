import 'package:commutr_main/core/network/api_client.dart';
import 'package:commutr_main/features/trip_detail/data/model/cancel_schedules_response.dart';
import 'package:commutr_main/features/trip_detail/data/model/roaster_shifts_response.dart';
import 'package:commutr_main/features/trip_detail/data/model/update_schedules_response.dart';
import 'package:flutter/foundation.dart';

class ReachedHomeResponse {
  final bool isSuccess;
  final String message;

  const ReachedHomeResponse({required this.isSuccess, required this.message});

  factory ReachedHomeResponse.fromJson(Map<String, dynamic> json) {
    final errorCode = json['ErrorCode'] ?? json['errorCode'] ?? 0;
    final dbResponse =
        (json['DBResponse'] ?? json['dbResponse'] ?? '').toString().trim();
    final msg =
        (json['Message'] ?? json['message'] ?? '').toString().trim();
    final success =
        (errorCode == 0 || errorCode == '0') && dbResponse == '1';
    return ReachedHomeResponse(
      isSuccess: success,
      message: msg.isNotEmpty ? msg : dbResponse,
    );
  }
}

class RoasterShiftRepo {
  final ApiClient _apiClient;

  RoasterShiftRepo(this._apiClient);

  Future<ReachedHomeResponse> reachedHome({
    required int empId,
    required int tripId,
    required double empLat,
    required double empLng,
  }) async {
    final body = {
      'EmpId': empId,
      'TripID': tripId,
      'EmpLat': empLat,
      'EmpLng': empLng,
    };
    debugPrint('[REACHED_HOME] → POST /UserApp/ReachedHome body=$body');
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/UserApp/ReachedHome',
        data: body,
      );
      debugPrint(
        '[REACHED_HOME] ← status=${response.statusCode} data=${response.data}',
      );
      final raw = response.data;
      Map<String, dynamic>? payload;
      if (raw is Map<String, dynamic>) {
        payload = raw;
      } else if (raw is Map) {
        payload = Map<String, dynamic>.from(raw);
      } else if (raw is List && raw.isNotEmpty && raw.first is Map) {
        payload = Map<String, dynamic>.from(raw.first as Map);
      }
      if (payload == null) {
        debugPrint('[REACHED_HOME] ✖ unexpected response format');
        return const ReachedHomeResponse(
          isSuccess: false,
          message: 'Unexpected response format',
        );
      }
      return ReachedHomeResponse.fromJson(payload);
    } catch (e, st) {
      debugPrint('[REACHED_HOME] ✖ exception=$e\n$st');
      rethrow;
    }
  }

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

  /// Cancels a previously scheduled trip for the given date.
  ///
  /// Maps to:
  /// ```
  /// POST /TransRoster/CancelSchedules
  /// {
  ///   "LocCode": <locCode>,
  ///   "Empid": "<empId>",
  ///   "ScheduleDate": "<yyyy-MM-dd>",
  ///   "TripType": "1"  // "1" = Login, "2" = Logout
  /// }
  /// ```
  Future<CancelSchedulesResponse> cancelSchedules({
    required int locCode,
    required String empId,
    required String scheduleDate,
    required String tripType,
  }) async {
    final body = {
      'LocCode': locCode,
      'Empid': empId,
      'ScheduleDate': scheduleDate,
      'TripType': tripType,
      "ScheduleCancelVersion":"APP"
    };

    debugPrint('[CANCEL_SCHEDULES] → POST /TransRoster/CancelSchedules');
    debugPrint('[CANCEL_SCHEDULES] → body=$body');

    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/TransRoster/CancelSchedules',
        data: body,
      );

      debugPrint(
        '[CANCEL_SCHEDULES] ← status=${response.statusCode} '
        'dataType=${response.data.runtimeType}',
      );
      debugPrint('[CANCEL_SCHEDULES] ← raw=${response.data}');

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
        debugPrint('[CANCEL_SCHEDULES] ✖ payload is null/unrecognized');
        throw Exception('Unexpected response format');
      }

      final parsed = CancelSchedulesResponse.fromJson(payload);

      debugPrint(
        '[CANCEL_SCHEDULES] parsed → '
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
              : 'Failed to cancel ride',
        );
      }

      return parsed;
    } catch (e, st) {
      debugPrint('[CANCEL_SCHEDULES] ✖ exception=$e');
      debugPrint('[CANCEL_SCHEDULES] ✖ stack=$st');
      rethrow;
    }
  }
}
