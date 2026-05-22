import 'dart:convert';

/// Wraps the `GET /UserApp/GetScheduleHomePage` response.
///
/// Observed shape (note the `result` value is a JSON-encoded string):
/// ```json
/// [
///   {
///     "errorCode": 0,
///     "dB_Response": "Success",
///     "result": "[{\"DateIn\":\"Today\",\"data\":[ ... ]},{\"DateIn\":\"Tomorrow\",\"data\":[ ... ]}]"
///   }
/// ]
/// ```
///
/// Every field is optional/null-safe; the server has been observed to omit
/// most of the per-trip fields when no schedule exists for the day.
class ScheduleHomeResponse {
  final int? errorCode;
  final String? dbResponse;
  final List<ScheduleDateGroup> groups;

  const ScheduleHomeResponse({
    this.errorCode,
    this.dbResponse,
    this.groups = const [],
  });

  bool get isSuccess =>
      (errorCode ?? -1) == 0 &&
      (dbResponse ?? '').toLowerCase() == 'success';

  factory ScheduleHomeResponse.fromJson(Map<String, dynamic> json) {
    final groups = _parseGroups(json['result']);
    return ScheduleHomeResponse(
      errorCode: (json['errorCode'] as num?)?.toInt(),
      dbResponse: json['dB_Response']?.toString() ?? json['dbResponse']?.toString(),
      groups: groups,
    );
  }

  static List<ScheduleDateGroup> _parseGroups(Object? raw) {
    if (raw == null) return const [];
    Object? decoded = raw;
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return const [];
      try {
        decoded = jsonDecode(trimmed);
      } catch (_) {
        return const [];
      }
    }
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) => ScheduleDateGroup.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }
}

/// One day-grouping from the API (e.g. `DateIn = "Today"` / `"Tomorrow"`).
class ScheduleDateGroup {
  final String? dateIn;
  final List<ScheduleItem> data;

  const ScheduleDateGroup({this.dateIn, this.data = const []});

  factory ScheduleDateGroup.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final items = (rawData is List)
        ? rawData
            .whereType<Map>()
            .map((m) => ScheduleItem.fromJson(Map<String, dynamic>.from(m)))
            .toList(growable: false)
        : const <ScheduleItem>[];
    return ScheduleDateGroup(
      dateIn: json['DateIn']?.toString() ?? json['DayName']?.toString(),
      data: items,
    );
  }
}

/// A single schedule entry. All fields are optional — the backend regularly
/// omits trip-specific data (e.g. `LoginScheduleDate`) when nothing is
/// actually scheduled for the day.
class ScheduleItem {
  final int? empId;
  final String? employeeId;
  final String? userName;

  /// Date the login (pickup) trip is scheduled for. Server sends formats like
  /// `"21-May-2026"`. `null`, missing or empty → no login schedule.
  final String? loginScheduleDate;

  /// Date the logout (drop) trip is scheduled for. Server sends formats like
  /// `"22-May-2026"`. `null`, missing or empty → no logout schedule.
  final String? logoutScheduleDate;

  /// 24-hour shift time for the login (pickup) trip, e.g. `"09:45"`.
  final String? loginShiftTime;

  /// 24-hour shift time for the logout (drop) trip, e.g. `"00:00"`.
  final String? logoutShiftTime;

  /// Status text from the backend, e.g. `"Scheduled"`, `"Vehicle Allocated"`,
  /// `"Trip Started"` ...
  final String? tripStatusName;

  final String? userAddress;
  final String? officeAddress;

  const ScheduleItem({
    this.empId,
    this.employeeId,
    this.userName,
    this.loginScheduleDate,
    this.logoutScheduleDate,
    this.loginShiftTime,
    this.logoutShiftTime,
    this.tripStatusName,
    this.userAddress,
    this.officeAddress,
  });

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    String? readString(String key) {
      final v = json[key];
      if (v == null) return null;
      final s = v.toString();
      return s.isEmpty ? null : s;
    }

    return ScheduleItem(
      empId: (json['Empid'] as num?)?.toInt(),
      employeeId: readString('EmployeeID'),
      userName: readString('UserName'),
      loginScheduleDate: readString('LoginScheduleDate'),
      logoutScheduleDate: readString('LogoutScheduleDate'),
      loginShiftTime: readString('LoginShiftTime'),
      logoutShiftTime: readString('LogoutShiftTime'),
      tripStatusName: readString('TripStatusName'),
      userAddress: readString('UserAddress'),
      officeAddress: readString('OfficeAddress'),
    );
  }

  /// `true` when `LoginScheduleDate` is present and non-empty.
  bool get hasLoginSchedule {
    final v = loginScheduleDate?.trim() ?? '';
    return v.isNotEmpty;
  }

  /// `true` when `LogoutScheduleDate` is present and non-empty.
  bool get hasLogoutSchedule {
    final v = logoutScheduleDate?.trim() ?? '';
    return v.isNotEmpty;
  }

  bool get _hasLoginShiftTime {
    final v = loginShiftTime?.trim() ?? '';
    return v.isNotEmpty;
  }

  bool get _hasLogoutShiftTime {
    final v = logoutShiftTime?.trim() ?? '';
    return v.isNotEmpty;
  }

  /// Whether the login schedule card should appear on the home screen.
  ///
  /// The API often returns `"Today"` rows with `TripStatusName: Scheduled` but
  /// without `LoginScheduleDate` (see observed `GetScheduleHomePage` payloads).
  bool get shouldShowLoginCard {
    if (hasLoginSchedule || _hasLoginShiftTime) return true;
    if (isScheduledStatus && !hasLogoutSchedule && !_hasLogoutShiftTime) {
      return true;
    }
    return false;
  }

  /// Whether the logout schedule card should appear on the home screen.
  bool get shouldShowLogoutCard {
    return hasLogoutSchedule || _hasLogoutShiftTime;
  }

  /// `true` when the backend marks the trip as still `"Scheduled"` —
  /// meaning the vehicle hasn't been assigned/dispatched yet and the
  /// rich trip details (OTP, pickup time, vehicle info, tracking) are
  /// not applicable.
  bool get isScheduledStatus =>
      (tripStatusName ?? '').trim().toLowerCase() == 'scheduled';
}
