import 'dart:io';

import 'package:dio/dio.dart';
import 'package:commutr_main/features/auth/presentation/screens/mobile_no_verification.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:commutr_main/commutr_ltr/commutr_ltr_login/commutr_ltr_login.dart';
import 'package:commutr_main/commutr_ltr/commutr_ltr_login/ltr_session_storage.dart';
import 'package:commutr_main/commutr_ltr/scan_qr/scan_qr.dart';
import 'package:commutr_main/core/debug/api_logger_interceptor.dart';
import 'package:commutr_main/core/debug/api_logger_screen.dart';
import 'package:commutr_main/core/network/api_constants.dart';
import 'package:commutr_main/core/storage/auth_local_storage.dart';
import 'package:commutr_main/features/ai_chatbot/chat_inapp.dart';
import 'package:commutr_main/commutr_ltr/commutr_ltr_profile/commutr_ltr_profile.dart';

/// Commutr LTR home screen.
///
/// Static shell: contains no API/BLoC wiring, no side navigation (drawer /
/// hamburger menu), and no notification icon. All sections render local,
/// placeholder data so the screen can be laid out and previewed independently
/// of the network layer.
class CommutrLtrHome extends StatelessWidget {
  const CommutrLtrHome({super.key});

  @override
  Widget build(BuildContext context) {
    return const _CommutrLtrHomeView();
  }
}

class _CommutrLtrHomeView extends StatefulWidget {
  const _CommutrLtrHomeView();

  @override
  State<_CommutrLtrHomeView> createState() => _CommutrLtrHomeState();
}

class _CommutrLtrHomeState extends State<_CommutrLtrHomeView> {
  static const Color _primaryGreen = Color(0xFF1A6B3C);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _selectedIndex = 0;

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

  bool _loadingTrip = false;
  String? _tripError;
  Map<String, dynamic>? _trip;

  bool _closingTrip = false;

