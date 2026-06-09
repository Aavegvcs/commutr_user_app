import 'dart:async';
import 'dart:math' as math;

import 'package:commutr_main/core/di/injection.dart';
import 'package:commutr_main/core/storage/auth_local_storage.dart';
import 'package:commutr_main/features/trip_detail/data/model/cab_tracking/user_cab_tracking_response.dart';
import 'package:commutr_main/features/trip_detail/data/repository/cab_tracking/user_cab_tracking_repo.dart';
import 'package:commutr_main/ride_tracking/bloc/cab_tracking_bloc.dart';
import 'package:commutr_main/ride_tracking/bloc/cab_tracking_event.dart';
import 'package:commutr_main/ride_tracking/bloc/cab_tracking_state.dart';
import 'package:commutr_main/ride_tracking/config/tracking_config.dart';
import 'package:commutr_main/ride_tracking/model/ride_timeline.dart';
import 'package:commutr_main/ride_tracking/service/dummy_tracking_service.dart';
import 'package:commutr_main/ride_tracking/service/ivr_call_repo.dart';
import 'package:commutr_main/ride_tracking/service/route_tracking_signalr_service.dart';
import 'package:commutr_main/features/trip_chat/presentation/trip_group_chat_screen.dart';
import 'package:commutr_main/trip_summary/trip_directions_service.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class RideTrackingScreen extends StatefulWidget {
  final String? userName;
  final int? tripId;
  final int? empId;
  final String? boardingOtp;

  const RideTrackingScreen({
    super.key,
    this.userName,
    this.tripId,
    this.empId,
    this.boardingOtp,
  });

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen>
    with TickerProviderStateMixin {
  final Completer<GoogleMapController> _mapController = Completer();

  static const LatLng _fallbackCenter = LatLng(28.5930, 77.0490);
  static const double _followZoom = 17.0;

  LatLng _driverLatLng = _fallbackCenter;
  LatLng _animatedDriverLatLng = _fallbackCenter;

  // ── Camera behaviour (Ola/Uber style) ──────────────────────────────────────
  // The camera is deliberately NOT moved on every GPS update. It is positioned
  // once at the start (fit to bounds), then left fixed so the background map
  // stays rock-steady while only the marker + polyline animate. It moves again
  // only on: recenter tap, the initial fit, or the cab drifting off-screen.

  // Whether the one-time initial camera fit has run yet.
  bool _didInitialCameraFit = false;
  // The latitude/longitude region currently visible on screen, refreshed from
  // onCameraIdle. Used to detect when the cab has drifted out of view.
  LatLngBounds? _visibleBounds;
  // Guards against issuing overlapping programmatic camera moves (which would
  // themselves fire onCameraIdle and could loop).
  bool _cameraMoveInFlight = false;
  // Padding (px) used when fitting bounds so markers aren't flush to the edge.
  static const double _boundsPadding = 80.0;

  // Bearing state. `_carBearing` is the live (animated) rotation rendered on the
  // marker; `_bearingFrom`/`_bearingTo` are the endpoints the current move tween
  // rotates between, taking the shortest angular path (no jitter / no spinning).
  double _carBearing = 0.0;
  double _bearingFrom = 0.0;
  double _bearingTo = 0.0;

  // Car PNG is a top-view image facing LEFT. Google Maps treats marker rotation
  // 0° as facing RIGHT/EAST, so we add 180° to make the car face the heading.
  static const double _carIconRotationOffset = 180.0;

  CameraPosition _initialCamera = const CameraPosition(
    target: _fallbackCenter,
    zoom: _followZoom,
  );

  // Smooth car movement animation (like Rapido/Ola).
  late AnimationController _moveController;
  Animation<double>? _latAnim;
  Animation<double>? _lngAnim;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  bool _isExpanded = false;
  bool _showPassengerList = false;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  late AnimationController _pulseController;
  Timer? _pollingTimer;
  // Silent 200 ms tick: re-merges the latest SignalR pax data (status, ETA
  // deviation, planned time) and repaints so the live arrival clock stays
  // current. See [_refreshPaxTrackingStatus].
  Timer? _statusRefreshTimer;

  final RouteTrackingSignalRService _signalR = RouteTrackingSignalRService();
  bool _signalREnabled = false;
  // Set to true after the first SignalR location push. Once true, REST polling
  // must not overwrite the driver position — SignalR is the authoritative source.
  bool _signalRHasLocation = false;

  // Testing-only simulator. Non-null ONLY when TrackingConfig.useDummyTracking
  // is true (debug build started with --dart-define=DUMMY_TRACKING=true). In
  // every release build this stays null and the live flow runs untouched.
  DummyTrackingService? _dummy;
  // In dummy mode the bloc never emits data, so the bottom sheet reads from this
  // seed instead (driver/vehicle/OTP). Null in live mode.
  RideTrackingDataState? _dummyData;

  // Live ETA computed from each SignalR location update (driver position +
  // speed → remaining distance to the office). Null until first computed.
  int? _etaMinutes;
  // Latest status + planned route cached from the bloc so the SignalR callback
  // can compute the ETA without reaching back into bloc state.
  TrackingStatusResponse? _latestStatus;
  List<LatLng> _plannedPoints = const [];
  // True when [_plannedPoints] was built via Google Directions (no encoded polyline).
  bool _plannedRouteFromDirections = false;
  // Road-following cab → next-stop leg from Google Directions (Option B).
  List<LatLng> _activeLegPoints = const [];
  DateTime? _lastActiveLegFetchAt;
  String? _activeLegTargetKey;
  int _activeLegFetchGen = 0;
  static const Duration _activeLegThrottle = Duration(seconds: 12);
  // Personalised, ordered tracking timeline (built from status.passengers and
  // the logged-in user's empId). Drives the markers, polyline colouring, and
  // the bottom-sheet timeline UI.
  RideTimeline _timeline = RideTimeline.empty;
  // Full (non-personalised) timeline — every passenger on the route, shown in
  // the expanded passenger list. Built alongside [_timeline] from the same
  // status but with includeAllStops, so the list shows everyone while the map /
  // ETA / banner keep using the personalised [_timeline].
  RideTimeline _fullTimeline = RideTimeline.empty;
  // Fallback average speed (km/h) used when the cab is stopped / GPS speed is
  // 0 or missing, so the ETA never shows infinity.
  static const double _fallbackSpeedKmh = 25.0;

  BitmapDescriptor _carIcon = BitmapDescriptor.defaultMarker;

  // Latest SignalR payload, surfaced verbatim in the debug overlay so the live
  // cab lat/lng and every passenger's paxOrder are visible while tracking.
  RouteLocationPayload? _lastPayload;

  Future<void> _loadCarIcon() async {
    final bytes = await rootBundle.load(
      'assets/images/car_photo.png',
    );
    final codec = await ui.instantiateImageCodec(
      bytes.buffer.asUint8List(),
      targetWidth: 50,
    );
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    if (data != null && mounted) {
      setState(() {
        _carIcon = BitmapDescriptor.bytes(data.buffer.asUint8List());
      });
    }
  }

  void _onSignalRLocation(RouteLocationPayload payload) {
    if (!mounted) return;
    // Keep the freshest payload for the debug overlay (cab lat/lng + pax orders).
    _lastPayload = payload;
    if (payload.latitude == null || payload.longitude == null) return;
    _signalRHasLocation = true;
    context.read<CabTrackingBloc>().add(SignalRLocationReceived(payload));
    final newLatLng = LatLng(payload.latitude!, payload.longitude!);
    // Recompute the ETA from this fresh location + speed every time SignalR
    // pushes an update, so the bottom sheet always shows a live estimate.
    _updateEta(driver: newLatLng, speedKmh: payload.speed);
    // If this payload carries fresher passenger boarding data, rebuild the
    // timeline so the markers / segments / sheet reflect new boardings live.
    _rebuildTimelineFromPayload(payload);
    if (_useSignalRWaypoints && payload.passengers.isNotEmpty) {
      _rebuildStopMarkers();
      // Refresh the directions-based planned route when live waypoints move.
      if (_plannedRouteFromDirections || _plannedPoints.length < 2) {
        unawaited(_refreshDirectionsRoute(cabOverride: newLatLng));
      }
    }
    _rebuildRoutePolylines(_plannedPoints, cabOverride: newLatLng);
    unawaited(_refreshActiveLegPolyline(cab: newLatLng));
    _animateCarTo(newLatLng);
  }

  /// Merges any passenger boarding data carried on a SignalR payload into the
  /// cached status and rebuilds the personalised [_timeline].
  ///
  /// Polling is disabled while SignalR is live, so boarding changes
  /// (`empSigninTime` becoming non-null, or a `noShow` flip) would otherwise
  /// never reach the UI between REST refreshes. Each payload passenger is
  /// matched to the cached one by [empId] and its boarding fields override the
  /// cached values; passengers absent from the payload keep their cached state.
  void _rebuildTimelineFromPayload(RouteLocationPayload payload) {
    final status = _latestStatus;
    if (status == null || payload.passengers.isEmpty) return;

    final byEmpId = {
      for (final p in payload.passengers)
        if (p.empId != null) p.empId!: p,
    };

    final merged = status.passengers.map((cached) {
      final live = byEmpId[cached.empId];
      if (live == null) return cached;
      return TripPassenger(
        empId: cached.empId,
        employeeID: cached.employeeID,
        firstname: cached.firstname,
        lastName: cached.lastName,
        gender: cached.gender,
        mobileno: cached.mobileno,
        empLocCode: cached.empLocCode,
        tripType: cached.tripType,
        paxOrder: live.paxOrder ?? cached.paxOrder,
        address: cached.address,
        plannedLat: status.shouldUseSignalR && status.shouldUsePolyline
            ? (live.plannedLat ?? cached.plannedLat)
            : cached.plannedLat,
        plannedLng: status.shouldUseSignalR && status.shouldUsePolyline
            ? (live.plannedLng ?? cached.plannedLng)
            : cached.plannedLng,
        noShow: live.noShow ?? cached.noShow,
        noShowReasonId: live.noShowReasonId ?? cached.noShowReasonId,
        orsDeviation: cached.orsDeviation,
        scheduled: cached.scheduled,
        paxAdded: cached.paxAdded,
        paxType: cached.paxType,
        empDistance: cached.empDistance,
        empDirectDistance: cached.empDirectDistance,
        empCost: cached.empCost,
        plannedScheduleTime: cached.plannedScheduleTime,
        empSigninTime: live.empSigninTime ?? cached.empSigninTime,
        empSigninLat: live.empSigninLat ?? cached.empSigninLat,
        empSigninLng: live.empSigninLng ?? cached.empSigninLng,
        empSignOutTime: live.empSignOutTime ?? cached.empSignOutTime,
        empSignOutLat: live.empSignOutLat ?? cached.empSignOutLat,
        empSignOutLng: live.empSignOutLng ?? cached.empSignOutLng,
        cabReachedTime: live.cabReachedTime ?? cached.cabReachedTime,
        cabReachedLat: live.cabReachedLat ?? cached.cabReachedLat,
        cabReachedLng: live.cabReachedLng ?? cached.cabReachedLng,
        reachedHomeTime: live.reachedHomeTime ?? cached.reachedHomeTime,
        reachedHomeLat: live.reachedHomeLat ?? cached.reachedHomeLat,
        reachedHomeLng: live.reachedHomeLng ?? cached.reachedHomeLng,
        paxTrackingStatus: live.paxTrackingStatus ?? cached.paxTrackingStatus,
      );
    }).toList();

    final wasBoarded = _timeline.meBoarded;
    final mergedStatus = status.withPassengers(merged);
    _latestStatus = mergedStatus;
    _timeline = RideTimeline.fromStatus(mergedStatus, meEmpId: widget.empId);
    _fullTimeline = RideTimeline.fromStatus(mergedStatus,
        meEmpId: widget.empId, includeAllStops: true);
    // Refresh markers + active leg when paxTrackingStatus advances the target.
    _rebuildStopMarkers();
    // Flush to UI so _StatusPill / _TrackingStatusBanner reflect the new
    // paxTrackingStatus values immediately on every SignalR push.
    if (mounted) setState(() {});
    final cab = (payload.latitude != null && payload.longitude != null)
        ? LatLng(payload.latitude!, payload.longitude!)
        : null;
    // LOGIN: when the viewer's boarding state flips, the planned route changes
    // shape (not boarded → only the active leg; boarded → next pickups +
    // office). Rebuild it so the blue tail appears/disappears live, regardless
    // of whether waypoints come from SignalR or REST.
    if (_isLoginTripType() && _timeline.meBoarded != wasBoarded) {
      unawaited(_refreshDirectionsRoute(cabOverride: cab));
    }
    unawaited(_refreshActiveLegPolyline(cab: cab));
  }

  /// True when waypoint markers should use live SignalR passenger coordinates.
  bool get _useSignalRWaypoints {
    final status = _latestStatus;
    return status?.shouldUseSignalR == true &&
        status?.shouldUsePolyline == true;
  }

  /// Resolves a stop's map position from the correct source:
  /// SignalR [RouteTripPassenger.plannedLat]/[plannedLng] when both tracking
  /// flags are on, otherwise [TripPassenger.plannedLat]/[plannedLng] from REST.
  LatLng? _waypointLocationForStop(RideStop stop) {
    if (stop.isOffice) return stop.location;

    // REST passengers — [TripPassenger.plannedLat]/[plannedLng] via timeline.
    if (!_useSignalRWaypoints) return stop.location;

    // Live SignalR waypoints — match by [paxOrder], fall back to merged status.
    final order = stop.order;
    if (order != null) {
      final payloadPax = _lastPayload?.passengers ?? const [];
      for (final p in payloadPax) {
        if (p.paxOrder == order) {
          final lat = p.plannedLat;
          final lng = p.plannedLng;
          if (lat != null &&
              lng != null &&
              (lat != 0 || lng != 0)) {
            return LatLng(lat, lng);
          }
          break;
        }
      }

      final statusPax = _latestStatus?.passengers ?? const [];
      for (final p in statusPax) {
        if (p.paxOrder == order) {
          final lat = p.plannedLat;
          final lng = p.plannedLng;
          if (lat != null &&
              lng != null &&
              (lat != 0 || lng != 0)) {
            return LatLng(lat, lng);
          }
          break;
        }
      }
    }

    return stop.location;
  }

  /// Ordered waypoint coordinates for the Google Directions API fallback.
  ///
  /// Uses the full fleet passenger list (all paxOrders sorted ascending) plus
  /// the office — NOT the personalised [_timeline.stops] — so that the planned
  /// polyline always passes through every stop in route order regardless of
  /// which passenger is viewing (e.g. pax2 still sees the pax1 → pax2 leg).
  List<LatLng> _orderedWaypointPoints() {
    final status = _latestStatus;
    if (status == null) {
      // Fallback: derive from timeline stops (no status cached yet).
      final pts = <LatLng>[];
      for (final stop in _timeline.stops) {
        final loc = _waypointLocationForStop(stop);
        if (loc != null) pts.add(loc);
      }
      return pts;
    }

    // LOGIN: the planned route is personalised by boarding state — not boarded
    // shows only the active leg (no planned route), boarded shows the remaining
    // pickups after me + office. LOGOUT keeps its existing full-route behaviour.
    if (_isLoginTripType()) {
      return _loginPlannedWaypoints();
    }

    final pax = List<TripPassenger>.from(status.passengers)
      ..sort((a, b) => (a.paxOrder ?? 0).compareTo(b.paxOrder ?? 0));

    final pts = <LatLng>[];
    final isLogout = _timeline.isLogout;

    // LOGOUT: the planned route for THIS viewer ends at their own drop stop —
    // never beyond it. Cap the waypoint list at the viewer's paxOrder so the
    // polyline (gray completed + orange active) terminates at their lat/lng.
    final int? myOrder = isLogout ? _myPaxOrder : null;

    // LOGOUT: office first (origin), then drop stops.
    if (isLogout) {
      final officeLat = status.officeLat;
      final officeLng = status.officeLng;
      if (officeLat != null && officeLng != null && (officeLat != 0 || officeLng != 0)) {
        pts.add(LatLng(officeLat, officeLng));
      }
    }

    for (final p in pax) {
      // Stop once we pass the viewer's own drop on a LOGOUT trip.
      if (myOrder != null && p.paxOrder != null && p.paxOrder! > myOrder) break;
      LatLng? loc;
      if (_useSignalRWaypoints) {
        // Prefer live SignalR coords when available.
        final payloadPax = _lastPayload?.passengers ?? const [];
        for (final pp in payloadPax) {
          if (pp.paxOrder == p.paxOrder) {
            final lat = pp.plannedLat;
            final lng = pp.plannedLng;
            if (lat != null && lng != null && (lat != 0 || lng != 0)) {
              loc = LatLng(lat, lng);
            }
            break;
          }
        }
        // Fall back to merged status coords.
        if (loc == null) {
          final lat = p.plannedLat;
          final lng = p.plannedLng;
          if (lat != null && lng != null && (lat != 0 || lng != 0)) {
            loc = LatLng(lat, lng);
          }
        }
      } else {
        final lat = p.plannedLat;
        final lng = p.plannedLng;
        if (lat != null && lng != null && (lat != 0 || lng != 0)) {
          loc = LatLng(lat, lng);
        }
      }
      if (loc != null) pts.add(loc);
    }

    // LOGIN: office last (destination).
    if (!isLogout) {
      final officeLat = status.officeLat;
      final officeLng = status.officeLng;
      if (officeLat != null && officeLng != null && (officeLat != 0 || officeLng != 0)) {
        pts.add(LatLng(officeLat, officeLng));
      }
    }

    return pts;
  }

  /// Builds the planned route through every stop via Google Directions API.
  Future<List<LatLng>> _fetchDirectionsPlannedRoute() async {
    final waypoints = _orderedWaypointPoints();
    if (waypoints.length < 2) return const [];
    return fetchRoutePolylineThroughPoints(waypoints);
  }

  Future<void> _applyDirectionsPlannedRoute({LatLng? cabOverride}) async {
    final planned = await _fetchDirectionsPlannedRoute();
    if (!mounted || planned.isEmpty) return;
    _plannedPoints = planned;
    _plannedRouteFromDirections = true;
    _rebuildRoutePolylines(_plannedPoints);
    setState(() {});
    unawaited(_refreshActiveLegPolyline(cab: cabOverride));
  }

  Future<void> _refreshDirectionsRoute({LatLng? cabOverride}) async {
    await _applyDirectionsPlannedRoute(cabOverride: cabOverride);
  }

  List<LatLng> _decodePolyline(String? encoded) {
    if (encoded == null || encoded.trim().isEmpty) return const [];
    try {
      return PolylinePoints()
          .decodePolyline(encoded)
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Fetches [GpsRouteResponse] and decodes the full planned polyline for the
  /// map. Falls back to Google Directions through waypoint stops when
  /// the encoded planned polyline is absent. Safe to call repeatedly.
  Future<void> _loadGpsRoutePolylines(int tripId) async {
    try {
      final route =
          await sl<UserCabTrackingRepo>().getGpsRoute(tripId: tripId);
      if (!mounted) return;

      // The encoded planned polyline from the API traces the FULL fleet route
      // (office → every drop). On LOGOUT trips that would draw the route past
      // the viewer's own drop, and on LOGIN trips it would show the whole route
      // before the viewer has even boarded — both want a personalised route
      // instead, so suppress the encoded polyline and let the Directions
      // fallback below build the capped/boarding-gated route. Other trip types
      // keep using the precise encoded polyline when present.
      var planned = (_isLogoutTripType() || _isLoginTripType())
          ? const <LatLng>[]
          : _decodePolyline(route.plannedRoutePolyline);

      if (planned.isNotEmpty) {
        _plannedPoints = planned;
        _plannedRouteFromDirections = false;
      } else {
        planned = await _fetchDirectionsPlannedRoute();
        if (planned.isNotEmpty) {
          _plannedPoints = planned;
          _plannedRouteFromDirections = true;
        }
      }

      _rebuildRoutePolylines(_plannedPoints);
      setState(() {});
      unawaited(_refreshActiveLegPolyline());
    } catch (e) {
      debugPrint('[RideTrackingScreen] GPS route fetch error: $e');
      await _applyDirectionsPlannedRoute();
    }
  }

  /// Rebuilds only the pickup/office markers from the current [_timeline],
  /// leaving the driver marker untouched (it is animated separately).
  void _rebuildStopMarkers() {
    _markers.removeWhere((m) =>
        m.markerId.value.startsWith('pax_') || m.markerId.value == 'office');
    for (final stop in _timeline.stops) {
      final loc = _waypointLocationForStop(stop);
      if (loc == null) continue;
      final id = stop.isOffice ? 'office' : 'pax_${stop.order}';
      final titlePrefix = stop.isOffice ? '' : '${stop.sequenceLabel} · ';
      final meSuffix = stop.isMe ? ' (You)' : '';
      final isEtaDest = _isEtaDestinationStop(stop);
      _markers.add(Marker(
        markerId: MarkerId(id),
        position: loc,
        icon: BitmapDescriptor.defaultMarkerWithHue(markerHueForStop(stop)),
        infoWindow: InfoWindow(
          title: '$titlePrefix${stop.title}$meSuffix',
          snippet: isEtaDest
              ? _etaMarkerSnippet(stop)
              : (stop.isOffice ? stop.subtitle : statusLabelForStop(stop)),
        ),
      ));
    }
  }

  /// Recomputes the live ETA to the office destination from the driver's
  /// current position and reported GPS speed.
  ///
  /// Distance is measured along the remaining planned route polyline when one
  /// is available (more accurate than straight-line), falling back to the
  /// great-circle distance to the office otherwise. Speed falls back to
  /// [_fallbackSpeedKmh] when the cab is stopped so the ETA never blows up.
  /// When [notify] is false the field is updated without calling setState —
  /// used when the caller (e.g. `_applyStateToMap`) flushes its own setState.
  void _updateEta({
    required LatLng driver,
    double? speedKmh,
    bool notify = true,
  }) {
    final dest = _destination;
    if (dest == null) return;

    final meters = _remainingRouteMeters(driver, dest);
    final int minutes;
    if (meters <= 0) {
      minutes = 0;
    } else {
      final effectiveSpeed =
          (speedKmh != null && speedKmh > 1) ? speedKmh : _fallbackSpeedKmh;
      final hours = (meters / 1000.0) / effectiveSpeed;
      minutes = (hours * 60).ceil().clamp(0, 24 * 60);
    }

    if (minutes == _etaMinutes) return;
    if (notify) {
      setState(() {
        _etaMinutes = minutes;
        _rebuildStopMarkers();
      });
    } else {
      _etaMinutes = minutes;
    }
  }

  /// Whether [stop] is the live-ETA destination (matches orange active-leg target).
  bool _isEtaDestinationStop(RideStop stop) {
    final target = _activeTarget;
    if (target == null || !_shouldShowActiveLeg()) return false;
    if (stop.isOffice && target.isOffice) return true;
    if (stop.isMe && target.isMe) return true;
    return !stop.isOffice &&
        !target.isOffice &&
        stop.order != null &&
        stop.order == target.order;
  }

  String _etaMarkerSnippet(RideStop stop) {
    final base = stop.isOffice
        ? (stop.subtitle?.trim().isNotEmpty == true
            ? stop.subtitle!.trim()
            : 'Office')
        : statusLabelForStop(stop);
    return '$base · ETA ${formatEta(_etaMinutes)}';
  }

  /// The office coordinates, when known.
  LatLng? get _officeLatLng {
    final status = _latestStatus;
    final lat = status?.officeLat;
    final lng = status?.officeLng;
    if (lat == null || lng == null || (lat == 0 && lng == 0)) return null;
    return LatLng(lat, lng);
  }

  /// My own pickup/drop stop on the personalised timeline (the "(You)" stop).
  RideStop? get _myStop {
    for (final s in _timeline.stops) {
      if (s.isMe) return s;
    }
    return null;
  }

  /// The logged-in passenger's own paxOrder, or null if it can't be resolved.
  int? get _myPaxOrder {
    final meEmpId = widget.empId;
    final status = _latestStatus;
    if (meEmpId != null && status != null) {
      for (final p in status.passengers) {
        if (p.empId == meEmpId) return p.paxOrder;
      }
    }
    // Fall back to the personalised timeline's "(You)" stop order.
    return _myStop?.order;
  }

  /// The cab's first/next pending pickup on a LOGIN trip ("pickup1") — the first
  /// stop in route order whose passenger has not yet been picked up. Used to aim
  /// the active leg at the cab's next real pickup before the viewer has boarded,
  /// even when other passengers are picked up ahead of them. Null on non-LOGIN
  /// trips or when no pending pickup remains.
  RideStop? get _fleetFirstPendingPickup {
    if (!_isLoginTripType()) return null;
    final status = _latestStatus;
    if (status == null) return null;

    final pax = List<TripPassenger>.from(status.passengers)
      ..sort((a, b) => (a.paxOrder ?? 0).compareTo(b.paxOrder ?? 0));
    for (final p in pax) {
      if (isPaxFleetActiveLegCandidate(p, isPickupTrip: true)) {
        for (final s in _timeline.stops) {
          if (!s.isOffice && s.order == p.paxOrder) return s;
        }
        break;
      }
    }
    return null;
  }

  /// Effective active-leg target stop.
  ///
  /// LOGIN before the viewer has boarded: always the cab's next pending pickup
  /// ("pickup1"), so the orange leg traces cab → pickup1 only. In every other
  /// case it is the personalised [_timeline.target] (which, once boarded, is the
  /// next pickup or the office).
  RideStop? get _activeTarget {
    if (_isLoginTripType() && !_timeline.meBoarded) {
      return _fleetFirstPendingPickup ?? _timeline.target;
    }
    return _timeline.target;
  }

  /// Destination for the live ETA — matches the orange active-leg endpoint.
  LatLng? get _destination => _activeLegDestinationLatLng();

  /// True when the orange cab→stop leg should render (hidden after Completed/Dropped).
  bool _shouldShowActiveLeg() {
    final target = _activeTarget;
    if (target == null) return false;

    final me = _myStop;
    if (me != null) {
      final status = _latestStatus;
      final meEmpId = widget.empId;
      if (status != null && meEmpId != null) {
        for (final p in status.passengers) {
          if (p.empId == meEmpId) {
            return !shouldHideActiveLegForPassenger(
              p,
              isPickupTrip: !_timeline.isLogout,
            );
          }
        }
      }
    }
    return true;
  }

  /// Resolves the orange active-leg endpoint from [paxTrackingStatus] + trip type.
  LatLng? _activeLegDestinationLatLng() {
    if (!_shouldShowActiveLeg()) return null;

    final target = _activeTarget;
    if (target == null) return null;

    if (target.isOffice) return _waypointLocationForStop(target);

    final loc = _waypointLocationForStop(target);
    if (loc == null) return null;

    // Drop + Not Boarded → cab heads to office to board.
    if (_timeline.isLogout && target.isMe) {
      final s = (target.paxTrackingStatus ?? '').trim().toLowerCase();
      if (s == 'not boarded' || s == 'pending') {
        return _officeLatLng ?? loc;
      }
    }

    return loc;
  }

  /// Distance (m) from [driver] to [dest] along the planned polyline if one
  /// exists, else the straight-line great-circle distance.
  ///
  /// Sums segment lengths from the vertex nearest the driver to the vertex
  /// nearest [dest] (the current target stop), so the ETA counts down to the
  /// stop the cab is actually heading to — not always the route's end.
  double _remainingRouteMeters(LatLng driver, LatLng dest) {
    final route = _plannedPoints;
    if (route.length < 2) return _approxDistanceMeters(driver, dest);

    final driverIdx = _nearestVertexIndex(route, driver);
    final destIdx = _nearestVertexIndex(route, dest);
    // If the target sits "behind" the cab along the polyline, fall back to the
    // straight-line distance rather than summing a negative span.
    if (destIdx <= driverIdx) return _approxDistanceMeters(driver, dest);

    var meters = _approxDistanceMeters(driver, route[driverIdx]);
    for (var i = driverIdx; i < destIdx; i++) {
      meters += _approxDistanceMeters(route[i], route[i + 1]);
    }
    return meters;
  }

  String? _activeLegTargetKeyFor(RideStop? stop) {
    if (stop == null) return null;
    return '${stop.kind}_${stop.order ?? 'office'}';
  }

  /// Rebuilds [_polylines] per tracking spec:
  ///   * gray  — completed portion of planned route (behind the cab)
  ///   * orange — active leg ONLY (cab → target via Directions API)
  ///   * blue  — upcoming planned route ahead of the cab. LOGIN only, and only
  ///            once the viewer has boarded: cab → next pickups → office. Before
  ///            boarding (and on every other trip type) it stays hidden.
  void _rebuildRoutePolylines(List<LatLng> points, {LatLng? cabOverride}) {
    _polylines.clear();

    if (points.length >= 2) {
      final cabIdx = _nearestVertexIndex(
        points,
        cabOverride ?? _animatedDriverLatLng,
      );
      if (cabIdx > 0) {
        _polylines.add(Polyline(
          polylineId: const PolylineId('route_completed'),
          color: const Color(0xFFB0B6BE),
          width: 4,
          zIndex: 0,
          points: points.sublist(0, cabIdx + 1),
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ));
      }

      // LOGIN + boarded: draw the upcoming tail (next pickups → office) ahead
      // of the cab so the viewer sees the rest of the route once on board.
      if (_isLoginTripType() && _timeline.meBoarded && cabIdx < points.length - 1) {
        _polylines.add(Polyline(
          polylineId: const PolylineId('route_upcoming'),
          color: const Color(0xFF2563EB),
          width: 4,
          zIndex: 1,
          points: points.sublist(cabIdx),
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ));
      }
    }

    if (_shouldShowActiveLeg() && _activeLegPoints.length >= 2) {
      _polylines.add(Polyline(
        polylineId: const PolylineId('route_active'),
        color: const Color(0xFFF59E0B),
        width: 5,
        zIndex: 2,
        points: _activeLegPoints,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ));
    }
  }

  /// Fetches a road-following polyline from the cab to the active-leg destination
  /// via Google Directions. Throttled to avoid hammering the API on every GPS tick.
  ///
  /// For tripTypeCode 2 (LOGOUT/drop trips) the route passes through every
  /// intermediate stop in order: cab → office → pax1 → pax2 → … → targetPax.
  /// For all other trip types the route goes directly: cab → target.
  Future<void> _refreshActiveLegPolyline({LatLng? cab}) async {
    final cabPos = cab ?? _animatedDriverLatLng;
    final targetStop = _activeTarget;
    final targetKey = _activeLegTargetKeyFor(targetStop);

    if (!_shouldShowActiveLeg() || targetStop == null || targetKey == null) {
      if (_activeLegPoints.isNotEmpty) {
        _activeLegPoints = const [];
        _activeLegTargetKey = null;
        _rebuildRoutePolylines(_plannedPoints, cabOverride: cab);
        if (mounted) setState(() {});
      }
      return;
    }

    final targetLoc = _activeLegDestinationLatLng();
    if (targetLoc == null) return;

    if (_approxDistanceMeters(cabPos, targetLoc) < 30) {
      _activeLegPoints = const [];
      _rebuildRoutePolylines(_plannedPoints, cabOverride: cab);
      if (mounted) setState(() {});
      return;
    }

    final targetChanged = targetKey != _activeLegTargetKey;
    if (targetChanged) {
      _activeLegTargetKey = targetKey;
      _lastActiveLegFetchAt = null;
      // Clear stale points immediately so the old route (which may extend past
      // the new target) is removed before the new fetch completes.
      if (_activeLegPoints.isNotEmpty) {
        _activeLegPoints = const [];
        _rebuildRoutePolylines(_plannedPoints, cabOverride: cab);
        if (mounted) setState(() {});
      }
    }

    final now = DateTime.now();
    if (!targetChanged &&
        _lastActiveLegFetchAt != null &&
        now.difference(_lastActiveLegFetchAt!) < _activeLegThrottle &&
        _activeLegPoints.length >= 2) {
      return;
    }

    _lastActiveLegFetchAt = now;
    final gen = ++_activeLegFetchGen;

    final List<LatLng> leg;
    if (_isLogoutTripType()) {
      // LOGOUT (tripType 2): route through office then every paxOrder stop up
      // to and including the target — cab → office → pax1 → … → targetPax.
      final throughPoints = _buildLogoutActiveLegWaypoints(cabPos, targetStop);
      leg = throughPoints.length >= 2
          ? await fetchRoutePolylineThroughPoints(throughPoints)
          : await fetchDirectionsPolyline(origin: cabPos, destination: targetLoc);
    } else {
      leg = await fetchDirectionsPolyline(
        origin: cabPos,
        destination: targetLoc,
      );
    }

    if (!mounted || gen != _activeLegFetchGen) return;

    _activeLegPoints = leg;
    _rebuildRoutePolylines(_plannedPoints, cabOverride: cab);
    setState(() {});
  }

  /// True when the current trip is a LOGOUT/drop trip (tripTypeCode == 2).
  bool _isLogoutTripType() {
    final status = _latestStatus;
    if (status == null) return _timeline.isLogout;
    final code = status.tripType ?? status.tripTypeCode;
    if (code != null) return code == 2;
    return _timeline.isLogout;
  }

  /// True when the current trip is a LOGIN/pickup trip (tripTypeCode == 1).
  bool _isLoginTripType() {
    final status = _latestStatus;
    if (status == null) return !_timeline.isLogout;
    final code = status.tripType ?? status.tripTypeCode;
    if (code != null) return code == 1;
    return !_timeline.isLogout;
  }

  /// LOGIN-only planned-route gating.
  ///
  /// Until the logged-in passenger boards (their paxTrackingStatus is still
  /// "not picked up"/"pending"), the only route the viewer should see is the
  /// orange active leg cab → first/next pickup. So the gray planned route is
  /// suppressed (empty). Once boarded, the planned route should trace the
  /// remaining pickups after the viewer plus the office (the tail of the trip).
  ///
  /// Returns the personalised planned-route waypoints for a LOGIN trip, or an
  /// empty list when nothing beyond the active leg should be drawn.
  List<LatLng> _loginPlannedWaypoints() {
    final status = _latestStatus;
    if (status == null) return const [];

    // Not boarded yet → show only cab → pickup1 (handled by the active leg).
    if (!_timeline.meBoarded) return const [];

    // Boarded → remaining pickups after me (still pending) + office tail.
    final myOrder = _myPaxOrder;
    final pax = List<TripPassenger>.from(status.passengers)
      ..sort((a, b) => (a.paxOrder ?? 0).compareTo(b.paxOrder ?? 0));

    final pts = <LatLng>[];
    for (final p in pax) {
      final order = p.paxOrder;
      if (order == null) continue;
      // Only stops AFTER my own pickup, and skip ones already resolved.
      if (myOrder != null && order <= myOrder) continue;
      if (isPaxRouteResolved(p, isPickupTrip: true)) continue;

      LatLng? loc;
      if (_useSignalRWaypoints) {
        final payloadPax = _lastPayload?.passengers ?? const [];
        for (final pp in payloadPax) {
          if (pp.paxOrder == order) {
            final lat = pp.plannedLat;
            final lng = pp.plannedLng;
            if (lat != null && lng != null && (lat != 0 || lng != 0)) {
              loc = LatLng(lat, lng);
            }
            break;
          }
        }
      }
      loc ??= (p.plannedLat != null &&
              p.plannedLng != null &&
              (p.plannedLat != 0 || p.plannedLng != 0))
          ? LatLng(p.plannedLat!, p.plannedLng!)
          : null;

      if (loc != null) pts.add(loc);
    }

    // Office tail (destination).
    final office = _officeLatLng;
    if (office != null) pts.add(office);

    // Fewer than 2 points can't draw a polyline.
    return pts.length >= 2 ? pts : const [];
  }

  /// Builds the ordered waypoint list for the orange active-leg on LOGOUT trips:
  ///   [cabPos, office, pax1, pax2, …, targetPax]
  ///
  /// All paxOrders from 1 up to and including [target.order] are included so
  /// the polyline faithfully traces the full drop sequence the cab must follow.
  List<LatLng> _buildLogoutActiveLegWaypoints(LatLng cabPos, RideStop target) {
    final pts = <LatLng>[cabPos];

    // Office is always the first stop after the cab on a drop trip.
    final officeLoc = _officeLatLng;
    if (officeLoc != null) pts.add(officeLoc);

    // Collect all passengers sorted by paxOrder ascending.
    final status = _latestStatus;
    if (status == null) {
      // Fallback: only add the target stop itself.
      final loc = _waypointLocationForStop(target);
      if (loc != null && (pts.isEmpty || loc != pts.last)) pts.add(loc);
      return pts;
    }

    final pax = List<TripPassenger>.from(status.passengers)
      ..sort((a, b) => (a.paxOrder ?? 0).compareTo(b.paxOrder ?? 0));

    // The polyline must end at the viewer's OWN drop, never beyond it. When the
    // target is the office (viewer "Not boarded" → cab heads to office first),
    // there is no pax order on the target, so fall back to the viewer's own
    // paxOrder as the cap. Otherwise cap at the target stop's order.
    final targetOrder = target.isOffice ? _myPaxOrder : (target.order ?? _myPaxOrder);

    for (final p in pax) {
      final order = p.paxOrder;
      if (order == null) continue;
      // Include all stops from paxOrder 1 up to and including the cap order.
      if (targetOrder != null && order > targetOrder) break;

      LatLng? loc;
      if (_useSignalRWaypoints) {
        final payloadPax = _lastPayload?.passengers ?? const [];
        for (final pp in payloadPax) {
          if (pp.paxOrder == order) {
            final lat = pp.plannedLat;
            final lng = pp.plannedLng;
            if (lat != null && lng != null && (lat != 0 || lng != 0)) {
              loc = LatLng(lat, lng);
            }
            break;
          }
        }
      }
      loc ??= (p.plannedLat != null &&
              p.plannedLng != null &&
              (p.plannedLat != 0 || p.plannedLng != 0))
          ? LatLng(p.plannedLat!, p.plannedLng!)
          : null;

      if (loc != null) pts.add(loc);
    }

    // If target is the office itself (all pax done), the office was already added.
    return pts;
  }

  /// Index of the polyline vertex closest to [p].
  int _nearestVertexIndex(List<LatLng> points, LatLng p) {
    var bestIdx = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final d = _approxDistanceMeters(p, points[i]);
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  // ── Camera control (fit once, then stay fixed) ─────────────────────────────

  /// All the points the initial camera should frame: cab + every visible stop
  /// (pickups/drops) + office, deduped of empty coordinates.
  List<LatLng> _trackingFocusPoints() {
    final pts = <LatLng>[_animatedDriverLatLng];
    for (final stop in _timeline.stops) {
      final loc = _waypointLocationForStop(stop);
      if (loc != null) pts.add(loc);
    }
    return pts;
  }

  /// Builds a [LatLngBounds] enclosing [points] (≥1). Returns null if empty.
  LatLngBounds? _boundsOf(List<LatLng> points) {
    if (points.isEmpty) return null;
    var minLat = points.first.latitude, maxLat = points.first.latitude;
    var minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    // Guard against a zero-area box (single point) which fitBounds dislikes.
    if ((maxLat - minLat).abs() < 1e-5) {
      minLat -= 0.0015;
      maxLat += 0.0015;
    }
    if ((maxLng - minLng).abs() < 1e-5) {
      minLng -= 0.0015;
      maxLng += 0.0015;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  /// Frames the whole trip (cab + stops + office) ONCE. Subsequent live updates
  /// never call this — the camera then stays put until the user recenters or
  /// the cab drifts off-screen. Safe to call before the controller exists.
  Future<void> _fitToTrackingBounds({bool force = false}) async {
    if (!force && _didInitialCameraFit) return;
    if (!_mapController.isCompleted) return;

    // Don't fit on a fallback-only frame (no real cab fix AND no stops yet) —
    // we'd just frame an arbitrary default point. Wait for real data.
    final hasRealCab = _animatedDriverLatLng != _fallbackCenter;
    final hasStops = _timeline.stops.any((s) => s.location != null);
    if (!force && !hasRealCab && !hasStops) return;

    final bounds = _boundsOf(_trackingFocusPoints());
    if (bounds == null) return;

    _didInitialCameraFit = true;
    _cameraMoveInFlight = true;
    final ctrl = await _mapController.future;
    await ctrl.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, _boundsPadding),
    );
  }

  /// Recenters on the cab at a close zoom — used by the recenter FAB and when
  /// the cab drifts out of the visible region. This is the ONLY camera move
  /// during live tracking, and it is event-driven (not per-GPS-update).
  Future<void> _recenterOnCab({double zoom = _followZoom}) async {
    if (!_mapController.isCompleted) return;
    _cameraMoveInFlight = true;
    final ctrl = await _mapController.future;
    await ctrl.animateCamera(
      CameraUpdate.newLatLngZoom(_animatedDriverLatLng, zoom),
    );
  }

  /// True when [p] sits outside the currently-visible map region, leaving a
  /// small inner margin so we recenter slightly before the cab hits the edge.
  bool _isOutsideVisibleBounds(LatLng p) {
    final b = _visibleBounds;
    if (b == null) return false;
    final latMargin = (b.northeast.latitude - b.southwest.latitude) * 0.12;
    final lngMargin = (b.northeast.longitude - b.southwest.longitude) * 0.12;
    return p.latitude > b.northeast.latitude - latMargin ||
        p.latitude < b.southwest.latitude + latMargin ||
        p.longitude > b.northeast.longitude - lngMargin ||
        p.longitude < b.southwest.longitude + lngMargin;
  }

  // Computes compass bearing (0–360°) from [from] to [to].
  double _bearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLng = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  void _animateCarTo(LatLng target) {
    final from = _animatedDriverLatLng;

    // Only update the heading on meaningful movement (>1m). Below that, GPS
    // noise would spin the marker randomly while the car is effectively stopped.
    final dist = _approxDistanceMeters(from, target);
    _bearingFrom = _carBearing;
    if (dist > 1) {
      // Compute the new compass heading and pick the shortest rotation path
      // from the current bearing (e.g. 350° → 10° rotates +20°, not -340°).
      final newBearing = _bearing(from, target);
      _bearingTo = _bearingFrom + _shortestTurn(_bearingFrom, newBearing);
    } else {
      _bearingTo = _bearingFrom;
    }

    _moveController.stop();
    _latAnim = Tween<double>(begin: from.latitude, end: target.latitude)
        .animate(
            CurvedAnimation(parent: _moveController, curve: Curves.easeInOut));
    _lngAnim = Tween<double>(begin: from.longitude, end: target.longitude)
        .animate(
            CurvedAnimation(parent: _moveController, curve: Curves.easeInOut));

    _moveController
      ..reset()
      ..addListener(_onMoveAnimTick)
      ..forward()
          .whenComplete(() => _moveController.removeListener(_onMoveAnimTick));

    // Ola/Uber behaviour: the camera is NOT moved on every GPS update — the
    // background map stays fixed while only the marker animates. The camera is
    // nudged only when the cab drifts out of the currently-visible region, and
    // only after the initial fit has happened.
    if (_didInitialCameraFit &&
        !_cameraMoveInFlight &&
        _isOutsideVisibleBounds(target)) {
      _recenterOnCab();
    }
  }

  // Signed shortest angular delta (−180..180) to rotate from [from] to [to].
  double _shortestTurn(double from, double to) {
    var diff = (to - from) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return diff;
  }

  void _onMoveAnimTick() {
    if (!mounted) return;
    final lat = _latAnim?.value;
    final lng = _lngAnim?.value;
    if (lat == null || lng == null) return;

    _animatedDriverLatLng = LatLng(lat, lng);

    // Interpolate the rotation with the same eased progress as the position so
    // the car turns gradually into the new heading instead of snapping.
    final t = _moveController.value;
    _carBearing = _bearingFrom + (_bearingTo - _bearingFrom) * t;

    // Update driver marker position + rotation. The +180 offset compensates for
    // the car PNG facing LEFT while Maps renders rotation 0° as facing EAST.
    _markers.removeWhere((m) => m.markerId.value == 'driver');
    _markers.add(Marker(
      markerId: const MarkerId('driver'),
      position: _animatedDriverLatLng,
      icon: _carIcon,
      anchor: const Offset(0.5, 0.5),
      rotation: (_carBearing + _carIconRotationOffset) % 360,
      flat: true,
      zIndexInt: 1,
    ));
    setState(() {});
  }

  double _approxDistanceMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final sinLat = math.sin(dLat / 2);
    final sinLng = math.sin(dLng / 2);
    final h = sinLat * sinLat +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            sinLng *
            sinLng;
    return 2 * r * math.asin(math.sqrt(h));
  }

  Future<void> _connectSignalR(TrackingStatusResponse status) async {
    // Only connect if the backend says to use SignalR and we haven't yet.
    if (_signalREnabled || !status.shouldUseSignalR) return;
    final dsId = status.dsId ?? widget.tripId;
    if (dsId == null) return;

    final token = AuthLocalStorage().getAccessToken();
    if (token == null) return;

    _signalREnabled = true;
    _signalR.addLocationListener(_onSignalRLocation);

    try {
      await _signalR.connect(accessToken: token);
      await _signalR.joinTrackingGroup(dsId);
      // Disable polling when SignalR is active to avoid redundant REST calls.
      _pollingTimer?.cancel();
      _pollingTimer = null;
    } catch (e) {
      debugPrint('[RideTrackingScreen] SignalR connect error: $e');
      _signalREnabled = false;
      _signalR.removeLocationListener(_onSignalRLocation);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCarIcon();
    _setupFallbackMarkers();

    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _sheetController.addListener(() {
      final expanded = _sheetController.size > 0.35;
      if (expanded != _isExpanded) setState(() => _isExpanded = expanded);
    });

    if (TrackingConfig.useDummyTracking) {
      // Testing/demo path: drive the SAME code paths with a local simulator
      // instead of the bloc/REST/SignalR feed. The screen never learns it's
      // dummy — it consumes identical RouteLocationPayload updates.
      _startDummyTracking();
    } else {
      // Production path — unchanged.
      _startPolling();
    }

    // Refresh paxTrackingStatus + rebuild the personalised/full timelines from
    // the latest SignalR payload every 200 ms (silent UI tick — no loader).
    // This also keeps the expected-arrival clock current since it repaints.
    _statusRefreshTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _refreshPaxTrackingStatus(),
    );
  }

  /// Seeds the screen from canned data and starts the local GPS simulator.
  /// Bypasses the bloc/REST/SignalR flow entirely; only runs in dummy mode.
  void _startDummyTracking() {
    final dummy = DummyTrackingService();
    _dummy = dummy;

    // Seed the map/timeline from a status that matches the live API structure,
    // routed through the same _applyStateToMap the live state uses.
    final status = dummy.seedStatus;
    final seed = RideTrackingDataState(
      status: status,
      detail: CabTrackingData(
        driverName: status.driverName,
        vehicleRegistrationNo: status.vehicleNo,
        officeLat: status.officeLat,
        officeLng: status.officeLng,
        otp: 4821,
        totalPax: status.passengers.length,
      ),
      plannedPolylinePoints: dummy.routePoints,
    );
    _dummyData = seed;
    // After first frame so the map controller / context are ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyStateToMap(seed);
      // Synthetic location updates arrive via the SAME callback SignalR uses.
      dummy.addLocationListener(_onSignalRLocation);
      dummy.start();
    });
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      context.read<CabTrackingBloc>().add(const RefreshCabTracking());
    });
  }

  /// Silently re-applies [paxTrackingStatus] from the latest SignalR payload
  /// into the timeline stops and flushes the UI — no loading state touched.
  void _refreshPaxTrackingStatus() {
    final payload = _lastPayload;
    if (!mounted || payload == null || payload.passengers.isEmpty) return;

    final byEmpId = <int, RouteTripPassenger>{
      for (final p in payload.passengers)
        if (p.empId != null) p.empId!: p,
    };

    final status = _latestStatus;
    if (status == null) return;

    bool changed = false;
    final updated = status.passengers.map((p) {
      final live = byEmpId[p.empId];
      final liveStatus = live?.paxTrackingStatus;
      final liveDeviation = live?.etaDeviationMinutes;
      final liveSchedule = live?.plannedScheduleTime;
      final statusChanged =
          liveStatus != null && liveStatus != p.paxTrackingStatus;
      final deviationChanged =
          liveDeviation != null && liveDeviation != p.etaDeviationMinutes;
      final scheduleChanged = liveSchedule != null &&
          liveSchedule.trim().isNotEmpty &&
          liveSchedule != p.plannedScheduleTime;
      if (statusChanged || deviationChanged || scheduleChanged) {
        changed = true;
        return TripPassenger(
          empId: p.empId,
          employeeID: p.employeeID,
          firstname: p.firstname,
          lastName: p.lastName,
          gender: p.gender,
          mobileno: p.mobileno,
          empLocCode: p.empLocCode,
          tripType: p.tripType,
          paxOrder: p.paxOrder,
          address: p.address,
          plannedLat: p.plannedLat,
          plannedLng: p.plannedLng,
          noShow: p.noShow,
          noShowReasonId: p.noShowReasonId,
          orsDeviation: p.orsDeviation,
          scheduled: p.scheduled,
          paxAdded: p.paxAdded,
          paxType: p.paxType,
          empDistance: p.empDistance,
          empDirectDistance: p.empDirectDistance,
          empCost: p.empCost,
          plannedScheduleTime: scheduleChanged ? liveSchedule : p.plannedScheduleTime,
          etaDeviationMinutes: deviationChanged ? liveDeviation : p.etaDeviationMinutes,
          empSigninTime: p.empSigninTime,
          empSigninLat: p.empSigninLat,
          empSigninLng: p.empSigninLng,
          empSignOutTime: p.empSignOutTime,
          empSignOutLat: p.empSignOutLat,
          empSignOutLng: p.empSignOutLng,
          cabReachedTime: p.cabReachedTime,
          cabReachedLat: p.cabReachedLat,
          cabReachedLng: p.cabReachedLng,
          reachedHomeTime: p.reachedHomeTime,
          reachedHomeLat: p.reachedHomeLat,
          reachedHomeLng: p.reachedHomeLng,
          paxTrackingStatus: statusChanged ? liveStatus : p.paxTrackingStatus,
        );
      }
      return p;
    }).toList();

    // Always repaint so the live expected-arrival clock stays current, even on
    // ticks where no passenger field changed. Only rebuild the timelines when
    // the underlying data actually changed (avoids needless work every 200 ms).
    if (changed) {
      _latestStatus = status.withPassengers(updated);
      _timeline = RideTimeline.fromStatus(_latestStatus!, meEmpId: widget.empId);
      _fullTimeline = RideTimeline.fromStatus(_latestStatus!,
          meEmpId: widget.empId, includeAllStops: true);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _statusRefreshTimer?.cancel();
    _moveController.dispose();
    _pulseController.dispose();
    _sheetController.dispose();
    // Clean up the dummy simulator if it was running (testing mode only).
    if (_dummy != null) {
      _dummy!.removeLocationListener(_onSignalRLocation);
      _dummy!.dispose();
      _dummy = null;
    }
    // Clean up SignalR: leave the group and close the connection.
    if (_signalREnabled) {
      final dsId = widget.tripId;
      if (dsId != null) _signalR.leaveTrackingGroup(dsId);
      _signalR.removeLocationListener(_onSignalRLocation);
      _signalR.disconnect();
    }
    super.dispose();
  }

  void _setupFallbackMarkers() {
    _markers
      ..clear()
      ..add(
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverLatLng,
          icon: _carIcon,
          infoWindow: const InfoWindow(title: 'Driver'),
          anchor: const Offset(0.5, 0.5),
        ),
      );
  }

  void _applyStateToMap(RideTrackingDataState data) {
    final status = data.status;

    // Cache for the SignalR ETA computation, which runs outside the bloc.
    _latestStatus = status;

    // Rebuild the personalised timeline (boarding states, current target, my
    // position in the pickup sequence) from the freshest status.
    _timeline = RideTimeline.fromStatus(status, meEmpId: widget.empId);
    _fullTimeline = RideTimeline.fromStatus(status,
        meEmpId: widget.empId, includeAllStops: true);

    // The bloc's planned polyline traces the FULL fleet route (office → every
    // drop). On LOGOUT trips that overshoots the viewer's own drop, and on
    // LOGIN trips it shows the whole route before the viewer boards — both
    // want a personalised route, so don't seed it; the boarding-gated /capped
    // Directions route built below replaces it instead.
    if (_isLogoutTripType() || _isLoginTripType()) {
      _plannedPoints = const [];
    } else {
      _plannedPoints = data.plannedPolylinePoints;
    }

    if (status != null && status.hasLocation && !_signalRHasLocation) {
      final newLatLng = LatLng(status.latestLat!, status.latestLng!);
      // Only snap position on initial REST load — SignalR uses animated path.
      if (_animatedDriverLatLng == _fallbackCenter) {
        _animatedDriverLatLng = newLatLng;
      }
      // Seed the ETA from the REST status so a value shows before the first
      // SignalR push; subsequent SignalR updates keep it live. notify:false —
      // _applyStateToMap flushes its own setState below.
      _updateEta(
        driver: newLatLng,
        speedKmh: status.latestSpeed,
        notify: false,
      );
      _driverLatLng = newLatLng;
    }

    _initialCamera =
        CameraPosition(target: _animatedDriverLatLng, zoom: _followZoom);

    _markers.clear();

    // Stop markers, coloured by their live state (completed=green,
    // current=orange, upcoming=blue, no-show=red, office=purple). Only the
    // stops relevant to this passenger's view are rendered.
    _rebuildStopMarkers();

    // Driver marker — uses animated position + bearing for smooth direction.
    _markers.add(
      Marker(
        markerId: const MarkerId('driver'),
        position: _animatedDriverLatLng,
        icon: _carIcon,
        anchor: const Offset(0.5, 0.5),
        rotation: (_carBearing + _carIconRotationOffset) % 360,
        flat: true,
        zIndexInt: 1,
        infoWindow: InfoWindow(
          title: status?.driverName ?? data.detail?.driverName ?? 'Driver',
          snippet: status?.trackingMessage ?? 'Your driver is on the way',
        ),
      ),
    );

    // Gray completed route + orange active cab→stop leg (Directions).
    _rebuildRoutePolylines(_plannedPoints);

    setState(() {});

    final tripId = status?.dsId ?? widget.tripId;
    if (tripId != null) {
      unawaited(_loadGpsRoutePolylines(tripId));
    } else if (_plannedPoints.length < 2) {
      unawaited(_applyDirectionsPlannedRoute());
    } else {
      unawaited(_refreshActiveLegPolyline());
    }

    // Camera: fit the whole trip ONCE (cab + stops + office), then leave it
    // fixed. Live GPS updates afterwards never move the camera — they only
    // animate the marker — so the background stays steady (Ola/Uber feel).
    _fitToTrackingBounds();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CabTrackingBloc, CabTrackingState>(
      listener: (context, state) {
        if (state is RideTrackingDataState) {
          _applyStateToMap(state);
          // Connect SignalR on first successful data load if server requests it.
          if (state.status != null) _connectSignalR(state.status!);
        } else if (state is CabTrackingError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      builder: (context, state) {
        // In dummy mode the bloc stays idle, so fall back to the seeded data.
        final data = state is RideTrackingDataState ? state : _dummyData;
        final isLoading = data == null &&
            (state is CabTrackingLoading || state is CabTrackingInitial);

        return Scaffold(
          body: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: _initialCamera,
                style: _kMapStyle,
                onMapCreated: (controller) {
                  if (!_mapController.isCompleted) {
                    _mapController.complete(controller);
                  }
                  if (data != null) _applyStateToMap(data);
                  // Frame the trip once the controller is ready.
                  _fitToTrackingBounds();
                },
                // Track the visible region so we can detect cab drift, and clear
                // the in-flight guard once a programmatic move settles.
                onCameraIdle: () async {
                  if (!_mapController.isCompleted) return;
                  final ctrl = await _mapController.future;
                  _visibleBounds = await ctrl.getVisibleRegion();
                  _cameraMoveInFlight = false;
                },
                markers: _markers,
                polylines: _polylines,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: false,
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).size.height * 0.23,
                ),
              ),
              if (isLoading)
                const ColoredBox(
                  color: Color(0x33FFFFFF),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF1A6B4A)),
                  ),
                ),
              _TopBar(onBack: () => Navigator.of(context).maybePop()),
              // _DebugInfoOverlay(
              //   payload: _lastPayload,
              //   animatedCab: _animatedDriverLatLng,
              //   timeline: _timeline,
              // ),
              _RecenterFab(
                // Tap → recenter on the cab. Long-press → re-fit the whole trip.
                onTap: () => _recenterOnCab(zoom: 15.0),
                onLongPress: () => _fitToTrackingBounds(force: true),
              ),
              _buildBottomSheet(data: data, isLoading: isLoading),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomSheet({
    required RideTrackingDataState? data,
    required bool isLoading,
  }) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.27,
      minChildSize: 0.27,
      maxChildSize: 0.55,
      snap: true,
      snapSizes: const [0.27, 0.55],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 14,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 8),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // OTP card — prefer the boarding OTP passed from the
                      // home screen (always present); fall back to the API value.
                      _OtpCard(
                        otp: widget.boardingOtp?.trim().isNotEmpty == true
                            ? widget.boardingOtp
                            : data?.detail?.otpDisplay,
                        isLoading: isLoading,
                      ),
                      const SizedBox(height: 10),

                      // Driver card
                      _DriverCard(
                        driverName: data?.status?.driverName ??
                            data?.detail?.driverName,
                        vehicleNo: data?.status?.vehicleNo ??
                            data?.detail?.vehicleRegistrationNo,
                        driverMobileNo: data?.status?.driverMobileNo,
                        dsId: data?.status?.dsId ?? widget.tripId,
                        empId: widget.empId,
                        isLoading: isLoading,
                      ),

                      // Personalised status banner — waiting vs boarded.
                      if (!isLoading && _timeline.stops.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _TrackingStatusBanner(
                          timeline: _timeline,
                          etaMinutes: _etaMinutes,
                        ),
                      ],

                      // Expanded section
                      AnimatedSize(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeInOut,
                        child: _isExpanded
                            ? _ExpandedSection(
                                data: data,
                                timeline: _timeline,
                                fullTimeline: _fullTimeline,
                                userName: widget.userName,
                                tripId: widget.tripId,
                                empId: widget.empId,
                                isLoading: isLoading,
                                etaMinutes: _etaMinutes,
                                showPassengerList: _showPassengerList,
                                onTogglePassengers: () => setState(() =>
                                    _showPassengerList = !_showPassengerList),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Top bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _CircleButton(
                onTap: onBack,
                child: const Icon(Icons.arrow_back,
                    color: Color(0xFF1A6B4A), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Tracking',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A6B4A),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Debug info overlay ───────────────────────────────────────────────────────

/// Compact, collapsible diagnostics panel pinned to the top-right of the map.
/// Surfaces the live cab lat/lng (from the latest SignalR [RouteLocationPayload])
/// and every passenger's paxOrder so the tracking feed can be eyeballed.
class _DebugInfoOverlay extends StatefulWidget {
  final RouteLocationPayload? payload;
  final LatLng animatedCab;
  final RideTimeline timeline;

  const _DebugInfoOverlay({
    required this.payload,
    required this.animatedCab,
    required this.timeline,
  });

  @override
  State<_DebugInfoOverlay> createState() => _DebugInfoOverlayState();
}

class _DebugInfoOverlayState extends State<_DebugInfoOverlay> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.payload;
    // Prefer the payload's reported position; fall back to the animated marker.
    final lat = p?.latitude ?? widget.animatedCab.latitude;
    final lng = p?.longitude ?? widget.animatedCab.longitude;

    // All passenger orders, sorted, taken from the payload if present else the
    // built timeline (so something shows before the first SignalR push).
    final List<_PaxOrderRow> orders;
    if (p != null && p.passengers.isNotEmpty) {
      orders = (List.of(p.passengers)
            ..sort((a, b) => (a.paxOrder ?? 0).compareTo(b.paxOrder ?? 0)))
          .map((e) => _PaxOrderRow(
                order: e.paxOrder,
                name: [e.firstname, e.lastName]
                    .where((s) => s?.trim().isNotEmpty == true)
                    .join(' ')
                    .trim(),
                status: e.paxTrackingStatus,
              ))
          .toList();
    } else {
      orders = widget.timeline.stops
          .where((s) => s.isPickup)
          .map((s) => _PaxOrderRow(
                order: s.order,
                name: s.title,
                status: s.paxTrackingStatus ?? statusLabelForStop(s),
              ))
          .toList();
    }

    return Positioned(
      top: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 56, right: 12),
          child: GestureDetector(
            onTap: () => setState(() => _open = !_open),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 240),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.78),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bug_report_outlined,
                          size: 14, color: Colors.white70),
                      const SizedBox(width: 6),
                      const Text(
                        'Cab',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(_open ? Icons.expand_less : Icons.expand_more,
                          size: 14, color: Colors.white54),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF7CFC9A),
                      fontFeatures: [ui.FontFeature.tabularFigures()],
                    ),
                  ),
                  if (p?.speed != null)
                    Text(
                      'speed ${p!.speed!.toStringAsFixed(1)} km/h',
                      style: const TextStyle(
                          fontSize: 10, color: Colors.white60),
                    ),
                  if (_open) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Pax orders (${orders.length})',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (orders.isEmpty)
                      const Text('—',
                          style:
                              TextStyle(fontSize: 11, color: Colors.white54))
                    else
                      ...orders.map((o) => Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '#${o.order ?? '?'}  ${o.name.isEmpty ? 'Passenger' : o.name}'
                              '${o.status?.trim().isNotEmpty == true ? '  · ${o.status!.trim()}' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                              ),
                            ),
                          )),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One row in the debug overlay's passenger-order list.
