import 'dart:convert';

/// Wraps the `GET /UserApp/GetScheduleHomePage` response.
///
/// Observed shape (note the `result` value is a JSON-encoded string). The
/// server now returns a *flat* list of per-day schedule items rather than the
/// older `[{DateIn, data:[...]}]` day-grouped shape:
/// ```json
/// [
///   {
///     "errorCode": 0,
///     "dB_Response": "Success",
///     "result": "[{\"Empid\":578,\"LoginScheduleDate\":\"09-Jun-2026\",\"LogoutScheduleDate\":\"09-Jun-2026\",\"LoginShiftTime\":\"21:00\",\"LogoutShiftTime\":\"\",\"TripStatusName\":\"Scheduled\",\"UserAddress\":\" ... \",\"OfficeAddress\":\" ... \",\"LocCode\":183,\"TripStatus\":\"TripFound\"}, ... ]"
///   }
/// ]
/// ```
///
/// The legacy day-grouped shape is still accepted for backwards compatibility.
/// [_parseGroups] normalises either shape into a list of [ScheduleDateGroup]s
/// (one group per schedule date) so the UI contract is unchanged.
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

    final maps =
        decoded.whereType<Map>().map((m) => Map<String, dynamic>.from(m));

    // Legacy day-grouped shape: each element carries a `data` array (and
    // usually a `DateIn`). Parse it directly into [ScheduleDateGroup]s.
    final isLegacyGrouped = maps.any((m) => m['data'] is List);
    if (isLegacyGrouped) {
      return maps
          .map((m) => ScheduleDateGroup.fromJson(m))
          .toList(growable: false);
    }

    // New flat shape: a list of per-day [ScheduleItem]s. Group them by their
    // schedule date so the UI keeps rendering one date header per day.
    final items =
        maps.map((m) => ScheduleItem.fromJson(m)).toList(growable: false);
    return _groupByDate(items);
  }

  /// Groups a flat list of [ScheduleItem]s into one [ScheduleDateGroup] per
  /// schedule date, preserving the order in which dates first appear.
  static List<ScheduleDateGroup> _groupByDate(List<ScheduleItem> items) {
    final order = <String>[];
    final buckets = <String, List<ScheduleItem>>{};

    for (final item in items) {
      final key = item.loginScheduleDate?.trim().isNotEmpty == true
          ? item.loginScheduleDate!.trim()
          : (item.logoutScheduleDate?.trim() ?? '');
      if (!buckets.containsKey(key)) {
        order.add(key);
        buckets[key] = <ScheduleItem>[];
      }
      buckets[key]!.add(item);
    }

    return order
        .map((key) => ScheduleDateGroup(
              dateIn: _relativeDayLabel(key),
              data: buckets[key]!,
            ))
        .toList(growable: false);
  }

  /// Returns `"Today"` / `"Tomorrow"` for the given `"dd-MMM-yyyy"` date when it
  /// matches, otherwise `null` (the UI falls back to the formatted header date).
  static String? _relativeDayLabel(String rawDate) {
    final date = _parseDdMmmYyyy(rawDate);
    if (date == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = DateTime(date.year, date.month, date.day)
        .difference(today)
        .inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return null;
  }

  static const Map<String, int> _monthIndex = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  static DateTime? _parseDdMmmYyyy(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final parts = trimmed.split('-');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = _monthIndex[parts[1].toLowerCase()];
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
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

  /// Office/location code for this schedule (`LocCode`). Used as the primary
  /// source when cancelling/editing a roster entry.
  final int? locCode;

  /// Trip availability flag from the backend, e.g. `"TripFound"` /
  /// `"TripNotFound"`. Indicates whether a vehicle/trip has been found for the
  /// scheduled shift.

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
    this.locCode,
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
      locCode: (json['LocCode'] as num?)?.toInt(),
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

  /// Login card: both [loginScheduleDate] and [loginShiftTime] must be set.
  bool get shouldShowLoginCard => hasLoginSchedule && _hasLoginShiftTime;

  /// Logout card: both [logoutScheduleDate] and [logoutShiftTime] must be set.
  bool get shouldShowLogoutCard => hasLogoutSchedule && _hasLogoutShiftTime;

  /// `true` when the backend marks the trip as still `"Scheduled"` —
  /// meaning the vehicle hasn't been assigned/dispatched yet and the
  /// rich trip details (OTP, pickup time, vehicle info, tracking) are
  /// not applicable.
  bool get isScheduledStatus =>
      (tripStatusName ?? '').trim().toLowerCase() == 'scheduled';
}
