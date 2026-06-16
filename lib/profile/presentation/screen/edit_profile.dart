import 'dart:convert';

import 'package:commutr_main/features/auth/presentation/screens/pin_map/location_data.dart';
import 'package:commutr_main/features/auth/presentation/screens/pin_map/pin_map_screen.dart';
import 'package:commutr_main/features/auth/presentation/screens/mobile_no_verification.dart';
import 'package:commutr_main/core/network/api_client.dart';
import 'package:commutr_main/core/network/api_constants.dart';
import 'package:commutr_main/core/utils/error_message.dart';
import 'package:commutr_main/core/di/injection.dart';
import 'package:commutr_main/core/storage/auth_local_storage.dart';
import 'package:commutr_main/profile/bloc/profile_bloc.dart';
import 'package:commutr_main/profile/bloc/profile_event.dart';
import 'package:commutr_main/profile/bloc/profile_state.dart';
import 'package:commutr_main/profile/data/repository/profile_repository.dart';
import 'package:commutr_main/profile/presentation/profile_user_data.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({
    super.key,
    required this.initialData,
  });

  final ProfileUserData initialData;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _pincodeController;

  late String _selectedGender;
  final List<String> _genders = ['Male', 'Female', 'Other'];

  LocationData? _pinnedLocation;
  GoogleMapController? _mapPreviewController;
  bool _isSavingProfile = false;

  // Mobile OTP state
  final TextEditingController _otpController = TextEditingController();
  bool _showOtpField = false;
  bool _sendingOtp = false;
  bool _verifyingOtp = false;
  bool _mobileOtpVerified = false;
  String? _otpSentForMobile;
  String? _verifiedMobile;

  static const String _otpSendUrl =
      '${ApiConstants.appBaseUrl}/Otp/send';
  static const String _otpVerifyUrl =
      '${ApiConstants.appBaseUrl}/Otp/verify';

  late final Dio _otpDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  @override
  void initState() {
    super.initState();
    _applyFromData(widget.initialData);
    final names = widget.initialData.firstAndLastName;
    _firstNameController = TextEditingController(text: names.$1);
    _lastNameController = TextEditingController(text: names.$2);
    _mobileController = TextEditingController(
      text: widget.initialData.formattedPhone,
    );
    _emailController = TextEditingController(text: widget.initialData.email);
    _addressController =
        TextEditingController(text: widget.initialData.address);
    _cityController = TextEditingController(text: widget.initialData.city);
    _stateController = TextEditingController(text: widget.initialData.state);
    _pincodeController =
        TextEditingController(text: widget.initialData.pincode);
  }

  void _applyFromData(ProfileUserData data) {
    _selectedGender =
        _genders.contains(data.gender) ? data.gender : _genders.first;
  }

  void _resetFormToInitial() {
    final d = widget.initialData;
    final names = d.firstAndLastName;
    _firstNameController.text = names.$1;
    _lastNameController.text = names.$2;
    _mobileController.text = d.formattedPhone;
    _emailController.text = d.email;
    _addressController.text = d.address;
    _cityController.text = d.city;
    _stateController.text = d.state;
    _pincodeController.text = d.pincode;
    setState(() => _applyFromData(d));
  }

  static const Color _primaryGreen = Color(0xFF1A6B4A);
  static const Color _fieldBg = Color(0xFFF5F5F4);
  static const Color _bgColor = Colors.white;

  void _goToSignIn() {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MobileNoVerification()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _otpController.dispose();
    _otpDio.close();
    super.dispose();
  }

  // ── OTP helpers (mirrors signup.dart pattern) ────────────────────────────

  static final RegExp _mobileRegex = RegExp(r'^[6-9]\d{9}$');

  dynamic _otpResponseAsJson(dynamic raw) {
    if (raw is String) {
      final t = raw.trim();
      if (t.isEmpty) return raw;
      try {
        return jsonDecode(t);
      } catch (_) {
        return raw;
      }
    }
    return raw;
  }

  bool _otpApiTruthy(dynamic data, [int depth = 0]) {
    if (depth > 5) return false;
    data = _otpResponseAsJson(data);
    if (data == true || data == 'true') return true;
    if (data is String) {
      final lower = data.trim().toLowerCase();
      if (lower == 'true' || lower == 'success') return true;
    }
    if (data is List && data.isNotEmpty) return _otpApiTruthy(data.first, depth + 1);
    if (data is Map) {
      final m = Map<dynamic, dynamic>.from(data);
      if (m['isSuccess'] == true || m['success'] == true || m['succeeded'] == true) return true;
      final status = m['status'];
      if (status == 1 || status == '1') return true;
      final result = m['result'];
      if (result == true) return true;
      if (result != null && _otpApiTruthy(result, depth + 1)) return true;
      final inner = m['data'];
      if (inner != null && _otpApiTruthy(inner, depth + 1)) return true;
    }
    return false;
  }

  String _otpErrorMessage(DioException e) {
    var data = _otpResponseAsJson(e.response?.data);
    if (data is Map) {
      final m = Map<dynamic, dynamic>.from(data);
      final errors = m['errors'];
      if (errors is Map) {
        for (final v in errors.values) {
          if (v is List && v.isNotEmpty) return v.first.toString();
          if (v is String && v.trim().isNotEmpty) return v.trim();
        }
      }
      for (final key in ['detail', 'title', 'message', 'error', 'errorMessage']) {
        final v = m[key];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
    }
    if (data is String && data.trim().isNotEmpty) return data.trim();
    return ErrorMessage.from(e, fallback: 'Could not send OTP. Please try again.');
  }

  Future<void> _sendMobileOtp({required bool fromResend}) async {
    final mobile = _mobileController.text.trim();
    if (mobile.isEmpty || !_mobileRegex.hasMatch(mobile)) {
      _showOtpSnackBar('Enter a valid 10-digit mobile number');
      return;
    }
    if (!mounted) return;
    setState(() => _sendingOtp = true);
    try {
      final token = sl<AuthLocalStorage>().getAccessToken();
      final response = await _otpDio.post<dynamic>(
        _otpSendUrl,
        data: {'mobileNo': mobile, 'requestType': 'S'},
        options: Options(headers: {
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        }),
      );
      if (!mounted) return;
      final ok = _otpApiTruthy(_otpResponseAsJson(response.data));
      if (ok) {
        setState(() {
          _showOtpField = true;
          _otpSentForMobile = mobile;
          _mobileOtpVerified = false;
          _verifiedMobile = null;
        });
      } else {
        _showOtpSnackBar('Could not send OTP. Please try again.');
        if (!fromResend) {
          setState(() {
            _showOtpField = false;
            _otpSentForMobile = null;
            _otpController.clear();
          });
        }
      }
    } on DioException catch (e) {
      if (!mounted) return;
      _showOtpSnackBar(_otpErrorMessage(e));
      if (!fromResend) {
        setState(() {
          _showOtpField = false;
          _otpSentForMobile = null;
          _otpController.clear();
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showOtpSnackBar(ErrorMessage.from(e, fallback: 'Could not send OTP'));
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  Future<void> _verifyMobileOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 4) {
      _showOtpSnackBar('Please enter a valid 4-digit OTP');
      return;
    }
    final mobile = _mobileController.text.trim();
    if (!mounted) return;
    setState(() => _verifyingOtp = true);
    try {
      final token = sl<AuthLocalStorage>().getAccessToken();
      final response = await _otpDio.post<dynamic>(
        _otpVerifyUrl,
        data: {'mobileNo': mobile, 'otp': otp, 'requestType': 'S'},
        options: Options(headers: {
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        }),
      );
      if (!mounted) return;
      final ok = _otpApiTruthy(_otpResponseAsJson(response.data));
      if (ok) {
        setState(() {
          _mobileOtpVerified = true;
          _verifiedMobile = mobile;
          _showOtpField = false;
          _otpController.clear();
        });
      } else {
        _showOtpSnackBar('Invalid OTP. Please try again.');
      }
    } on DioException catch (e) {
      if (!mounted) return;
      _showOtpSnackBar(_otpErrorMessage(e));
    } catch (e) {
      if (!mounted) return;
      _showOtpSnackBar(ErrorMessage.from(e, fallback: 'Could not verify OTP'));
    } finally {
      if (mounted) setState(() => _verifyingOtp = false);
    }
  }

  void _showOtpSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _primaryGreen),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Profile Edit',
          style: TextStyle(
            color: _primaryGreen,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Photo
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFFCFE3D4),
                      child: Text(
                        () {
                          final first = _firstNameController.text.trim();
                          final last = _lastNameController.text.trim();
                          final f = first.isNotEmpty ? first[0].toUpperCase() : '';
                          final l = last.isNotEmpty ? last[0].toUpperCase() : '';
                          return '$f$l'.isNotEmpty ? '$f$l' : '?';
                        }(),
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: _primaryGreen,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Personal Details Section
              _buildSectionHeader('Personal Details'),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildLabeledField(
                      label: 'FIRST NAME',
                      child: _buildTextField(
                        controller: _firstNameController,
                        hintText: 'First Name',
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                        ],
                        validator: (val) {
                          if (val == null || val.trim().isEmpty)
                            return 'Required';
                          if (val.trim().length < 2) return 'Min 2 chars';
                          return null;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildLabeledField(
                      label: 'LAST NAME',
                      child: _buildTextField(
                        controller: _lastNameController,
                        hintText: 'Last Name',
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                        ],
                        validator: (val) {
                          if (val == null || val.trim().isEmpty)
                            return 'Required';
                          if (val.trim().length < 2) return 'Min 2 chars';
                          return null;
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Gender
              _buildLabeledField(
                label: 'GENDER',
                child: Row(
                  children: _genders.map((gender) {
                    final isSelected = _selectedGender == gender;
                    IconData icon;
                    switch (gender) {
                      case 'Male':
                        icon = Icons.male;
                        break;
                      case 'Female':
                        icon = Icons.female;
                        break;
                      default:
                        icon = Icons.do_not_disturb_on_outlined;
                    }
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: gender != 'Other' ? 8 : 0,
                        ),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedGender = gender),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? _primaryGreen : Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: isSelected
                                    ? _primaryGreen
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  icon,
                                  size: 16,
                                  color:
                                      isSelected ? Colors.white : Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  gender,
                                  style: TextStyle(
                                    color:
                                        isSelected ? Colors.white : Colors.grey,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 28),

              // Contact Section
              _buildSectionHeader('Contact'),
              const SizedBox(height: 16),

              _buildLabeledField(
                label: 'MOBILE NO.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mobile number field with Resend button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _mobileController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                            decoration: InputDecoration(
                              hintText: '9XXXXXXXXX',
                              hintStyle: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 14),
                              filled: true,
                              fillColor: const Color(0xFFF5F5F5),
                              prefixIcon: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 13),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE8E8E8),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    bottomLeft: Radius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  '+91',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              prefixIconConstraints:
                                  const BoxConstraints(minWidth: 0, minHeight: 0),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 0),
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
                                borderSide: const BorderSide(
                                    color: Color(0xFF2E7D32), width: 1.5),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Colors.redAccent, width: 1),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Colors.redAccent, width: 1.5),
                              ),
                              errorStyle: const TextStyle(fontSize: 11),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Mobile number required';
                              }
                              if (val.trim().length != 10 ||
                                  !_mobileRegex.hasMatch(val.trim())) {
                                return 'Enter valid 10-digit mobile number';
                              }
                              return null;
                            },
                            onChanged: (val) {
                              if (_mobileOtpVerified &&
                                  _verifiedMobile != null &&
                                  val != _verifiedMobile) {
                                setState(() {
                                  _mobileOtpVerified = false;
                                  _verifiedMobile = null;
                                  _showOtpField = false;
                                  _otpSentForMobile = null;
                                  _otpController.clear();
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: TextButton(
                            onPressed: (_sendingOtp || _verifyingOtp)
                                ? null
                                : () => _sendMobileOtp(fromResend: _showOtpField),
                            style: TextButton.styleFrom(
                              foregroundColor: _primaryGreen,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: _sendingOtp
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _primaryGreen),
                                  )
                                : Text(
                                    _showOtpField ? 'Resend' : 'Send OTP',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    // Verified banner
                    if (_mobileOtpVerified) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEBF5F0),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _primaryGreen.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: _primaryGreen, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              () {
                                final digits = _verifiedMobile!.replaceAll(RegExp(r'\D'), '');
                                final ten = digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
                                return '+91 ${ten.substring(0, 5)}${ten.substring(5)} verified';
                              }(),
                              style: const TextStyle(
                                color: _primaryGreen,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // OTP field + Submit button
                    if (_showOtpField) ...[
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _otpController,
                              hintText: 'Enter 4-digit OTP',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: ElevatedButton(
                              onPressed: (_verifyingOtp || _sendingOtp)
                                  ? null
                                  : _verifyMobileOtp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryGreen,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _verifyingOtp
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : const Text(
                                      'Submit',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _buildLabeledField(
                label: 'EMAIL ID',
                child: _buildTextField(
                  controller: _emailController,
                  hintText: 'email@example.com',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(Icons.mail_outline,
                      size: 18, color: Colors.grey),
                  readOnly: true,
                ),
              ),
              const SizedBox(height: 28),

              // Location Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          color: _primaryGreen, size: 20),
                      const SizedBox(width: 6),
                      const Text(
                        'Location Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _primaryGreen,
                        ),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: _openLocationDialog,
                    icon: const Icon(Icons.edit_location_alt_outlined,
                        size: 16, color: _primaryGreen),
                    label: const Text(
                      'EDIT LOCATION',
                      style: TextStyle(
                        fontSize: 12,
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
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // // Map preview (tappable to open dialog)
              // GestureDetector(
              //   onTap: _openLocationDialog,
              //   child: ClipRRect(
              //     borderRadius: BorderRadius.circular(16),
              //     child: SizedBox(
              //       height: 160,
              //       child: _pinnedLocation != null
              //           ? Stack(
              //               children: [
              //                 GoogleMap(
              //                   initialCameraPosition: CameraPosition(
              //                     target: LatLng(
              //                       _pinnedLocation!.latitude,
              //                       _pinnedLocation!.longitude,
              //                     ),
              //                     zoom: 15,
              //                   ),
              //                   zoomControlsEnabled: false,
              //                   myLocationButtonEnabled: false,
              //                   scrollGesturesEnabled: false,
              //                   zoomGesturesEnabled: false,
              //                   tiltGesturesEnabled: false,
              //                   rotateGesturesEnabled: false,
              //                   markers: {
              //                     Marker(
              //                       markerId: const MarkerId('pinned'),
              //                       position: LatLng(
              //                         _pinnedLocation!.latitude,
              //                         _pinnedLocation!.longitude,
              //                       ),
              //                     ),
              //                   },
              //                   onMapCreated: (c) => _mapPreviewController = c,
              //                 ),
              //                 // Transparent overlay to capture taps
              //                 Positioned.fill(
              //                   child: Container(color: Colors.transparent),
              //                 ),
              //               ],
              //             )
              //           : Container(
              //               color: const Color(0xFFE8F0EE),
              //               child: Center(
              //                 child: Column(
              //                   mainAxisSize: MainAxisSize.min,
              //                   children: [
              //                     Icon(Icons.map_outlined,
              //                         size: 40, color: _primaryGreen.withValues(alpha: 0.5)),
              //                     const SizedBox(height: 8),
              //                     Text(
              //                       'Tap to set location',
              //                       style: TextStyle(
              //                         fontSize: 13,
              //                         color: Colors.grey.shade500,
              //                       ),
              //                     ),
              //                   ],
              //                 ),
              //               ),
              //             ),
              //     ),
              //   ),
              // ),
              // const SizedBox(height: 16),

              // Address summary (read-only, tap to edit via dialog)
              GestureDetector(
                onTap: _openLocationDialog,
                child: _buildLabeledField(
                  label: 'CURRENT ADDRESS',
                  child: AbsorbPointer(
                    child: _buildTextField(
                      controller: _addressController,
                      hintText: 'Tap to set address',
                      maxLines: 3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _openLocationDialog,
                      child: _buildLabeledField(
                        label: 'CITY',
                        child: AbsorbPointer(
                          child: _buildTextField(
                            controller: _cityController,
                            hintText: 'City',
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: _openLocationDialog,
                      child: _buildLabeledField(
                        label: 'STATE',
                        child: AbsorbPointer(
                          child: _buildTextField(
                            controller: _stateController,
                            hintText: 'State',
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: _openLocationDialog,
                      child: _buildLabeledField(
                        label: 'PINCODE',
                        child: AbsorbPointer(
                          child: _buildTextField(
                            controller: _pincodeController,
                            hintText: 'Pincode',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSavingProfile ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: _isSavingProfile
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Discard Button
              Center(
                child: TextButton(
                  onPressed: _handleDiscard,
                  child: const Text(
                    'Discard',
                    style: TextStyle(
                      color: _primaryGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _primaryGreen,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Divider(color: Color(0xFFCCDDD2), thickness: 1)),
      ],
    );
  }

  Widget _buildLabeledField({required String label, required Widget child}) {
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    Widget? prefixIcon,
    Widget? suffixIcon,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      readOnly: readOnly,
      style: TextStyle(fontSize: 14, color: readOnly ? Colors.black45 : Colors.black87),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        filled: true,
        fillColor: readOnly ? const Color(0xFFEAEAE9) : const Color(0xFFF5F5F5),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        contentPadding: EdgeInsets.symmetric(
          horizontal: prefixIcon != null ? 4 : 14,
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
          borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        errorStyle: const TextStyle(fontSize: 11),
      ),
    );
  }


  void _openLocationDialog() {
    // Local controllers seeded from the current state so the dialog is
    // independently editable and only commits on "Save".
    final addrCtrl = TextEditingController(text: _addressController.text);
    final cityCtrl = TextEditingController(text: _cityController.text);
    final stateCtrl = TextEditingController(text: _stateController.text);
    final pinCtrl = TextEditingController(text: _pincodeController.text);

    // Start with already-pinned location (from a previous map pick).
    // If none exists, we'll geocode the address text to get a fallback location.
    LocationData? dialogPinnedLocation = _pinnedLocation;
    bool isGeocoding = false;
    bool isSaving = false;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            // ── Geocode address on first open when no pin exists ─────
            if (dialogPinnedLocation == null && !isGeocoding) {
              final query = [
                addrCtrl.text.trim(),
                cityCtrl.text.trim(),
                stateCtrl.text.trim(),
                pinCtrl.text.trim(),
              ].where((s) => s.isNotEmpty).join(', ');

              if (query.isNotEmpty) {
                isGeocoding = true;
                locationFromAddress(query).then((locations) {
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
            }

            return Dialog(
              backgroundColor: _bgColor,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                color: _primaryGreen, size: 20),
                            const SizedBox(width: 6),
                            const Text(
                              'Location Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _primaryGreen,
                              ),
                            ),
                          ],
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            // Push PinMapScreen ON TOP of the dialog so we
                            // return here when the user confirms a location.
                            final result =
                                await Navigator.of(ctx).push<LocationData>(
                              MaterialPageRoute(
                                  builder: (_) => const PinMapScreen()),
                            );
                            if (result == null) return;
                            // Update dialog map + fields
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
                              fontSize: 12,
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
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Map preview ─────────────────────────────────
                    InkWell(
                      splashColor: Colors.transparent,
                      onTap: () async{
                        // return here when the user confirms a location.
                        final result =
                            await Navigator.of(ctx).push<LocationData>(
                          MaterialPageRoute(
                              builder: (_) => const PinMapScreen()),
                        );
                        if (result == null) return;
                        // Update dialog map + fields
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
                              // Loading state while geocoding the address
                              ? Container(
                                  color: const Color(0xFFE8F0EE),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(
                                          color: _primaryGreen,
                                          strokeWidth: 2.5,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'Locating address…',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
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
                                                'dialog_pinned'),
                                            position: LatLng(
                                              dialogPinnedLocation!.latitude,
                                              dialogPinnedLocation!.longitude,
                                            ),
                                          ),
                                        },
                                        onMapCreated: (_) {},
                                      ),
                                    )
                                  // No address to geocode — prompt user
                                  : Container(
                                      color: const Color(0xFFE8F0EE),
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.map_outlined,
                                                size: 40,
                                                color: _primaryGreen.withValues(
                                                    alpha: 0.5)),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Tap "PIN ON MAP" to set location',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Address ─────────────────────────────────────
                    _buildLabeledField(
                      label: 'CURRENT ADDRESS',
                      child: AbsorbPointer(
                        child: _buildTextField(
                          controller: addrCtrl,
                          hintText: 'Pin on map to set address',
                          maxLines: 3,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty)
                              return 'Address required';
                            if (val.trim().length < 5)
                              return 'Enter a valid address';
                            return null;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── City / State / Pincode ───────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _buildLabeledField(
                            label: 'CITY',
                            child: AbsorbPointer(
                              child: _buildTextField(
                                controller: cityCtrl,
                                hintText: 'City',
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty)
                                    return 'Required';
                                  return null;
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildLabeledField(
                            label: 'STATE',
                            child: AbsorbPointer(
                              child: _buildTextField(
                                controller: stateCtrl,
                                hintText: 'State',
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty)
                                    return 'Required';
                                  return null;
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildLabeledField(
                            label: 'PINCODE',
                            child: AbsorbPointer(
                              child: _buildTextField(
                                controller: pinCtrl,
                                hintText: 'Pincode',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(6),
                                ],
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty)
                                    return 'Required';
                                  if (val.length != 6) return '6 digits';
                                  return null;
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Action buttons ───────────────────────────────
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
                                : () => _saveLocationDialog(
                                      dialogContext: ctx,
                                      setDialogState: setDialogState,
                                      onSavingChanged: (saving) {
                                        setDialogState(() => isSaving = saving);
                                      },
                                      addrCtrl: addrCtrl,
                                      cityCtrl: cityCtrl,
                                      stateCtrl: stateCtrl,
                                      pinCtrl: pinCtrl,
                                      dialogPinnedLocation: dialogPinnedLocation,
                                    ),
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

  Future<void> _saveLocationDialog({
    required BuildContext dialogContext,
    required void Function(void Function()) setDialogState,
    required void Function(bool saving) onSavingChanged,
    required TextEditingController addrCtrl,
    required TextEditingController cityCtrl,
    required TextEditingController stateCtrl,
    required TextEditingController pinCtrl,
    required LocationData? dialogPinnedLocation,
  }) async {
    final address = addrCtrl.text.trim();
    final city = cityCtrl.text.trim();
    final state = stateCtrl.text.trim();
    final pin = pinCtrl.text.trim();

    if (address.isEmpty ||
        city.isEmpty ||
        state.isEmpty ||
        pin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please complete address, city, state and pincode.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (dialogPinnedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pin your location on the map before saving.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    ProfileBloc bloc;
    try {
      bloc = context.read<ProfileBloc>();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile data is not available. Open from Profile.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final blocState = bloc.state;
    if (blocState is! ProfileLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile is still loading. Please wait.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    onSavingChanged(true);

    bloc.add(
      SubmitAddressChange(
        address: address,
        city: city,
        state: state,
        pin: pin,
        empLat: dialogPinnedLocation.latitude,
        empLng: dialogPinnedLocation.longitude,
      ),
    );

    try {
      final result = await bloc.stream.firstWhere(
        (s) =>
            s is ProfileAddressChangeSuccess ||
            s is ProfileAddressChangeFailed ||
            s is ProfileUnauthorized,
      );

      if (!mounted) return;

      if (result is ProfileAddressChangeSuccess) {
        setState(() {
          _addressController.text = address;
          _cityController.text = city;
          _stateController.text = state;
          _pincodeController.text = pin;
          _pinnedLocation = dialogPinnedLocation;
          _mapPreviewController?.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(
                dialogPinnedLocation.latitude,
                dialogPinnedLocation.longitude,
              ),
              15,
            ),
          );
        });
        if (dialogContext.mounted) {
          Navigator.of(dialogContext).pop();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: _primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else if (result is ProfileUnauthorized) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        _goToSignIn();
      } else if (result is ProfileAddressChangeFailed) {
        await _showAddressChangeErrorDialog(
          'Address change request already sent',
        );
      }
    } finally {
      if (mounted) {
        onSavingChanged(false);
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fix the errors before saving.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    ProfileBloc bloc;
    try {
      bloc = context.read<ProfileBloc>();
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile data is not available.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final current = bloc.state;
    if (current is! ProfileLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile is still loading. Please wait.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSavingProfile = true);
    try {
      await sl<ProfileRepository>().updateUserProfile(
        profile: current.profile,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        genderCode: _genderCode(_selectedGender),
        address: _addressController.text,
        city: _cityController.text,
        state: _stateController.text,
        pin: _pincodeController.text,
        emailId: _emailController.text,
        mobileNo: _mobileController.text.trim(),
        depCode: current.profile.depCode,
        proCode: current.profile.proCode,
        lobCode: current.profile.lobCode,
        empLat: _pinnedLocation?.latitude,
        empLng: _pinnedLocation?.longitude,
      );

      if (!mounted) return;
      await _showSaveSuccessDialog();
      if (!mounted) return;
      context.read<ProfileBloc>().add(const FetchUserProfile());
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      if (ApiClient.refreshFailedFor(e)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Session expired. Please sign in again.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        _goToSignIn();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorMessage.from(e,
              fallback: 'Could not save profile. Please try again.')),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  String _genderCode(String value) {
    switch (value) {
      case 'Male':
        return 'M';
      case 'Female':
        return 'F';
      default:
        return 'O';
    }
  }

  void _handleDiscard() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Discard Changes?'),
        content: const Text('All unsaved changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetFormToInitial();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _primaryGreen),
            child: const Text('Discard', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showSaveSuccessDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F4),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: _primaryGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 48),
                ),
                const SizedBox(height: 26),
                const Text(
                  'Profile saved successfully!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B1F22),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
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

  Future<void> _showAddressChangeErrorDialog(String message) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F4),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFFB71C1C),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 48),
                ),
                const SizedBox(height: 26),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B1F22),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB71C1C),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: const Text(
                      'Go Back',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
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
}

/// Opens the address-change dialog standalone (no full edit-profile screen).
/// Reads initial field values from the [ProfileBloc] in scope and submits via
/// [SubmitAddressChange] / waits for [ProfileAddressChangeSuccess] or
/// [ProfileAddressChangeFailed].
void showAddressChangeDialog(BuildContext context) {
  ProfileBloc? bloc;
  try {
    bloc = context.read<ProfileBloc>();
  } catch (_) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Profile not available. Please try again.'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    return;
  }

  final state = bloc.state;
  String initAddr = '';
  String initCity = '';
  String initState = '';
  String initPin = '';
  if (state is ProfileLoaded) {
    final d = ProfileUserData.fromApiResponse(state.profile);
    initAddr = d.address;
    initCity = d.city;
    initState = d.state;
    initPin = d.pincode;
  }

  final addrCtrl = TextEditingController(text: initAddr);
  final cityCtrl = TextEditingController(text: initCity);
  final stateCtrl = TextEditingController(text: initState);
  final pinCtrl = TextEditingController(text: initPin);

  LocationData? dialogPinnedLocation;
  bool isGeocoding = false;
  bool isSaving = false;

  const Color primaryGreen = Color(0xFF1A6B4A);
  const Color bgColor = Colors.white;

  Widget buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      validator: validator,
      readOnly: readOnly,
      style: TextStyle(
          fontSize: 14, color: readOnly ? Colors.black45 : Colors.black87),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        filled: true,
        fillColor:
            readOnly ? const Color(0xFFEAEAE9) : const Color(0xFFF5F5F5),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 14, vertical: maxLines > 1 ? 14 : 0),
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
          borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        errorStyle: const TextStyle(fontSize: 11),
      ),
    );
  }

  Widget buildLabeledField({required String label, required Widget child}) {
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

  Future<void> saveLocation({
    required BuildContext dialogContext,
    required void Function(void Function()) setDialogState,
    required void Function(bool) onSavingChanged,
    required LocationData? pinnedLocation,
  }) async {
    final address = addrCtrl.text.trim();
    final city = cityCtrl.text.trim();
    final state2 = stateCtrl.text.trim();
    final pin = pinCtrl.text.trim();

    if (address.isEmpty || city.isEmpty || state2.isEmpty || pin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              const Text('Please complete address, city, state and pincode.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    if (pinnedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pin your location on the map before saving.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final currentBloc = bloc;
    if (currentBloc == null) return;
    final blocState = currentBloc.state;
    if (blocState is! ProfileLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile is still loading. Please wait.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    onSavingChanged(true);
    currentBloc.add(
      SubmitAddressChange(
        address: address,
        city: city,
        state: state2,
        pin: pin,
        empLat: pinnedLocation.latitude,
        empLng: pinnedLocation.longitude,
      ),
    );

    try {
      final result = await currentBloc.stream.firstWhere(
        (s) =>
            s is ProfileAddressChangeSuccess ||
            s is ProfileAddressChangeFailed ||
            s is ProfileUnauthorized,
      );

      if (result is ProfileAddressChangeSuccess) {
        // Capture a stable navigator from the still-mounted dialog context
        // BEFORE popping it, so the success popup can be shown even if the
        // original caller context is no longer mounted.
        final rootNavigator = dialogContext.mounted
            ? Navigator.of(dialogContext, rootNavigator: true)
            : null;
        if (dialogContext.mounted) Navigator.of(dialogContext).pop();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: primaryGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        if (rootNavigator != null) {
          await showDialog<void>(
            context: rootNavigator.context,
            useRootNavigator: true,
            barrierDismissible: false,
            builder: (ctx) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F4),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: primaryGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 48),
                    ),
                    const SizedBox(height: 26),
                    const Text(
                      'Address updated successfully!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B1F22),
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        child: const Text(
                          'OK',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      } else if (result is ProfileUnauthorized) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else if (result is ProfileAddressChangeFailed) {
        if (dialogContext.mounted) {
          showDialog<void>(
            context: dialogContext,
            barrierDismissible: true,
            builder: (ctx) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F4),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: Color(0xFFB71C1C),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 48),
                    ),
                    const SizedBox(height: 26),
                    const Text(
                      'Address change request already sent',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B1F22),
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB71C1C),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        child: const Text(
                          'Go Back',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      }
    } finally {
      onSavingChanged(false);
    }
  }

  showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Geocode address on first open when no pin exists
          if (dialogPinnedLocation == null && !isGeocoding) {
            final query = [
              addrCtrl.text.trim(),
              cityCtrl.text.trim(),
              stateCtrl.text.trim(),
              pinCtrl.text.trim(),
            ].where((s) => s.isNotEmpty).join(', ');

            if (query.isNotEmpty) {
              isGeocoding = true;
              locationFromAddress(query).then((locations) {
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
          }

          return Dialog(
            backgroundColor: bgColor,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.location_on,
                              color: primaryGreen, size: 20),
                          SizedBox(width: 6),
                          Text(
                            'Location Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryGreen,
                            ),
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final result =
                              await Navigator.of(ctx).push<LocationData>(
                            MaterialPageRoute(
                                builder: (_) => const PinMapScreen()),
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
                            size: 16, color: primaryGreen),
                        label: const Text(
                          'PIN ON MAP',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: primaryGreen,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: primaryGreen),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Map preview
                  InkWell(
                    splashColor: Colors.transparent,
                    onTap: () async {
                      final result =
                          await Navigator.of(ctx).push<LocationData>(
                        MaterialPageRoute(
                            builder: (_) => const PinMapScreen()),
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
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircularProgressIndicator(
                                        color: primaryGreen,
                                        strokeWidth: 2.5,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Locating address…',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
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
                                          markerId:
                                              const MarkerId('dialog_pinned'),
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
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.map_outlined,
                                              size: 40,
                                              color: primaryGreen.withValues(
                                                  alpha: 0.5)),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Tap "PIN ON MAP" to set location',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Address
                  buildLabeledField(
                    label: 'CURRENT ADDRESS',
                    child: AbsorbPointer(
                      child: buildTextField(
                        controller: addrCtrl,
                        hintText: 'Pin on map to set address',
                        maxLines: 3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // City / State / Pincode
                  Row(
                    children: [
                      Expanded(
                        child: buildLabeledField(
                          label: 'CITY',
                          child: AbsorbPointer(
                            child: buildTextField(
                              controller: cityCtrl,
                              hintText: 'City',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: buildLabeledField(
                          label: 'STATE',
                          child: AbsorbPointer(
                            child: buildTextField(
                              controller: stateCtrl,
                              hintText: 'State',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: buildLabeledField(
                          label: 'PINCODE',
                          child: AbsorbPointer(
                            child: buildTextField(
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

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: primaryGreen),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: primaryGreen,
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
                              : () => saveLocation(
                                    dialogContext: ctx,
                                    setDialogState: setDialogState,
                                    onSavingChanged: (saving) {
                                      setDialogState(() => isSaving = saving);
                                    },
                                    pinnedLocation: dialogPinnedLocation,
                                  ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
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
