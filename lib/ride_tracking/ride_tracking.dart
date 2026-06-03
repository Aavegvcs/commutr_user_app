import 'dart:async';

import 'package:commutr_main/core/storage/auth_local_storage.dart';
import 'package:commutr_main/features/trip_detail/data/model/cab_tracking/user_cab_tracking_response.dart';
import 'package:commutr_main/ride_tracking/bloc/cab_tracking_bloc.dart';
import 'package:commutr_main/ride_tracking/bloc/cab_tracking_event.dart';
import 'package:commutr_main/ride_tracking/bloc/cab_tracking_state.dart';
import 'package:commutr_main/ride_tracking/service/route_tracking_signalr_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RideTrackingScreen extends StatefulWidget {
  final String? userName;
  final int? tripId;
  final int? empId;

  const RideTrackingScreen({
    super.key,
    this.userName,
    this.tripId,
    this.empId,
  });

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen>
    with TickerProviderStateMixin {
  final Completer<GoogleMapController> _mapController = Completer();

  static const LatLng _fallbackCenter = LatLng(28.5930, 77.0490);

  LatLng _driverLatLng = _fallbackCenter;
  CameraPosition _initialCamera = const CameraPosition(
    target: _fallbackCenter,
    zoom: 14.8,
  );

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  bool _isExpanded = false;
  bool _showPassengerList = false;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  late AnimationController _pulseController;
  Timer? _pollingTimer;

  final RouteTrackingSignalRService _signalR = RouteTrackingSignalRService();
  bool _signalREnabled = false;

  void _onSignalRLocation(RouteLocationPayload payload) {
    if (!mounted) return;
    if (payload.latitude == null || payload.longitude == null) return;
    context.read<CabTrackingBloc>().add(SignalRLocationReceived(
          latitude: payload.latitude!,
          longitude: payload.longitude!,
        ));
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
    _setupFallbackMarkers();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _sheetController.addListener(() {
      final expanded = _sheetController.size > 0.35;
      if (expanded != _isExpanded) setState(() => _isExpanded = expanded);
    });

    _startPolling();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      context.read<CabTrackingBloc>().add(const RefreshCabTracking());
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _pulseController.dispose();
    _sheetController.dispose();
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
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Driver'),
        ),
      );
  }

  void _applyStateToMap(RideTrackingDataState data) {
    final status = data.status;

    if (status != null && status.hasLocation) {
      _driverLatLng = LatLng(status.latestLat!, status.latestLng!);
    }

    _initialCamera = CameraPosition(target: _driverLatLng, zoom: 14.8);

    _markers
      ..clear()
      ..add(
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: status?.driverName ?? data.detail?.driverName ?? 'Driver',
            snippet: status?.trackingMessage ?? 'Your driver is on the way',
          ),
        ),
      );

    // Draw planned polyline.
    _polylines.clear();
    final points = data.plannedPolylinePoints;
    if (points.isNotEmpty) {
      _polylines.add(Polyline(
        polylineId: const PolylineId('planned_route'),
        color: const Color(0xFF1C1B1B),
        width: 4,
        points: points,
      ));
    }

    setState(() {});

    if (_mapController.isCompleted) {
      _mapController.future.then((ctrl) {
        if (points.length >= 2) {
          double minLat = points.first.latitude;
          double maxLat = points.first.latitude;
          double minLng = points.first.longitude;
          double maxLng = points.first.longitude;
          for (final p in points) {
            if (p.latitude < minLat) minLat = p.latitude;
            if (p.latitude > maxLat) maxLat = p.latitude;
            if (p.longitude < minLng) minLng = p.longitude;
            if (p.longitude > maxLng) maxLng = p.longitude;
          }
          ctrl.animateCamera(
            CameraUpdate.newLatLngBounds(
              LatLngBounds(
                southwest: LatLng(minLat, minLng),
                northeast: LatLng(maxLat, maxLng),
              ),
              60,
            ),
          );
        } else if (status != null && status.hasLocation) {
          ctrl.animateCamera(
            CameraUpdate.newLatLngZoom(_driverLatLng, 15.0),
          );
        }
      });
    }
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
        final data = state is RideTrackingDataState ? state : null;
        final isLoading =
            state is CabTrackingLoading || state is CabTrackingInitial;

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
                  if (data != null) _applyStateToMap(data);
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
              _RecenterFab(
                onTap: () async {
                  final ctrl = await _mapController.future;
                  ctrl.animateCamera(
                    CameraUpdate.newLatLngZoom(_driverLatLng, 15.0),
                  );
                },
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
                      // OTP card
                      _OtpCard(
                        otp: data?.detail?.otpDisplay,
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
                        isLoading: isLoading,
                      ),

                      // Expanded section
                      AnimatedSize(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeInOut,
                        child: _isExpanded
                            ? _ExpandedSection(
                                data: data,
                                userName: widget.userName,
                                isLoading: isLoading,
                                showPassengerList: _showPassengerList,
                                onTogglePassengers: () => setState(
                                    () => _showPassengerList =
                                        !_showPassengerList),
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

// ─── Recenter FAB ─────────────────────────────────────────────────────────────

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
  final bool isLoading;

  const _DriverCard({
    this.driverName,
    this.vehicleNo,
    this.driverMobileNo,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = isLoading ? 'Loading…' : (driverName ?? '—');
    final plate = vehicleNo?.trim();

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

// ─── Expanded section ─────────────────────────────────────────────────────────

class _ExpandedSection extends StatelessWidget {
  final RideTrackingDataState? data;
  final String? userName;
  final bool isLoading;
  final bool showPassengerList;
  final VoidCallback onTogglePassengers;

  const _ExpandedSection({
    this.data,
    this.userName,
    this.isLoading = false,
    required this.showPassengerList,
    required this.onTogglePassengers,
  });

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

    final pickedCount = detail?.currentSequenceIndex ?? 0;
    final totalPax = detail?.passengerCount ?? 0;
    final passengers =
        detail?.passengersForDisplay(userName) ?? const <CabPassenger>[];

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
                  Text(
                    mode,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),
        Divider(color: Colors.grey.shade200, height: 1),
        const SizedBox(height: 12),

        // Passengers picked row with toggle
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
                  'Passengers Picked  $pickedCount/$totalPax',
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

        // Passenger list
        if (showPassengerList && passengers.isNotEmpty) ...[
          const SizedBox(height: 12),
          _PassengerList(
            passengers: passengers,
            currentSequenceIndex: detail?.currentSequenceIndex ?? 0,
            userName: userName,
          ),
        ],

        const SizedBox(height: 12),
        Divider(color: Colors.grey.shade200, height: 1),
        const SizedBox(height: 12),

        // Need Cab Update row
        GestureDetector(
          onTap: () {},
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

// ─── Passenger list ───────────────────────────────────────────────────────────

class _PassengerList extends StatelessWidget {
  final List<CabPassenger> passengers;
  final int currentSequenceIndex;
  final String? userName;

  const _PassengerList({
    required this.passengers,
    required this.currentSequenceIndex,
    this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < passengers.length; i++) ...[
          _PassengerRow(
            passenger: passengers[i],
            index: i,
            currentSequenceIndex: currentSequenceIndex,
            isLast: i == passengers.length - 1,
            userName: userName,
          ),
        ],
        // Office destination row
        _OfficeRow(),
      ],
    );
  }
}

class _PassengerRow extends StatelessWidget {
  final CabPassenger passenger;
  final int index;
  final int currentSequenceIndex;
  final bool isLast;
  final String? userName;

  const _PassengerRow({
    required this.passenger,
    required this.index,
    required this.currentSequenceIndex,
    required this.isLast,
    this.userName,
  });

  @override
  Widget build(BuildContext context) {
    final isPicked = index < currentSequenceIndex;
    final isCurrent = index == currentSequenceIndex;
    final name = passenger.empName?.trim() ?? '—';
    final isMe = userName != null &&
        name.toLowerCase() == userName!.trim().toLowerCase();

    final initials = _initials(name);
    final Color avatarBg = isPicked
        ? const Color(0xFF1A6B4A)
        : isCurrent
            ? const Color(0xFF1A6B4A)
            : Colors.grey.shade300;
    final Color avatarFg = isPicked || isCurrent ? Colors.white : Colors.grey;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: avatarBg,
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: avatarFg,
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 24,
                color: const Color(0xFFE0E0E0),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isMe ? '$name (You)' : name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (passenger.pickTime != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      passenger.pickTime!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class _OfficeRow extends StatelessWidget {
  const _OfficeRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF1A6B4A),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.business_rounded,
              color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Office',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              Text(
                'Expected Arrival',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF1A6B4A),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Map style ────────────────────────────────────────────────────────────────

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
