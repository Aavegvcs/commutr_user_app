import 'dart:async';

import 'package:commutr_main/core/di/injection.dart';
import 'package:commutr_main/features/trip_detail/data/model/cab_tracking/user_cab_tracking_response.dart';
import 'package:commutr_main/features/trip_detail/data/model/trip_home_response.dart';
import 'package:commutr_main/features/trip_detail/data/repository/cab_tracking/user_cab_tracking_repo.dart';
import 'package:commutr_main/trip_summary/trip_directions_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class TripSummaryWelcomeScreen extends StatefulWidget {
  const TripSummaryWelcomeScreen({
    super.key,
    required this.item,
    this.fromTeamCab = false,
    this.isQrBoarding = false,
  });

  final TripHomeItem item;

  /// QR boarding mode (`BoardingType == 3`), passed down from the caller because
  /// [UserAppConfigBloc] is scoped to the Welcome subtree and is not visible on
  /// this pushed route. Defaults to `false`, so the Sequence label keeps its
  /// existing behaviour wherever the flag is not supplied.
  final bool isQrBoarding;

  /// When opened from the Team Cab screen, we additionally fetch and render the
  /// full cab-tracking details (driver / vehicle / OTP / timings / passengers)
  /// for the passed [TripHomeItem.tripId] (`dsId`) + [TripHomeItem.empId].
  final bool fromTeamCab;

  @override
  State<TripSummaryWelcomeScreen> createState() =>
      _TripSummaryWelcomeScreenState();
}

class _TripSummaryWelcomeScreenState extends State<TripSummaryWelcomeScreen> {
  TripHomeItem get item => widget.item;
  bool get fromTeamCab => widget.fromTeamCab;
  bool get isQrBoarding => widget.isQrBoarding;

  // Cab-tracking detail fetched when [fromTeamCab] — drives both the new
  // details section and the enrichment of the top cards (addresses / vehicle /
  // times), which the team-cab [TripHomeItem] otherwise leaves blank.
  bool _detailLoading = false;
  TrackingStatusResponse? _status;
  CabTrackingData? _cab;

  @override
  void initState() {
    super.initState();
    if (fromTeamCab && item.tripId != null) {
      _loadTeamCabDetail();
    }
  }

  Future<void> _loadTeamCabDetail() async {
    setState(() => _detailLoading = true);
    final repo = sl<UserCabTrackingRepo>();
    final results = await Future.wait([
      repo
          .getTrackingStatus(tripId: item.tripId!)
          .then<TrackingStatusResponse?>((v) => v)
          .catchError((e) {
        debugPrint('[TEAM_CAB_DETAIL] getTrackingStatus failed: $e');
        return null;
      }),
      if (item.empId != null)
        repo
            .getUserCabTracking(empId: item.empId!, tripId: item.tripId!)
            .then<CabTrackingData?>((v) => v)
            .catchError((e) {
          debugPrint('[TEAM_CAB_DETAIL] getUserCabTracking failed: $e');
          return null;
        }),
    ]);

    if (!mounted) return;
    setState(() {
      _detailLoading = false;
      _status = results[0] as TrackingStatusResponse?;
      _cab = results.length > 1 ? results[1] as CabTrackingData? : null;
    });
  }

