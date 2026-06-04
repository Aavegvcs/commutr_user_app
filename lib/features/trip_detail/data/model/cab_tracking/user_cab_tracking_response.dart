import 'dart:convert';

/// Wraps `GET /Tracking/gps-route?DsId=<tripId>`.
class GpsRouteResponse {
  final int? dsId;
  final bool isTripFound;
  final String? trackingMode;
  final String? plannedRoutePolyline;
  final String? actualRoutePolyline;
  final GpsPoint? latestGps;

  const GpsRouteResponse({
    this.dsId,
    this.isTripFound = false,
    this.trackingMode,
    this.plannedRoutePolyline,
    this.actualRoutePolyline,
    this.latestGps,
  });

  factory GpsRouteResponse.fromJson(Map<String, dynamic> json) {
    return GpsRouteResponse(
      dsId: (json['dsId'] as num?)?.toInt(),
      isTripFound: json['isTripFound'] == true,
      trackingMode: json['trackingMode']?.toString(),
      plannedRoutePolyline: json['plannedRoutePolyline']?.toString(),
      actualRoutePolyline: json['actualRoutePolyline']?.toString(),
      latestGps: json['latestGps'] is Map<String, dynamic>
          ? GpsPoint.fromJson(json['latestGps'] as Map<String, dynamic>)
          : null,
    );
  }
}

class GpsPoint {
  final double? latitude;
  final double? longitude;
  final String? tripStatusName;
  final String? gpsTime;

  const GpsPoint({
    this.latitude,
    this.longitude,
    this.tripStatusName,
    this.gpsTime,
  });

  factory GpsPoint.fromJson(Map<String, dynamic> json) {
    double? readDouble(Object? v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return GpsPoint(
      latitude: readDouble(json['latitude']),
      longitude: readDouble(json['longitude']),
      tripStatusName: json['tripStatusName']?.toString(),
      gpsTime: json['gpsTime']?.toString(),
    );
  }
}

/// Wraps `POST /Tracking/status?DsId=<tripId>`.
class TrackingStatusResponse {
  final int? dsId;
  final bool isTripFound;
  final int? locCode;
  final String? dsDate;
  final int? tripTypeCode;
  final int? tripType;
  final String? tripTypeName;
  final int? totalPax;
  final String? scheduledStartTime;
  final String? scheduledEndTime;
  final String? actualStartTime;
  final String? actualEndTime;
  final double? startKm;
  final double? endKm;
  final double? plannedRouteDistance;
  final String? plannedTotalDuration;
  final bool hasPlannedRoutePolyline;
  final int? transTripStatusCode;
  final String? transTripStatusName;
  final int? latestGpsStatusCode;
  final String? latestGpsStatusName;
  final int? effectiveTripStatusCode;
  final String? effectiveTripStatusName;
  final double? latestLat;
  final double? latestLng;
  final double? latestSpeed;
  final String? latestGpsTime;
  final String? latestGpsSource;
  final bool? panic;
  final int? driverId;
  final String? driverGuid;
  final String? driverName;
  final String? driverMobileNo;
  final String? driverAlternateMobileNo;
  final String? driverProfileImage;
  final int? transporterId;
  final String? vendorName;
  final String? vendorMobileNo;
  final String? vendorEmailId;
  final int? vehicleId;
  final String? vehicleNo;
  final int? vehicleType;
  final int? fuelType;
  final bool isActive;
  final bool isCompleted;
  final bool shouldUseSignalR;
  final bool shouldUsePolyline;
  final bool isPassengerPickedUp;
  final String? trackingMessage;
  final String? trackingMode;
  final List<TripPassenger> passengers;

