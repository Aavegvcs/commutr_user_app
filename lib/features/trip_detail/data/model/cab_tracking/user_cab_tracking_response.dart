import 'dart:convert';

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
