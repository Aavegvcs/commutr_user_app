import 'dart:async';

import 'package:commutr_main/features/trip_detail/data/model/trip_home_response.dart';
import 'package:commutr_main/trip_summary/trip_directions_service.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class TripSummaryWelcomeScreen extends StatelessWidget {
  const TripSummaryWelcomeScreen({super.key, required this.item});

  final TripHomeItem item;

  @override
  Widget build(BuildContext context) {
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
                    _MapCard(item: item),
                    const SizedBox(height: 16),
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
          // Map area
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(
              height: 220,
              width: double.infinity,
              child: Stack(
                children: [
                  _TripRouteMap(item: item),
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

// ─── Trip Route Google Map ────────────────────────────────────────────────────

class _TripRouteMap extends StatefulWidget {
  const _TripRouteMap({required this.item});

  final TripHomeItem item;

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
    final item = widget.item;
    final routeStops = item.buildOrderedRouteStops();

    final validStops = <MapRouteStop>[];
    final stopPoints = <LatLng>[];
    for (final stop in routeStops) {
      final ll = parseLatLngString(stop.latLng);
      if (ll == null) continue;
      validStops.add(stop);
      stopPoints.add(ll);
    }

    final Set<Marker> markers = {};
    for (var i = 0; i < validStops.length; i++) {
      final stop = validStops[i];
      markers.add(Marker(
        markerId: MarkerId(stop.id),
        position: stopPoints[i],
        icon: locationMarker,
        infoWindow: InfoWindow(title: stop.title, snippet: stop.snippet),
      ));
    }

    if (stopPoints.length < 2) {
      final camera = stopPoints.isNotEmpty
          ? CameraPosition(target: stopPoints.first, zoom: 14)
          : _camera;
      if (mounted) setState(() { _markers = markers; _camera = camera; });
      return;
    }

    // Show markers + fallback dashed straight line while Directions API loads.
    final fallbackBounds = boundsFromPoints(stopPoints);
    final fallbackCamera = fallbackBounds != null
        ? CameraPosition(
            target: LatLng(
              (fallbackBounds.southwest.latitude +
                      fallbackBounds.northeast.latitude) /
                  2,
              (fallbackBounds.southwest.longitude +
                      fallbackBounds.northeast.longitude) /
                  2,
            ),
            zoom: 12,
          )
        : _camera;

    if (mounted) {
      setState(() {
        _markers = markers;
        _camera = fallbackCamera;
        _loading = true;
        _polylines = {
          Polyline(
            polylineId: const PolylineId('trip_route'),
            color: const Color(0xFF1A3A8F).withValues(alpha: 0.4),
            width: 2,
            points: stopPoints,
            patterns: [PatternItem.dash(16), PatternItem.gap(8)],
          ),
        };
      });
    }

    final roadPoints = await fetchRoutePolylineThroughPoints(stopPoints);

    if (!mounted) return;

    final polylinePoints = roadPoints.isNotEmpty ? roadPoints : stopPoints;
    final bounds = boundsFromPoints(polylinePoints);

    setState(() {
      _loading = false;
      _polylines = {
        Polyline(
          polylineId: const PolylineId('trip_route'),
          color: const Color(0xFF1A3A8F),
          width: 3,
          points: polylinePoints,
        ),
      };
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
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
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