  /// The [item] enriched with whatever the cab-tracking APIs returned, so the
  /// existing top cards (addresses / vehicle / times) show real data instead of
  /// the blanks the bare team-cab [TripHomeItem] carries.
  TripHomeItem get _effectiveItem {
    final status = _status;
    final cab = _cab;
    if (status == null && cab == null) return item;

    String? nz(String? a, String? b) {
      final av = a?.trim();
      if (av != null && av.isNotEmpty) return av;
      final bv = b?.trim();
      return (bv != null && bv.isNotEmpty) ? bv : null;
    }

    // For login (pick) the user pickup is the planned passenger location; the
    // office address/latlng come from the status payload.
    final userPax = _matchedPassenger(status);

    return TripHomeItem(
      tripId: item.tripId,
      empId: item.empId,
      userName: nz(item.userName, userPax?.fullName),
      tripType: item.tripType,
      tripStatusName: item.tripStatusName,
      tripStatusCode: item.tripStatusCode,
      tripDate: item.tripDate,
      cancelorNoshow: item.cancelorNoshow,
      userAddress: nz(item.userAddress, userPax?.address),
      officeAddress: nz(item.officeAddress, status?.officeAddress),
      officeLatLng: item.officeLatLng ??
          ((status?.officeLat != null && status?.officeLng != null)
              ? '${status!.officeLat},${status.officeLng}'
              : null),
      empLatLng: item.empLatLng ??
          ((userPax?.pickupLat != null && userPax?.pickupLng != null)
              ? '${userPax!.pickupLat},${userPax.pickupLng}'
              : null),
      vehicleInfo:
          nz(item.vehicleInfo, status?.vehicleNo ?? cab?.vehicleRegistrationNo),
      pickShift:
          nz(item.pickShift, _formatShiftTime(status?.scheduledStartTime)),
      pickTime:
          nz(item.pickTime, _formatShiftTime(userPax?.plannedScheduleTime)),
      paxCount: item.paxCount ?? status?.totalPax ?? cab?.passengerCount,
      paxOrder: item.paxOrder ?? userPax?.paxOrder ?? cab?.paxOrder,
      otp: nz(item.otp, cab?.otp?.toString()),
    );
  }

  /// Best-effort match of the logged-in employee within the status passenger
  /// list (by empId, else by name).
  TripPassenger? _matchedPassenger(TrackingStatusResponse? status) {
    if (status == null || status.passengers.isEmpty) return null;
    for (final p in status.passengers) {
      if (item.empId != null && p.empId == item.empId) return p;
    }
    final name = item.userName?.trim().toLowerCase();
    if (name != null && name.isNotEmpty) {
      for (final p in status.passengers) {
        if (p.fullName.trim().toLowerCase() == name) return p;
      }
    }
    return status.passengers.first;
  }

