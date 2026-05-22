import 'dart:convert';

/// Wraps the `GET /UserApp/GetTripHomePage` response.
///
/// ```json
/// [
///   {
///     "errorCode": 0,
///     "dB_Response": "Success",
///     "result": "[{\"DayName\":\"Today\",\"data\":[ ... ]}]"
///   }
/// ]
/// ```
class TripHomeResponse {
  final int? errorCode;
  final String? dbResponse;
  final List<TripDayGroup> groups;

  const TripHomeResponse({
    this.errorCode,
    this.dbResponse,
    this.groups = const [],
  });

  bool get isSuccess =>
      (errorCode ?? -1) == 0 &&
      (dbResponse ?? '').toLowerCase() == 'success';

  factory TripHomeResponse.fromJson(Map<String, dynamic> json) {
    return TripHomeResponse(
      errorCode: (json['errorCode'] as num?)?.toInt(),
      dbResponse:
          json['dB_Response']?.toString() ?? json['dbResponse']?.toString(),
      groups: _parseGroups(json['result']),
    );
  }

  static List<TripDayGroup> _parseGroups(Object? raw) {
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
        .map((m) => TripDayGroup.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }
}

/// One day-grouping (e.g. `DayName = "Today"`).
class TripDayGroup {
  final String? dayName;
  final List<TripHomeItem> data;

  const TripDayGroup({this.dayName, this.data = const []});

  factory TripDayGroup.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final items = (rawData is List)
        ? rawData
            .whereType<Map>()
            .map((m) => TripHomeItem.fromJson(Map<String, dynamic>.from(m)))
            .toList(growable: false)
        : const <TripHomeItem>[];
    return TripDayGroup(
      dayName: json['DayName']?.toString(),
      data: items,
    );
  }
}

/// A single trip from `GetTripHomePage`.
class TripHomeItem {
  final int? tripId;
  final String? tripDate;
  final String? tripType;
  final String? otp;
  final String? pickShift;
  final int? empId;
  final String? employeeId;
  final String? userName;
  final String? userAddress;
  final String? officeAddress;
  final String? tripLocation;
  final String? pickTime;
  final String? tripStatusName;
  final int? tripStatusCode;
  final String? vehicleInfo;
  final int? flapNo;
  final bool isBoarded;
  final bool isDeBoarded;
  final int? paxCount;
  final int? paxOrder;
  final int? reachedHomeReq;
  final int? isReached;
  final String? userAppIvrNumber;

  const TripHomeItem({
    this.tripId,
    this.tripDate,
    this.tripType,
    this.otp,
    this.pickShift,
    this.empId,
    this.employeeId,
    this.userName,
    this.userAddress,
    this.officeAddress,
    this.tripLocation,
    this.pickTime,
    this.tripStatusName,
    this.tripStatusCode,
    this.vehicleInfo,
    this.flapNo,
    this.isBoarded = false,
    this.isDeBoarded = false,
    this.paxCount,
    this.paxOrder,
    this.reachedHomeReq,
    this.isReached,
    this.userAppIvrNumber,
  });

  factory TripHomeItem.fromJson(Map<String, dynamic> json) {
    String? readString(String key) {
      final v = json[key];
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    bool readBool(String key) {
      final v = json[key];
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final lower = v.toLowerCase();
        return lower == 'true' || lower == '1';
      }
      return false;
    }

    return TripHomeItem(
      tripId: (json['TripID'] as num?)?.toInt(),
      tripDate: readString('TripDate'),
      tripType: readString('Triptype'),
      otp: readString('OTP'),
      pickShift: readString('PickShift'),
      empId: (json['EMPID'] as num?)?.toInt(),
      employeeId: readString('EmployeeID'),
      userName: readString('UserName'),
      userAddress: readString('UserAddress'),
      officeAddress: readString('OfficeAddress'),
      tripLocation: readString('TripLocation'),
      pickTime: readString('PickTime'),
      tripStatusName: readString('TripStatusName'),
      tripStatusCode: (json['TripStatusCode'] as num?)?.toInt(),
      vehicleInfo: readString('VehicleInfo'),
      flapNo: (json['FlapNo'] as num?)?.toInt(),
      isBoarded: readBool('IsBoarded'),
      isDeBoarded: readBool('IsDeBoarded'),
      paxCount: (json['PaxCount'] as num?)?.toInt(),
      paxOrder: (json['Paxorder'] as num?)?.toInt(),
      reachedHomeReq: (json['ReachedHomeReq'] as num?)?.toInt(),
      isReached: (json['IsReached'] as num?)?.toInt(),
      userAppIvrNumber: readString('UserAppIVRNumber'),
    );
  }

  bool get isLogin => (tripType ?? '').trim().toLowerCase() == 'login';

  bool get isScheduledStatus =>
      (tripStatusName ?? '').trim().toLowerCase() == 'scheduled';

  bool get hasOtp => (otp ?? '').trim().isNotEmpty;

  bool get hasVehicleInfo => (vehicleInfo ?? '').trim().isNotEmpty;
}
