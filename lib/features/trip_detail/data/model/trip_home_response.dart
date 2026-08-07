import 'dart:convert';

import 'package:commutr_main/trip_summary/trip_directions_service.dart';

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

/// UI button visibility config for a home-page trip (`tripButtonUiConfig`).
class TripButtonUiConfig {
  final bool isTripCancellationButtonShow;
  final bool isTripNoShowButtonShow;

  const TripButtonUiConfig({
    this.isTripCancellationButtonShow = false,
    this.isTripNoShowButtonShow = false,
  });

  factory TripButtonUiConfig.fromJson(Map<String, dynamic> json) {
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

    return TripButtonUiConfig(
      isTripCancellationButtonShow: readBool('isTripCancellationButtonShow'),
      isTripNoShowButtonShow: readBool('isTripNoShowButtonShow'),
    );
  }
}

/// Passenger entry from the `B` array inside a home-page trip object.
class TripHomePax {
  final int? empId;
  final String? empName;
  final String? empLatLng;
  final String? userAddress;
  final int? paxOrder;

  const TripHomePax({
    this.empId,
    this.empName,
    this.empLatLng,
    this.userAddress,
    this.paxOrder,
  });

  factory TripHomePax.fromJson(Map<String, dynamic> json) {
    String? rs(String key) {
      final v = json[key];
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    return TripHomePax(
      empId: (json['Empid'] as num?)?.toInt(),
      empName: rs('Empname'),
      empLatLng: rs('EmpLatLng'),
      userAddress: rs('UserAddress'),
      paxOrder: (json['Paxorder'] as num?)?.toInt(),
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
  final String? dropShift;
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
  final int? tripTypeCode;
  final String? officeLatLng;
  final String? empLatLng;
  final String? cancelorNoshow;
  final int? deBoardOtp;
  final int? isCancelTripByUserAfterTat;
  final int? transportType;
  final TripButtonUiConfig? tripButtonUiConfig;
  final List<TripHomePax>? passengers;

  const TripHomeItem({
    this.tripId,
    this.tripDate,
    this.tripType,
    this.otp,
    this.pickShift,
    this.dropShift,
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
    this.tripTypeCode,
    this.officeLatLng,
    this.empLatLng,
    this.cancelorNoshow,
    this.deBoardOtp,
    this.isCancelTripByUserAfterTat,
    this.transportType,
    this.tripButtonUiConfig,
    this.passengers,
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

    final rawB = json['B'];
    final passengers = (rawB is List)
        ? rawB
            .whereType<Map>()
            .map((m) => TripHomePax.fromJson(Map<String, dynamic>.from(m)))
            .toList(growable: false)
        : const <TripHomePax>[];

    return TripHomeItem(
      tripId: (json['TripID'] as num?)?.toInt(),
      tripDate: readString('TripDate'),
      tripType: readString('Triptype'),
      otp: readString('OTP'),
      pickShift: readString('PickShift'),
      dropShift: readString('DropShift'),
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
      tripTypeCode: (json['TripTypeCode'] as num?)?.toInt(),
      officeLatLng: readString('OfficeLatLng'),
      empLatLng: readString('EmpLatLng'),
      cancelorNoshow: readString('CancelorNoshow'),
      deBoardOtp: (json['DeBoardOTP'] as num?)?.toInt(),
      isCancelTripByUserAfterTat:
          (json['IsCancelTripByUserAfterTAT'] as num?)?.toInt(),
      transportType: (json['TransportType'] as num?)?.toInt(),
      tripButtonUiConfig: json['tripButtonUiConfig'] is Map
          ? TripButtonUiConfig.fromJson(
              Map<String, dynamic>.from(json['tripButtonUiConfig'] as Map),
            )
          : null,
      passengers: passengers,
    );
  }

  bool get isLogin => isPickTrip;

  /// True for PICK/Login, false for DROP/Logout.
  bool get isPickTrip => isPickTripType(tripType);

  /// [transportType] code for a SHUTTLE trip — a fixed-route service rather than
  /// a door-to-door cab.
  static const int transportTypeShuttle = 2;

  /// Whether this trip is served by a shuttle (`TransportType == 2`).
  ///
  /// Shuttle trips have no trip group chat (riders are never shown who else is
  /// on the line) and are tracked on the dedicated shuttle tracking screen.
  /// `false` when the field is absent, so cab behaviour stays the default.
  bool get isShuttle => transportType == transportTypeShuttle;

  /// Passengers sorted by ascending [paxOrder] (P1 → P2 → P3 …).
  List<TripHomePax> get passengersSortedByPaxOrder {
    final list = List<TripHomePax>.from(passengers ?? const []);
    if (list.isEmpty && empLatLng != null) {
      list.add(
        TripHomePax(
          empId: empId,
          empName: userName,
          empLatLng: empLatLng,
          userAddress: userAddress,
          paxOrder: paxOrder ?? 1,
        ),
      );
    }
    list.sort((a, b) {
      final ao = a.paxOrder ?? 999;
      final bo = b.paxOrder ?? 999;
      if (ao != bo) return ao.compareTo(bo);
      return (a.empId ?? 0).compareTo(b.empId ?? 0);
    });
    return list;
  }

  /// Map route stops: PICK = pax → office, DROP = office → pax (ascending paxOrder).
  List<MapRouteStop> buildOrderedRouteStops() => buildOrderedMapRouteStops(
        isPick: isPickTrip,
        officeLatLng: officeLatLng,
        officeAddress: officeAddress,
        passengers: passengersSortedByPaxOrder
            .map(
              (p) => MapRoutePassenger(
                empId: p.empId,
                empName: p.empName,
                empLatLng: p.empLatLng,
                paxOrder: p.paxOrder,
              ),
            )
            .toList(growable: false),
      );

  bool get isScheduledStatus =>
      (tripStatusName ?? '').trim().toLowerCase() == 'scheduled';

  bool get hasOtp => (otp ?? '').trim().isNotEmpty;

  bool get hasVehicleInfo => (vehicleInfo ?? '').trim().isNotEmpty;

  /// Trip is in the "Started" state (TripStatusName = "Started", code 3).
  bool get isStarted =>
      tripStatusCode == 3 &&
      (tripStatusName ?? '').trim().toLowerCase() == 'started';

  /// Trip has started (code 3) and the user has not boarded yet.
  bool get isStartedNotBoarded => !isBoarded && isStarted;

  /// Green Board CTA — not boarded and not deboarded.
  bool get canShowBoardButton => !isBoarded && !isDeBoarded;

  /// User has boarded but not yet deboarded.
  bool get isBoardedNotDeboarded => isBoarded && !isDeBoarded;

  /// Show board/deboard action row (share, chat, track + primary CTA).
  bool get showBoardDeboardActions =>
      canShowBoardButton || isBoardedNotDeboarded;

  /// Trip has ended (TripStatusName = "End", TripStatusCode = 4).
  bool get isCompleted =>
      tripStatusCode == 4 &&
      (tripStatusName ?? '').trim().toLowerCase() == 'end';
}