  const TrackingStatusResponse({
    this.dsId,
    this.isTripFound = false,
    this.locCode,
    this.dsDate,
    this.tripTypeCode,
    this.tripType,
    this.tripTypeName,
    this.totalPax,
    this.scheduledStartTime,
    this.scheduledEndTime,
    this.actualStartTime,
    this.actualEndTime,
    this.startKm,
    this.endKm,
    this.plannedRouteDistance,
    this.plannedTotalDuration,
    this.hasPlannedRoutePolyline = false,
    this.transTripStatusCode,
    this.transTripStatusName,
    this.latestGpsStatusCode,
    this.latestGpsStatusName,
    this.effectiveTripStatusCode,
    this.effectiveTripStatusName,
    this.latestLat,
    this.latestLng,
    this.latestSpeed,
    this.latestGpsTime,
    this.latestGpsSource,
    this.panic,
    this.driverId,
    this.driverGuid,
    this.driverName,
    this.driverMobileNo,
    this.driverAlternateMobileNo,
    this.driverProfileImage,
    this.transporterId,
    this.vendorName,
    this.vendorMobileNo,
    this.vendorEmailId,
    this.vehicleId,
    this.vehicleNo,
    this.vehicleType,
    this.fuelType,
    this.isActive = true,
    this.isCompleted = false,
    this.shouldUseSignalR = false,
    this.shouldUsePolyline = false,
    this.isPassengerPickedUp = false,
    this.trackingMessage,
    this.trackingMode,
    this.passengers = const [],
  });

  bool get hasLocation =>
      latestLat != null &&
      latestLng != null &&
      (latestLat != 0 || latestLng != 0);

  TrackingStatusResponse withLocation({
    required double lat,
    required double lng,
  }) {
    return TrackingStatusResponse(
      dsId: dsId,
      isTripFound: isTripFound,
      locCode: locCode,
      dsDate: dsDate,
      tripTypeCode: tripTypeCode,
      tripType: tripType,
      tripTypeName: tripTypeName,
      totalPax: totalPax,
      scheduledStartTime: scheduledStartTime,
      scheduledEndTime: scheduledEndTime,
      actualStartTime: actualStartTime,
      actualEndTime: actualEndTime,
      startKm: startKm,
      endKm: endKm,
      plannedRouteDistance: plannedRouteDistance,
      plannedTotalDuration: plannedTotalDuration,
      hasPlannedRoutePolyline: hasPlannedRoutePolyline,
      transTripStatusCode: transTripStatusCode,
      transTripStatusName: transTripStatusName,
      latestGpsStatusCode: latestGpsStatusCode,
      latestGpsStatusName: latestGpsStatusName,
      effectiveTripStatusCode: effectiveTripStatusCode,
      effectiveTripStatusName: effectiveTripStatusName,
      latestLat: lat,
      latestLng: lng,
      latestSpeed: latestSpeed,
      latestGpsTime: latestGpsTime,
      latestGpsSource: latestGpsSource,
      panic: panic,
      driverId: driverId,
      driverGuid: driverGuid,
      driverName: driverName,
      driverMobileNo: driverMobileNo,
      driverAlternateMobileNo: driverAlternateMobileNo,
      driverProfileImage: driverProfileImage,
      transporterId: transporterId,
      vendorName: vendorName,
      vendorMobileNo: vendorMobileNo,
      vendorEmailId: vendorEmailId,
      vehicleId: vehicleId,
      vehicleNo: vehicleNo,
      vehicleType: vehicleType,
      fuelType: fuelType,
      isActive: isActive,
      isCompleted: isCompleted,
      shouldUseSignalR: shouldUseSignalR,
      shouldUsePolyline: shouldUsePolyline,
      isPassengerPickedUp: isPassengerPickedUp,
      trackingMessage: trackingMessage,
      trackingMode: trackingMode,
      passengers: passengers,
    );
  }

