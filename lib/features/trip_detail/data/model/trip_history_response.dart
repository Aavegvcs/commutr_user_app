import 'dart:convert';

/// Top-level `POST /UserApp/UserTripHistory` body.
///
/// ```json
/// {
///   "result": [{ "errorCode": 0, "dB_Response": "Success", "result": "[...]" }],
///   "isSuccess": true,
///   "message": "Success"
/// }
/// ```
class UserTripHistoryApiResponse {
  final bool isSuccess;
  final String message;
  final List<TripHistoryEnvelope> envelopes;

  const UserTripHistoryApiResponse({
    required this.isSuccess,
    required this.message,
    this.envelopes = const [],
  });

  TripHistoryEnvelope? get firstEnvelope =>
      envelopes.isNotEmpty ? envelopes.first : null;

  factory UserTripHistoryApiResponse.fromJson(Map<String, dynamic> json) {
    final rawResult = json['result'];
    final envelopes = <TripHistoryEnvelope>[];
    if (rawResult is List) {
      for (final entry in rawResult) {
        if (entry is Map<String, dynamic>) {
          envelopes.add(TripHistoryEnvelope.fromJson(entry));
        } else if (entry is Map) {
          envelopes.add(
            TripHistoryEnvelope.fromJson(Map<String, dynamic>.from(entry)),
          );
        }
      }
    }
    return UserTripHistoryApiResponse(
      isSuccess: json['isSuccess'] == true,
      message: json['message']?.toString() ?? '',
      envelopes: envelopes,
    );
  }
}

/// Inner envelope inside `result[0]`.
class TripHistoryEnvelope {
  final int errorCode;
  final String dbResponse;
  final List<TripHistoryTrip> trips;

  const TripHistoryEnvelope({
    required this.errorCode,
    required this.dbResponse,
    this.trips = const [],
  });

  bool get isSuccess =>
      errorCode == 0 && dbResponse.toLowerCase() == 'success';

  factory TripHistoryEnvelope.fromJson(Map<String, dynamic> json) {
    return TripHistoryEnvelope(
      errorCode: (json['errorCode'] as num?)?.toInt() ?? -1,
      dbResponse: json['dB_Response']?.toString() ?? '',
      trips: _parseTrips(json['result']),
    );
  }

  static List<TripHistoryTrip> _parseTrips(Object? raw) {
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
        .map((m) => TripHistoryTrip.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }
}

/// One trip row from the inner `result` JSON array.
class TripHistoryTrip {
  final int? tripId;
  final String? tripDate;
  final int? totalPax;
  final String? officeAddress;
  final String? officeLatLng;
  final String? vehicleRegistrationNo;
  final String? tripStatus;
  final String? loginShift;
  final List<TripHistoryPassenger> passengers;

  const TripHistoryTrip({
    this.tripId,
    this.tripDate,
    this.totalPax,
    this.officeAddress,
    this.officeLatLng,
    this.vehicleRegistrationNo,
    this.tripStatus,
    this.loginShift,
    this.passengers = const [],
  });

  factory TripHistoryTrip.fromJson(Map<String, dynamic> json) {
    final rawB = json['B'];
    final passengers = (rawB is List)
        ? rawB
            .whereType<Map>()
            .map(
              (m) => TripHistoryPassenger.fromJson(
                Map<String, dynamic>.from(m),
              ),
            )
            .toList(growable: false)
        : const <TripHistoryPassenger>[];

    return TripHistoryTrip(
      tripId: (json['TripID'] as num?)?.toInt(),
      tripDate: json['Dsdate']?.toString(),
      totalPax: (json['TotalPax'] as num?)?.toInt(),
      officeAddress: json['OfficeAddress']?.toString(),
      officeLatLng: json['OfficeLatLng']?.toString(),
      vehicleRegistrationNo: json['Vehicle_Registration_No']?.toString(),
      tripStatus: json['TripStatus']?.toString(),
      loginShift: json['LoginShift']?.toString(),
      passengers: passengers,
    );
  }
}

/// Passenger row inside trip `B`.
class TripHistoryPassenger {
  final int? empId;
  final String? employeeId;
  final String? empName;
  final String? userAddress;
  final String? empLatLng;
  final String? tripType;
  final String? pickupAddress;
  final String? pickTime;
  final int? paxOrder;
  final bool isBoarded;
  final bool isDeBoarded;
  final String? noShowOrCancelled;

