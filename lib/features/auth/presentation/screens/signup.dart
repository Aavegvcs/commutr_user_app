import 'dart:convert';

import 'package:commutr_main/core/network/api_constants.dart';
import 'package:commutr_main/features/auth/presentation/screens/pin_map/location_data.dart';
import 'package:commutr_main/features/auth/presentation/screens/pin_map/pin_map_screen.dart';
import 'package:commutr_main/features/auth/presentation/screens/signup_success.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'mobile_no_verification.dart';

class SignupScreen extends StatefulWidget {
  final LocationData? locationData;

  const SignupScreen({super.key, this.locationData});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String _selectedGender = 'Male';
  final TextEditingController companyCodeController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _officeHubController = TextEditingController();
  final TextEditingController _signupOtpController = TextEditingController();
  final FocusNode _mobileFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();

  /// After `/Users/check-exists`, true means that field is already registered.
  bool _emailExistsDuplicate = false;
  bool _mobileExistsDuplicate = false;
  bool _checkingEmailExists = false;
  bool _checkingMobileExists = false;

  /// OTP for signup mobile (app :5001); shown only after [POST /Otp/send] succeeds.
  bool _showSignupOtpField = false;
  bool _sendingSignupOtp = false;

  /// Digits we already triggered [POST /Otp/send] for; avoids repeat auto-send on refocus (cooldown 400).
  String? _otpSentForMobile;
  bool _mobileOtpVerified = false;

  /// Mobile digits last successfully verified; used to clear [\_mobileOtpVerified] only when the number changes.
  String? _verifiedSignupMobile;
  bool _verifyingSignupOtp = false;

  bool _isLoading = false;
  double? _empLat;
  double? _empLng;
  double? _currentLat;
  double? _currentLng;

