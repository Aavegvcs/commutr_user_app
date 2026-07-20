import 'package:commutr_main/core/network/api_client.dart';
import 'package:commutr_main/features/trip_detail/data/model/cancel_schedule_confirmation_response.dart';
import 'package:commutr_main/features/trip_detail/data/model/cancel_schedules_response.dart';
import 'package:commutr_main/features/trip_detail/data/model/roaster_shifts_response.dart';
import 'package:commutr_main/features/trip_detail/data/model/update_schedules_response.dart';
import 'package:flutter/foundation.dart';

class ReachedHomeResponse {
  final bool isSuccess;
  final String message;

  const ReachedHomeResponse({required this.isSuccess, required this.message});

  /// Parses the inner result object, e.g.:
  ///   { "errorCode": 0, "dB_Response": "Reached home updated successfully." }
  ///
  /// Success is driven solely by `errorCode == 0`. The user-facing message comes
  /// from `dB_Response` (falling back to a top-level `message` if present).
  factory ReachedHomeResponse.fromJson(Map<String, dynamic> json) {
    final errorCode = json['ErrorCode'] ?? json['errorCode'] ?? 0;
    final dbResponse = (json['dB_Response'] ??
            json['DBResponse'] ??
            json['dbResponse'] ??
            '')
        .toString()
        .trim();
    final msg =
        (json['Message'] ?? json['message'] ?? '').toString().trim();
    final success = errorCode == 0 || errorCode == '0';
    return ReachedHomeResponse(
      isSuccess: success,
      message: dbResponse.isNotEmpty ? dbResponse : msg,
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
      if (raw is Map) {
        // The API wraps the data in a `result` array:
        //   { "result": [ { "errorCode": 0, "dB_Response": "..." } ], ... }
        // Prefer the first result entry; fall back to the top-level map for
        // older/flat response shapes.
        final result = raw['result'] ?? raw['Result'];
        if (result is List && result.isNotEmpty && result.first is Map) {
          payload = Map<String, dynamic>.from(result.first as Map);
        } else if (result is Map) {
          payload = Map<String, dynamic>.from(result);
        } else {
          payload = Map<String, dynamic>.from(raw);
        }
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

  /// Schedules a hybrid roster for a set of arbitrary (non-contiguous) dates.
  ///
  /// Maps to:
  /// ```
  /// POST /TransRoster/UpdateScheduleHybrid
  /// {
  ///   "LocCode": <locCode>,
  ///   "SelectedDates": "2026-06-20,2026-06-21,2026-06-24",
  ///   "ShiftStart": <shiftStart>,
  ///   "ShiftEnd": <shiftEnd>,
  ///   "WeekOffs": "",
  ///   "User_Empids": <userEmpIds>
  /// }
  /// ```
  ///
  /// Reuses [UpdateSchedulesResponse] since the response envelope matches
  /// `/TransRoster/UpdateSchedules`.
  Future<UpdateSchedulesResponse> updateScheduleHybrid({
    required int locCode,
    required String selectedDates,
    required String shiftStart,
    required String shiftEnd,
    required String userEmpIds,
    String weekOffs = '',
  }) async {
    final body = {
      'LocCode': locCode,
      'SelectedDates': selectedDates,
      'ShiftStart': shiftStart,
      'ShiftEnd': shiftEnd,
      'WeekOffs': weekOffs,
      'User_Empids': userEmpIds,
    };

    debugPrint('[UPDATE_SCHEDULE_HYBRID] → POST /TransRoster/UpdateScheduleHybrid');
    debugPrint('[UPDATE_SCHEDULE_HYBRID] → body=$body');

    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/TransRoster/UpdateScheduleHybrid',
        data: body,
      );
      debugPrint(
        '[UPDATE_SCHEDULE_HYBRID] ← status=${response.statusCode} '
        'dataType=${response.data.runtimeType}',
      );
      debugPrint('[UPDATE_SCHEDULE_HYBRID] ← raw=${response.data}');

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
        debugPrint('[UPDATE_SCHEDULE_HYBRID] ✖ payload is null/unrecognized');
        throw Exception('Unexpected response format');
      }

      final parsed = UpdateSchedulesResponse.fromJson(payload);

      debugPrint(
        '[UPDATE_SCHEDULE_HYBRID] parsed → '
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
      debugPrint('[UPDATE_SCHEDULE_HYBRID] ✖ exception=$e');
      debugPrint('[UPDATE_SCHEDULE_HYBRID] ✖ stack=$st');
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

  /// Fetches the cancel / no-show confirmation popup configuration.
  ///
  /// Maps to:
  /// ```
  /// POST /TransRoster/CancelScheduleConfirmation
  /// {
  ///   "LocCode": <locCode>,
  ///   "Empid": "<empId>",
  ///   "ScheduleDate": "<yyyy-MM-dd>",
  ///   "TripType": "1"  // "1" = Login, "2" = Logout
  /// }
  /// ```
  ///
  /// Unlike [cancelSchedules], this does *not* throw when `ErrorCode != 0` — the
  /// caller inspects [CancelScheduleConfirmationResponse.isSuccess] and surfaces
  /// [CancelScheduleConfirmationResponse.dbResponse] rather than opening the
  /// dialog. Only transport/parse failures are thrown (and 401 handled upstream).
  Future<CancelScheduleConfirmationResponse> cancelScheduleConfirmation({
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
    };

    debugPrint(
        '[CANCEL_SCHEDULE_CONFIRMATION] → POST /TransRoster/CancelScheduleConfirmation');
    debugPrint('[CANCEL_SCHEDULE_CONFIRMATION] → body=$body');

    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/TransRoster/CancelScheduleConfirmation',
        data: body,
      );

      debugPrint(
        '[CANCEL_SCHEDULE_CONFIRMATION] ← status=${response.statusCode} '
        'dataType=${response.data.runtimeType}',
      );
      debugPrint('[CANCEL_SCHEDULE_CONFIRMATION] ← raw=${response.data}');

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
        debugPrint('[CANCEL_SCHEDULE_CONFIRMATION] ✖ payload is null/unrecognized');
        throw Exception('Unexpected response format');
      }

      final parsed = CancelScheduleConfirmationResponse.fromJson(payload);

      debugPrint(
        '[CANCEL_SCHEDULE_CONFIRMATION] parsed → '
        'errorCode=${parsed.errorCode} '
        'dbResponse="${parsed.dbResponse}" '
        'popupId="${parsed.popup?.popupId}" '
        'buttons=${parsed.popup?.buttons.length ?? 0}',
      );

      return parsed;
    } catch (e, st) {
      debugPrint('[CANCEL_SCHEDULE_CONFIRMATION] ✖ exception=$e');
      debugPrint('[CANCEL_SCHEDULE_CONFIRMATION] ✖ stack=$st');
      rethrow;
    }
  }
}
