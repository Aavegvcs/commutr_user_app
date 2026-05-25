import 'dart:async';

import 'package:commutr_main/features/trip_detail/data/model/cab_tracking/user_cab_tracking_response.dart';
import 'package:commutr_main/ride_tracking/bloc/cab_tracking_bloc.dart';
import 'package:commutr_main/ride_tracking/bloc/cab_tracking_state.dart';
import 'package:commutr_main/ride_tracking/trip_progress_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RideTrackingScreen extends StatefulWidget {
  final String? userName;

  const RideTrackingScreen({super.key, this.userName});

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen>
    with TickerProviderStateMixin {
  final Completer<GoogleMapController> _mapController = Completer();

  static const LatLng _fallbackCenter = LatLng(28.5930, 77.0490);

  LatLng _driverLatLng = _fallbackCenter;
  LatLng _officeLatLng = _fallbackCenter;
  CameraPosition _initialCamera = const CameraPosition(
    target: _fallbackCenter,
    zoom: 14.8,
  );

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  bool _isExpanded = false;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupFallbackMarkersAndRoute();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _sheetController.addListener(() {
      final expanded = _sheetController.size > 0.35;
      if (expanded != _isExpanded) setState(() => _isExpanded = expanded);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  void _setupFallbackMarkersAndRoute() {
    _markers
      ..clear()
      ..addAll([
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverLatLng,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Driver'),
        ),
        Marker(
          markerId: const MarkerId('office'),
          position: _officeLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: const InfoWindow(title: 'Office'),
        ),
      ]);

    _polylines
      ..clear()
      ..add(
        Polyline(
          polylineId: const PolylineId('route'),
          color: const Color(0xFF1A6B4A),
          width: 4,
          points: [_driverLatLng, _officeLatLng],
          patterns: [PatternItem.dash(18), PatternItem.gap(9)],
        ),
      );
  }

  void _applyTrackingToMap(CabTrackingData data) {
    if (data.hasDriverLocation) {
      _driverLatLng = LatLng(data.currentLat!, data.currentLng!);
    }
    if (data.hasOfficeLocation) {
      _officeLatLng = LatLng(data.officeLat!, data.officeLng!);
    }

    _initialCamera = CameraPosition(
      target: _driverLatLng,
      zoom: 14.8,
    );

    _markers
      ..clear()
      ..addAll([
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverLatLng,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: data.driverName ?? 'Driver',
            snippet: 'Your driver is on the way',
          ),
        ),
        if (data.hasOfficeLocation)
          Marker(
            markerId: const MarkerId('office'),
            position: _officeLatLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange,
            ),
            infoWindow: const InfoWindow(title: 'Office'),
          ),
      ]);

    _polylines
      ..clear()
      ..add(
        Polyline(
          polylineId: const PolylineId('route'),
          color: const Color(0xFF1A6B4A),
          width: 4,
          points: [_driverLatLng, _officeLatLng],
          patterns: [PatternItem.dash(18), PatternItem.gap(9)],
        ),
      );

    setState(() {});

    if (_mapController.isCompleted) {
      _mapController.future.then((ctrl) {
        ctrl.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(
                _driverLatLng.latitude < _officeLatLng.latitude
                    ? _driverLatLng.latitude
                    : _officeLatLng.latitude,
                _driverLatLng.longitude < _officeLatLng.longitude
                    ? _driverLatLng.longitude
                    : _officeLatLng.longitude,
              ),
              northeast: LatLng(
                _driverLatLng.latitude > _officeLatLng.latitude
                    ? _driverLatLng.latitude
                    : _officeLatLng.latitude,
                _driverLatLng.longitude > _officeLatLng.longitude
                    ? _driverLatLng.longitude
                    : _officeLatLng.longitude,
              ),
            ),
            72,
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CabTrackingBloc, CabTrackingState>(
      listener: (context, state) {
        if (state is CabTrackingLoaded) {
          _applyTrackingToMap(state.data);
        } else if (state is CabTrackingError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      builder: (context, state) {
        final tracking =
            state is CabTrackingLoaded ? state.data : null;
        final isLoading = state is CabTrackingLoading;

        return Scaffold(
          body: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: _initialCamera,
                onMapCreated: (controller) {
                  if (!_mapController.isCompleted) {
                    _mapController.complete(controller);
                  }
                  controller.setMapStyle(_kMapStyle);
                  if (tracking != null) {
                    _applyTrackingToMap(tracking);
                  }
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
                    child: CircularProgressIndicator(
                      color: Color(0xFF1A6B4A),
                    ),
                  ),
                ),
              _TopBar(onBack: () => Navigator.of(context).maybePop()),
              _RecenterFab(
                onTap: () async {
                  final ctrl = await _mapController.future;
                  ctrl.animateCamera(
                    CameraUpdate.newLatLngZoom(_driverLatLng, 15.0),
                  );
                },
              ),
              _buildBottomSheet(tracking: tracking, isLoading: isLoading),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomSheet({
    required CabTrackingData? tracking,
    required bool isLoading,
  }) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.27,
      minChildSize: 0.27,
      maxChildSize: 0.49,
      snap: true,
      snapSizes: const [0.27, 0.49],
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
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 6),
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
                    children: [
                      _OtpCard(
                        pulseAnimation: _pulseAnimation,
                        otp: tracking?.otpDisplay,
                        isLoading: isLoading,
                      ),
                      const SizedBox(height: 10),
                      _DriverCard(
                        driverName: tracking?.driverName,
                        driverImageUrl: tracking?.driverProfileImage,
                        isLoading: isLoading,
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeInOut,
                        child: _isExpanded
                            ? _ExpandedInfo(
                                tracking: tracking,
                                userName: widget.userName,
                                isLoading: isLoading,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

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

class _RecenterFab extends StatelessWidget {
  final VoidCallback onTap;
  const _RecenterFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: MediaQuery.of(context).size.height * 0.26,
      child: _CircleButton(
        onTap: onTap,
        child: const Icon(Icons.my_location_rounded,
            color: Color(0xFF1A6B4A), size: 20),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _CircleButton({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
        child: child,
      ),
    );
  }
}

class _OtpCard extends StatelessWidget {
  final Animation<double> pulseAnimation;
  final String? otp;
  final bool isLoading;

  const _OtpCard({
    required this.pulseAnimation,
    this.otp,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final display = isLoading ? '—' : (otp ?? '—');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7F3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Ride PIN / OTP',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w400,
            ),
          ),
          AnimatedBuilder(
            animation: pulseAnimation,
            builder: (_, child) =>
                Transform.scale(scale: pulseAnimation.value, child: child),
            child: Text(
              display,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A6B4A),
                letterSpacing: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  final String? driverName;
  final String? driverImageUrl;
  final bool isLoading;

  const _DriverCard({
    this.driverName,
    this.driverImageUrl,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = isLoading ? 'Loading…' : (driverName ?? '—');
    final imageUrl = driverImageUrl?.trim();

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
              child: (imageUrl != null && imageUrl.isNotEmpty)
                  ? Image.network(
                      imageUrl,
                      width: 46,
                      height: 46,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.person_outline_rounded,
                        color: Color(0xFF1A6B4A),
                        size: 26,
                      ),
                    )
                  : const Icon(
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
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.phone_rounded, size: 16),
            label: const Text('Call'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A6B4A),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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

class _ExpandedInfo extends StatelessWidget {
  final CabTrackingData? tracking;
  final String? userName;
  final bool isLoading;

  const _ExpandedInfo({
    this.tracking,
    this.userName,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final data = tracking;
    final paxLabel = isLoading
        ? '—'
        : (data != null && data.passengerCount > 0
            ? '${data.passengerCount}'
            : '—');
    final seqLabel = isLoading ? '—' : (tracking?.paxSequenceLabel ?? '—');
    final plate = isLoading
        ? '—'
        : (tracking?.vehicleRegistrationNo?.trim().isNotEmpty == true
            ? tracking!.vehicleRegistrationNo!.trim()
            : '—');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Divider(color: Colors.grey.shade200, height: 1),
        const SizedBox(height: 14),
        Text(
          plate,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 14),
        Divider(color: Colors.grey.shade200, height: 1),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.airline_seat_recline_normal_rounded,
              color: Colors.black87,
              size: 22,
            ),
            const SizedBox(width: 4),
            Text(
              paxLabel,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              width: 1,
              height: 20,
              color: Colors.grey.shade300,
            ),
            Text(
              'Users',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            const Spacer(),
            Text(
              seqLabel,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 12),
            if (tracking != null)
              InkWell(
                splashColor: Colors.transparent,
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => TripProgressBottomSheet(
                      tracking: tracking!,
                      currentUserName: userName,
                    ),
                  );
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF1A6B4A),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF1A6B4A),
                    size: 22,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

const String _kMapStyle = '''
[
  { "elementType": "geometry", "stylers": [{ "color": "#f5f5f0" }] },
  { "elementType": "labels.icon", "stylers": [{ "visibility": "off" }] },
  { "elementType": "labels.text.fill", "stylers": [{ "color": "#616161" }] },
  { "elementType": "labels.text.stroke", "stylers": [{ "color": "#f5f5f5" }] },
  {
    "featureType": "administrative.land_parcel",
    "elementType": "labels.text.fill",
    "stylers": [{ "color": "#bdbdbd" }]
  },
  { "featureType": "poi", "elementType": "geometry", "stylers": [{ "color": "#eeeeee" }] },
  { "featureType": "poi", "elementType": "labels.text.fill", "stylers": [{ "color": "#757575" }] },
  { "featureType": "poi.park", "elementType": "geometry", "stylers": [{ "color": "#d5e8ce" }] },
  { "featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [{ "color": "#9e9e9e" }] },
  { "featureType": "road", "elementType": "geometry", "stylers": [{ "color": "#ffffff" }] },
  { "featureType": "road.arterial", "elementType": "labels.text.fill", "stylers": [{ "color": "#757575" }] },
  { "featureType": "road.highway", "elementType": "geometry", "stylers": [{ "color": "#dadada" }] },
  { "featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [{ "color": "#616161" }] },
  { "featureType": "road.local", "elementType": "labels.text.fill", "stylers": [{ "color": "#9e9e9e" }] },
  { "featureType": "transit.line", "elementType": "geometry", "stylers": [{ "color": "#e5e5e5" }] },
  { "featureType": "transit.station", "elementType": "geometry", "stylers": [{ "color": "#eeeeee" }] },
  { "featureType": "water", "elementType": "geometry", "stylers": [{ "color": "#b8d4e8" }] },
  { "featureType": "water", "elementType": "labels.text.fill", "stylers": [{ "color": "#9e9e9e" }] }
]
''';
