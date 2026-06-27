import 'dart:async';

import 'package:commutr_main/features/trip_detail/data/model/trip_history_response.dart';
import 'package:commutr_main/trip_summary/trip_directions_service.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class TripSummaryScreen extends StatelessWidget {
  const TripSummaryScreen({super.key, required this.tripItem});

  final TripHistoryItem tripItem;

  // ─── Helpers ────────────────────────────────────────────────────────────────

  static const List<String> _monthAbbrev = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const Map<String, int> _monthIndex = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  /// Parses `"21-May-2026"` → `DateTime`.
  DateTime? _parseDate(String? raw) {
    if (raw == null) return null;
    final parts = raw.trim().split('-');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = _monthIndex[parts[1].toLowerCase()];
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  String _formatDate(String? raw) {
    final d = _parseDate(raw);
    if (d == null) return raw ?? '--';
    return '${d.day} ${_monthAbbrev[d.month - 1]} ${d.year}';
  }

  /// `"09:30"` → `"9:30 AM"`.
  String _formatTime(String? raw) {
    if (raw == null) return '--';
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '--';
    final parts = trimmed.split(':');
    if (parts.length < 2) return trimmed;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return trimmed;
    final period = h >= 12 ? 'PM' : 'AM';
    var h12 = h % 12;
    if (h12 == 0) h12 = 12;
    return '$h12:${m.toString().padLeft(2, '0')} $period';
  }

  String _tripTypeLabel() => tripItem.isLogin ? 'Login' : 'Logout';

  String _statusLabel() {
    if (tripItem.isNoShow) return 'No Show';
    if (tripItem.isCancelled) return 'Cancelled';
    if (tripItem.isCompleted) return 'Completed';
    final s = (tripItem.tripStatus ?? '').trim();
    return s.isEmpty ? '--' : s;
  }

  Color _statusColor() {
    if (tripItem.isNoShow || tripItem.isCancelled) return const Color(0xFFDC2626);
    if (tripItem.isCompleted) return const Color(0xFF2563EB);
    return const Color(0xFF888888);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F1),
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
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
                      color: Color(0xFF1B5E3B),
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Map Card
                    _MapCard(
                      tripItem: tripItem,
                      status: _statusLabel(),
                      statusColor: _statusColor(),
                      // Cancelled / no-show trips never travelled — show the
                      // planned route drawn dashed.
                      plannedOnly: tripItem.isCancelled || tripItem.isNoShow,
                    ),
                    const SizedBox(height: 16),

                    // Trip Detail Card
                    _TripDetailCard(
                      tripDate: _formatDate(tripItem.tripDate),
                      tripType: _tripTypeLabel(),
                      shiftTime: _formatTime(tripItem.shiftTime),
                      pickTime: _formatTime(tripItem.pickTime),
                      pickupAddress: tripItem.pickupAddress,
                      officeAddress: tripItem.officeAddress,
                      status: _statusLabel(),
                      statusColor: _statusColor(),
                    ),
                    const SizedBox(height: 16),

                    // Vehicle Detail Card
                    _VehicleDetailCard(
                      vehicleNo: tripItem.vehicleRegistrationNo,
                    ),
                    const SizedBox(height: 16),

                    // Pickup & Drop Row
                    _PickupDropRow(
                      pickTime: _formatTime(tripItem.pickTime),
                      hasPickTime: (tripItem.pickTime?.trim().isNotEmpty) == true,
                      shiftTime: _formatTime(tripItem.shiftTime),
                      isLogin: tripItem.isLogin,
                    ),
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

// ─── Map Card ────────────────────────────────────────────────────────────────

class _MapCard extends StatelessWidget {
  const _MapCard({
    required this.tripItem,
    required this.status,
    required this.statusColor,
    this.plannedOnly = false,
  });

  final TripHistoryItem tripItem;
  final String status;
  final Color statusColor;

  /// When true (cancelled / no-show), the route is drawn dashed and labelled
  /// "Planned Route".
  final bool plannedOnly;

  void _openMapModal(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: SizedBox(
            width: double.infinity,
            height: MediaQuery.of(ctx).size.height * 0.8,
            child: Stack(
              children: [
                Positioned.fill(
                  child: _TripRouteMap(
                    tripItem: tripItem,
                    plannedOnly: plannedOnly,
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(ctx).pop(),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.close, color: Color(0xFF1B5E3B), size: 22),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(
              height: 220,
              width: double.infinity,
              child: Stack(
                children: [
                  _TripRouteMap(tripItem: tripItem, plannedOnly: plannedOnly),
                  // Tap anywhere on the preview to open the full-screen map.
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _openMapModal(context),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            plannedOnly ? Icons.route : Icons.fullscreen,
                            color: const Color(0xFF1B5E3B),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            plannedOnly ? 'Planned Route' : 'View Map',
                            style: const TextStyle(
                              color: Color(0xFF1B5E3B),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: statusColor, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
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
        ],
      ),
    );
  }
}

// ─── Trip Route Google Map ────────────────────────────────────────────────────

class _TripRouteMap extends StatefulWidget {
  const _TripRouteMap({required this.tripItem, this.plannedOnly = false});

  final TripHistoryItem tripItem;

  /// When true (cancelled / no-show), the route is drawn dashed to signal it
  /// was planned but never travelled.
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
    final item = widget.tripItem;
    final routeStops = item.buildOrderedRouteStops();

    final validStops = <TripHistoryRouteStop>[];
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
      // Not enough points — just show markers at whatever we have.
      final camera = stopPoints.isNotEmpty
          ? CameraPosition(target: stopPoints.first, zoom: 14)
          : _camera;
      if (mounted) setState(() { _markers = markers; _camera = camera; });
      return;
    }

    // Set markers + fallback straight-line polyline while Directions loads.
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

    // Fetch real road polyline through every stop in paxOrder sequence.
    final roadPoints = await fetchRoutePolylineThroughPoints(stopPoints);

    if (!mounted) return;

    final polylinePoints = roadPoints.isNotEmpty ? roadPoints : stopPoints;
    final bounds = boundsFromPoints(polylinePoints);

    setState(() {
      _loading = false;
      _polylines = {
        Polyline(
          polylineId: const PolylineId('trip_route'),
          // Planned (cancelled / no-show) → muted dashed; travelled → solid.
          color: widget.plannedOnly
              ? const Color(0xFF1A3A8F).withValues(alpha: 0.6)
              : const Color(0xFF1A3A8F),
          width: 3,
          points: polylinePoints,
          patterns: widget.plannedOnly
              ? [PatternItem.dash(16), PatternItem.gap(8)]
              : const [],
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
    _ctrl.future.then((ctrl) {
      ctrl.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
    });
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
  const _TripDetailCard({
    required this.tripDate,
    required this.tripType,
    required this.shiftTime,
    required this.pickTime,
    required this.pickupAddress,
    required this.officeAddress,
    required this.status,
    required this.statusColor,
  });

  final String tripDate;
  final String tripType;
  final String shiftTime;
  final String pickTime;
  final String? pickupAddress;
  final String? officeAddress;
  final String status;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD0E8DC), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Date + Type + Shift
          Row(
            children: [
              _infoChip(Icons.calendar_today_outlined, tripDate),
              const SizedBox(width: 10),
              _infoChip(
                tripType == 'Login' ? Icons.login : Icons.logout,
                tripType,
              ),
              const SizedBox(width: 10),
              _infoChip(Icons.access_time, shiftTime),
            ],
          ),
          const SizedBox(height: 16),

          // Route
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/images/pre_location.png',
                  width: 19,
                  height: 88,
                  fit: BoxFit.cover,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _addressBlock(
                        'PICKUP',
                        pickupAddress?.isNotEmpty == true
                            ? pickupAddress!
                            : 'Address not available',
                      ),
                      const SizedBox(height: 20),
                      _addressBlock(
                        'OFFICE / DROP',
                        officeAddress?.isNotEmpty == true
                            ? officeAddress!
                            : 'Address not available',
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

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF596064)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C3437),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addressBlock(String label, String address) {
    final idx = address.indexOf(',');
    final title = idx < 0 ? address : address.substring(0, idx).trim();
    final sub = idx < 0 ? null : address.substring(idx + 1).trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3437),
          ),
        ),
        if (sub != null && sub.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            sub,
            style: const TextStyle(fontSize: 12, color: Color(0xFF596064)),
          ),
        ],
      ],
    );
  }
}

// ─── Vehicle Detail Card ──────────────────────────────────────────────────────

class _VehicleDetailCard extends StatelessWidget {
  const _VehicleDetailCard({required this.vehicleNo});

  final String? vehicleNo;

  @override
  Widget build(BuildContext context) {
    final hasVehicle = vehicleNo != null && vehicleNo!.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
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
                hasVehicle ? vehicleNo!.trim() : 'Not available',
                style: TextStyle(
                  color: hasVehicle
                      ? const Color(0xFF1B5E3B)
                      : const Color(0xFF9E9E9E),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
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
  const _PickupDropRow({
    required this.pickTime,
    required this.hasPickTime,
    required this.shiftTime,
    required this.isLogin,
  });

  final String pickTime;

  /// Whether a real pickup/drop time exists. When false, the time card is
  /// hidden entirely instead of showing a placeholder.
  final bool hasPickTime;
  final String shiftTime;
  final bool isLogin;

  @override
  Widget build(BuildContext context) {
    // The boarding time only applies to its own trip type: a pickup time for
    // login trips, a drop time for logout trips. We never show a drop time on
    // a login card or a pickup time on a logout card.
    final stopTimeLabel = isLogin ? 'Pickup Time' : 'Drop Time';

    return Row(
      children: [
        // Hide the pickup/drop time card when there's no value for it.
        if (hasPickTime) ...[
          Expanded(child: _TimeCard(label: stopTimeLabel, time: pickTime)),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: _TimeCard(
            label: isLogin ? 'Login Shift' : 'Logout Shift',
            time: shiftTime,
          ),
        ),
      ],
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({required this.label, required this.time});

  final String label;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
