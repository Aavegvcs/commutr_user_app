export 'package:commutr_main/profile/presentation/profile_user_data.dart';

import 'package:commutr_main/core/di/injection.dart';
import 'package:commutr_main/features/auth/presentation/screens/pin_map/location_data.dart';
import 'package:commutr_main/features/auth/presentation/screens/pin_map/pin_map_screen.dart';
import 'package:commutr_main/features/auth/presentation/screens/mobile_no_verification.dart';
import 'package:commutr_main/profile/bloc/profile_bloc.dart';
import 'package:commutr_main/profile/bloc/profile_event.dart';
import 'package:commutr_main/profile/bloc/profile_state.dart';
import 'package:commutr_main/profile/presentation/profile_user_data.dart';
import 'package:commutr_main/profile/presentation/screen/edit_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // If a ProfileBloc is already provided in the tree (e.g. from Welcome),
    // reuse it. Otherwise spin up a fresh one.
    ProfileBloc? existing;
    try {
      existing = context.read<ProfileBloc>();
    } catch (_) {
      existing = null;
    }

    if (existing != null) {
      return const _ProfileView();
    }
    return BlocProvider<ProfileBloc>(
      create: (_) => sl<ProfileBloc>()..add(const FetchUserProfile()),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatefulWidget {
  const _ProfileView();

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  bool _tripReminderEnabled = true;
  bool _savedAddressesExpanded = false;
  String? _nodalPointOverride;
  LocationData? _nodalPointPinnedLocation;

  static const Color _primaryGreen = Color(0xFF1B7A3E);
  static const Color _lightGreen = Color(0xFFE8F5EE);
  static const Color _iconGreen = Color(0xFF2E7D52);
  static const Color _bgColor = Color(0xFFF2F4F3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Icon(
                      Icons.arrow_back,
                      color: _primaryGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Profile',
                    style: TextStyle(
                      color: _primaryGreen,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: BlocBuilder<ProfileBloc, ProfileState>(
                builder: (context, state) {
                  if (state is ProfileLoading || state is ProfileInitial) {
                    return const Center(
                      child: CircularProgressIndicator(color: _primaryGreen),
                    );
                  }

                  if (state is ProfileError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 48, color: Colors.redAccent),
                            const SizedBox(height: 12),
                            Text(state.message,
                                textAlign: TextAlign.center,
                                style:
                                    const TextStyle(color: Color(0xFF555555))),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryGreen),
                              onPressed: () => context
                                  .read<ProfileBloc>()
                                  .add(const FetchUserProfile()),
                              child: const Text('Retry',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (state is ProfileUnauthorized) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              state.message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFF555555)),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryGreen,
                              ),
                              onPressed: () => Navigator.of(
                                context,
                                rootNavigator: true,
                              ).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const MobileNoVerification(),
                                ),
                                (route) => false,
                              ),
                              child: const Text(
                                'Sign in again',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final userData = state is ProfileLoaded
                      ? ProfileUserData.fromApiResponse(state.profile)
                      : kProfileUserDataFallback;
                  final nodalPointTextRaw =
                      _nodalPointOverride ?? userData.nodalPoint;
                  final nodalPointText = nodalPointTextRaw.trim();
                  final showNodalPoint = nodalPointText.isNotEmpty;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // Profile Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _primaryGreen,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              // Avatar
                              Stack(
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      size: 40,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 2,
                                    right: 2,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF4CAF50),
                                        shape: BoxShape.circle,
                                        border: Border.fromBorderSide(
                                          BorderSide(
                                              color: _primaryGreen, width: 2),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              // User Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userData.fullName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      userData.email,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'ID: ${userData.empId}',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.8),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Edit Button
                              InkWell(
                                splashColor: Colors.transparent,
                                onTap: () {
                                  final profileBloc =
                                      context.read<ProfileBloc>();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (routeContext) =>
                                          BlocProvider.value(
                                        value: profileBloc,
                                        child: ProfileEditScreen(
                                          initialData: userData,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Office
                        _buildInfoCard(
                          icon: Icons.domain_outlined,
                          label: 'OFFICE',
                          value: userData.office,
                        ),

                        const SizedBox(height: 10),

                        // Pickup / Drop Point
                        _buildExpandableCard(
                          icon: Icons.location_on_outlined,
                          label: 'PICKUP/ DROP POINT',
                          value: 'Saved Addresses',
                          isExpanded: _savedAddressesExpanded,
                          onTap: () {
                            setState(() {
                              _savedAddressesExpanded =
                                  !_savedAddressesExpanded;
                            });
                          },
                        ),

                        const SizedBox(height: 10),

                        // Nodal Point
                        if (showNodalPoint) ...[
                          _buildInfoCard(
                            icon: Icons.my_location_outlined,
                            label: 'NODAL POINT',
                            value: nodalPointText,
                            useTargetIcon: true,
                            onTap: () => _openNodalPointDialog(nodalPointText),
                          ),
                          const SizedBox(height: 10),
                        ],

                        // Your Settings
                        _buildNavCard(
                          icon: Icons.settings_outlined,
                          label: 'Your settings',
                          onTap: () {},
                        ),

                        const SizedBox(height: 10),

                        // Privacy Policy
                        _buildNavCard(
                          icon: Icons.security_outlined,
                          label: 'Privacy Policy',
                          onTap: () {},
                        ),

                        const SizedBox(height: 20),

                        // PREFERENCES heading
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'PREFERENCES',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Trip Reminder
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _lightGreen,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.notifications_outlined,
                                  color: _iconGreen,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Text(
                                  'Trip Reminder',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                              ),
                              // "5 minutes" pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F0F0),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  '5 minutes',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF333333),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Toggle
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _tripReminderEnabled =
                                        !_tripReminderEnabled;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 52,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: _tripReminderEnabled
                                        ? _primaryGreen
                                        : Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: AnimatedAlign(
                                    duration: const Duration(milliseconds: 200),
                                    alignment: _tripReminderEnabled
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.all(3),
                                      width: 24,
                                      height: 24,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    bool useTargetIcon = false,
    VoidCallback? onTap,
  }) {
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5EE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              useTargetIcon ? Icons.adjust_outlined : icon,
              color: const Color(0xFF2E7D52),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) {
      return card;
    }
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: card,
    );
  }

  Widget _buildDialogLabeledField({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 14, color: Colors.black87),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF5F5F4),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: maxLines > 1 ? 14 : 0,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryGreen, width: 1.5),
        ),
      ),
    );
  }

  void _openNodalPointDialog(String currentNodalPoint) {
    final addrCtrl = TextEditingController(text: currentNodalPoint);
    final cityCtrl = TextEditingController();
    final stateCtrl = TextEditingController();
    final pinCtrl = TextEditingController();

    LocationData? dialogPinnedLocation = _nodalPointPinnedLocation;
    bool isGeocoding = false;
    bool isSaving = false;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            if (dialogPinnedLocation == null &&
                !isGeocoding &&
                addrCtrl.text.trim().isNotEmpty) {
              isGeocoding = true;
              locationFromAddress(addrCtrl.text.trim()).then((locations) {
                if (!ctx.mounted) return;
                if (locations.isEmpty) {
                  setDialogState(() => isGeocoding = false);
                  return;
                }
                final loc = locations.first;
                setDialogState(() {
                  isGeocoding = false;
                  dialogPinnedLocation = LocationData(
                    latitude: loc.latitude,
                    longitude: loc.longitude,
                    city: cityCtrl.text.trim(),
                    state: stateCtrl.text.trim(),
                    pincode: pinCtrl.text.trim(),
                    fullAddress: addrCtrl.text.trim(),
                  );
                });
              }).catchError((_) {
                if (!ctx.mounted) return;
                setDialogState(() => isGeocoding = false);
              });
            }

            return Dialog(
              backgroundColor: _bgColor,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.my_location_outlined,
                                color: _primaryGreen, size: 20),
                            SizedBox(width: 6),
                            Text(
                              'Edit Nodal Point',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _primaryGreen,
                              ),
                            ),
                          ],
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final result =
                                await Navigator.of(ctx).push<LocationData>(
                              MaterialPageRoute(
                                builder: (_) => const PinMapScreen(),
                              ),
                            );
                            if (result == null) return;
                            setDialogState(() {
                              dialogPinnedLocation = result;
                              addrCtrl.text = result.fullAddress;
                              cityCtrl.text = result.city;
                              stateCtrl.text = result.state;
                              pinCtrl.text =
                                  result.pincode == 'N/A' ? '' : result.pincode;
                            });
                          },
                          icon: const Icon(Icons.location_searching,
                              size: 16, color: _primaryGreen),
                          label: const Text(
                            'PIN ON MAP',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: _primaryGreen,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: _primaryGreen),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      splashColor: Colors.transparent,
                      onTap: () async {
                        final result =
                            await Navigator.of(ctx).push<LocationData>(
                          MaterialPageRoute(
                            builder: (_) => const PinMapScreen(),
                          ),
                        );
                        if (result == null) return;
                        setDialogState(() {
                          dialogPinnedLocation = result;
                          addrCtrl.text = result.fullAddress;
                          cityCtrl.text = result.city;
                          stateCtrl.text = result.state;
                          pinCtrl.text =
                              result.pincode == 'N/A' ? '' : result.pincode;
                        });
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: 160,
                          child: isGeocoding
                              ? Container(
                                  color: const Color(0xFFE8F0EE),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: _primaryGreen,
                                      strokeWidth: 2.5,
                                    ),
                                  ),
                                )
                              : dialogPinnedLocation != null
                                  ? IgnorePointer(
                                      child: GoogleMap(
                                        initialCameraPosition: CameraPosition(
                                          target: LatLng(
                                            dialogPinnedLocation!.latitude,
                                            dialogPinnedLocation!.longitude,
                                          ),
                                          zoom: 15,
                                        ),
                                        zoomControlsEnabled: false,
                                        myLocationButtonEnabled: false,
                                        scrollGesturesEnabled: false,
                                        zoomGesturesEnabled: false,
                                        tiltGesturesEnabled: false,
                                        rotateGesturesEnabled: false,
                                        markers: {
                                          Marker(
                                            markerId: const MarkerId(
                                              'nodal_dialog_pinned',
                                            ),
                                            position: LatLng(
                                              dialogPinnedLocation!.latitude,
                                              dialogPinnedLocation!.longitude,
                                            ),
                                          ),
                                        },
                                        onMapCreated: (_) {},
                                      ),
                                    )
                                  : Container(
                                      color: const Color(0xFFE8F0EE),
                                      child: Center(
                                        child: Text(
                                          'Tap "PIN ON MAP" to set nodal point',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ),
                                    ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDialogLabeledField(
                      label: 'NODAL POINT ADDRESS',
                      child: AbsorbPointer(
                        child: _buildDialogTextField(
                          controller: addrCtrl,
                          hintText: 'Pin on map to set nodal point address',
                          maxLines: 3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDialogLabeledField(
                            label: 'CITY',
                            child: AbsorbPointer(
                              child: _buildDialogTextField(
                                controller: cityCtrl,
                                hintText: 'City',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDialogLabeledField(
                            label: 'STATE',
                            child: AbsorbPointer(
                              child: _buildDialogTextField(
                                controller: stateCtrl,
                                hintText: 'State',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDialogLabeledField(
                            label: 'PINCODE',
                            child: AbsorbPointer(
                              child: _buildDialogTextField(
                                controller: pinCtrl,
                                hintText: 'Pincode',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(6),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: _primaryGreen),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                color: _primaryGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () {
                                    final address = addrCtrl.text.trim();
                                    if (address.isEmpty ||
                                        dialogPinnedLocation == null) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: const Text(
                                            'Pin nodal point on map before saving.',
                                          ),
                                          backgroundColor: Colors.redAccent,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    setDialogState(() => isSaving = true);
                                    setState(() {
                                      _nodalPointOverride = address;
                                      _nodalPointPinnedLocation =
                                          dialogPinnedLocation;
                                    });
                                    if (dialogCtx.mounted) {
                                      Navigator.of(dialogCtx).pop();
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                          'Nodal point updated successfully.',
                                        ),
                                        backgroundColor: _primaryGreen,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Save',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildExpandableCard({
    required IconData icon,
    required String label,
    required String value,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5EE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF2E7D52), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              color: Colors.grey.shade600,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5EE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF2E7D52), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey.shade500,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