  /// Patches all fields that the SignalR `ReceiveRouteLocation` payload carries.
  TrackingStatusResponse withSignalRUpdate({
    required double lat,
    required double lng,
    double? speed,
    String? gpsTime,
    int? tripStatusCode,
    String? tripStatusName,
    bool? panic,
  }) {
    return TrackingStatusResponse(
      dsId: dsId,
      isTripFound: isTripFound,
      locCode: locCode,
      dsDate: dsDate,
      tripTypeCode: tripTypeCode,
      tripType: tripType,
      tripTypeName: tripTypeName,
      totalPax: totalPax,
      scheduledStartTime: scheduledStartTime,
      scheduledEndTime: scheduledEndTime,
      actualStartTime: actualStartTime,
      actualEndTime: actualEndTime,
      startKm: startKm,
      endKm: endKm,
      plannedRouteDistance: plannedRouteDistance,
      plannedTotalDuration: plannedTotalDuration,
      hasPlannedRoutePolyline: hasPlannedRoutePolyline,
      transTripStatusCode: tripStatusCode ?? transTripStatusCode,
      transTripStatusName: tripStatusName ?? transTripStatusName,
      latestGpsStatusCode: latestGpsStatusCode,
      latestGpsStatusName: latestGpsStatusName,
      effectiveTripStatusCode: tripStatusCode ?? effectiveTripStatusCode,
      effectiveTripStatusName: tripStatusName ?? effectiveTripStatusName,
      latestLat: lat,
      latestLng: lng,
      latestSpeed: speed ?? latestSpeed,
      latestGpsTime: gpsTime ?? latestGpsTime,
      latestGpsSource: latestGpsSource,
      panic: panic ?? this.panic,
      driverId: driverId,
      driverGuid: driverGuid,
      driverName: driverName,
      driverMobileNo: driverMobileNo,
      driverAlternateMobileNo: driverAlternateMobileNo,
      driverProfileImage: driverProfileImage,
      transporterId: transporterId,
      vendorName: vendorName,
      vendorMobileNo: vendorMobileNo,
      vendorEmailId: vendorEmailId,
      vehicleId: vehicleId,
      vehicleNo: vehicleNo,
      vehicleType: vehicleType,
      fuelType: fuelType,
      isActive: isActive,
      isCompleted: isCompleted,
      shouldUseSignalR: shouldUseSignalR,
      shouldUsePolyline: shouldUsePolyline,
      isPassengerPickedUp: isPassengerPickedUp,
      trackingMessage: trackingMessage,
      trackingMode: trackingMode,
      passengers: passengers,
    );
  }

