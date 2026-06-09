import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../features/trip_detail/data/model/cab_tracking/user_cab_tracking_response.dart';
import 'route_tracking_signalr_service.dart';

/// A purely-local, testing-only stand-in for the live SignalR tracking feed.
///
/// It mirrors the public surface the screen already consumes:
///   * [addLocationListener] / [removeLocationListener] — same callback shape as
///     [RouteTrackingSignalRService], emitting the SAME [RouteLocationPayload]
///     type, so the screen cannot tell dummy from live.
///   * [seedState] — a one-shot [TrackingStatusResponse] whose structure matches
///     the live API response (passengers, office, polyline, driver, OTP…), used
///     to bootstrap the UI without any backend call.
///
/// On [start] it walks a marker along [routePoints] with a [Timer.periodic],
/// updating latitude/longitude/speed each tick and flipping each passenger's
/// boarding/drop timestamp as the cab passes their stop — exercising the exact
/// same timeline/marker/polyline code paths the live feed drives.
///
/// This class never runs unless something explicitly constructs and starts it.
/// Gate that behind `TrackingConfig.useDummyTracking`.
class DummyTrackingService {
  DummyTrackingService({
    Duration tickInterval = const Duration(milliseconds: 1200),
    double stepMeters = 60,
  })  : _tickInterval = tickInterval,
        _stepMeters = stepMeters;

  final Duration _tickInterval;

  /// Roughly how far the cab advances along the route per tick (metres).
  final double _stepMeters;

  final List<void Function(RouteLocationPayload)> _listeners = [];

  Timer? _timer;
  List<LatLng> _route = const [];
  int _segment = 0; // current polyline segment index
  double _segmentProgress = 0; // 0..1 along the current segment
  LatLng _current = const LatLng(0, 0);

  // Mutable dummy passengers so we can flip boarding/drop times over time.
  List<_DummyPax> _pax = [];
  bool _logout = false;
  int? _dsId;

  void addLocationListener(void Function(RouteLocationPayload) l) =>
      _listeners.add(l);
  void removeLocationListener(void Function(RouteLocationPayload) l) =>
      _listeners.remove(l);

  /// The seed status the screen should render before/while the dummy feed runs.
  /// Built once from the canned data; structurally identical to the live API.
  TrackingStatusResponse get seedStatus => _buildStatus();

  /// The decoded route polyline used by the dummy cab and the UI segments.
  List<LatLng> get routePoints => List.unmodifiable(_dummyRoute);

  /// Begins emitting synthetic location updates. Safe to call once.
  void start() {
    _route = List<LatLng>.from(_dummyRoute);
    _pax = _dummyPassengers();
    _logout = _dummyTripType == 2;
    _dsId = _dummyDsId;
    _segment = 0;
    _segmentProgress = 0;
    _current = _route.isNotEmpty ? _route.first : const LatLng(0, 0);

    _timer?.cancel();
    _timer = Timer.periodic(_tickInterval, (_) => _tick());
    if (kDebugMode) {
      debugPrint('[DummyTracking] ▶️ started — ${_route.length} pts, '
          'tripType=$_dummyTripType, pax=${_pax.length}');
    }
    // Emit an immediate first frame so the marker shows without a tick delay.
    _emit(speed: 0);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    if (kDebugMode) debugPrint('[DummyTracking] ⏹ stopped');
  }

  void dispose() {
    stop();
    _listeners.clear();
  }

  // ── Simulation step ─────────────────────────────────────────────────────────

  void _tick() {
    if (_route.length < 2) return;
    if (_segment >= _route.length - 1) {
      // Reached the end of the route — mark everyone done and stop.
      for (final p in _pax) {
        p.done = true;
      }
      _emit(speed: 0);
      stop();
      return;
    }

    final a = _route[_segment];
    final b = _route[_segment + 1];
    final segMeters = _distanceMeters(a, b);

    // Advance progress proportional to the configured step distance.
    final stepFraction = segMeters > 0 ? (_stepMeters / segMeters) : 1.0;
    _segmentProgress += stepFraction;
    while (_segmentProgress >= 1.0 && _segment < _route.length - 1) {
      _segmentProgress -= 1.0;
      _segment++;
    }
    if (_segment >= _route.length - 1) {
      _current = _route.last;
    } else {
      final from = _route[_segment];
      final to = _route[_segment + 1];
      _current = _lerp(from, to, _segmentProgress.clamp(0.0, 1.0));
    }

    // Flip a passenger's boarding/drop state once the cab is near their stop.
    for (final p in _pax) {
      if (p.done) continue;
      if (_distanceMeters(_current, p.location) < 70) {
        p.done = true;
        if (kDebugMode) {
          debugPrint('[DummyTracking] ${_logout ? "dropped" : "boarded"} '
              '${p.name} (#${p.order})');
        }
      }
    }

    // Speed in km/h derived from step distance / tick (kept in a sane band).
    final kmh =
        (_stepMeters / _tickInterval.inMilliseconds * 1000 * 3.6).clamp(8, 60);
    _emit(speed: kmh.toDouble());
  }