class _PaxOrderRow {
  final int? order;
  final String name;
  final String? status;
  const _PaxOrderRow({required this.order, required this.name, this.status});
}

// ─── Recenter FAB ─────────────────────────────────────────────────────────────

class _RecenterFab extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _RecenterFab({required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: MediaQuery.of(context).size.height * 0.26,
      child: _CircleButton(
        onTap: onTap,
        onLongPress: onLongPress,
        child: const Icon(Icons.my_location_rounded,
            color: Color(0xFF1A6B4A), size: 20),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _CircleButton({
    required this.child,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.14),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ─── OTP card ─────────────────────────────────────────────────────────────────

class _OtpCard extends StatelessWidget {
  final String? otp;
  final bool isLoading;
  const _OtpCard({this.otp, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7F3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.pin_outlined, color: Color(0xFF1A6B4A), size: 18),
          const SizedBox(width: 10),
          Text(
            'Ride PIN / OTP',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            isLoading ? '—' : (otp ?? '—'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A6B4A),
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Driver card ──────────────────────────────────────────────────────────────

class _DriverCard extends StatelessWidget {
  final String? driverName;
  final String? vehicleNo;
  final String? driverMobileNo;
  final int? dsId;
  final int? empId;
  final bool isLoading;

  const _DriverCard({
    this.driverName,
    this.vehicleNo,
    this.driverMobileNo,
    this.dsId,
    this.empId,
    this.isLoading = false,
  });

  Future<void> _onCallPressed(BuildContext context) async {
    final phone = driverMobileNo?.trim();
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver phone number not available')),
      );
      return;
    }

    if (dsId == null || empId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start call')),
      );
      return;
    }

    // Show a blocking loader while the IVR call is being initiated.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    String? virtualNumber;
    try {
      final response = await sl<IvrCallRepo>().initiate(
        dsId: dsId!,
        empId: empId!,
        phoneNo: phone,
        callerType: 'E',
      );
      virtualNumber = response.ivrVirtualNumber?.trim();
    } catch (_) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loader
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to start call')),
        );
      }
      return;
    }

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // dismiss loader

    if (virtualNumber == null || virtualNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start call')),
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: virtualNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to start call')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = isLoading ? 'Loading…' : (driverName ?? '—');
    final plate = vehicleNo?.trim();
    final canCall =
        !isLoading && driverMobileNo?.trim().isNotEmpty == true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Row(
        children: [
          ClipOval(
            child: Container(
              width: 46,
              height: 46,
              color: Colors.grey.shade200,
              child: const Icon(
                Icons.person_outline_rounded,
                color: Color(0xFF1A6B4A),
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Driver',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                if (plate != null && plate.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    plate,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: canCall ? () => _onCallPressed(context) : null,
            icon: const Icon(Icons.phone_rounded, size: 16),
            label: const Text('Call'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A6B4A),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Expanded section ─────────────────────────────────────────────────────────

class _ExpandedSection extends StatelessWidget {
  final RideTrackingDataState? data;
  final RideTimeline timeline;
  // Full passenger list (everyone on the route), shown in the expanded list.
  final RideTimeline fullTimeline;
  final String? userName;
  final int? tripId;
  final int? empId;
  final bool isLoading;
  final int? etaMinutes;
  final bool showPassengerList;
  final VoidCallback onTogglePassengers;

  const _ExpandedSection({
    this.data,
    required this.timeline,
    required this.fullTimeline,
    this.userName,
    this.tripId,
    this.empId,
    this.isLoading = false,
    this.etaMinutes,
    required this.showPassengerList,
    required this.onTogglePassengers,
  });

  void _openTripGroupChat(BuildContext context) {
    final id = tripId;
    if (id == null || id == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip ID is not available.')),
      );
      return;
    }

    final name = userName?.trim() ?? '';
    final participants = name.isNotEmpty ? name : 'Trip passengers';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TripGroupChatScreen(
          tripId: id,
          myEmpId: empId ?? 0,
          otherEmpId: 373,
          otherName: 'Trip Group Chat',
          participants: participants,
          myName: name.isNotEmpty ? name : 'You',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = data?.detail;
    final status = data?.status;

    final mode = status?.trackingMode?.trim().isNotEmpty == true
        ? status!.trackingMode!
        : (isLoading ? '—' : '—');

    final vehicle = (status?.vehicleNo?.trim().isNotEmpty == true
            ? status!.vehicleNo!.trim()
            : detail?.vehicleRegistrationNo?.trim()) ??
        '—';

    // Total/boarded counts + the stop list come from the FULL timeline so they
    // show every passenger on the route (not just the personalised view).
    final logout = fullTimeline.isLogout;
    final stops = fullTimeline.stops;
    final pickupStops = stops.where((s) => s.isPickup).toList();
    final totalPax = pickupStops.length;
    final boardedCount =
        pickupStops.where((s) => s.state == StopState.completed).length;
    final progressWord = logout ? 'Dropped' : 'Boarded';
    final etaHeader = logout ? 'ETA to your drop' : 'ETA to office';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Divider(color: Colors.grey.shade200, height: 1),
        const SizedBox(height: 12),

        // Vehicle number + mode row
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Text(
                  //   mode,
                  //   style: TextStyle(
                  //     fontSize: 12,
                  //     color: Colors.grey.shade500,
                  //     fontWeight: FontWeight.w500,
                  //   ),
                  // ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),
        Divider(color: Colors.grey.shade200, height: 1),
        const SizedBox(height: 12),

        // Route progress row with toggle (boarded vs total pickups).
        GestureDetector(
          onTap: totalPax > 0 ? onTogglePassengers : null,
          child: Row(
            children: [
              const Icon(Icons.airline_seat_recline_normal_rounded,
                  size: 18, color: Color(0xFF1A6B4A)),
              const SizedBox(width: 8),
              Text(
                '$totalPax',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  '$progressWord  $boardedCount/$totalPax',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              if (totalPax > 0)
                AnimatedRotation(
                  turns: showPassengerList ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF1A6B4A)),
                    ),
                    child: const Icon(Icons.keyboard_arrow_down,
                        size: 18, color: Color(0xFF1A6B4A)),
                  ),
                ),
            ],
          ),
        ),

        // Personalised stop timeline (pickups + office, colour-coded by state).
        if (showPassengerList && stops.isNotEmpty) ...[
          const SizedBox(height: 16),
          _RouteTimelineView(timeline: fullTimeline, etaMinutes: etaMinutes),
        ],

        const SizedBox(height: 12),
        Divider(color: Colors.grey.shade200, height: 1),
        const SizedBox(height: 12),

        // Need Cab Update row
        GestureDetector(
          onTap: () => _openTripGroupChat(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded,
                        size: 22, color: Color(0xFF1A6B4A)),
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Need Cab Update?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Chat with your group',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF888888),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: Color(0xFFAAAAAA), size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ─── Tracking status banner ─────────────────────────────────────────────────

/// A compact, always-visible banner that frames the trip from the logged-in
/// passenger's point of view: waiting (with N stops + current target) vs.
/// boarded (heading to office), vs. no-show / completed.
class _TrackingStatusBanner extends StatelessWidget {
  final RideTimeline timeline;
  final int? etaMinutes;

  const _TrackingStatusBanner({required this.timeline, this.etaMinutes});

  @override
  Widget build(BuildContext context) {
    final me = timeline.stops.firstWhere(
      (s) => s.isMe,
      orElse: () => timeline.stops.first,
    );

    late final IconData icon;
    late final Color color;
    late final String title;
    late final String subtitle;

    final logout = timeline.isLogout;
    if (me.state == StopState.noShow) {
      icon = Icons.person_off_rounded;
      color = const Color(0xFFDC2626);
      title = 'Marked as no-show';
      subtitle = 'Contact your transport desk if this is wrong.';
    } else if (timeline.meBoarded) {
      // Login → boarded & heading to office. Logout → dropped home.
      icon = logout ? Icons.home_rounded : Icons.event_seat_rounded;
      color = const Color(0xFF1A6B4A);
      if (logout) {
        title = "You've been dropped";
        subtitle = 'Hope you had a good ride home';
      } else {
        title = "You're on board";
        final remaining = timeline.stops.where((s) => s.isPickup).length;
        subtitle = remaining > 0
            ? 'Heading to office · $remaining pickup${remaining == 1 ? '' : 's'} left'
            : 'Heading straight to office';
      }
    } else {
      icon = Icons.directions_car_rounded;
      color = const Color(0xFFF59E0B);
      final stops = timeline.stopsBeforeMe;
      final target = timeline.target;
      if (logout) {
        // LOGOUT (tripType 2): Office → Home drop. Two phases for "me":
        //   1. In cab, being driven home  → target is my own drop stop.
        //   2. Cab still leaving the office to pick me up → target is office.
        final inCabToDrop = target != null && target.isMe;
        if (inCabToDrop) {
          title = "You're on the way home";
        } else {
          title = stops == 0
              ? 'Cab is on the way to your home'
              : '$stops drop${stops == 1 ? '' : 's'} before you';
        }
        // Both phases of a logout/drop trip describe progress toward MY drop.
        subtitle = stops == 0
            ? 'Heading to your drop'
            : '$stops drop${stops == 1 ? '' : 's'} before yours';
      } else {
        title = stops == 0
            ? 'Cab is arriving for you'
            : '$stops stop${stops == 1 ? '' : 's'} before you';
        subtitle = target == null
            ? 'Waiting for cab'
            : 'Now heading to ${target.isMe ? 'your pickup' : target.title}';
      }
    }

    final showEta =
        me.state != StopState.noShow && !(timeline.meBoarded && logout);
    final etaLabel = !showEta
        ? null
        : (!timeline.meBoarded
            ? (logout ? 'ETA to your drop' : 'ETA to your pickup')
            : (logout ? 'ETA to your drop' : 'ETA to office'));

    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (etaLabel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF1A6B4A),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_rounded,
                      size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      etaLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ), 
                  Text(
                    formatPlannedArrivalClock(
                          me.plannedScheduleTime,
                          me.etaDeviationMinutes,
                        ) ??
                        formatEta(etaMinutes),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Route timeline view ────────────────────────────────────────────────────

/// Vertical timeline of the personalised stops, colour-coded by [StopState]:
/// completed=green ✔, current=orange ⌛ (pulsing-style ring), upcoming=blue ○,
/// no-show=red ✕, office=purple 🏢.
class _RouteTimelineView extends StatelessWidget {
  final RideTimeline timeline;
  final int? etaMinutes;

  const _RouteTimelineView({required this.timeline, this.etaMinutes});

  @override
  Widget build(BuildContext context) {
    final stops = timeline.stops;
    return Column(
      children: [
        for (int i = 0; i < stops.length; i++)
          _TimelineRow(
            stop: stops[i],
            isLast: i == stops.length - 1,
            etaMinutes: stops[i].isOffice ? etaMinutes : null,
            isLogout: timeline.isLogout,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final RideStop stop;
  final bool isLast;
  final int? etaMinutes;
  final bool isLogout;

  const _TimelineRow({
    required this.stop,
    required this.isLast,
    this.etaMinutes,
    this.isLogout = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = colorForStop(stop);
    final done = stop.state == StopState.completed;
    final current = stop.state == StopState.current;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Node + connector.
          Column(
            children: [
              _StopNode(stop: stop, color: color),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: done ? color : const Color(0xFFE0E0E0),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Label + status.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          stop.isMe ? '${stop.title} (You)' : stop.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: (stop.isMe || current)
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      // Logout trips start from the office, so its status pill
                      // is meaningless — hide it for the office stop only.
                      if (!(isLogout && stop.isOffice))
                        _StatusPill(stop: stop, color: color),
                    ],
                  ),
                  if (!stop.isOffice ||
                      stop.subtitle?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(
                      stop.isOffice
                          ? stop.subtitle!.trim()
                          : [
                              stop.sequenceLabel,
                              if (stop.subtitle?.trim().isNotEmpty == true)
                                stop.subtitle!.trim(),
                            ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The circular node on the timeline — icon + colour reflect the stop state.
class _StopNode extends StatelessWidget {
  final RideStop stop;
  final Color color;

  const _StopNode({required this.stop, required this.color});

  @override
  Widget build(BuildContext context) {
    final IconData? icon;
    final bool filled;
    switch (stop.state) {
      case StopState.completed:
        icon = stop.isOffice ? Icons.business_rounded : Icons.check_rounded;
        filled = true;
        break;
      case StopState.current:
        icon = stop.isOffice
            ? Icons.business_rounded
            : Icons.directions_car_rounded;
        filled = true;
        break;
      case StopState.noShow:
        icon = Icons.close_rounded;
        filled = true;
        break;
      case StopState.upcoming:
        icon = stop.isOffice ? Icons.business_rounded : null;
        filled = stop.isOffice;
        break;
    }

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : Colors.white,
        border: Border.all(color: color, width: 2),
      ),
      child: icon == null
          ? null
          : Icon(icon, size: 18, color: filled ? Colors.white : color),
    );
  }
}

/// Small status chip ("Boarded", "Arriving", "Not boarded", "No show").
class _StatusPill extends StatelessWidget {
  final RideStop stop;
  final Color color;

  const _StatusPill({required this.stop, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        // Prefer the live server-provided status (paxTrackingStatus) from the
        // SignalR payload; fall back to the locally-derived StopState label.
        stop.paxTrackingStatus ?? statusLabelForStop(stop),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Small pill that renders a live ETA in minutes (or a placeholder until the
/// first SignalR location update arrives).
class _EtaChip extends StatelessWidget {
  final int? etaMinutes;
  const _EtaChip({this.etaMinutes});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7F3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.access_time_rounded,
              size: 14, color: Color(0xFF1A6B4A)),
          const SizedBox(width: 6),
          Text(
            formatEta(etaMinutes),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A6B4A),
            ),
          ),
        ],
      ),
    );
  }
}

/// Expected arrival clock time = planned schedule time + ETA deviation,
/// formatted as a 12-hour AM/PM string (e.g. `8:45 AM`).
///
/// [plannedScheduleTime] may be a full ISO datetime (`2026-06-08T08:30:00`) or
/// a bare time string (`08:30`, `8:30 AM`). Returns null when it can't be
/// parsed, so callers can fall back to the duration ETA.
String? formatPlannedArrivalClock(String? plannedScheduleTime, int? deviation) {
  final raw = plannedScheduleTime?.trim();
  if (raw == null || raw.isEmpty) return null;

  DateTime? parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    // Bare time string fallback: "8:30 AM", "08:30", "8:30:00".
    final m = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*([AaPp][Mm])?$')
        .firstMatch(raw);
    if (m == null) return null;
    var hour = int.parse(m.group(1)!);
    final minute = int.parse(m.group(2)!);
    final ampm = m.group(3)?.toUpperCase();
    if (ampm == 'PM' && hour != 12) hour += 12;
    if (ampm == 'AM' && hour == 12) hour = 0;
    parsed = DateTime(2000, 1, 1, hour, minute);
  }

  final arrival = parsed.add(Duration(minutes: deviation ?? 0));
  final hour24 = arrival.hour;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = arrival.minute.toString().padLeft(2, '0');
  final period = hour24 < 12 ? 'AM' : 'PM';
  return '$hour12:$minute $period';
}

/// Formats minutes into a compact ETA label (e.g. `5 min`, `1 h 10 min`).
String formatEta(int? minutes) {
  if (minutes == null) return '—';
  if (minutes <= 0) return 'Arriving';
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

// ─── Map style ────────────────────────────────────────────────────────────────

const String _kMapStyle = '''
[
  { "featureType": "administrative", "elementType": "labels", "stylers": [{ "visibility": "off" }] },
  { "featureType": "landscape", "elementType": "all", "stylers": [{ "visibility": "on" }] },
  { "featureType": "poi.attraction", "elementType": "labels", "stylers": [{ "visibility": "on" }] },
  { "featureType": "poi.business", "elementType": "all", "stylers": [{ "visibility": "on" }] },
  { "featureType": "poi.business", "elementType": "labels", "stylers": [{ "visibility": "on" }] },
  { "featureType": "poi.business", "elementType": "labels.icon", "stylers": [{ "visibility": "off" }] },
  { "featureType": "poi.government", "elementType": "labels", "stylers": [{ "visibility": "on" }] },
  { "featureType": "poi.school", "elementType": "all", "stylers": [{ "visibility": "on" }] },
  { "featureType": "poi.school", "elementType": "labels", "stylers": [{ "visibility": "off" }] },
  { "featureType": "road", "elementType": "all", "stylers": [{ "visibility": "on" }] },
  { "featureType": "road", "elementType": "labels", "stylers": [{ "visibility": "off" }] }
]
''';
