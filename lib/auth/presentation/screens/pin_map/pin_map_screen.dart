import 'package:commutr_main/auth/presentation/screens/signup.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

import 'location_data.dart';


class PinMapScreen extends StatefulWidget {
  const PinMapScreen({super.key});

  @override
  State<PinMapScreen> createState() => _PinMapScreenState();
}

class _PinMapScreenState extends State<PinMapScreen>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  LatLng _pinnedLocation = const LatLng(28.6139, 77.2090); // Default: Delhi
  bool _isPinned = false;
  bool _isLoading = false;

  /// Human-readable preview at crosshair (reverse geocode on idle).
  String _placePreview = '';
  bool _isFetchingPlacePreview = false;
  int _placePreviewGeocodeToken = 0;

  // Pin animation
  late AnimationController _pinAnimationController;
  late Animation<double> _pinDropAnimation;

  static const CameraPosition _initialCamera = CameraPosition(
    target: LatLng(28.6139, 77.2090),
    zoom: 14,
  );

  @override
  void initState() {
    super.initState();
    _pinAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pinDropAnimation = CurvedAnimation(
      parent: _pinAnimationController,
      curve: Curves.bounceOut,
    );
  }

  @override
  void dispose() {
    _pinAnimationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  /// Called whenever camera stops moving (like Uber/Ola - pin stays centered)
  void _onCameraIdle() {
    setState(() {
      _isPinned = true;
      _isFetchingPlacePreview = true;
      _placePreview = '';
    });
    _pinAnimationController.forward(from: 0);
    _refreshPinnedPlacePreview();
  }

  static String _formatPlacePreview(Placemark p) {
    final segments = <String>[];
    void add(String? s) {
      if (s == null || s.isEmpty) return;
      if (segments.contains(s)) return;
      segments.add(s);
    }

    add(p.name);
    add(p.street);
    add(p.subThoroughfare);
    add(p.thoroughfare);
    add(p.subLocality);
    add(p.locality);
    add(p.subAdministrativeArea);
    if (segments.isEmpty) {
      add(p.administrativeArea);
      add(p.country);
    }
    return segments.join(', ');
  }

  Future<void> _refreshPinnedPlacePreview() async {
    final lat = _pinnedLocation.latitude;
    final lng = _pinnedLocation.longitude;
    final token = ++_placePreviewGeocodeToken;

    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (!mounted || token != _placePreviewGeocodeToken) return;

      if (placemarks.isEmpty) {
        setState(() {
          _placePreview = 'Could not resolve this spot';
          _isFetchingPlacePreview = false;
        });
        return;
      }

      final label = _formatPlacePreview(placemarks.first);
      setState(() {
        _placePreview =
            label.isEmpty ? 'Could not resolve this spot' : label;
        _isFetchingPlacePreview = false;
      });
    } catch (_) {
      if (!mounted || token != _placePreviewGeocodeToken) return;
      setState(() {
        _placePreview = 'Could not resolve this spot';
        _isFetchingPlacePreview = false;
      });
    }
  }

  void _onCameraMove(CameraPosition position) {
    setState(() {
      _pinnedLocation = position.target;
      _isPinned = false;
      _placePreview = '';
      _isFetchingPlacePreview = false;
    });
    _placePreviewGeocodeToken++;
  }

  Future<void> _confirmLocation() async {
    setState(() => _isLoading = true);

    try {
      // Reverse geocode the pinned lat/lng
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _pinnedLocation.latitude,
        _pinnedLocation.longitude,
      );

      if (placemarks.isEmpty) {
        _showError('Could not fetch location details. Try again.');
        return;
      }

      final Placemark place = placemarks.first;

      final locationData = LocationData(
        latitude: _pinnedLocation.latitude,
        longitude: _pinnedLocation.longitude,
        city: place.locality ??
            place.subAdministrativeArea ??
            place.administrativeArea ??
            'Unknown City',
        state: place.administrativeArea ?? 'Unknown State',
        pincode: place.postalCode ?? 'N/A',
        fullAddress: [
          place.subThoroughfare,
          place.thoroughfare,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.postalCode,
          place.country,
        ].where((e) => e != null && e.isNotEmpty).join(', '),
      );

      if (!mounted) return;

      // ✅ Navigate to details screen using Constructor to pass data
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SignupScreen(locationData: locationData),
        ),
      );
    } catch (e) {
      _showError('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Google Map ──────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: _initialCamera,
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) => _mapController = controller,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
          ),

          // ── Center Pin (Uber/Ola style) ─────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _pinDropAnimation,
                  builder: (_, child) {
                    return Transform.translate(
                      offset: Offset(0, -10 * (1 - _pinDropAnimation.value)),
                      child: child,
                    );
                  },
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A73E8),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1A73E8).withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(10),
                        child: const Icon(
                          Icons.location_pin,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      // Pin shadow/dot on the map
                      Container(
                        width: 10,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Top Header ─────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  // Search bar decoration (non-functional, UI only)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.search,
                            color: Color(0xFF1A73E8), size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Move map to pin a location',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom Panel ───────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.location_on,
                          color: const Color(0xFF1A73E8),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _isPinned && _isFetchingPlacePreview
                            ? Row(
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Fetching place…',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                _isPinned
                                    ? (_placePreview.isEmpty
                                        ? 'Move slightly to load place'
                                        : _placePreview)
                                    : 'Move the map to select a location',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _isPinned
                                      ? Colors.black87
                                      : Colors.grey.shade500,
                                  fontWeight: _isPinned
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Confirm Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isPinned && !_isLoading
                          ? _confirmLocation
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A73E8),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                          : const Text(
                        'Confirm Location',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── My Location FAB ────────────────────────────────────
          Positioned(
            right: 16,
            bottom: 170,
            child: FloatingActionButton.small(
              onPressed: () async {
                // Center map on current position (requires location permission)
                _mapController?.animateCamera(
                  CameraUpdate.newLatLng(_pinnedLocation),
                );
              },
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1A73E8),
              elevation: 4,
              child: const Icon(Icons.my_location, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}