  void _emit({required double speed}) {
    final payload = RouteLocationPayload(
      dsId: _dsId,
      latitude: _current.latitude,
      longitude: _current.longitude,
      speed: speed,
      gpsTime: null, // dummy clock omitted intentionally
      tripStatusCode: 2,
      tripStatusName: 'In Transit (Dummy)',
      source: 'DUMMY',
      panic: false,
      passengers: _pax.map((p) => p.toPayload(logout: _logout)).toList(),
    );
    for (final l in List.of(_listeners)) {
      l(payload);
    }
  }

  // ── Seed status (matches the live API response structure) ───────────────────

  TrackingStatusResponse _buildStatus() {
    final pax = _dummyPassengers();
    return TrackingStatusResponse(
      dsId: _dummyDsId,
      isTripFound: true,
      tripType: _dummyTripType,
      tripTypeCode: _dummyTripType,
      tripTypeName: _dummyTripType == 2 ? 'Logout Shift' : 'Login Shift',
      totalPax: pax.length,
      latestLat: _dummyRoute.first.latitude,
      latestLng: _dummyRoute.first.longitude,
      latestSpeed: 0,
      driverName: 'Demo Driver',
      driverMobileNo: '+91 90000 00000',
      vehicleNo: 'DL 01 AB 1234',
      trackingMode: 'Dummy',
      trackingMessage: 'Simulated ride (testing mode)',
      shouldUseSignalR: false, // never let the dummy seed trigger live SignalR
      shouldUsePolyline: true,
      isActive: true,
      officeLat: _dummyOffice.latitude,
      officeLng: _dummyOffice.longitude,
      officeDisplayName: 'Head Office',
      officeAddress: 'Tech Park, Sector 21',
      passengers:
          pax.map((p) => p.toTripPassenger(logout: _logout)).toList(),
    );
  }

  // ── Geometry helpers ─────────────────────────────────────────────────────────

  LatLng _lerp(LatLng a, LatLng b, double t) => LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );

  double _distanceMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    const d2r = math.pi / 180;
    final dLat = (b.latitude - a.latitude) * d2r;
    final dLng = (b.longitude - a.longitude) * d2r;
    final sinLat = math.sin(dLat / 2);
    final sinLng = math.sin(dLng / 2);
    final h = sinLat * sinLat +
        math.cos(a.latitude * d2r) *
            math.cos(b.latitude * d2r) *
            sinLng *
            sinLng;
    return 2 * r * math.asin(math.sqrt(h));
  }
}

// ── Canned dummy data (Delhi NCR sample route) ────────────────────────────────

/// 1 = login (pickups → office). 2 = logout (office → drops). Flip to test both.
const int _dummyTripType = 1;
const int _dummyDsId = 999001;

const LatLng _dummyOffice = LatLng(28.5021, 77.0840); // last point of the route

/// A hand-traced polyline from the first pickup to the office (login direction).
const List<LatLng> _dummyRoute = [
  LatLng(28.5930, 77.0490),
  LatLng(28.5880, 77.0540),
  LatLng(28.5805, 77.0602),
  LatLng(28.5720, 77.0651),
  LatLng(28.5642, 77.0688),
  LatLng(28.5560, 77.0712),
  LatLng(28.5470, 77.0744),
  LatLng(28.5388, 77.0772),
  LatLng(28.5300, 77.0796),
  LatLng(28.5190, 77.0818),
  LatLng(28.5090, 77.0832),
  LatLng(28.5021, 77.0840),
];

class _DummyPax {
  final int empId;
  final String name;
  final int order;
  final LatLng location;
  bool done = false; // boarded (login) / dropped (logout)

  _DummyPax({
    required this.empId,
    required this.name,
    required this.order,
    required this.location,
  });

  RouteTripPassenger toPayload({required bool logout}) {
    final ts = done ? '2024-01-01T08:0$order:00' : null;
    return RouteTripPassenger(
      empId: empId,
      firstname: name,
      paxOrder: order,
      plannedLat: location.latitude,
      plannedLng: location.longitude,
      noShow: false,
      tripType: _dummyTripType,
      empSigninTime: logout ? null : ts,
      reachedHomeTime: logout ? ts : null,
      cabReachedTime: logout ? ts : null,
    );
  }

  TripPassenger toTripPassenger({required bool logout}) {
    return TripPassenger(
      empId: empId,
      firstname: name,
      paxOrder: order,
      plannedLat: location.latitude,
      plannedLng: location.longitude,
      tripType: _dummyTripType,
      address: 'Pickup point #$order',
    );
  }
}

List<_DummyPax> _dummyPassengers() => [
      _DummyPax(
        empId: 1001,
        name: 'Aarav',
        order: 1,
        location: const LatLng(28.5805, 77.0602),
      ),
      _DummyPax(
        empId: 1002,
        name: 'Diya',
        order: 2,
        location: const LatLng(28.5560, 77.0712),
      ),
      _DummyPax(
        empId: 1003,
        name: 'Kabir',
        order: 3,
        location: const LatLng(28.5300, 77.0796),
      ),
    ];

/// The empId the dummy screen treats as "me" (Diya, pickup #2) so you can watch
/// the waiting → boarded transition for a middle passenger.
const int dummyMeEmpId = 1002;