  factory TrackingStatusResponse.fromJson(Map<String, dynamic> json) {
    double? readDouble(Object? v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    bool readBool(Object? v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final lower = v.toLowerCase();
        return lower == 'true' || lower == '1';
      }
      return false;
    }

    final rawPassengers = json['passengers'];
    final passengers = (rawPassengers is List)
        ? rawPassengers
            .whereType<Map>()
            .map((m) => TripPassenger.fromJson(Map<String, dynamic>.from(m)))
            .toList(growable: false)
        : const <TripPassenger>[];

    return TrackingStatusResponse(
      dsId: (json['dsId'] as num?)?.toInt(),
      isTripFound: readBool(json['isTripFound']),
      locCode: (json['locCode'] as num?)?.toInt(),
      dsDate: json['dsDate']?.toString(),
      tripTypeCode: (json['tripTypeCode'] as num?)?.toInt(),
      tripType: (json['tripType'] as num?)?.toInt(),
      tripTypeName: json['tripTypeName']?.toString(),
      totalPax: (json['totalPax'] as num?)?.toInt(),
      scheduledStartTime: json['scheduledStartTime']?.toString(),
      scheduledEndTime: json['scheduledEndTime']?.toString(),
      actualStartTime: json['actualStartTime']?.toString(),
      actualEndTime: json['actualEndTime']?.toString(),
      startKm: readDouble(json['startKm']),
      endKm: readDouble(json['endKm']),
      plannedRouteDistance: readDouble(json['plannedRouteDistance']),
      plannedTotalDuration: json['plannedTotalDuration']?.toString(),
      hasPlannedRoutePolyline: readBool(json['hasPlannedRoutePolyline']),
      transTripStatusCode: (json['transTripStatusCode'] as num?)?.toInt(),
      transTripStatusName: json['transTripStatusName']?.toString(),
      latestGpsStatusCode: (json['latestGpsStatusCode'] as num?)?.toInt(),
      latestGpsStatusName: json['latestGpsStatusName']?.toString(),
      effectiveTripStatusCode: (json['effectiveTripStatusCode'] as num?)?.toInt(),
      effectiveTripStatusName: json['effectiveTripStatusName']?.toString(),
      latestLat: readDouble(json['latestLat']),
      latestLng: readDouble(json['latestLng']),
      latestSpeed: readDouble(json['latestSpeed']),
      latestGpsTime: json['latestGpsTime']?.toString(),
      latestGpsSource: json['latestGpsSource']?.toString(),
      panic: json['panic'] is bool ? json['panic'] as bool : null,
      driverId: (json['driverId'] as num?)?.toInt(),
      driverGuid: json['driverGuid']?.toString(),
      driverName: json['driverName']?.toString(),
      driverMobileNo: json['driverMobileNo']?.toString(),
      driverAlternateMobileNo: json['driverAlternateMobileNo']?.toString(),
      driverProfileImage: json['driverProfileImage']?.toString(),
      transporterId: (json['transporterId'] as num?)?.toInt(),
      vendorName: json['vendorName']?.toString(),
      vendorMobileNo: json['vendorMobileNo']?.toString(),
      vendorEmailId: json['vendorEmailId']?.toString(),
      vehicleId: (json['vehicleId'] as num?)?.toInt(),
      vehicleNo: json['vehicleNo']?.toString(),
      vehicleType: (json['vehicleType'] as num?)?.toInt(),
      fuelType: (json['fuelType'] as num?)?.toInt(),
      isActive: readBool(json['isActive']),
      isCompleted: readBool(json['isCompleted']),
      shouldUseSignalR: readBool(json['shouldUseSignalR']),
      shouldUsePolyline: readBool(json['shouldUsePolyline']),
      isPassengerPickedUp: readBool(json['isPassengerPickedUp']),
      trackingMessage: json['trackingMessage']?.toString(),
      trackingMode: json['trackingMode']?.toString(),
      passengers: passengers,
    );
  }
}

class TripPassenger {
  final int? empId;
  final String? employeeID;
  final String? firstname;
  final String? lastName;
  final String? gender;
  final String? mobileno;
  final int? empLocCode;
  final int? tripType;
  final int? paxOrder;
  final String? address;
  final double? plannedLat;
  final double? plannedLng;
  final bool noShow;
  final int? noShowReasonId;
  final bool orsDeviation;
  final bool scheduled;
  final bool paxAdded;
  final String? paxType;
  final double? empDistance;
  final double? empDirectDistance;
  final double? empCost;
  final String? plannedScheduleTime;
  final String? empSigninTime;
  final double? empSigninLat;
  final double? empSigninLng;
  final String? empSignOutTime;
  final double? empSignOutLat;
  final double? empSignOutLng;
  final String? cabReachedTime;
  final double? cabReachedLat;
  final double? cabReachedLng;
  final String? reachedHomeTime;
  final double? reachedHomeLat;
  final double? reachedHomeLng;
  final String? paxTrackingStatus;

  String get fullName => [firstname, lastName].where((s) => s != null && s.isNotEmpty).join(' ');

  const TripPassenger({
    this.empId,
    this.employeeID,
    this.firstname,
    this.lastName,
    this.gender,
    this.mobileno,
    this.empLocCode,
    this.tripType,
    this.paxOrder,
    this.address,
    this.plannedLat,
    this.plannedLng,
    this.noShow = false,
    this.noShowReasonId,
    this.orsDeviation = false,
    this.scheduled = false,
    this.paxAdded = false,
    this.paxType,
    this.empDistance,
    this.empDirectDistance,
    this.empCost,
    this.plannedScheduleTime,
    this.empSigninTime,
    this.empSigninLat,
    this.empSigninLng,
    this.empSignOutTime,
    this.empSignOutLat,
    this.empSignOutLng,
    this.cabReachedTime,
    this.cabReachedLat,
    this.cabReachedLng,
    this.reachedHomeTime,
    this.reachedHomeLat,
    this.reachedHomeLng,
    this.paxTrackingStatus,
  });

