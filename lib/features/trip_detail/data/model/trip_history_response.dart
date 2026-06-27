import 'dart:convert';

import 'package:commutr_main/trip_summary/trip_directions_service.dart';

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
  final String? logoutShift;
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
    this.logoutShift,
    this.passengers = const [],
  });

  static String? _clean(String? raw) {
    final s = raw?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  /// Shift time for a given trip type — `LoginShift` for PICK trips,
  /// `LogoutShift` for DROP trips. Never crosses over: a login trip must not
  /// surface the logout shift, and vice versa.
  String? shiftTimeFor({required bool isPick}) =>
      _clean(isPick ? loginShift : logoutShift);

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
      logoutShift: json['LogoutShift']?.toString(),
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
      paxOrder: _readPaxOrder(json),
      isBoarded: _readBool(json['IsBoarded']),
      isDeBoarded: _readBool(json['IsDeBoarded']),
      noShowOrCancelled: json['NoShowOrCancelled']?.toString(),
    );
  }

  /// Sort key for route waypoints — lower [paxOrder] is visited first.
  int get routeSortKey => paxOrder ?? 999;

  /// Whether this passenger row is a PICK (login) trip.
  bool get isPickTrip => isPickTripType(tripType);

  /// Whether this passenger row is a DROP (logout) trip.
  bool get isDropTrip => !isPickTripType(tripType, defaultPick: false);

  static int? _readPaxOrder(Map<String, dynamic> json) {
    for (final key in ['Paxorder', 'PaxOrder', 'Paxcode', 'PaxCode']) {
      final raw = json[key];
      if (raw is num) return raw.toInt();
      if (raw is String) {
        final parsed = int.tryParse(raw.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
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

/// One stop on the trip route map — passengers ordered by [paxOrder], office
/// marked separately.
class TripHistoryRouteStop {
  const TripHistoryRouteStop({
    required this.id,
    this.latLng,
    this.title,
    this.snippet,
    this.paxOrder,
    this.isOffice = false,
    this.isOrigin = false,
    this.isDestination = false,
  });

  final String id;
  final String? latLng;
  final String? title;
  final String? snippet;

  /// Passenger pickup sequence (P1, P2, …). Null for the office stop.
  final int? paxOrder;
  final bool isOffice;
  final bool isOrigin;
  final bool isDestination;
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
  final String? officeLatLng;
  final String? empLatLng;
  final List<TripHistoryPassenger>? passengers;
  final int? paxOrder;

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
    this.officeLatLng,
    this.empLatLng,
    this.passengers,
    this.paxOrder,
  });

  /// PICK = login (home → office), DROP = logout (office → home).
  bool get isLogin => isPickTrip;

  /// True when this is a PICK trip; false for DROP.
  bool get isPickTrip => _resolvePickDropTrip(defaultPick: true);

  bool _resolvePickDropTrip({required bool defaultPick}) {
    final fromItem = parsePickDropTripType(tripType);
    if (fromItem != null) return fromItem;
    for (final pax in passengers ?? const <TripHistoryPassenger>[]) {
      final fromPax = parsePickDropTripType(pax.tripType);
      if (fromPax != null) return fromPax;
    }
    return defaultPick;
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

  /// All passengers for this trip sorted by [TripHistoryPassenger.paxOrder]
  /// (P1 → P2 → P3 …). Falls back to a single synthetic row when only the
  /// flattened employee coordinates are available.
  List<TripHistoryPassenger> get passengersSortedByPaxOrder {
    final list = List<TripHistoryPassenger>.from(passengers ?? const []);
    if (list.isEmpty && empLatLng != null) {
      list.add(
        TripHistoryPassenger(
          empId: empId,
          empName: employeeName,
          empLatLng: empLatLng,
          userAddress: pickupAddress,
          tripType: tripType,
          pickupAddress: pickupAddress,
          pickTime: pickTime,
          paxOrder: paxOrder ?? 1,
        ),
      );
    }
    list.sort((a, b) {
      final orderCmp = a.routeSortKey.compareTo(b.routeSortKey);
      if (orderCmp != 0) return orderCmp;
      return (a.empId ?? 0).compareTo(b.empId ?? 0);
    });
    return list;
  }

  /// Builds every map waypoint in route order:
  /// - **PICK (login):** P1 → P2 → … → Office
  /// - **DROP (logout):** Office → P1 → P2 → … (ascending [paxOrder])
  List<TripHistoryRouteStop> buildOrderedRouteStops() {
    final mapStops = buildOrderedMapRouteStops(
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

    return mapStops
        .map(
          (s) => TripHistoryRouteStop(
            id: s.id,
            latLng: s.latLng,
            title: s.title,
            snippet: s.snippet,
            paxOrder: s.paxOrder,
            isOffice: s.isOffice,
            isOrigin: s.isOrigin,
            isDestination: s.isDestination,
          ),
        )
        .toList(growable: false);
  }

  /// Ordered `"lat,lng"` strings suitable for Directions API waypoints.
  List<String> get orderedRouteLatLngs => buildOrderedRouteStops()
      .map((s) => s.latLng)
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .toList(growable: false);

  /// Builds one [TripHistoryItem] per passenger matching [empId].
  static List<TripHistoryItem> flattenForEmployee(
    List<TripHistoryTrip> trips,
    int empId,
  ) {
    final items = <TripHistoryItem>[];
    for (final trip in trips) {
      for (final pax in trip.passengers) {
        if (pax.empId != empId) continue;
        final isPick = isPickTripType(pax.tripType);
        items.add(
          TripHistoryItem(
            tripId: trip.tripId,
            empId: pax.empId,
            tripDate: trip.tripDate,
            shiftTime: trip.shiftTimeFor(isPick: isPick),
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
            officeLatLng: trip.officeLatLng,
            empLatLng: pax.empLatLng,
            passengers: trip.passengers,
            paxOrder: pax.paxOrder,
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