  /// App service (:5001) — [POST /UserStages].
  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConstants.appBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
    },
  ));

  /// App service (:5001) — signup [POST /Otp/send] and [POST /Otp/verify].
  final Dio _otpDio = Dio(BaseOptions(
    baseUrl: ApiConstants.appBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
    },
  ));

  static const Color _primaryGreen = Color(0xFF1A5C45);
  static const Color _lightGreenBg = Color(0xFFEBF5F0);
  static const String _apiPath = '/UserStages';

  /// Auth service (:5000) — [GET /Users/check-exists].
  static const String _checkExistsUrl =
      'https://dev-auth.commutr.in/api/v1/Users/check-exists';

  /// Absolute URLs — passing absolute URLs to Dio overrides `baseUrl`,
  /// guaranteeing signup OTP always hits :5001 regardless of any other config.
  static const String _otpSendPath =
      'https://dev-core.commutr.in/api/v1/Otp/send';
  static const String _otpVerifyPath =
      'https://dev-core.commutr.in/api/v1/Otp/verify';

  void _logApiRequest({
    required String tag,
    required String method,
    required String path,
    String baseUrl = ApiConstants.appBaseUrl,
    Map<String, dynamic>? queryParameters,
    Object? body,
    Map<String, dynamic>? headers,
  }) {
    debugPrint('┌─────────────────────────────────────────');
    debugPrint('│ $tag');
    final url = path.startsWith('http://') || path.startsWith('https://')
        ? path
        : '$baseUrl$path';
    debugPrint('│ $method $url');
    if (queryParameters != null && queryParameters.isNotEmpty) {
      debugPrint('│ QUERY   : ${jsonEncode(queryParameters)}');
    }
    if (headers != null && headers.isNotEmpty) {
      debugPrint('│ HEADERS : ${jsonEncode(headers)}');
    }
    if (body != null) {
      debugPrint('│ BODY    : ${jsonEncode(body)}');
    }
    debugPrint('└─────────────────────────────────────────');
  }

  void _logApiSuccess(String tag, int? status, dynamic data) {
    debugPrint('┌─────────────────────────────────────────');
    debugPrint('│ ✅ $tag');
    debugPrint('│ STATUS  : $status');
    debugPrint('│ RESPONSE: ${jsonEncode(data)}');
    debugPrint('└─────────────────────────────────────────');
  }

  void _logApiDioError(String tag, DioException e) {
    debugPrint('┌─────────────────────────────────────────');
    debugPrint('│ ❌ $tag');
    debugPrint('│ TYPE   : ${e.type}');
    debugPrint('│ MSG    : ${e.message}');
    debugPrint('│ STATUS : ${e.response?.statusCode}');
    debugPrint('│ DATA   : ${jsonEncode(e.response?.data)}');
    debugPrint('└─────────────────────────────────────────');
  }

  void _logApiUnexpected(String tag, Object e) {
    debugPrint('┌─────────────────────────────────────────');
    debugPrint('│ 💥 $tag');
    debugPrint('│ ERROR  : $e');
    debugPrint('└─────────────────────────────────────────');
  }

  void _onMobileFocusChanged() {
    if (!_mobileFocusNode.hasFocus) {
      _checkExistsAfterBlur(checkMobile: true);
    }
  }

  void _onEmailFocusChanged() {
    if (!_emailFocusNode.hasFocus) {
      _checkExistsAfterBlur(checkEmail: true);
    }
  }

  /// Calls GET check-exists with only `email` or `mobile` query param when that field loses focus.
  Future<void> _checkExistsAfterBlur({
    bool checkEmail = false,
    bool checkMobile = false,
  }) async {
    if (checkMobile) {
      final t = _mobileController.text.replaceAll(RegExp(r'\s'), '');
      if (t.isEmpty || !_mobileRegex.hasMatch(t)) {
        if (mounted) {
          setState(() {
            _mobileExistsDuplicate = false;
            _showSignupOtpField = false;
            _otpSentForMobile = null;
            _mobileOtpVerified = false;
            _verifiedSignupMobile = null;
            _signupOtpController.clear();
          });
          _formKey.currentState?.validate();
        }
        return;
      }
      final corp = companyCodeController.text.trim();
      if (corp.isEmpty) {
        debugPrint('[CheckExists mobile :5000] skipped — empty corporate code');
        return;
      }
      if (!mounted) return;
      var shouldSendOtpAfterCheck = false;
      setState(() {
        _checkingMobileExists = true;
        _mobileExistsDuplicate = false;
      });
      try {
        final query = <String, dynamic>{'mobile': t};
        final headers = <String, dynamic>{'X-CorporateCode': corp};
        _logApiRequest(
          tag: 'CheckExists mobile :5000',
          method: 'GET',
          path: _checkExistsUrl,
          queryParameters: query,
          headers: headers,
        );
        final response = await _dio.get<Map<String, dynamic>>(
          _checkExistsUrl,
          queryParameters: query,
          options: Options(headers: headers),
        );
        _logApiSuccess(
          'CheckExists mobile :5000',
          response.statusCode,
          response.data,
        );
        final duplicate = _applyCheckExistsResult(
          response.data,
          forEmail: false,
          forMobile: true,
        );
        shouldSendOtpAfterCheck = !duplicate;
      } on DioException catch (e) {
        _logApiDioError('CheckExists mobile :5000', e);
        if (mounted) {
          setState(() => _mobileExistsDuplicate = false);
          _showSnackBar(e.message ?? 'Could not verify mobile number');
          _formKey.currentState?.validate();
        }
      } catch (e) {
        _logApiUnexpected('CheckExists mobile :5000', e);
        if (mounted) {
          setState(() => _mobileExistsDuplicate = false);
          _showSnackBar('Could not verify mobile number');
          _formKey.currentState?.validate();
        }
      } finally {
        if (mounted) {
          setState(() => _checkingMobileExists = false);
          _formKey.currentState?.validate();
        }
      }
      if (mounted && shouldSendOtpAfterCheck && _otpSentForMobile != t) {
        await _sendSignupOtp(fromResend: false);
      }
    }

    if (checkEmail) {
      final t = _emailController.text.trim();
      if (t.isEmpty || !_emailRegex.hasMatch(t)) {
        if (mounted) {
          setState(() => _emailExistsDuplicate = false);
          _formKey.currentState?.validate();
        }
        return;
      }
      final corp = companyCodeController.text.trim();
      if (corp.isEmpty) {
        debugPrint('[CheckExists email :5000] skipped — empty corporate code');
        return;
      }
      if (!mounted) return;
      setState(() {
        _checkingEmailExists = true;
        _emailExistsDuplicate = false;
      });
      try {
        final query = <String, dynamic>{'email': t};
        final headers = <String, dynamic>{'X-CorporateCode': corp};
        _logApiRequest(
          tag: 'CheckExists email :5000',
          method: 'GET',
          path: _checkExistsUrl,
          queryParameters: query,
          headers: headers,
        );
        final response = await _dio.get<Map<String, dynamic>>(
          _checkExistsUrl,
          queryParameters: query,
          options: Options(headers: headers),
        );
        _logApiSuccess(
          'CheckExists email :5000',
          response.statusCode,
          response.data,
        );
        _applyCheckExistsResult(
          response.data,
          forEmail: true,
          forMobile: false,
        );
      } on DioException catch (e) {
        _logApiDioError('CheckExists email :5000', e);
        if (mounted) {
          setState(() => _emailExistsDuplicate = false);
          _showSnackBar(e.message ?? 'Could not verify email');
          _formKey.currentState?.validate();
        }
      } catch (e) {
        _logApiUnexpected('CheckExists email :5000', e);
        if (mounted) {
          setState(() => _emailExistsDuplicate = false);
          _showSnackBar('Could not verify email');
          _formKey.currentState?.validate();
        }
      } finally {
        if (mounted) {
          setState(() => _checkingEmailExists = false);
          _formKey.currentState?.validate();
        }
      }
    }
  }

  /// Updates duplicate flags. Returns `true` if the field that was checked
  /// already exists, or the response could not be applied (do not send OTP).
  bool _applyCheckExistsResult(
    Map<String, dynamic>? data, {
    required bool forEmail,
    required bool forMobile,
  }) {
    if (!mounted) return true;
    if (data == null) return true;
    final dynamic result = data['result'];
    if (result is! Map) return true;
    final emailExists = result['emailExists'] == true;
    final mobileExists = result['mobileExists'] == true;
    var duplicate = false;
    setState(() {
      if (forEmail) {
        _emailExistsDuplicate = emailExists;
        duplicate = emailExists;
      }
      if (forMobile) {
        _mobileExistsDuplicate = mobileExists;
        duplicate = mobileExists;
      }
    });
    return duplicate;
  }

  /// Decodes JSON string bodies from OTP APIs (some stacks return `text/plain` or raw strings).
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

  /// Treats OTP send/verify responses as success (app :5001 shapes vary: flat, nested `result`, etc.).
  bool _otpApiTruthy(dynamic data, [int depth = 0]) {
    if (depth > 5) return false;
    data = _otpResponseAsJson(data);
    if (data == true || data == 'true') return true;
    if (data is String) {
      final lower = data.trim().toLowerCase();
      if (lower == 'true' || lower == 'success') return true;
    }
    if (data is List && data.isNotEmpty) {
      return _otpApiTruthy(data.first, depth + 1);
    }
    if (data is Map) {
      final m = Map<dynamic, dynamic>.from(data);
      if (m['isSuccess'] == true ||
          m['success'] == true ||
          m['succeeded'] == true) {
        return true;
      }
      final status = m['status'];
      if (status == 1 || status == '1') return true;
      final result = m['result'];
      if (result == true) return true;
      if (result != null) {
        if (_otpApiTruthy(result, depth + 1)) return true;
      }
      final inner = m['data'];
      if (inner != null && _otpApiTruthy(inner, depth + 1)) return true;
    }
    return false;
  }

  String? _otpFailureUserMessage(dynamic raw) {
    final data = _otpResponseAsJson(raw);
    if (data is! Map) return null;
    final m = Map<dynamic, dynamic>.from(data);
    final fromProblem = _otpProblemDetailsUserMessage(m);
    if (fromProblem != null && fromProblem.isNotEmpty) return fromProblem;
    for (final key in ['message', 'errorMessage', 'error', 'title']) {
      final v = m[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v is List && v.isNotEmpty) return v.first.toString();
    }
    final nested = m['result'];
    if (nested is Map) {
      for (final key in ['message', 'errorMessage', 'error']) {
        final v = nested[key];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
    }
    return null;
  }

  /// True when an OTP was sent for the current mobile but it is not yet verified.
  bool get _needsMobileOtpVerify {
    final m = _mobileController.text.replaceAll(RegExp(r'\s'), '');
    if (m.isEmpty || !_mobileRegex.hasMatch(m)) return false;
    return _otpSentForMobile != null &&
        _otpSentForMobile == m &&
        !_mobileOtpVerified;
  }

  String _otpSendErrorMessage(DioException e) {
    var data = e.response?.data;
    data = _otpResponseAsJson(data);
    if (data is Map) {
      final msg =
          _otpProblemDetailsUserMessage(Map<dynamic, dynamic>.from(data));
      if (msg != null && msg.isNotEmpty) return msg;
      final fallback = _otpFailureUserMessage(data);
      if (fallback != null && fallback.isNotEmpty) return fallback;
    }
    if (data is String && data.trim().isNotEmpty) return data.trim();
    return e.message ?? 'Could not send OTP';
  }

  String? _otpProblemDetailsUserMessage(Map<dynamic, dynamic> data) {
    final errors = data['errors'];
    if (errors is Map) {
      final cooldown = errors['Cooldown.Otp'];
      if (cooldown is List && cooldown.isNotEmpty) {
        final first = cooldown.first;
        if (first is String && first.trim().isNotEmpty) return first.trim();
        return first.toString();
      }
      for (final entry in errors.entries) {
        final v = entry.value;
        if (v is List && v.isNotEmpty) {
          final first = v.first;
          if (first is String && first.trim().isNotEmpty) return first.trim();
          return first.toString();
        }
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
    }
    final detail = data['detail'];
    if (detail is String && detail.trim().isNotEmpty) return detail.trim();
    final title = data['title'];
    if (title is String && title.trim().isNotEmpty) return title.trim();
    final message = data['message'] ?? data['error'];
    if (message is String && message.trim().isNotEmpty) return message.trim();
    if (message is List && message.isNotEmpty) {
      return message.first.toString();
    }
    return null;
  }

  Future<void> _sendSignupOtp({required bool fromResend}) async {
    final corp = companyCodeController.text.trim();
    final mobile = _mobileController.text.replaceAll(RegExp(r'\s'), '');
    if (corp.isEmpty) {
      if (mounted) {
        _showSnackBar('Please enter company code to receive OTP');
        setState(() {
          _showSignupOtpField = false;
          _otpSentForMobile = null;
          _mobileOtpVerified = false;
          _verifiedSignupMobile = null;
          _signupOtpController.clear();
        });
        _formKey.currentState?.validate();
      }
      return;
    }
    if (mobile.isEmpty || !_mobileRegex.hasMatch(mobile)) {
      if (mounted) {
        _showSnackBar('Enter a valid 10-digit mobile number');
        _formKey.currentState?.validate();
      }
      return;
    }
    if (!mounted) return;
    setState(() => _sendingSignupOtp = true);
    final otpSendPayload = <String, dynamic>{
      'mobileNo': mobile,
      'requestType': 'S',
    };
    final otpSendHeaders = <String, dynamic>{
      'Content-Type': 'application/json',
      'X-CorporateCode': corp,
    };
    _logApiRequest(
      tag: 'Signup OTP send :5001 (fromResend=$fromResend)',
      method: 'POST',
      path: _otpSendPath,
      body: otpSendPayload,
      headers: otpSendHeaders,
    );
    try {
      final response = await _otpDio.post<dynamic>(
        _otpSendPath,
        data: otpSendPayload,
        options: Options(
          headers: otpSendHeaders,
        ),
      );
      if (!mounted) return;
      final data = _otpResponseAsJson(response.data);
      final ok = _otpApiTruthy(data);
      _logApiSuccess(
          'Signup OTP send :5001 (truthy=$ok)', response.statusCode, data);
      if (ok) {
        setState(() {
          _showSignupOtpField = true;
          _otpSentForMobile = mobile;
          _mobileOtpVerified = false;
          _verifiedSignupMobile = null;
        });
      } else {
        setState(() {
          _showSignupOtpField = false;
          _otpSentForMobile = null;
          _mobileOtpVerified = false;
          _verifiedSignupMobile = null;
          _signupOtpController.clear();
        });
        final msg = _otpFailureUserMessage(data);
        debugPrint('[Signup OTP send :5001] treat as failure msg=$msg');
        _showSnackBar(msg ?? 'Could not send OTP. Please try again.');
      }
    } on DioException catch (e) {
      if (!mounted) return;
      _logApiDioError('Signup OTP send :5001', e);
      final keepOtpUi = fromResend ||
          _showSignupOtpField ||
          (_otpSentForMobile != null && _otpSentForMobile == mobile);
      if (!keepOtpUi) {
        setState(() {
          _showSignupOtpField = false;
          _otpSentForMobile = null;
          _mobileOtpVerified = false;
          _verifiedSignupMobile = null;
          _signupOtpController.clear();
        });
      }
      _showSnackBar(_otpSendErrorMessage(e));
    } catch (e) {
      if (!mounted) return;
      final keepOtpUi = fromResend ||
          _showSignupOtpField ||
          (_otpSentForMobile != null && _otpSentForMobile == mobile);
      if (!keepOtpUi) {
        setState(() {
          _showSignupOtpField = false;
          _otpSentForMobile = null;
          _mobileOtpVerified = false;
          _verifiedSignupMobile = null;
          _signupOtpController.clear();
        });
      }
      _logApiUnexpected('Signup OTP send :5001', e);
      _showSnackBar('Could not send OTP');
    } finally {
      if (mounted) {
        setState(() => _sendingSignupOtp = false);
        _formKey.currentState?.validate();
      }
    }
  }

  Future<void> _verifySignupOtp() async {
    if (!_showSignupOtpField) return;
    final otpErr = _validateSignupOtp(_signupOtpController.text);
    if (otpErr != null) {
      _showSnackBar(otpErr);
      return;
    }
    final corp = companyCodeController.text.trim();
    final mobile = _mobileController.text.replaceAll(RegExp(r'\s'), '');
    if (corp.isEmpty) {
      _showSnackBar('Please enter company code');
      return;
    }
    if (!mounted) return;
    setState(() => _verifyingSignupOtp = true);
    final otpVerifyPayload = <String, dynamic>{
      'mobileNo': mobile,
      'otp': _signupOtpController.text.trim(),
      'requestType': 'S',
    };
    final otpVerifyHeaders = <String, dynamic>{
      'Content-Type': 'application/json',
      'X-CorporateCode': corp,
    };
    _logApiRequest(
      tag: 'Signup OTP verify :5001',
      method: 'POST',
      path: _otpVerifyPath,
      body: otpVerifyPayload,
      headers: otpVerifyHeaders,
    );
    try {
      final response = await _otpDio.post<dynamic>(
        _otpVerifyPath,
        data: otpVerifyPayload,
        options: Options(
          headers: otpVerifyHeaders,
        ),
      );
      if (!mounted) return;
      final data = _otpResponseAsJson(response.data);
      final ok = _otpApiTruthy(data);
      _logApiSuccess(
          'Signup OTP verify :5001 (truthy=$ok)', response.statusCode, data);
      if (ok) {
        setState(() {
          _mobileOtpVerified = true;
          _verifiedSignupMobile = mobile;
          _showSignupOtpField = false;
          _signupOtpController.clear();
        });
      } else {
        debugPrint('[Signup OTP verify :5001] treat as failure — invalid OTP');
        _showSnackBar('Invalid OTP. Please try again.');
      }
    } on DioException catch (e) {
      _logApiDioError('Signup OTP verify :5001', e);
      if (mounted) _showSnackBar(_otpSendErrorMessage(e));
    } catch (e) {
      _logApiUnexpected('Signup OTP verify :5001', e);
      if (mounted) _showSnackBar('Could not verify OTP');
    } finally {
      if (mounted) {
        setState(() => _verifyingSignupOtp = false);
        _formKey.currentState?.validate();
      }
    }
  }

  bool get _submitBlockedByExists =>
      _emailExistsDuplicate ||
      _mobileExistsDuplicate ||
      _checkingEmailExists ||
      _checkingMobileExists ||
      _sendingSignupOtp ||
      _verifyingSignupOtp ||
      _needsMobileOtpVerify;

  @override
  void initState() {
    super.initState();
    _mobileFocusNode.addListener(_onMobileFocusChanged);
    _emailFocusNode.addListener(_onEmailFocusChanged);
    final loc = widget.locationData;
    if (loc != null) {
      _cityController.text = loc.city;
      _stateController.text = loc.state;
      final pin = loc.pincode.trim();
      if (pin.isNotEmpty && pin != 'N/A') {
        _pincodeController.text = pin;
      }
      _empLat = loc.latitude;
      _empLng = loc.longitude;
    }
    _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (mounted) {
        setState(() {
          _currentLat = position.latitude;
          _currentLng = position.longitude;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    companyCodeController.dispose();
    _fullNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _officeHubController.dispose();
    _signupOtpController.dispose();
    _mobileFocusNode.removeListener(_onMobileFocusChanged);
    _emailFocusNode.removeListener(_onEmailFocusChanged);
    _mobileFocusNode.dispose();
    _emailFocusNode.dispose();
    _dio.close();
    _otpDio.close();
    super.dispose();
  }

  // Helper method to split full name into first and last name
  Map<String, String> _splitFullName(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return {'firstName': '', 'lastName': ''};
    final parts = trimmed.split(' ');
    if (parts.length == 1) {
      return {'firstName': parts[0], 'lastName': ''};
    }
    final firstName = parts.first;
    final lastName = parts.sublist(1).join(' ');
    return {'firstName': firstName, 'lastName': lastName};
  }

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  static final RegExp _mobileRegex = RegExp(r'^[6-9]\d{9}$');
  static final RegExp _pincodeRegex = RegExp(r'^\d{6}$');

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Clears routes above verification (e.g. pin map) so back never stops on an intermediate screen.
  void _goBackToMobileVerification() {
    Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(
        builder: (_) => const MobileNoVerification(),
      ),
      (route) => false,
    );
  }

  Future<void> _submitForm() async {
    if (_submitBlockedByExists) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final nameParts = _splitFullName(_fullNameController.text.trim());

      // Build request body according to API specification
      final Map<String, dynamic> requestBody = {
        "locCode": null,
        "depCode": null,
        "proCode": null,
        "lobCode": null,
        "gender": selectedGender(_selectedGender),
        "city": _cityController.text.trim(),
        "pin": _pincodeController.text.trim(),
        "state": _stateController.text.trim(),
        "stateCode": null,
        "phoneNo": null,
        "emerContactNo": null,
        "address": null,
        "supId": null,
        "empType": null,
        "empTypeId": 1,
        "transport": null,
        "useDayPickupPoint": null,
        "nodalPick": null,
        "nodalDrop": null,
        "geocodeId": null,
        "empLat": _empLat,
        "empLng": _empLng,
        "locationName": _officeHubController.text.trim(),
        "employeeId": null,
        "firstName": nameParts['firstName'],
        "middleName": null,
        "lastName": nameParts['lastName'],
        "mobileNo": _mobileController.text.trim().replaceAll(RegExp(r'\s'), ''),
        "emailId": _emailController.text.trim(),
        "specialNeeds": null,
        "supEmployeeId": null,
        "spocEmployeeId": null,
        "spoc": null,
        "tpin": null,
        "actionType": null,
        "supervisorName": null,
        "departmentName": null,
        "projectName": null,
        "regisLocation": null,
        "ipAddress": null
      };

      final userStagesHeaders = <String, dynamic>{
        'X-CorporateCode': companyCodeController.text,
      };
      _logApiRequest(
        tag: 'UserStages :5001',
        method: 'POST',
        path: _apiPath,
        body: requestBody,
        headers: userStagesHeaders,
      );

      final response = await _dio.post(
        _apiPath,
        data: requestBody,
        options: Options(
          headers: userStagesHeaders,
        ),
      );

      _logApiSuccess('UserStages :5001', response.statusCode, response.data);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => SignupSuccessScreen()),
          (route) => false,
        );
        _clearForm();
      } else {
        _showSnackBar('Server error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (!mounted) return;

      _logApiDioError('UserStages :5001', e);

      String errorMessage = 'Network error';
      if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage = 'Connection timeout. Please try again.';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        errorMessage = 'Server response timeout.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'No internet connection.';
      } else if (e.response != null) {
        errorMessage = 'Server error: ${e.response?.statusCode}';
      } else {
        errorMessage = e.message ?? 'Unknown error occurred';
      }

      _showSnackBar(errorMessage);
    } catch (e) {
      if (!mounted) return;

      _logApiUnexpected('UserStages :5001', e);

      _showSnackBar('Unexpected error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _clearForm() {
    companyCodeController.clear();
    _fullNameController.clear();
    _mobileController.clear();
    _emailController.clear();
    _cityController.clear();
    _stateController.clear();
    _pincodeController.clear();
    _officeHubController.clear();
    setState(() {
      _selectedGender = 'Male';
      _emailExistsDuplicate = false;
      _mobileExistsDuplicate = false;
      _showSignupOtpField = false;
      _otpSentForMobile = null;
      _mobileOtpVerified = false;
      _verifiedSignupMobile = null;
    });
    _signupOtpController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _goBackToMobileVerification();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: SafeArea(
          child: Column(
            children: [
              // Top bar
              Container(
                color: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _goBackToMobileVerification,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 40, minHeight: 40),
                      icon: Icon(Icons.arrow_back,
                          color: _primaryGreen, size: 22),
                    ),
                    Text(
                      'Personal Details',
                      style: TextStyle(
                        color: _primaryGreen,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable content
              Expanded(
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Account Details Card
                            _buildSectionCard(
                              icon: Icons.person_outline,
                              title: 'Account Details',
                              child: Column(
                                children: [
                                  _buildBoxField(
                                    controller: _fullNameController,
                                    hint: 'Enter Your Full name',
                                    label: 'Full Name',
                                    validator: _validateFullName,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildBoxField(
                                    controller: companyCodeController,
                                    hint: 'Enter Your Company Code',
                                    label: 'Company Code',
                                  ),
                                  const SizedBox(height: 12),
                                  _buildGenderSelector(),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Contact Information Card
                            _buildSectionCard(
                              icon: Icons.person_pin_outlined,
                              title: 'Contact information',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Mobile row with phone icon + Resend
                                  _buildLabel('Mobile'),
                                  const SizedBox(height: 6),
                                  _buildMobileField(),
                                  if (_mobileOtpVerified) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _lightGreenBg,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: _primaryGreen.withValues(
                                                alpha: 0.25)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.check_circle,
                                              color: _primaryGreen, size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Mobile number verified',
                                            style: TextStyle(
                                              color: _primaryGreen,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (_showSignupOtpField) ...[
                                    const SizedBox(height: 12),
                                    _buildLabel('OTP'),
                                    const SizedBox(height: 6),
                                    _buildOtpRow(),
                                  ],
                                  const SizedBox(height: 12),
                                  // Email with envelope icon
                                  _buildLabel('Email'),
                                  const SizedBox(height: 6),
                                  _buildBoxField(
                                    controller: _emailController,
                                    hint: 'Enter Your email ID',
                                    keyboardType: TextInputType.emailAddress,
                                    validator: _validateEmail,
                                    focusNode: _emailFocusNode,
                                    prefixIcon: const Icon(Icons.mail_outline,
                                        size: 18, color: Color(0xFF1A5C45)),
                                    onChanged: (_) {
                                      if (_emailExistsDuplicate) {
                                        setState(() =>
                                            _emailExistsDuplicate = false);
                                        _formKey.currentState?.validate();
                                      }
                                    },
                                    suffixWidget: _checkingEmailExists
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 1.8),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  // Office Branch with building icon
                                  _buildLabel('Office Branch'),
                                  const SizedBox(height: 6),
                                  _buildBoxField(
                                    controller: _officeHubController,
                                    hint: 'Enter Your office branch',
                                    validator: _validateOfficeHub,
                                    prefixIcon: const Icon(
                                        Icons.domain_outlined,
                                        size: 18,
                                        color: Color(0xFF1A5C45)),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Location Details Card
                            _buildLocationCard(),

                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                    // Full screen loader overlay
                    if (_isLoading)
                      Container(
                        color: Colors.black.withValues(alpha: 0.3),
                        child: const Center(
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 12),
                                  Text('Submitting...'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Fixed bottom submit
              Material(
                elevation: 8,
                color: Colors.white,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: (_isLoading || _submitBlockedByExists)
                            ? null
                            : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Submit',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Colors.grey.shade700,
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: _primaryGreen,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildBoxField({
    required TextEditingController controller,
    required String hint,
    String? label,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int? maxLength,
    FocusNode? focusNode,
    ValueChanged<String>? onChanged,
    Widget? prefixIcon,
    Widget? suffixWidget,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          _buildLabel(label),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          validator: validator,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: prefixIcon,
            suffixIcon: suffixWidget != null
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: suffixWidget,
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFF7F7F7),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _primaryGreen, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.red.shade400),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.red.shade700, width: 1.5),
            ),
            errorStyle: TextStyle(color: Colors.red.shade700, fontSize: 12),
            counterText: '',
          ),
        ),
      ],
    );
  }

  Widget _buildMobileField() {
    return TextFormField(
      controller: _mobileController,
      focusNode: _mobileFocusNode,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      validator: _validateMobile,
      onChanged: (_) {
        final cur = _mobileController.text.replaceAll(RegExp(r'\s'), '');
        debugPrint(
          '[Signup mobile] onChanged len=${cur.length} '
          'otpField=$_showSignupOtpField '
          'otpSentFor=$_otpSentForMobile verified=$_mobileOtpVerified',
        );
        var needsValidate = false;
        if (_mobileOtpVerified &&
            _verifiedSignupMobile != null &&
            cur != _verifiedSignupMobile) {
          setState(() {
            _mobileOtpVerified = false;
            _verifiedSignupMobile = null;
          });
          needsValidate = true;
        }
        if (_mobileExistsDuplicate) {
          setState(() => _mobileExistsDuplicate = false);
          needsValidate = true;
        }
        if (_showSignupOtpField) {
          setState(() {
            _showSignupOtpField = false;
            _otpSentForMobile = null;
            _mobileOtpVerified = false;
            _verifiedSignupMobile = null;
          });
          _signupOtpController.clear();
          needsValidate = true;
        }
        if (needsValidate) {
          _formKey.currentState?.validate();
        }
      },
      style: const TextStyle(fontSize: 14, color: Colors.black87),
      decoration: InputDecoration(
        hintText: 'Enter mobile number',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(Icons.phone_outlined, color: _primaryGreen, size: 18),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 42),
        suffixIcon: (_checkingMobileExists || _sendingSignupOtp)
            ? const Padding(
                padding: EdgeInsets.all(13),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 1.8),
                ),
              )
            : (!_mobileOtpVerified && _otpSentForMobile == null)
                ? null
                : (_mobileOtpVerified
                    ? Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(Icons.check_circle,
                            color: _primaryGreen, size: 20),
                      )
                    : TextButton(
                        onPressed: (_sendingSignupOtp || _verifyingSignupOtp)
                            ? null
                            : () => _sendSignupOtp(fromResend: true),
                        child: Text(
                          'Resend',
                          style: TextStyle(
                            color: (_sendingSignupOtp || _verifyingSignupOtp)
                                ? Colors.grey
                                : _primaryGreen,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      )),
        filled: true,
        fillColor: const Color(0xFFF7F7F7),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _primaryGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red.shade700, width: 1.5),
        ),
        errorStyle: TextStyle(color: Colors.red.shade700, fontSize: 12),
        counterText: '',
      ),
    );
  }

  Widget _buildOtpRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: _signupOtpController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            validator: _validateSignupOtp,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
            decoration: InputDecoration(
              hintText: 'Enter OTP',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              filled: true,
              fillColor: const Color(0xFFF7F7F7),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _primaryGreen, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.red.shade400),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.red.shade700, width: 1.5),
              ),
              errorStyle: TextStyle(color: Colors.red.shade700, fontSize: 12),
              counterText: '',
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: (_verifyingSignupOtp || _sendingSignupOtp)
                ? null
                : _verifySignupOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _verifyingSignupOtp
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Submit',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      color: _primaryGreen, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Location Details',
                    style: TextStyle(
                      color: _primaryGreen,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              InkWell(
                splashColor: Colors.transparent,
                onTap: () async {
                  final loc = await Navigator.push<LocationData>(
                    context,
                    MaterialPageRoute(builder: (_) => const PinMapScreen()),
                  );
                  if (loc != null) {
                    _cityController.text = loc.city;
                    _stateController.text = loc.state;
                    final pin = loc.pincode.trim();
                    if (pin.isNotEmpty && pin != 'N/A') {
                      _pincodeController.text = pin;
                    }
                    setState(() {
                      _empLat = loc.latitude;
                      _empLng = loc.longitude;
                    });
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _lightGreenBg,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: _primaryGreen.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_searching,
                          color: _primaryGreen, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        'PIN ON MAP',
                        style: TextStyle(
                          color: _primaryGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Map preview
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 130,
              width: double.infinity,
              child: (_empLat != null && _empLng != null) ||
                      (_currentLat != null && _currentLng != null)
                  ? GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _empLat != null && _empLng != null
                            ? LatLng(_empLat!, _empLng!)
                            : LatLng(_currentLat!, _currentLng!),
                        zoom: 15,
                      ),
                      markers: _empLat != null && _empLng != null
                          ? {
                              Marker(
                                markerId: const MarkerId('selected'),
                                position: LatLng(_empLat!, _empLng!),
                              ),
                            }
                          : {},
                      zoomControlsEnabled: false,
                      scrollGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                      rotateGesturesEnabled: false,
                      zoomGesturesEnabled: false,
                      myLocationButtonEnabled: false,
                      onTap: (_) async {
                        final loc = await Navigator.push<LocationData>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PinMapScreen()),
                        );
                        if (loc != null) {
                          _cityController.text = loc.city;
                          _stateController.text = loc.state;
                          final pin = loc.pincode.trim();
                          if (pin.isNotEmpty && pin != 'N/A') {
                            _pincodeController.text = pin;
                          }
                          setState(() {
                            _empLat = loc.latitude;
                            _empLng = loc.longitude;
                          });
                        }
                      },
                    )
                  : GestureDetector(
                      onTap: () async {
                        final loc = await Navigator.push<LocationData>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PinMapScreen()),
                        );
                        if (loc != null) {
                          _cityController.text = loc.city;
                          _stateController.text = loc.state;
                          final pin = loc.pincode.trim();
                          if (pin.isNotEmpty && pin != 'N/A') {
                            _pincodeController.text = pin;
                          }
                          setState(() {
                            _empLat = loc.latitude;
                            _empLng = loc.longitude;
                          });
                        }
                      },
                      child: Stack(
                        children: [
                          CustomPaint(
                            size: const Size(double.infinity, 130),
                            painter: _MapPainter(),
                          ),
                          const Center(
                            child: Icon(Icons.location_pin,
                                color: Color(0xFF1A5C45), size: 36),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          // City and State
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('City'),
                    const SizedBox(height: 6),
                    _buildInlineBoxField(
                      controller: _cityController,
                      hint: 'Enter City',
                      validator: _validateCity,
                      readOnly: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('State / Province'),
                    const SizedBox(height: 6),
                    _buildInlineBoxField(
                      controller: _stateController,
                      hint: 'Enter state/province',
                      validator: _validateState,
                      readOnly: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildLabel('Zip / Postal Code'),
          const SizedBox(height: 6),
          _buildInlineBoxField(
            controller: _pincodeController,
            hint: 'Enter ZIP or postal code',
            keyboardType: TextInputType.number,
            validator: _validatePincode,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            readOnly: true,
          ),
        ],
      ),
    );
  }

  Widget _buildInlineBoxField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      readOnly: readOnly,
      style: const TextStyle(fontSize: 14, color: Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF7F7F7),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _primaryGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red.shade700, width: 1.5),
        ),
        errorStyle: TextStyle(color: Colors.red.shade700, fontSize: 11),
        counterText: '',
      ),
    );
  }

  String? _validateFullName(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return 'Please enter full name';
    if (t.length < 2) return 'Name is too short';
    return null;
  }

  String? _validateMobile(String? value) {
    final t = (value ?? '').replaceAll(RegExp(r'\s'), '');
    if (t.isEmpty) return 'Please enter mobile number';
    if (!_mobileRegex.hasMatch(t)) {
      return 'Enter a valid 10-digit mobile number';
    }
    if (_mobileExistsDuplicate) {
      return 'This mobile number is already registered';
    }
    return null;
  }

  String? _validateSignupOtp(String? value) {
    if (!_showSignupOtpField) return null;
    final t = (value ?? '').trim();
    if (t.isEmpty) return 'Please enter OTP';
    if (t.length < 4) return 'OTP is too short';
    if (t.length > 8) return 'OTP is too long';
    if (!RegExp(r'^\d+$').hasMatch(t)) return 'OTP must contain only digits';
    return null;
  }

  String? _validateEmail(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return 'Please enter email ID';
    if (!_emailRegex.hasMatch(t)) return 'Enter a valid email address';
    if (_emailExistsDuplicate) {
      return 'This email is already registered';
    }
    return null;
  }

  String? _validateCity(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return 'Please enter city';
    if (t.length < 2) return 'City name is too short';
    return null;
  }

  String? _validateState(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return 'Please enter state';
    if (t.length < 2) return 'State name is too short';
    return null;
  }

  String? _validatePincode(String? value) {
    final t = (value ?? '').trim();
    if (t.isEmpty) return 'Please enter pincode';
    if (!_pincodeRegex.hasMatch(t)) return 'Pincode must be 6 digits';
    return null;
  }

  String? _validateOfficeHub(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please enter office hub';
    return null;
  }

  String selectedGender(String gender) {
    switch (gender) {
      case 'Male':
        return 'M';

      case 'Female':
        return 'F';

      case 'Other':
        return 'O';

      default:
        return '';
    }
  }

  Widget _buildGenderSelector() {
    final genders = ['Male', 'Female', 'Other'];
    return Row(
      children: [
        Text(
          'GENDER',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: genders.map((gender) {
                final isSelected = _selectedGender == gender;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedGender = gender),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: isSelected ? _primaryGreen : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        gender,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter to simulate a dark map grid
class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Background gradient (dark teal/slate like map)
    final bgPaint = Paint();
    final bgRect = Rect.fromLTWH(0, 0, size.width, size.height);
    bgPaint.shader = const LinearGradient(
      colors: [Color(0xFF3A5A7A), Color(0xFF2E4A6A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(bgRect);
    canvas.drawRect(bgRect, bgPaint);

    // Grid lines (streets)
    final linePaint = Paint()
      ..color = const Color(0xFF5A7A9A).withValues(alpha: 0.6)
      ..strokeWidth = 1.0;

    // Horizontal lines
    for (double y = 0; y < size.height; y += 18) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Vertical lines
    for (double x = 0; x < size.width; x += 22) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }

    // Diagonal road
    final roadPaint = Paint()
      ..color = const Color(0xFF6A9ABF).withValues(alpha: 0.7)
      ..strokeWidth = 2.5;
    canvas.drawLine(
      Offset(0, size.height * 0.3),
      Offset(size.width, size.height * 0.7),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.2, 0),
      Offset(size.width * 0.8, size.height),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