  factory TripPassenger.fromJson(Map<String, dynamic> json) {
    double? readDouble(Object? v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    bool readBool(Object? v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final lower = v.toLowerCase();
        return lower == 'true' || lower == '1';
      }
      return false;
    }

    // API may send combined 'passengerName' or split 'firstname'/'lastName'.
    final combinedName = json['passengerName']?.toString();
    String? firstNameVal = json['firstname']?.toString();
    String? lastNameVal = json['lastName']?.toString();
    if (combinedName != null && combinedName.isNotEmpty) {
      final parts = combinedName.trim().split(RegExp(r'\s+'));
      firstNameVal ??= parts.first;
      lastNameVal ??= parts.length > 1 ? parts.sublist(1).join(' ') : null;
    }

    return TripPassenger(
      empId: (json['empId'] as num?)?.toInt(),
      employeeID: json['employeeID']?.toString(),
      firstname: firstNameVal,
      lastName: lastNameVal,
      gender: json['gender']?.toString(),
      mobileno: (json['mobileno'] ?? json['mobileNo'])?.toString(),
      empLocCode: (json['empLocCode'] as num?)?.toInt(),
      tripType: (json['tripType'] as num?)?.toInt(),
      paxOrder: (json['paxOrder'] as num?)?.toInt(),
      address: (json['address'] ?? json['pickupAddress'])?.toString(),
      plannedLat: readDouble(json['plannedLat'] ?? json['lat']),
      plannedLng: readDouble(json['plannedLng'] ?? json['lng']),
      noShow: readBool(json['noShow']),
      noShowReasonId: (json['noShowReasonId'] as num?)?.toInt(),
      orsDeviation: readBool(json['orsDeviation']),
      scheduled: readBool(json['scheduled']),
      paxAdded: readBool(json['paxAdded']),
      paxType: json['paxType']?.toString(),
      empDistance: readDouble(json['empDistance']),
      empDirectDistance: readDouble(json['empDirectDistance']),
      empCost: readDouble(json['empCost']),
      plannedScheduleTime: (json['plannedScheduleTime'] ?? json['pSchTime'])?.toString(),
      empSigninTime: json['empSigninTime']?.toString(),
      empSigninLat: readDouble(json['empSigninLat']),
      empSigninLng: readDouble(json['empSigninLng']),
      empSignOutTime: json['empSignOutTime']?.toString(),
      empSignOutLat: readDouble(json['empSignOutLat']),
      empSignOutLng: readDouble(json['empSignOutLng']),
      cabReachedTime: json['cabReachedTime']?.toString(),
      cabReachedLat: readDouble(json['cabReachedLat']),
      cabReachedLng: readDouble(json['cabReachedLng']),
      reachedHomeTime: json['reachedHomeTime']?.toString(),
      reachedHomeLat: readDouble(json['reachedHomeLat']),
      reachedHomeLng: readDouble(json['reachedHomeLng']),
      paxTrackingStatus: json['paxTrackingStatus']?.toString(),
    );
  }
}

/// Wraps `GET /UserApp/GetUserCabTracking`.
class UserCabTrackingResponse {
  final int? errorCode;
  final String? dbResponse;
  final CabTrackingData? data;

  const UserCabTrackingResponse({
    this.errorCode,
    this.dbResponse,
    this.data,
  });

  bool get isSuccess =>
      (errorCode ?? -1) == 0 &&
      (dbResponse ?? '').toLowerCase() == 'success' &&
      data != null;

  factory UserCabTrackingResponse.fromJson(Map<String, dynamic> json) {
    return UserCabTrackingResponse(
      errorCode: (json['errorCode'] as num?)?.toInt(),
      dbResponse:
          json['dB_Response']?.toString() ?? json['dbResponse']?.toString(),
      data: CabTrackingData.parseResult(json['result']),
    );
  }
}

class CabTrackingData {
  final double? currentLat;
  final double? currentLng;
  final String? vehicleRegistrationNo;
  final String? driverName;
  final String? driverProfileImage;
  final double? officeLat;
  final double? officeLng;
  final bool isUserBoarded;
  final int? otp;
  final int? paxOrder;
  final int? totalPax;
  final List<CabPassenger> passengers;

  const CabTrackingData({
    this.currentLat,
    this.currentLng,
    this.vehicleRegistrationNo,
    this.driverName,
    this.driverProfileImage,
    this.officeLat,
    this.officeLng,
    this.isUserBoarded = false,
    this.otp,
    this.paxOrder,
    this.totalPax,
    this.passengers = const [],
  });