  @override
  Widget build(BuildContext context) {
    final renderItem = fromTeamCab ? _effectiveItem : item;
    final cancelOrNoShow = renderItem.cancelorNoshow?.trim();
    // Cancelled / no-show trips never travelled, so there is no actual GPS
    // trail. We still show the map with the *planned* route (drawn dashed).
    final plannedOnly =
        cancelOrNoShow == 'Cancelled' || cancelOrNoShow == 'Noshow';
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F1),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF1B5E3B),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Trip Detail',
                    style: TextStyle(
                      color: Color(0xFF004128),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _MapCard(
                      item: renderItem,
                      plannedOnly: plannedOnly,
                      isQrBoarding: isQrBoarding,
                    ),
                    const SizedBox(height: 16),
                    _TripDetailCard(item: renderItem),
                    if (fromTeamCab) ...[
                      // Team-cab summary: show only the route map, trip
                      // addresses and the passenger list — nothing else.
                      if (item.tripId != null) ...[
                        const SizedBox(height: 16),
                        _TeamCabPassengersCard(
                          loading: _detailLoading,
                          status: _status,
                          isLogin: renderItem.isLogin,
                        ),
                      ],
                    ] else ...[
                      const SizedBox(height: 16),
                      _VehicleDetailCard(item: renderItem),
                      const SizedBox(height: 16),
                      _PickupDropRow(item: renderItem),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _formatShiftTime(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  // Full ISO date-time (e.g. "2026-06-27T12:40:27") → keep just the time.
  final dt = DateTime.tryParse(trimmed);
  if (dt != null && trimmed.contains('T')) {
    return _formatTime12(dt.hour, dt.minute);
  }
  final parts = trimmed.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return _formatTime12(h, m);
}

String _formatTime12(int h, int m) {
  final period = h >= 12 ? 'PM' : 'AM';
  var hour12 = h % 12;
  if (hour12 == 0) hour12 = 12;
  final mm = m.toString().padLeft(2, '0');
  return '$hour12:$mm $period';
}

const List<String> _kMonthsShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Formats an ISO / `HH:mm:ss` string to Indian-local `dd MMM yyyy, h:mm AM/PM`
/// (date dropped when the source has no date component). Returns null when the
/// input is null/blank/unparseable.
String? _formatIndianDateTime(String? raw, {bool dateOnly = false}) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;

  final dt = DateTime.tryParse(trimmed);
  if (dt != null) {
    final date =
        '${dt.day.toString().padLeft(2, '0')} ${_kMonthsShort[dt.month - 1]} ${dt.year}';
    if (dateOnly || !trimmed.contains('T')) return date;
    return '$date, ${_formatTime12(dt.hour, dt.minute)}';
  }
  // Plain HH:mm[:ss].
  return _formatShiftTime(trimmed);
}

String? _plannedPickupLabel(TripHomeItem item) {
  final pickTime = item.pickTime?.trim();
  if (pickTime != null && pickTime.isNotEmpty) {
    return _formatShiftTime(pickTime) ?? pickTime;
  }
  return _formatShiftTime(item.pickShift);
}

({String title, String? subtitle}) _splitAddress(String? address) {
  final cleaned = address?.trim();
  if (cleaned == null || cleaned.isEmpty) {
    return (title: 'Address not available', subtitle: null);
  }
  final idx = cleaned.indexOf(',');
  if (idx < 0) return (title: cleaned, subtitle: null);
  final title = cleaned.substring(0, idx).trim();
  final rest = cleaned.substring(idx + 1).trim();
  return (
    title: title.isEmpty ? cleaned : title,
    subtitle: rest.isEmpty ? null : rest,
  );
}

// ─── Map Card ────────────────────────────────────────────────────────────────

class _MapCard extends StatelessWidget {
  const _MapCard({
    required this.item,
    this.plannedOnly = false,
    this.isQrBoarding = false,
  });

  final TripHomeItem item;

  /// When true (cancelled / no-show), only the planned route is drawn (dashed)
  /// and a "PLANNED ROUTE" badge is shown instead of "TRIP COMPLETED".
  final bool plannedOnly;

  /// QR boarding mode (`BoardingType == 3`) — hides the Sequence label only.
  final bool isQrBoarding;

  @override
  Widget build(BuildContext context) {
    final isLogin = item.isLogin;
    final shiftSource = isLogin ? item.pickShift : item.dropShift;
    final shiftTime = _formatShiftTime(shiftSource) ?? shiftSource ?? '--:--';
    // Sequence / PA order is meaningless under QR boarding (BoardingType == 3):
    // a null label makes the existing `if (seqLabel != null)` branch below skip
    // the row entirely. Every other boarding type is unaffected.
    final seqLabel = (!isQrBoarding &&
            item.paxOrder != null &&
            item.paxCount != null)
        ? 'Sequence ${item.paxOrder}/${item.paxCount}'
        : null;
    final timeLabel = isLogin ? 'LOGIN TIME' : 'LOGOUT TIME';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Map area — tap to open the full route in a modal.
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(
              height: 220,
              width: double.infinity,
              child: Stack(
                children: [
                  _TripRouteMap(item: item, plannedOnly: plannedOnly),
                  // Transparent tap layer above the (non-interactive) preview
                  // map so the whole area opens the full-screen route modal.
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _showRouteModal(context, item, plannedOnly),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.open_in_full,
                          color: Color(0xFF1B5E3B),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  if (plannedOnly)
                    Positioned(
                      bottom: 14,
                      left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB0B6C2).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.route,
                              color: Color(0xFF4A5568),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'PLANNED ROUTE',
                              style: TextStyle(
                                color: Color(0xFF4A5568),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (item.isCompleted)
                    Positioned(
                      bottom: 14,
                      left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFB8C4E0).withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Color(0xFF3A5BA0),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'TRIP COMPLETED',
                              style: TextStyle(
                                color: Color(0xFF3A5BA0),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Login time & Sequence
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timeLabel,
                        style: const TextStyle(
                          color: Color(0xFF9E9E9E),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        shiftTime,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (seqLabel != null) ...[
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.accessible_forward,
                        color: Color(0xFF3E9B73),
                        size: 22,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        seqLabel,
                        style: const TextStyle(
                          color: Color(0xFF3E9B73),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Trip Route Data ──────────────────────────────────────────────────────────

/// The resolved markers + polyline for a trip route, shared by the inline
/// preview map and the full-screen modal.
class _TripRouteData {
  const _TripRouteData({
    required this.markers,
    required this.polylinePoints,
    this.isPlanned = false,
  });

  final Set<Marker> markers;
  final List<LatLng> polylinePoints;

  /// True when [polylinePoints] is the planned route (no actual GPS trail),
  /// so the map should draw it as a dashed line.
  final bool isPlanned;
}

/// Decodes an encoded Google polyline string into [LatLng] points.
List<LatLng> _decodeRoutePolyline(String? encoded) {
  if (encoded == null || encoded.trim().isEmpty) return const [];
  try {
    final points = PolylinePoints().decodePolyline(encoded.trim());
    return points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList(growable: false);
  } catch (e) {
    debugPrint('[TRIP_SUMMARY] polyline decode failed: $e');
    return const [];
  }
}

/// Markers for the planned route stops — fallback when the tracking APIs
/// return nothing usable.
Set<Marker> _stopMarkers(List<MapRouteStop> stops) {
  final markers = <Marker>{};
  for (final stop in stops) {
    final ll = parseLatLngString(stop.latLng);
    if (ll == null) continue;
    markers.add(Marker(
      markerId: MarkerId(stop.id),
      position: ll,
      icon: locationMarker,
      infoWindow: InfoWindow(title: stop.title, snippet: stop.snippet),
    ));
  }
  return markers;
}

/// Builds the trip-summary route by combining backend calls:
///
/// 1. `POST /Tracking/gps-route` → the complete `actualRoutePolyline`
///    (encoded), decoded into the route polyline. Falls back to
///    `plannedRoutePolyline`, then to the planned stop points.
/// 2. `GET /UserApp/GetUserCabTracking` → office + current cab markers, and
///    `POST /Tracking/status` → per-passenger planned-pickup markers
///    (`plannedLat`/`plannedLng`).
Future<_TripRouteData> _fetchTripRoute(
  TripHomeItem item, {
  bool plannedOnly = false,
}) async {
  final tripId = item.tripId;
  final empId = item.empId;

  // Planned stop points — used for fallback polyline.
  final routeStops = item.buildOrderedRouteStops();
  final stopPoints = <LatLng>[];
  for (final stop in routeStops) {
    final ll = parseLatLngString(stop.latLng);
    if (ll != null) stopPoints.add(ll);
  }

  if (tripId == null) {
    return _TripRouteData(
      markers: _stopMarkers(routeStops),
      polylinePoints: stopPoints.length >= 2 ? stopPoints : const [],
      isPlanned: plannedOnly || stopPoints.length >= 2,
    );
  }

  final repo = sl<UserCabTrackingRepo>();

  // Fetch route polyline, cab/office details and passenger pickups together.
  final results = await Future.wait([
    repo
        .getGpsRoute(tripId: tripId)
        .then<GpsRouteResponse?>((v) => v)
        .catchError((e) {
      debugPrint('[TRIP_SUMMARY] getGpsRoute failed: $e');
      return null;
    }),
    repo
        .getTrackingStatus(tripId: tripId)
        .then<TrackingStatusResponse?>((v) => v)
        .catchError((e) {
      debugPrint('[TRIP_SUMMARY] getTrackingStatus failed: $e');
      return null;
    }),
    if (empId != null)
      repo
          .getUserCabTracking(empId: empId, tripId: tripId)
          .then<CabTrackingData?>((v) => v)
          .catchError((e) {
        debugPrint('[TRIP_SUMMARY] getUserCabTracking failed: $e');
        return null;
      }),
  ]);

  final gpsRoute = results[0] as GpsRouteResponse?;
  final status = results[1] as TrackingStatusResponse?;
  final cab = results.length > 2 ? results[2] as CabTrackingData? : null;

  // ── Polyline ──
  // For cancelled / no-show trips there is no actual GPS trail, so prefer the
  // planned route. Otherwise prefer the actual route, falling back to planned.
  final encoded = plannedOnly
      ? (gpsRoute?.plannedRoutePolyline ?? gpsRoute?.actualRoutePolyline)
      : (gpsRoute?.actualRoutePolyline ?? gpsRoute?.plannedRoutePolyline);
  final decoded = _decodeRoutePolyline(encoded);
  // Whether what we're drawing is planned (dashed) rather than actually driven.
  final usedActual = !plannedOnly &&
      (gpsRoute?.actualRoutePolyline?.trim().isNotEmpty == true);
  final isPlanned = !usedActual;
  final polylinePoints = decoded.isNotEmpty
      ? decoded
      : (stopPoints.length >= 2 ? stopPoints : <LatLng>[]);

  // ── Markers ──
  final markers = <Marker>{};

  // Passenger planned-pickup markers from /Tracking/status.
  if (status != null) {
    for (final pax in status.passengers) {
      if (!pax.hasPickupLocation) continue;
      markers.add(Marker(
        markerId: MarkerId('pax_${pax.empId ?? pax.fullName}'),
        position: LatLng(pax.pickupLat!, pax.pickupLng!),
        icon: locationMarker,
        infoWindow: InfoWindow(
          title: pax.fullName.isEmpty ? 'Passenger' : pax.fullName,
          snippet: pax.address,
        ),
      ));
    }
  }

  // Office marker (from cab tracking, fallback to status).
  final officeLat = cab?.officeLat ?? status?.officeLat;
  final officeLng = cab?.officeLng ?? status?.officeLng;
  if (officeLat != null && officeLng != null) {
    markers.add(Marker(
      markerId: const MarkerId('office'),
      position: LatLng(officeLat, officeLng),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      infoWindow: InfoWindow(
        title: status?.officeDisplayName ?? status?.officeLocName ?? 'Office',
        snippet: status?.officeAddress,
      ),
    ));
  }

  // Current cab location marker.
  if (cab != null && cab.hasDriverLocation) {
    markers.add(Marker(
      markerId: const MarkerId('cab'),
      position: LatLng(cab.currentLat!, cab.currentLng!),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: InfoWindow(
        title: cab.driverName ?? 'Cab',
        snippet: cab.vehicleRegistrationNo,
      ),
    ));
  }

  // Fall back to planned route stops when no API markers were produced.
  final finalMarkers = markers.isNotEmpty ? markers : _stopMarkers(routeStops);

  return _TripRouteData(
    markers: finalMarkers,
    polylinePoints: polylinePoints,
    isPlanned: isPlanned,
  );
}

/// Opens the full-screen route map modal for [item].
void _showRouteModal(
  BuildContext context,
  TripHomeItem item,
  bool plannedOnly,
) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _TripRouteModal(item: item, plannedOnly: plannedOnly),
  );
}

// ─── Trip Route Google Map ────────────────────────────────────────────────────

class _TripRouteMap extends StatefulWidget {
  const _TripRouteMap({
    required this.item,
    this.interactive = false,
    this.plannedOnly = false,
  });

  final TripHomeItem item;

  /// When true, map gestures + zoom controls are enabled (used in the modal).
  final bool interactive;

  /// When true (cancelled / no-show), only the planned route is fetched and
  /// drawn dashed.
  final bool plannedOnly;

  @override
  State<_TripRouteMap> createState() => _TripRouteMapState();
}

class _TripRouteMapState extends State<_TripRouteMap> {
  final Completer<GoogleMapController> _ctrl = Completer();

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _loading = false;
  CameraPosition _camera = const CameraPosition(
    target: LatLng(20.5937, 78.9629),
    zoom: 5,
  );

  @override
  void initState() {
    super.initState();
    _buildRoute();
  }

  Future<void> _buildRoute() async {
    // Initial fit + dashed fallback line while the APIs load.
    final stopPoints = <LatLng>[];
    for (final stop in widget.item.buildOrderedRouteStops()) {
      final ll = parseLatLngString(stop.latLng);
      if (ll != null) stopPoints.add(ll);
    }
    final fallbackBounds = boundsFromPoints(stopPoints);

    if (mounted) {
      setState(() {
        _loading = true;
        if (fallbackBounds != null) {
          _camera = CameraPosition(
            target: LatLng(
              (fallbackBounds.southwest.latitude +
                      fallbackBounds.northeast.latitude) /
                  2,
              (fallbackBounds.southwest.longitude +
                      fallbackBounds.northeast.longitude) /
                  2,
            ),
            zoom: 12,
          );
        } else if (stopPoints.isNotEmpty) {
          _camera = CameraPosition(target: stopPoints.first, zoom: 14);
        }
        if (stopPoints.length >= 2) {
          _polylines = {
            Polyline(
              polylineId: const PolylineId('trip_route'),
              color: const Color(0xFF1A3A8F).withValues(alpha: 0.4),
              width: 2,
              points: stopPoints,
              patterns: [PatternItem.dash(16), PatternItem.gap(8)],
            ),
          };
        }
      });
    }

    final data = await _fetchTripRoute(
      widget.item,
      plannedOnly: widget.plannedOnly,
    );

    if (!mounted) return;

    final cameraPoints = <LatLng>[
      ...data.polylinePoints,
      ...data.markers.map((m) => m.position),
    ];
    final bounds = boundsFromPoints(cameraPoints);

    setState(() {
      _loading = false;
      _markers = data.markers;
      if (data.polylinePoints.isNotEmpty) {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('trip_route'),
            // Planned route → muted dashed line; actual driven route → solid.
            color: data.isPlanned
                ? const Color(0xFF1A3A8F).withValues(alpha: 0.6)
                : const Color(0xFF1A3A8F),
            width: 3,
            points: data.polylinePoints,
            patterns: data.isPlanned
                ? [PatternItem.dash(16), PatternItem.gap(8)]
                : const [],
          ),
        };
      }
    });

    if (bounds != null && _ctrl.isCompleted) {
      final ctrl = await _ctrl.future;
      ctrl.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
    }
  }

  void _fitCamera(List<LatLng> points) {
    final bounds = boundsFromPoints(points);
    if (bounds == null) return;
    _ctrl.future.then(
        (ctrl) => ctrl.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60)));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          style: kTripMapStyle,
          initialCameraPosition: _camera,
          onMapCreated: (controller) {
            if (!_ctrl.isCompleted) _ctrl.complete(controller);
            final pts =
                _polylines.isNotEmpty ? _polylines.first.points : <LatLng>[];
            if (pts.length >= 2) _fitCamera(pts);
          },
          markers: _markers,
          polylines: _polylines,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: widget.interactive,
          mapToolbarEnabled: false,
          compassEnabled: widget.interactive,
          zoomGesturesEnabled: widget.interactive,
          scrollGesturesEnabled: widget.interactive,
          rotateGesturesEnabled: widget.interactive,
          tiltGesturesEnabled: widget.interactive,
        ),
        if (_loading)
          const Positioned(
            top: 8,
            right: 8,
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF1A3A8F),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Full-screen Route Modal ──────────────────────────────────────────────────

class _TripRouteModal extends StatelessWidget {
  const _TripRouteModal({required this.item, this.plannedOnly = false});

  final TripHomeItem item;
  final bool plannedOnly;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: media.padding.top + 24,
      ),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(
              child: _TripRouteMap(
                item: item,
                interactive: true,
                plannedOnly: plannedOnly,
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 3,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.close,
                      color: Color(0xFF004128),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  plannedOnly ? 'Planned Route' : 'Trip Route',
                  style: const TextStyle(
                    color: Color(0xFF004128),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Trip Detail Card ─────────────────────────────────────────────────────────

class _TripDetailCard extends StatelessWidget {
  const _TripDetailCard({required this.item});

  final TripHomeItem item;

  @override
  Widget build(BuildContext context) {
    final isLogin = item.isLogin;
    final pickup = _splitAddress(
      isLogin ? item.userAddress : item.officeAddress,
    );
    final drop = _splitAddress(
      isLogin ? item.officeAddress : item.userAddress,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD0E8DC), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TRIP DETAIL',
            style: TextStyle(
              color: Color(0xFF596064),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 16),

          // Origin
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Image.asset(
                      'assets/images/pre_location.png',
                      width: 19,
                      height: 88,
                      fit: BoxFit.cover,
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pickup.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2C3437),
                            ),
                          ),
                          if (pickup.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              pickup.subtitle!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xff596064),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            drop.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2C3437),
                            ),
                          ),
                          if (drop.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              drop.subtitle!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xff596064),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
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

// ─── Vehicle Detail Card ──────────────────────────────────────────────────────

class _VehicleDetailCard extends StatelessWidget {
  const _VehicleDetailCard({required this.item});

  final TripHomeItem item;

  @override
  Widget build(BuildContext context) {
    final vehicle = item.vehicleInfo?.trim();
    final hasVehicle = vehicle != null && vehicle.isNotEmpty;
    final tripType = item.tripType?.trim();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const Icon(Icons.directions_car, color: Color(0xFF555555), size: 26),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'VEHICLE DETAIL',
                style: TextStyle(
                  color: Color(0xFF9E9E9E),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                hasVehicle ? vehicle : 'Not assigned',
                style: TextStyle(
                  color: hasVehicle
                      ? const Color(0xFF1B5E3B)
                      : const Color(0xFF9AA0A6),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              if (tripType != null && tripType.isNotEmpty)
                Text(
                  tripType,
                  style: const TextStyle(
                    color: Color(0xFF9E9E9E),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Pickup & Drop Row ────────────────────────────────────────────────────────

class _PickupDropRow extends StatelessWidget {
  const _PickupDropRow({required this.item});

  final TripHomeItem item;

  @override
  Widget build(BuildContext context) {
    final isLogin = item.isLogin;
    final plannedStop = _plannedPickupLabel(item);
    // Login → Login Shift (pickShift); Logout → Drop Time (dropShift), matching
    // the welcome home card.
    final shiftTime =
        _formatShiftTime(isLogin ? item.pickShift : item.dropShift) ?? '--:--';
    final shiftLabel = isLogin ? 'Login Shift' : 'Drop Time';
    // The planned-stop value is the passenger pickup time in both cases, so it
    // is always "Pickup Time". Only show the card when a real value exists.
    const stopLabel = 'Pickup Time';
    final hasStopTime = plannedStop != null && plannedStop.trim().isNotEmpty;
    // For a completed Logout trip we hide the Drop Time (shift) card entirely.
    final hideShiftCard = !isLogin && item.isCompleted;

    return Row(
      children: [
        if (hasStopTime) ...[
          Expanded(child: _TimeCard(label: stopLabel, time: plannedStop)),
          if (!hideShiftCard) const SizedBox(width: 14),
        ],
        // if (!hideShiftCard)
        //   Expanded(child: _TimeCard(label: shiftLabel, time: shiftTime)),
      ],
    );
  }
}

// ─── Team Cab Passengers Card ──────────────────────────────────────────────────

/// Renders only the passenger list for a team-cab trip from the already-fetched
/// `POST /Tracking/status` data. Status labels adapt to Login (pickup) vs Logout
/// (drop). Hidden entirely when there are no passengers.
class _TeamCabPassengersCard extends StatelessWidget {
  const _TeamCabPassengersCard({
    required this.loading,
    required this.status,
    required this.isLogin,
  });

  final bool loading;
  final TrackingStatusResponse? status;
  final bool isLogin;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        decoration: _cardDecoration(),
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: const Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF1B5E3B),
            ),
          ),
        ),
      );
    }

    final passengers = status?.passengers ?? const <TripPassenger>[];
    if (passengers.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PASSENGERS (${passengers.length})',
            style: const TextStyle(
              color: Color(0xFF596064),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < passengers.length; i++)
            _PassengerTile(
              pax: passengers[i],
              isLogin: isLogin,
              showDivider: i != passengers.length - 1,
            ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE8E8E8), width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );

class _PassengerTile extends StatelessWidget {
  const _PassengerTile({
    required this.pax,
    required this.isLogin,
    required this.showDivider,
  });

  final TripPassenger pax;
  final bool isLogin;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final name = pax.fullName.trim().isEmpty ? 'Passenger' : pax.fullName;
    final order = pax.paxOrder;
    final address = pax.address?.trim();

    // For login trips the relevant time is sign-in (pickup); for logout it's
    // sign-out / reached-home (drop). Shown in Indian-local date-time format.
    final timeRaw = isLogin
        ? pax.empSigninTime
        : (pax.empSignOutTime ?? pax.reachedHomeTime);
    final time = _formatIndianDateTime(timeRaw);

    final String statusText;
    final Color statusColor;
    if (pax.isNoShow) {
      statusText = 'No Show';
      statusColor = const Color(0xFFDC2626);
    } else if (isLogin) {
      statusText = pax.isBoarded ? 'Boarded' : 'Not Boarded';
      statusColor =
          pax.isBoarded ? const Color(0xFF1A6B3C) : const Color(0xFF7C3AED);
    } else {
      statusText = pax.isDropped ? 'Dropped' : 'En-Route';
      statusColor =
          pax.isDropped ? const Color(0xFF1A6B3C) : const Color(0xFF1D4ED8);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor:
                    const Color(0xFF1B5E3B).withValues(alpha: 0.12),
                child: Text(
                  order != null ? '$order' : '•',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B5E3B),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    if (address != null && address.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        address,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                    if (time != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${isLogin ? 'Pickup' : 'Drop'}: $time',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (showDivider) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFEFEFEF)),
          ],
        ],
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  final String label;
  final String time;

  const _TimeCard({required this.label, required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            time,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
