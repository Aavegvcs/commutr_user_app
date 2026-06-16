import 'dart:async';

import 'package:commutr_main/core/di/injection.dart';
import 'package:commutr_main/features/trip_detail/data/model/cab_tracking/user_cab_tracking_response.dart';
import 'package:commutr_main/features/trip_detail/data/model/trip_home_response.dart';
import 'package:commutr_main/features/trip_detail/data/repository/cab_tracking/user_cab_tracking_repo.dart';
import 'package:commutr_main/trip_summary/trip_directions_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class TripSummaryWelcomeScreen extends StatelessWidget {
  const TripSummaryWelcomeScreen({super.key, required this.item});

  final TripHomeItem item;

  @override
  Widget build(BuildContext context) {
    final cancelOrNoShow = item.cancelorNoshow?.trim();
    final showMapPreview =
        cancelOrNoShow != 'Cancelled' && cancelOrNoShow != 'Noshow';
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
                    if (showMapPreview) ...[
                      _MapCard(item: item),
                      const SizedBox(height: 16),
                    ],
                    _TripDetailCard(item: item),
                    const SizedBox(height: 16),
                    _VehicleDetailCard(item: item),
                    const SizedBox(height: 16),
                    _PickupDropRow(item: item),
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
  final parts = trimmed.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  final period = h >= 12 ? 'PM' : 'AM';
  var hour12 = h % 12;
  if (hour12 == 0) hour12 = 12;
  final mm = m.toString().padLeft(2, '0');
  return '$hour12:$mm $period';
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
  const _MapCard({required this.item});

  final TripHomeItem item;

  @override
  Widget build(BuildContext context) {
    final isLogin = item.isLogin;
    final shiftTime =
        _formatShiftTime(item.pickShift) ?? item.pickShift ?? '--:--';
    final seqLabel = (item.paxOrder != null && item.paxCount != null)
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
                  _TripRouteMap(item: item),
                  // Transparent tap layer above the (non-interactive) preview
                  // map so the whole area opens the full-screen route modal.
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _showRouteModal(context, item),
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
                  if (item.isCompleted)
                    Positioned(
                      bottom: 14,
                      left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB8C4E0).withOpacity(0.88),
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
                Column(
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
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (seqLabel != null)
                  Row(
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
  const _TripRouteData({required this.markers, required this.polylinePoints});

  final Set<Marker> markers;
  final List<LatLng> polylinePoints;
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
Future<_TripRouteData> _fetchTripRoute(TripHomeItem item) async {
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

  // ── Polyline: decode actualRoutePolyline (fallback planned → stops) ──
  final decoded = _decodeRoutePolyline(
    gpsRoute?.actualRoutePolyline ?? gpsRoute?.plannedRoutePolyline,
  );
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
  final finalMarkers =
      markers.isNotEmpty ? markers : _stopMarkers(routeStops);

  return _TripRouteData(
    markers: finalMarkers,
    polylinePoints: polylinePoints,
  );
}

/// Opens the full-screen route map modal for [item].
void _showRouteModal(BuildContext context, TripHomeItem item) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _TripRouteModal(item: item),
  );
}

// ─── Trip Route Google Map ────────────────────────────────────────────────────

class _TripRouteMap extends StatefulWidget {
  const _TripRouteMap({required this.item, this.interactive = false});

  final TripHomeItem item;

  /// When true, map gestures + zoom controls are enabled (used in the modal).
  final bool interactive;

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

    final data = await _fetchTripRoute(widget.item);

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
            color: const Color(0xFF1A3A8F),
            width: 3,
            points: data.polylinePoints,
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
            final pts = _polylines.isNotEmpty
                ? _polylines.first.points
                : <LatLng>[];
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
  const _TripRouteModal({required this.item});

  final TripHomeItem item;

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
              child: _TripRouteMap(item: item, interactive: true),
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
                child: const Text(
                  'Trip Route',
                  style: TextStyle(
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
    final plannedPickup = _plannedPickupLabel(item) ?? '--:--';
    final shiftTime = _formatShiftTime(item.pickShift) ?? '--:--';
    final pickupTime = isLogin ? plannedPickup : shiftTime;
    final dropTime = isLogin ? shiftTime : plannedPickup;
    final pickupLabel = isLogin ? 'Pickup' : 'Drop Time';
    final dropLabel = isLogin ? 'Drop Timing' : 'Pickup Time';

    return Row(
      children: [
        Expanded(child: _TimeCard(label: pickupLabel, time: pickupTime)),
        const SizedBox(width: 14),
        Expanded(child: _TimeCard(label: dropLabel, time: dropTime)),
      ],
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