  bool get hasDriverLocation =>
      currentLat != null &&
      currentLng != null &&
      (currentLat != 0 || currentLng != 0);

  bool get hasOfficeLocation =>
      officeLat != null && officeLng != null;

  String get otpDisplay => otp?.toString() ?? '—';

  /// Total passengers from the `Passengers` array (not API `TotalPax`).
  int get passengerCount => passengers.length;

  /// 1-based position in pickup sequence (`PaxOrder`). Defaults to 1.
  int get currentSequenceOrder {
    final order = paxOrder ?? 1;
    if (passengerCount == 0) return order;
    return order.clamp(1, passengerCount);
  }

  /// 0-based index of the passenger currently in sequence.
  int get currentSequenceIndex => currentSequenceOrder - 1;

  String get paxSequenceLabel {
    if (passengerCount == 0) return '—';
    return '$currentSequenceOrder/$passengerCount';
  }

  bool isPassengerPickedUp(int displayIndex) =>
      displayIndex < currentSequenceIndex;

  bool isPassengerCurrentInSequence(int displayIndex) =>
      passengerCount > 0 && displayIndex == currentSequenceIndex;

  /// Passengers ordered for pickup sequence (1st at top). Places the logged-in
  /// user at index `PaxOrder - 1` so `PaxOrder == 1` appears in first position.
  List<CabPassenger> passengersForDisplay(String? currentUserName) {
    if (passengers.isEmpty) return const [];

    final ordered = List<CabPassenger>.from(passengers);
    final userIndex = _indexOfPassengerNamed(currentUserName);
    if (userIndex == null) return ordered;

    final targetIndex = currentSequenceIndex;
    if (userIndex == targetIndex) return ordered;

    final user = ordered.removeAt(userIndex);
    ordered.insert(targetIndex.clamp(0, ordered.length), user);
    return ordered;
  }

  int? _indexOfPassengerNamed(String? userName) {
    final current = userName?.trim().toLowerCase();
    if (current == null || current.isEmpty) return null;

    for (var i = 0; i < passengers.length; i++) {
      final name = passengers[i].empName?.trim().toLowerCase();
      if (name != null && name == current) return i;
    }
    return null;
  }

  static CabTrackingData? parseResult(Object? raw) {
    if (raw == null) return null;
    Object? decoded = raw;
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      try {
        decoded = jsonDecode(trimmed);
      } catch (_) {
        return null;
      }
    }
    if (decoded is! Map) return null;
    return CabTrackingData.fromJson(Map<String, dynamic>.from(decoded));
  }

  factory CabTrackingData.fromJson(Map<String, dynamic> json) {
    double? readDouble(Object? v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    bool readBool(Object? v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final lower = v.toLowerCase();
        return lower == 'true' || lower == '1';
      }
      return false;
    }

    final rawPassengers = json['Passengers'];
    final passengers = (rawPassengers is List)
        ? rawPassengers
            .whereType<Map>()
            .map((m) => CabPassenger.fromJson(Map<String, dynamic>.from(m)))
            .toList(growable: false)
        : const <CabPassenger>[];

    return CabTrackingData(
      currentLat: readDouble(json['current_lat']),
      currentLng: readDouble(json['current_lng']),
      vehicleRegistrationNo: json['vehicle_registration_no']?.toString(),
      driverName: json['DriverName']?.toString(),
      driverProfileImage: json['DriverProfileImage']?.toString(),
      officeLat: readDouble(json['OfficeLat']),
      officeLng: readDouble(json['OfficeLng']),
      isUserBoarded: readBool(json['IsUserBoarded']),
      otp: (json['OTP'] as num?)?.toInt(),
      paxOrder: (json['PaxOrder'] as num?)?.toInt(),
      totalPax: (json['TotalPax'] as num?)?.toInt(),
      passengers: passengers,
    );
  }
}

class CabPassenger {
  final String? empName;
  final String? pickTime;

  const CabPassenger({this.empName, this.pickTime});

  factory CabPassenger.fromJson(Map<String, dynamic> json) {
    return CabPassenger(
      empName: json['Empname']?.toString(),
      pickTime: json['PickTime']?.toString(),
    );
  }
}
