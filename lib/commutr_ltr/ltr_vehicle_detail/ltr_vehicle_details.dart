import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:commutr_main/commutr_ltr/commutr_ltr_login/ltr_session_storage.dart';
import 'package:commutr_main/commutr_ltr/ltr_booking_confirmation/ltr_booking_confirmation.dart';
import 'package:commutr_main/core/debug/api_logger_interceptor.dart';
import 'package:commutr_main/core/network/api_constants.dart';

// Brand colors
const Color kPrimaryGreen = Color(0xFF005C3D);
const Color kBorderGrey = Color(0xFFE0E0E0);
const Color kLabelGrey = Color(0xFF9E9E9E);
const Color kHintGrey = Color(0xFFBDBDBD);

class LtrVehicleDetailsScreen extends StatefulWidget {
  /// Raw QR payload scanned on the previous screen.
  final String qrCode;

  const LtrVehicleDetailsScreen({super.key, required this.qrCode});

  @override
  State<LtrVehicleDetailsScreen> createState() => _LtrVehicleDetailsScreenState();
}

class _LtrVehicleDetailsScreenState extends State<LtrVehicleDetailsScreen> {
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _employeeIdController = TextEditingController();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.ltrGuestBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  bool _submitting = false;

  bool _loadingVehicle = false;
  String? _vehicleError;
  Map<String, dynamic>? _vehicle;
  Map<String, dynamic>? _driver;

  @override
  void initState() {
    super.initState();
    // Capture LTR guest API calls in the in-app API Logger — debug builds only.
    if (kDebugMode) {
      _dio.interceptors.add(ApiLoggerInterceptor());
    }
    _fetchVehicle();
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _nameController.dispose();
    _employeeIdController.dispose();
    _dio.close();
    super.dispose();
  }

  Future<void> _fetchVehicle() async {
    setState(() {
      _loadingVehicle = true;
      _vehicleError = null;
    });

    final path = '/vehicle/qr/${widget.qrCode}';
    final url = '${ApiConstants.ltrGuestBaseUrl}$path';

    debugPrint('[Vehicle] → GET $url');

    try {
      final response = await _dio.get<dynamic>(path);

      debugPrint('[Vehicle] ← [${response.statusCode}] $url');
      debugPrint('[Vehicle] ← response: ${response.data}');

      final data = response.data;
      final result = data is Map ? data['result'] : null;

      if (!mounted) return;
      setState(() {
        _vehicle = result is Map
            ? Map<String, dynamic>.from(result['vehicle'] as Map? ?? {})
            : null;
        _driver = result is Map
            ? Map<String, dynamic>.from(result['driver'] as Map? ?? {})
            : null;
      });
    } on DioException catch (e) {
      debugPrint('[Vehicle] ✖ [${e.response?.statusCode}] $url');
      debugPrint('[Vehicle] ✖ error body: ${e.response?.data}');

      if (!mounted) return;
      setState(() => _vehicleError = _errorMessage(e));
    } finally {
      if (mounted) setState(() => _loadingVehicle = false);
    }
  }