  const TripHistoryPassenger({
    this.empId,
    this.employeeId,
    this.empName,
    this.userAddress,
    this.empLatLng,
    this.tripType,
    this.pickupAddress,
    this.pickTime,
    this.paxOrder,
    this.isBoarded = false,
    this.isDeBoarded = false,
    this.noShowOrCancelled,
  });

  factory TripHistoryPassenger.fromJson(Map<String, dynamic> json) {
    return TripHistoryPassenger(
      empId: (json['Empid'] as num?)?.toInt(),
      employeeId: json['EmployeeID']?.toString(),
      empName: json['Empname']?.toString(),
      userAddress: json['UserAddress']?.toString(),
      empLatLng: json['EmpLatLng']?.toString(),
      tripType: json['Triptype']?.toString(),
      pickupAddress: json['Pickupadd']?.toString(),
      pickTime: _readPickTime(json),
      paxOrder: (json['Paxorder'] as num?)?.toInt(),
      isBoarded: _readBool(json['IsBoarded']),
      isDeBoarded: _readBool(json['IsDeBoarded']),
      noShowOrCancelled: json['NoShowOrCancelled']?.toString(),
    );
  }

  static String? _readPickTime(Map<String, dynamic> json) {
    final raw = json['PickTime'];
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty || s.toUpperCase() == 'AA') return null;
    return s;
  }

  static bool _readBool(Object? v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final lower = v.toLowerCase();
      return lower == 'true' || lower == '1';
    }
    return false;
  }
}

/// Flattened trip row for a single employee (used by bloc/UI).
class TripHistoryItem {
  final int? tripId;
  final int? empId;
  final String? tripDate;
  final String? shiftTime;
  final String? tripType;
  final String? tripStatus;
  final String? pickTime;
  final String? pickupAddress;
  final String? officeAddress;
  final String? vehicleRegistrationNo;
  final String? employeeName;
  final bool isBoarded;
  final bool isDeBoarded;
  final String? noShowOrCancelled;
  final int? rating;

  const TripHistoryItem({
    this.tripId,
    this.empId,
    this.tripDate,
    this.shiftTime,
    this.tripType,
    this.tripStatus,
    this.pickTime,
    this.pickupAddress,
    this.officeAddress,
    this.vehicleRegistrationNo,
    this.employeeName,
    this.isBoarded = false,
    this.isDeBoarded = false,
    this.noShowOrCancelled,
    this.rating,
  });

  /// PICK = login (home → office), DROP = logout.
  bool get isLogin {
    final t = (tripType ?? '').trim().toLowerCase();
    if (t == 'pick' || t == 'login' || t == '1') return true;
    if (t == 'drop' || t == 'logout' || t == '2') return false;
    return true;
  }

  bool get isCompleted =>
      isDeBoarded ||
      _statusLower.contains('end') ||
      _statusLower.contains('complet');

  bool get isNoShow {
    final n = (noShowOrCancelled ?? '').trim().toLowerCase();
    return n.contains('no show') || n.contains('noshow');
  }

  bool get isCancelled {
    final n = (noShowOrCancelled ?? '').trim().toLowerCase();
    if (n.contains('cancel')) return true;
    return _statusLower.contains('cancel');
  }

  String get _statusLower => (tripStatus ?? '').trim().toLowerCase();

  /// Builds one [TripHistoryItem] per passenger matching [empId].
  static List<TripHistoryItem> flattenForEmployee(
    List<TripHistoryTrip> trips,
    int empId,
  ) {
    final items = <TripHistoryItem>[];
    for (final trip in trips) {
      for (final pax in trip.passengers) {
        if (pax.empId != empId) continue;
        items.add(
          TripHistoryItem(
            tripId: trip.tripId,
            empId: pax.empId,
            tripDate: trip.tripDate,
            shiftTime: trip.loginShift,
            tripType: pax.tripType,
            tripStatus: trip.tripStatus,
            pickTime: pax.pickTime,
            pickupAddress: pax.pickupAddress ?? pax.userAddress,
            officeAddress: trip.officeAddress,
            vehicleRegistrationNo: trip.vehicleRegistrationNo,
            employeeName: pax.empName,
            isBoarded: pax.isBoarded,
            isDeBoarded: pax.isDeBoarded,
            noShowOrCancelled: pax.noShowOrCancelled,
          ),
        );
      }
    }
    items.sort((a, b) {
      final da = a.tripDate ?? '';
      final db = b.tripDate ?? '';
      final cmp = db.compareTo(da);
      if (cmp != 0) return cmp;
      return (b.pickTime ?? '').compareTo(a.pickTime ?? '');
    });
    return items;
  }
}