  bool _loadingHistory = false;
  String? _historyError;
  List<Map<String, dynamic>> _history = [];
  bool _historyLoaded = false;

  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    // Capture LTR guest API calls in the in-app API Logger — debug builds only.
    if (kDebugMode) {
      _dio.interceptors.add(ApiLoggerInterceptor());
    }
    _fetchLatestTrip();
    _fetchProfile();
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }

  /// Fetches the current user's latest booking (`GET /Booking/me/latest`) and
  /// stores the `result` payload for the Trip Detail card.
  Future<void> _fetchLatestTrip() async {
    final token = LtrSessionStorage().accessToken;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(
          () => _tripError = 'Your session has expired. Please log in again.');
      return;
    }

    setState(() {
      _loadingTrip = true;
      _tripError = null;
    });

    const path = '/Booking/me/latest';
    final url = '${ApiConstants.ltrGuestBaseUrl}$path';

    debugPrint('[LatestTrip] → GET $url');

    try {
      final response = await _dio.get<dynamic>(
        path,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      debugPrint('[LatestTrip] ← [${response.statusCode}] $url');
      debugPrint('[LatestTrip] ← response: ${response.data}');

      final data = response.data;
      final result = data is Map ? data['result'] : null;

      if (!mounted) return;
      setState(() {
        _trip = result is Map ? Map<String, dynamic>.from(result) : null;
      });
    } on DioException catch (e) {
      debugPrint('[LatestTrip] ✖ [${e.response?.statusCode}] $url');
      debugPrint('[LatestTrip] ✖ error body: ${e.response?.data}');

      // A 404 simply means the user has no bookings yet — not an error state.
      if (e.response?.statusCode == 404) {
        if (!mounted) return;
        setState(() => _trip = null);
      } else {
        if (!mounted) return;
        setState(() => _tripError = _errorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _loadingTrip = false);
    }
  }

  /// Fetches the current user's profile (`GET /User/me`) and stores the
  /// `result` payload for the drawer/header greeting and the Profile screen.
  Future<void> _fetchProfile() async {
    final token = LtrSessionStorage().accessToken;
    if (token == null || token.isEmpty) return;

    const path = '/User/me';
    final url = '${ApiConstants.ltrGuestBaseUrl}$path';

    debugPrint('[Profile] → GET $url');

    try {
      final response = await _dio.get<dynamic>(
        path,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      debugPrint('[Profile] ← [${response.statusCode}] $url');
      debugPrint('[Profile] ← response: ${response.data}');

      final data = response.data;
      final result = data is Map ? data['result'] : null;

      if (result is Map) {
        // Keep the stored session in sync so other screens read fresh values.
        await LtrSessionStorage().saveSession(
          accessToken: token,
          refreshToken: LtrSessionStorage().refreshToken ?? '',
          mobileNumber: result['mobileNumber']?.toString(),
          name: result['name']?.toString(),
          employeeCode: result['employeeCode']?.toString(),
        );
      }

      if (!mounted) return;
      setState(() {
        _profile = result is Map ? Map<String, dynamic>.from(result) : null;
      });
    } on DioException catch (e) {
      debugPrint('[Profile] ✖ [${e.response?.statusCode}] $url');
      debugPrint('[Profile] ✖ error body: ${e.response?.data}');
      // Profile is non-blocking — fall back to the stored/placeholder name.
    }
  }

  /// Fetches the current user's booking history (`GET /Booking/me/history`)
  /// and stores the `result` list for the Trip History tab.
  Future<void> _fetchTripHistory() async {
    final token = LtrSessionStorage().accessToken;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _historyLoaded = true;
        _historyError = 'Your session has expired. Please log in again.';
      });
      return;
    }

    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });

    const path = '/Booking/me/history';
    final url = '${ApiConstants.ltrGuestBaseUrl}$path';

    debugPrint('[TripHistory] → GET $url');

    try {
      final response = await _dio.get<dynamic>(
        path,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      debugPrint('[TripHistory] ← [${response.statusCode}] $url');
      debugPrint('[TripHistory] ← response: ${response.data}');

      final data = response.data;
      final result = data is Map ? data['result'] : null;

      if (!mounted) return;
      setState(() {
        _history = result is List
            ? result
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : <Map<String, dynamic>>[];
      });
    } on DioException catch (e) {
      debugPrint('[TripHistory] ✖ [${e.response?.statusCode}] $url');
      debugPrint('[TripHistory] ✖ error body: ${e.response?.data}');

      // A 404 simply means the user has no bookings yet — not an error state.
      if (e.response?.statusCode == 404) {
        if (!mounted) return;
        setState(() => _history = <Map<String, dynamic>>[]);
      } else {
        if (!mounted) return;
        setState(() => _historyError = _errorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingHistory = false;
          _historyLoaded = true;
        });
      }
    }
  }

  String _errorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final message = data['message']?.toString();
      if (message != null && message.isNotEmpty) return message;
      final title = data['title']?.toString();
      if (title != null && title.isNotEmpty) return title;
    }
    return 'Unable to load your trip. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Home is the post-login root — block the hardware/gesture back so the
      // user can't pop back to the login/verification flow.
      canPop: false,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFF9F9F9),
        drawer: _buildDrawer(),
        body: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildMainContent()),
              ],
            ),

            // Bottom navigation bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomNav(),
            ),

            // SOS button
            // Positioned(
            //   bottom: 90,
            //   left: 16,
            //   child: _buildSOSButton(),
            // ),

            // FAB image (sits above the notch)
            Positioned(
              bottom: 36,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _onFabTap,
                  child: _buildFAB(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 1:
        return _buildTripHistorySection();
      case 0:
      default:
        return _buildSchedulesSection();
    }
  }

  // ---------------------------------------------------------------------------
  // Side menu (drawer)
  // ---------------------------------------------------------------------------

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drawer header with avatar + name — tap to open Profile.
            InkWell(
              onTap: _onProfileTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE6F3ED),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _initials,
                        style: const TextStyle(
                          color: _primaryGreen,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          // const SizedBox(height: 2),
                          // const Text(
                          //   'Welcome back',
                          //   style: TextStyle(
                          //     fontSize: 13,
                          //     color: Color(0xFF6B7280),
                          //   ),
                          // ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Color(0xFF9CA3AF),
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
            const Divider(color: Color(0xFFE8E8E8), height: 1),
            const SizedBox(height: 8),
            _buildDrawerItem(
              icon: Icons.person_outline,
              label: 'Profile',
              onTap: _onProfileTap,
            ),
            _buildDrawerItem(
              icon: Icons.directions_bus_rounded,
              label: 'Trip History',
              onTap: _onTripHistoryTap,
            ),
            if (kDebugMode)
              _buildDrawerItem(
                icon: Icons.receipt_long_outlined,
                label: 'API Logger',
                onTap: _onApiLoggerTap,
                color: const Color(0xFF9C27B0),
              ),
            const Spacer(),
            const Divider(color: Color(0xFFE8E8E8), height: 1),
            _buildDrawerItem(
              icon: Icons.logout_rounded,
              label: 'Logout',
              onTap: _onLogoutTap,
              color: const Color(0xFFB40D1A),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = const Color(0xFF111827),
  }) {
    return ListTile(
      leading: Icon(icon, color: color, size: 24),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      onTap: onTap,
    );
  }

  void _onProfileTap() {
    Navigator.of(context).pop(); // close drawer
    final session = LtrSessionStorage();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CommutrLtrProfileScreen(
          name: _profile?['name']?.toString() ?? session.name,
          mobileNumber:
              _profile?['mobileNumber']?.toString() ?? session.mobileNumber,
          employeeCode:
              _profile?['employeeCode']?.toString() ?? session.employeeCode,
        ),
      ),
    );
  }

  void _onTripHistoryTap() {
    Navigator.of(context).pop(); // close drawer
    _openTripHistory();
  }

  /// Switches to the Trip History tab and fetches the history the first time
  /// it's opened.
  void _openTripHistory() {
    setState(() => _selectedIndex = 1);
    if (!_historyLoaded) {
      _fetchTripHistory();
    }
  }

  /// Opens the in-app API logger. Debug-only — the drawer entry is gated
  /// behind [kDebugMode] and stripped from release builds.
  void _onApiLoggerTap() {
    Navigator.of(context).pop(); // close drawer
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ApiLoggerScreen()),
    );
  }

  void _onLogoutTap() {
    Navigator.of(context).pop(); // close drawer
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _clearAllLocalStorage();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(
                  builder: (_) => const MobileNoVerification(),
                ),
                (route) => false,
              );
            },
            child: const Text(
              'Logout',
              style: TextStyle(
                color: Color(0xFFB40D1A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Wipes every Hive box the app uses on logout so no session data —
  /// including the access/refresh tokens — survives.
  Future<void> _clearAllLocalStorage() async {
    await Future.wait<void>([
      Hive.box(LtrSessionStorage.boxName).clear(),
      Hive.box(AuthLocalStorage.boxName).clear(),
      Hive.box(kEtsChatHiveBoxName).clear(),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    if (_selectedIndex == 1) {
      return _buildTripHistoryAppBar();
    }
    return SizedBox(
      height: 110 + MediaQuery.of(context).padding.top,
      child: Stack(
        children: [
          Image.asset(
            'assets/images/welcome_header.png',
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    borderRadius: BorderRadius.circular(24),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.menu, color: Colors.white, size: 26),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'HELLO',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          _displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: Platform.isAndroid ? 24 : 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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

  Widget _buildTripHistoryAppBar() {
    return Material(
      color: const Color(0xFFF5F5F4),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              InkWell(
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                borderRadius: BorderRadius.circular(24),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.menu, color: _primaryGreen, size: 26),
                ),
              ),
              const Expanded(
                child: Text(
                  'Trip History',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _primaryGreen,
                  ),
                ),
              ),
              const SizedBox(width: 34),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Schedules (static placeholder)
  // ---------------------------------------------------------------------------

  /// Best-known display name: freshly-fetched profile → stored session →
  /// "Guest" fallback.
  String get _displayName {
    final fromProfile = _profile?['name']?.toString().trim();
    if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;
    final fromSession = LtrSessionStorage().name?.trim();
    if (fromSession != null && fromSession.isNotEmpty) return fromSession;
    return 'Guest';
  }

  /// Up to two uppercase initials from [_displayName] (e.g. "Test Guest" → "TG").
  String get _initials {
    final parts = _displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Widget _buildSchedulesSection() {
    return RefreshIndicator(
      color: _primaryGreen,
      onRefresh: () => Future.wait([_fetchLatestTrip(), _fetchProfile()]),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 180),
        children: [
          _buildTripDetailContent(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Trip detail (from GET /Booking/me/latest)
  // ---------------------------------------------------------------------------

  /// Renders the latest-booking card, showing loading, error and empty states
  /// based on the fetched API response.
  Widget _buildTripDetailContent() {
    if (_loadingTrip && _trip == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator(color: _primaryGreen)),
      );
    }

    if (_tripError != null) {
      return _tripCardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tripError!,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFFB40D1A),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _fetchLatestTrip,
              style: TextButton.styleFrom(
                foregroundColor: _primaryGreen,
                padding: EdgeInsets.zero,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final trip = _trip;
    if (trip == null) {
      return _tripCardShell(
        child: const Text(
          'No active trip. Scan a vehicle QR to start one.',
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
      );
    }

    return _tripCardShell(child: _buildTripDetailBody(trip));
  }

  /// Builds the Trip Detail body (title + status chip + label/value rows) for a
  /// single booking map. Shared by the home Trip Detail card and the Trip
  /// History detail view.
  ///
  /// When [full] is `true`, every field from the booking payload is shown
  /// (end time, purpose, trip id, pickup/drop coordinates, booked-on); the
  /// compact home card leaves it `false`.
  Widget _buildTripDetailBody(Map<String, dynamic> trip, {bool full = false}) {
    final id = _intOrzero(trip['id']);
    final startTime = _parseDate(trip['startTime']);
    final endTime = _parseDate(trip['endTime']);
    final bookedOn = _parseDate(trip['bookedOn']);
    final vehicleNumber = _stringOrDash(trip['vehicleNumber']);
    final modal = _stringOrDash(trip['modal']);
    final driverName = _stringOrDash(trip['driverName']);
    final driverNumber = _stringOrDash(trip['driverNumber']);
    final purpose = _stringOrDash(trip['purpose']);
    final status = _stringOrDash(trip['status']);
    final tripId = _stringOrDash(trip['tripId']);
    final pickup = _formatLatLng(trip['pickLatitude'], trip['pickLongitude']);
    final drop = _formatLatLng(trip['dropLatitude'], trip['dropLongitude']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Trip Detail',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
            if (status != '-') _StatusChip(status: status),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(color: Color(0xFFE0E0E0), height: 1),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _LabelValue(
                label: 'DATE',
                value: startTime != null ? _formatDate(startTime) : '-',
              ),
            ),
            SizedBox(width: 16,),
            Expanded(
              child: _LabelValue(
                label: full ? 'START TIME' : 'TIME',
                value: startTime != null ? _formatTime(startTime) : '-',
              ),
            ),
          ],
        ),
        if (full) ...[
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _LabelValue(
                  label: 'END DATE',
                  value: endTime != null ? _formatDate(endTime) : '-',
                ),
              ),
              SizedBox(width: 16,),
              Expanded(
                child: _LabelValue(
                  label: 'END TIME',
                  value: endTime != null ? _formatTime(endTime) : '-',
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _LabelValue(
                label: 'CAR NO.',
                value: vehicleNumber == '-' ? '-' : vehicleNumber.toUpperCase(),
              ),
            ),
            SizedBox(width: 16,),
            Expanded(child: _LabelValue(label: 'MODEL', value: modal)),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _LabelValue(label: 'DRIVER NAME', value: driverName),
            ),
            SizedBox(width: 16,),
            Expanded(
              child: _LabelValue(label: 'DRIVER NO.', value: driverNumber),
            ),
          ],
        ),

        if (full) ...[
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _LabelValue(label: 'TRIP ID', value: tripId)),
              Expanded(
                child: _LabelValue(
                  label: 'BOOKED ON',
                  value: bookedOn != null
                      ? '${_formatDate(bookedOn)}, ${_formatTime(bookedOn)}'
                      : '-',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _LabelValue(label: 'PICKUP', value: pickup),
          const SizedBox(height: 18),
          _LabelValue(label: 'DROP', value: drop),
        ],
        // Only an in-progress ("Started") trip can be closed.
        if (!full && status.toLowerCase() == 'started') ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _closingTrip ? null : () => _onCloseTrip(id),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB40D1A),
                disabledBackgroundColor:
                    const Color(0xFFB40D1A).withValues(alpha: 0.5),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
              child: _closingTrip
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Close Trip',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ],
    );
  }


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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  /// Completes (closes) the in-progress booking (`POST /Booking/{id}/complete`)
  /// and refetches the Trip Detail card on success.
  Future<void> _onCloseTrip(int id) async {
    if (_closingTrip || id == 0) return;

    final token = LtrSessionStorage().accessToken;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(
          () => _tripError = 'Your session has expired. Please log in again.');
      return;
    }

    setState(() => _closingTrip = true);

    final position = await _resolveCurrentPosition();
    if (position == null) {
      if (!mounted) return;
      _showMessage(
        'Location is required to start a trip. Please enable location access.',
      );
      return;
    }

    final path = '/Booking/$id/complete';
    final url = '${ApiConstants.ltrGuestBaseUrl}$path';
    final payload = <String, dynamic>{
      'dropLatitude': position.latitude,
      'dropLongitude': position.longitude,
    };
    debugPrint('[CloseTrip] → POST $url');

    try {
      final response = await _dio.post<dynamic>(
        path,
        data: payload,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      debugPrint('[CloseTrip] ← [${response.statusCode}] $url');
      debugPrint('[CloseTrip] ← response: ${response.data}');

      if (!mounted) return;
      // Refetch the Trip Detail card so it reflects the new "Completed" status.
      await _fetchLatestTrip();

      if (!mounted) return;
      final data = response.data;
      final message = (data is Map && data['message'] is String)
          ? data['message'] as String
          : 'Booking completed successfully.';
      _showResultDialog(success: true, message: message);
    } on DioException catch (e) {
      debugPrint('[CloseTrip] ✖ [${e.response?.statusCode}] $url');
      debugPrint('[CloseTrip] ✖ error body: ${e.response?.data}');

      if (!mounted) return;
      _showResultDialog(success: false, message: _errorMessage(e));
    } finally {
      if (mounted) setState(() => _closingTrip = false);
    }
  }

  /// Shows a centered success/error popup carrying the API [message].
  void _showResultDialog({required bool success, required String message}) {
    const successGreen = _primaryGreen;
    const errorRed = Color(0xFFB40D1A);
    final accent = success ? successGreen : errorRed;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: success
                      ? const Color(0xFFE6F3ED)
                      : const Color(0xFFFDE7E9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  success ? Icons.check_circle_outline : Icons.error_outline,
                  color: accent,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                success ? 'Success' : 'Something went wrong',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF596064),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
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

  /// Formats a latitude/longitude pair as "lat, lng" with 6 decimals, or "-"
  /// when either is missing or both are zero (an unset location).
  String _formatLatLng(Object? lat, Object? lng) {
    final latVal = lat is num ? lat.toDouble() : double.tryParse('$lat');
    final lngVal = lng is num ? lng.toDouble() : double.tryParse('$lng');
    if (latVal == null || lngVal == null) return '-';
    if (latVal == 0 && lngVal == 0) return '-';
    return '${latVal.toStringAsFixed(6)}, ${lngVal.toStringAsFixed(6)}';
  }

  Widget _tripCardShell({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: child,
    );
  }

  String _stringOrDash(Object? value) {
    final s = value?.toString().trim();
    return (s == null || s.isEmpty) ? '-' : s;
  }

  int _intOrzero(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString().trim() ?? '') ?? 0;
  }

  DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
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

  // Widget _scheduleCard({
  //   required bool isLogin,
  //   required String time,
  //   required String label,
  // }) {
  //   return Container(
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(16),
  //       border: Border.all(color: const Color(0xFFE8E8E8)),
  //     ),
  //     child: Row(
  //       children: [
  //         Container(
  //           width: 44,
  //           height: 44,
  //           decoration: BoxDecoration(
  //             color: const Color(0xFFE6F3ED),
  //             borderRadius: BorderRadius.circular(12),
  //           ),
  //           child: Icon(
  //             isLogin ? Icons.login_rounded : Icons.logout_rounded,
  //             color: _primaryGreen,
  //             size: 22,
  //           ),
  //         ),
  //         const SizedBox(width: 14),
  //         Expanded(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(
  //                 label,
  //                 style: const TextStyle(
  //                   fontSize: 15,
  //                   fontWeight: FontWeight.w700,
  //                   color: Color(0xFF111827),
  //                 ),
  //               ),
  //               const SizedBox(height: 4),
  //               Text(
  //                 time,
  //                 style: const TextStyle(
  //                   fontSize: 13,
  //                   color: Color(0xFF6B7280),
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // ---------------------------------------------------------------------------
  // Trip history (static placeholder)
  // ---------------------------------------------------------------------------

  Widget _buildTripHistorySection() {
    return RefreshIndicator(
      color: _primaryGreen,
      onRefresh: _fetchTripHistory,
      child: _buildTripHistoryContent(),
    );
  }

  Widget _buildTripHistoryContent() {
    // Initial load — no data yet.
    if (_loadingHistory && _history.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 180),
        children: const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child:
                Center(child: CircularProgressIndicator(color: _primaryGreen)),
          ),
        ],
      );
    }

    if (_historyError != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 180),
        children: [
          Text(
            _historyError!,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFB40D1A),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _fetchTripHistory,
            style: TextButton.styleFrom(
              foregroundColor: _primaryGreen,
              padding: EdgeInsets.zero,
            ),
            child: const Text('Retry'),
          ),
        ],
      );
    }

    if (_history.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 180),
        children: const [
          Center(
            child: Text(
              'No trips yet.',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 180),
      itemCount: _history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final booking = _history[index];
        final startTime = _parseDate(booking['startTime']);
        final vehicleNumber = _stringOrDash(booking['vehicleNumber']);
        final driverName = _stringOrDash(booking['driverName']);
        return _historyCard(
          driverName: driverName == '-' ? 'Driver unassigned' : driverName,
          tripId: _stringOrDash(booking['tripId']),
          carNo: vehicleNumber == '-' ? '-' : vehicleNumber.toUpperCase(),
          date: startTime != null ? _formatDate(startTime) : '-',
          time: startTime != null ? _formatTime(startTime) : '-',
          status: _stringOrDash(booking['status']),
          onTap: () => _showTripDetailSheet(booking),
        );
      },
    );
  }

  Widget _historyCard({
    required String driverName,
    required String tripId,
    required String carNo,
    required String date,
    required String time,
    required String status,
    VoidCallback? onTap,
  }) {
    final initial = driverName.isNotEmpty ? driverName[0].toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEFEFEF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: avatar + driver name/subtitle, trip id pill.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE6F3ED),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _primaryGreen,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driverName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Driver',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (tripId != '-') ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F3ED),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Trip #$tripId',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFF0F0F0), height: 1),
                const SizedBox(height: 16),
                // Footer: Car No. / Date / Time with icons.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _historyStat(
                        icon: Icons.directions_car_filled_outlined,
                        label: 'Car No.',
                        value: carNo,
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: _historyStat(
                        icon: Icons.event_outlined,
                        label: 'Date',
                        value: date,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: _historyStat(
                        icon: Icons.schedule_outlined,
                        label: 'Time',
                        value: time,
                      ),
                    ),
                  ],
                ),
                if (status != '-') ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _StatusChip(status: status),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Icon + label-over-value stat used in the Trip History card footer.
  Widget _historyStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  /// Opens a bottom sheet showing the full Trip Detail for a history booking.
  void _showTripDetailSheet(Map<String, dynamic> booking) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF9F9F9),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D0D0),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _tripCardShell(
                      child: _buildTripDetailBody(booking, full: true),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Color(0xFF111827),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SOS button
  // ---------------------------------------------------------------------------

  Widget _buildSOSButton() {
    return _SosHoldButton(onActivated: _showSOSDialog);
  }

  void _showSOSDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFCCCC),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.gpp_maybe,
                  color: Color(0xFFB40D1A),
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Activate SOS?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                  fontFamily: 'Manrope',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Are you sure you want to trigger an emergency alert? This will '
                'immediately notify our safety team and share your live location '
                'with local authorities.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF596064),
                  height: 1.5,
                  fontFamily: 'Manrope',
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(dialogContext).pop(),
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFB40D1A),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Confirm',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontFamily: 'Manrope',
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(dialogContext).pop(),
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Go Back',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A6B3C),
                            fontFamily: 'Manrope',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FAB
  // ---------------------------------------------------------------------------

  void _onFabTap() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ScanQr()),
    );
  }

  Widget _buildFAB() {
    const fabSize = 100.0;
    return SizedBox(
      width: fabSize,
      height: fabSize,
      child: Image.asset(
        'assets/images/qr_scan.png',
        fit: BoxFit.cover,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom navigation
  // ---------------------------------------------------------------------------

  Widget _buildBottomNav() {
    return CustomPaint(
      painter: _BottomNavNotchPainter(),
      child: SizedBox(
        height: 86,
        child: Row(
          children: [
            // Home tab
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedIndex = 0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedIndex == 0
                            ? const Color(0xFFCCE8D8)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.home_rounded,
                            color: _selectedIndex == 0
                                ? _primaryGreen
                                : const Color(0xFF9E9E9E),
                            size: 24,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Home',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _selectedIndex == 0
                                  ? _primaryGreen
                                  : const Color(0xFF9E9E9E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Center gap for notch
            const SizedBox(width: 120),

            // Trip History tab
            Expanded(
              child: GestureDetector(
                onTap: _openTripHistory,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedIndex == 1
                            ? const Color(0xFFCCE8D8)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.directions_bus_rounded,
                            color: _selectedIndex == 1
                                ? _primaryGreen
                                : const Color(0xFF9E9E9E),
                            size: 24,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Trip History',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _selectedIndex == 1
                                  ? _primaryGreen
                                  : const Color(0xFF9E9E9E),
                            ),
                          ),
                        ],
                      ),
                    ),
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

/// Rounded status pill (e.g. "Started", "Completed") shown on the Trip Detail
/// card, coloured by the booking status.
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final lower = status.toLowerCase();
    late final Color fg;
    late final Color bg;
    if (lower == 'completed') {
      fg = const Color(0xFF1A6B3C);
      bg = const Color(0xFFE6F3ED);
    } else if (lower == 'cancelled' || lower == 'canceled') {
      fg = const Color(0xFFB40D1A);
      bg = const Color(0xFFFDE7E9);
    } else {
      // Started / in-progress and any other status.
      fg = const Color(0xFFB26A00);
      bg = const Color(0xFFFFF4E0);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

/// Label above value, used in the Trip Detail card.
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
            color: Color(0xFF9E9E9E),
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

// Draws the white nav bar with a smooth circular notch cut out at the top-center
class _BottomNavNotchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    const notchRadius = 0.0; // matches the FAB image circle area
    const notchMargin = 0.0;
    final centerX = size.width / 2;
    const totalRadius = notchRadius + notchMargin;

    final path = Path();
    path.moveTo(0, 0);

    // Left straight → left curve start
    path.lineTo(centerX - totalRadius - 12, 0);

    // Smooth left entry curve
    path.quadraticBezierTo(
      centerX - totalRadius,
      0,
      centerX - totalRadius + 4,
      8,
    );

    // Arc across the notch (bottom half of circle = dips down)
    path.arcToPoint(
      Offset(centerX + totalRadius - 4, 8),
      radius: const Radius.circular(totalRadius),
      clockwise: false,
    );

    // Smooth right exit curve
    path.quadraticBezierTo(
      centerX + totalRadius,
      0,
      centerX + totalRadius + 12,
      0,
    );

    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    // Draw shadow first, then white bar
    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, paint);

    // Top border line (skipping the notch area)
    final borderPaint = Paint()
      ..color = const Color(0xFFE8E8E8)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final borderPath = Path();
    borderPath.moveTo(0, 0.5);
    borderPath.lineTo(centerX - totalRadius - 12, 0.5);
    borderPath.moveTo(centerX + totalRadius + 12, 0.5);
    borderPath.lineTo(size.width, 0.5);

    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SosHoldButton extends StatefulWidget {
  final VoidCallback onActivated;

  const _SosHoldButton({required this.onActivated});

  @override
  State<_SosHoldButton> createState() => _SosHoldButtonState();
}

class _SosHoldButtonState extends State<_SosHoldButton>
    with SingleTickerProviderStateMixin {
  static const _holdDuration = Duration(seconds: 2);

  late AnimationController _controller;
  int _lastVibrationStep = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _holdDuration);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reset();
        HapticFeedback.heavyImpact();
        widget.onActivated();
      }
    });
    _controller.addListener(_onProgress);
  }

  void _onProgress() {
    // Vibrate on every 10% increment while holding
    final step = (_controller.value * 10).floor();
    if (step > _lastVibrationStep) {
      _lastVibrationStep = step;
      HapticFeedback.lightImpact();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    _lastVibrationStep = 0;
    HapticFeedback.mediumImpact();
    _controller.forward(from: 0);
  }

  void _cancel() {
    _controller.stop();
    _controller.reset();
    _lastVibrationStep = 0;
  }

  @override
  Widget build(BuildContext context) {
    const size = 67.0;
    const strokeWidth = 4.0;
    // Ring sits just outside the image so the border wraps around it.
    const ringSize = size + strokeWidth * 2;
    return GestureDetector(
      onLongPressStart: (_) => _start(),
      onLongPressEnd: (_) => _cancel(),
      onLongPressCancel: _cancel,
      child: SizedBox(
        width: ringSize,
        height: ringSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(
              'assets/images/sos.png',
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                if (_controller.value == 0) return const SizedBox.shrink();
                return SizedBox(
                  width: ringSize,
                  height: ringSize,
                  child: CircularProgressIndicator(
                    value: _controller.value,
                    strokeWidth: strokeWidth,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFB40D1A),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