  Future<void> _startTrip() async {
    if (_submitting) return;

    final token = LtrSessionStorage().accessToken;
    if (token == null || token.isEmpty) {
      _showMessage('Your session has expired. Please log in again.');
      return;
    }

    setState(() => _submitting = true);

    try {
      final position = await _resolveCurrentPosition();
      if (position == null) {
        if (!mounted) return;
        _showMessage(
          'Location is required to start a trip. Please enable location access.',
        );
        return;
      }

      final now = _nowIst();
      final startTime = _formatIst(now);
      final endTime = _formatIst(now.add(const Duration(hours: 3)));

      const path = '/booking';
      final url = '${ApiConstants.ltrGuestBaseUrl}$path';
      final payload = <String, dynamic>{
        'qrCode': widget.qrCode,
        'purpose': 'Client visit',
        'pickLatitude': position.latitude,
        'pickLongitude': position.longitude,
        'dropLatitude': position.latitude,
        'dropLongitude': position.longitude,
        'startTime': startTime,
        'endTime': endTime,
      };

      debugPrint('[Booking] → POST $url');
      debugPrint('[Booking] → payload: $payload');

      final response = await _dio.post<dynamic>(
        path,
        data: payload,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      debugPrint('[Booking] ← [${response.statusCode}] $url');
      debugPrint('[Booking] ← response: ${response.data}');

      if (!mounted) return;
      final bookingDate =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final bookingTime = _formatTime(now);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CommutrLtrBookingConfirmationScreen(
            selectedDate: bookingDate,
            selectedTime: bookingTime,
          ),
        ),
      );
    } on DioException catch (e) {
      debugPrint('[Booking] ✖ [${e.response?.statusCode}]');
      debugPrint('[Booking] ✖ error body: ${e.response?.data}');

      if (!mounted) return;
      _showMessage(_errorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Resolves the device's current position, requesting permission and falling
  /// back to the last known location when a live fix isn't available.
  Future<Position?> _resolveCurrentPosition() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      Position? lastKnown;
      try {
        lastKnown = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return lastKnown;

      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (_) {
        return lastKnown;
      }
    } catch (_) {
      return null;
    }
  }

  /// India Standard Time offset (UTC+5:30). IST has no DST, so a fixed offset
  /// is always correct.
  static const Duration _istOffset = Duration(hours: 5, minutes: 30);

  /// Current wall-clock time in India (IST), computed from UTC so it's correct
  /// regardless of the device's timezone.
  DateTime _nowIst() => DateTime.now().toUtc().add(_istOffset);

  /// Formats an IST [DateTime] as an ISO-8601 string with no timezone suffix
  /// and no fractional seconds (e.g. `2026-07-20T09:00:00`), representing India
  /// local time as expected by the booking API.
  String _formatIst(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year.toString().padLeft(4, '0')}-${two(dt.month)}-${two(dt.day)}'
        'T${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  /// Pulls the human-readable message out of the RFC 9110 problem-details body
  /// (e.g. "No vehicle was found for the scanned QR code."), falling back to a
  /// generic message.
  String _errorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final title = data['title']?.toString();
      if (title != null && title.isNotEmpty) return title;
      final message = data['message']?.toString();
      if (message != null && message.isNotEmpty) return message;
    }
    return 'Unable to start trip. Please try again.';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Builds the vehicle detail card based on the fetched API response,
  /// showing loading and error states as appropriate.
  Widget _buildVehicleContent() {
    if (_loadingVehicle && _vehicle == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(color: kPrimaryGreen),
        ),
      );
    }

    if (_vehicleError != null) {
      return _CardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _vehicleError!,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.redAccent,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _fetchVehicle,
              style: TextButton.styleFrom(
                foregroundColor: kPrimaryGreen,
                padding: EdgeInsets.zero,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final vehicle = _vehicle;
    if (vehicle == null) {
      return const _CardContainer(
        child: Text(
          'No vehicle details found for the scanned QR code.',
          style: TextStyle(fontSize: 14, color: kLabelGrey),
        ),
      );
    }

    final vehicleNumber = _stringOrDash(vehicle['vehicleNumber']);
    final vehicleCompany = _stringOrDash(vehicle['vehicleCompany']);
    final modal = _stringOrDash(vehicle['modal']);
    final createdOn = _parseDate(vehicle['createdOn']);
    final driverName = _stringOrDash(_driver?['driverName']);
    final driverNumber = _stringOrDash(_driver?['driverNumber']);

    return _CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _LabelValue(
                  label: 'DATE',
                  value: createdOn != null ? _formatDate(createdOn) : '-',
                ),
              ),
              SizedBox(width: 16,),
              Expanded(
                child: _LabelValue(
                  label: 'CAR NO.',
                  value: vehicleNumber.toUpperCase(),
                ),
              ),
              // Expanded(
              //   child: _LabelValue(
              //     label: 'TIME',
              //     value: createdOn != null ? _formatTime(createdOn) : '-',
              //   ),
              // ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _LabelValue(
                  label: 'COMPANY',
                  value: vehicleCompany,
                ),
              ),
              SizedBox(width: 16,),
              Expanded(
                child: _LabelValue(
                  label: 'MODEL',
                  value: modal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _LabelValue(
                  label: 'DRIVER NAME',
                  value: driverName,
                ),
              ),
              SizedBox(width: 16,),
              Expanded(
                child: _LabelValue(
                  label: 'DRIVER NO.',
                  value: driverNumber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _stringOrDash(Object? value) {
    final s = value?.toString().trim();
    return (s == null || s.isEmpty) ? '-' : s;
  }

  DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDate(DateTime dt) {
    return '${dt.day} ${_months[dt.month - 1]} ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable content
            Expanded(
              child: RefreshIndicator(
                color: kPrimaryGreen,
                onRefresh: _fetchVehicle,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          InkWell(
                            onTap: () => Navigator.of(context).maybePop(),
                            child: const Icon(
                              Icons.arrow_back,
                              color: kPrimaryGreen,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Vehicle Details',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: kPrimaryGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Vehicle Detail Card / loading / error
                      _buildVehicleContent(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Start Trip button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _startTrip,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryGreen,
                    disabledBackgroundColor: kPrimaryGreen.withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Start Trip',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
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

/// Rounded outlined card used for both "Trip Detail" and "Employee Detail"
class _CardContainer extends StatelessWidget {
  final Widget child;
  const _CardContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderGrey),
      ),
      child: child,
    );
  }
}

/// Label above value, used in the Vehicle Detail card.
class _LabelValue extends StatelessWidget {
  final String label;
  final String value;
  const _LabelValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: kLabelGrey,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

/// Rounded outlined text field matching the design
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final TextInputType keyboardType;

  const _InputField({
    required this.controller,
    required this.hintText,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: 10,
      style: const TextStyle(
        fontSize: 15,
        color: Colors.black87,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: kHintGrey,
          fontWeight: FontWeight.normal,
        ),
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBorderGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBorderGrey),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBorderGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kPrimaryGreen, width: 1.5),
        ),
      ),
    );
  }
}
