import 'dart:math' show pi;

import 'package:commutr_main/core/debug/api_logger_screen.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:commutr_main/core/di/injection.dart';
import 'package:commutr_main/core/storage/auth_local_storage.dart';
import 'package:commutr_main/features/auth/presentation/screens/mobile_no_verification.dart';
import 'package:commutr_main/features/trip_detail/bloc/roaster_bloc.dart';
import 'package:commutr_main/features/trip_detail/bloc/roaster_event.dart';
import 'package:commutr_main/features/trip_detail/bloc/roaster_state.dart';
import 'package:commutr_main/features/trip_detail/bloc/schedule_home_bloc.dart';
import 'package:commutr_main/features/trip_detail/bloc/schedule_home_event.dart';
import 'package:commutr_main/features/trip_detail/bloc/schedule_home_state.dart';
import 'package:commutr_main/features/trip_detail/bloc/trip_home_bloc.dart';
import 'package:commutr_main/features/trip_detail/bloc/trip_home_event.dart';
import 'package:commutr_main/features/trip_detail/bloc/trip_home_state.dart';
import 'package:commutr_main/features/trip_detail/bloc/shift_bloc.dart';
import 'package:commutr_main/features/trip_detail/bloc/shift_event.dart';
import 'package:commutr_main/features/trip_detail/bloc/shift_state.dart';
import 'package:commutr_main/features/trip_detail/data/model/schedule_home_response.dart';
import 'package:commutr_main/features/trip_detail/data/model/trip_home_response.dart';
import 'package:commutr_main/features/trip_detail/model/trip_schedule_flow_args.dart';
import 'package:commutr_main/profile/presentation/screen/profile.dart';
import 'package:commutr_main/ride_tracking/ride_tracking.dart';
import 'package:commutr_main/trip_summary/trip_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/ai_chatbot/chat_popup.dart';
import '../../../features/trip_detail/presentation/screen/trip_detail.dart';
import '../../../weekly_off/presentation/screen/weekly_off.dart';

enum _TripHistoryStatus { completed, noShow, cancelled }

class Welcome extends StatelessWidget {
  const Welcome({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<TripHomeBloc>(
          create: (_) => sl<TripHomeBloc>()..add(const FetchTripHome()),
        ),
        BlocProvider<ScheduleHomeBloc>(
          create: (_) =>
              sl<ScheduleHomeBloc>()..add(const FetchScheduleHome()),
        ),
        BlocProvider<RosterBloc>(
          create: (_) => sl<RosterBloc>()..add(const FetchRosterUserDetails()),
        ),
      ],
      child: const _WelcomeView(),
    );
  }
}

class _WelcomeView extends StatefulWidget {
  const _WelcomeView();

  @override
  State<_WelcomeView> createState() => _WelcomeState();
}

class _WelcomeState extends State<_WelcomeView> {
  int _selectedIndex = 0;

  /// Keys for which active-trip cards are expanded (prefix `trip_`).
  final Set<String> _tripExpanded = {};

  /// Keys for which schedule cards are expanded
  /// (e.g. `"Today_login_0"`, `"Tomorrow_logout_0"`).
  final Set<String> _scheduleExpanded = {};

  /// Keys for which trip-history cards are expanded (e.g. `"0"`, `"1"`).
  final Set<String> _tripHistoryExpanded = {};

  void _showCancelRideDialog(
    BuildContext context, {
    required bool isLogin,
    required ScheduleItem item,
  }) {
    final rosterState = context.read<RosterBloc>().state;
    final locCode = rosterState is RosterLoaded ? rosterState.details.locCode : null;
    final scheduleDateIso = _scheduleDateIsoForCancel(item, isLogin);
    final empIdStr = _empIdForCancelPayload(item);

    void showBar(String msg) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    }

    if (rosterState is RosterLoading || rosterState is RosterInitial) {
      showBar('Loading your office details… try again in a moment.');
      return;
    }
    if (rosterState is RosterUnauthorized) {
      showBar(rosterState.message);
      return;
    }
    if (locCode == null || locCode == 0) {
      showBar('Office location not available. Pull to refresh or try again later.');
      return;
    }
    if (scheduleDateIso == null || scheduleDateIso.isEmpty) {
      showBar('Schedule date is missing for this trip. Pull to refresh.');
      return;
    }
    if (empIdStr == null || empIdStr.isEmpty) {
      showBar('Employee ID is missing. Pull to refresh.');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (dialogContext) => CancelRideDialog(
        isLogin: isLogin,
        locCode: locCode,
        empId: empIdStr,
        scheduleDate: scheduleDateIso,
      ),
    );
  }

  /// `POST /TransRoster/CancelSchedules` expects `yyyy-MM-dd`.
  String? _scheduleDateIsoForCancel(ScheduleItem item, bool isLogin) {
    final raw = isLogin ? item.loginScheduleDate : item.logoutScheduleDate;
    return scheduleDateToIso(raw);
  }

  void _openEditRoster(
    BuildContext context, {
    required bool isLogin,
    required ScheduleItem item,
  }) {
    final rosterState = context.read<RosterBloc>().state;
    if (rosterState is RosterLoading || rosterState is RosterInitial) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Loading office details… try again in a moment.'),
          ),
        );
      return;
    }
    if (rosterState is RosterUnauthorized) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(rosterState.message)));
      return;
    }
    if (rosterState is! RosterLoaded) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not load office details.')),
        );
      return;
    }

    final args = TripScheduleFlowArgs.fromScheduleItem(
      item: item,
      isLogIn: isLogin,
      locCode: rosterState.details.locCode,
    );

    if (!args.hasValidDates) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Schedule date is missing. Pull to refresh.'),
          ),
        );
      return;
    }
    if (args.empId == 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Employee ID is missing. Pull to refresh.'),
          ),
        );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TripDetailsScreen(flowArgs: args),
      ),
    );
  }

  /// Prefer `EmployeeID` when non-empty; otherwise numeric `Empid`.
  String? _empIdForCancelPayload(ScheduleItem item) {
    final fromField = item.employeeId?.trim();
    if (fromField != null && fromField.isNotEmpty) return fromField;
    if (item.empId != null) return item.empId.toString();
    return null;
  }

  void _openTransportAssistantChat() {
    context.read<TripHomeBloc>().add(const FetchTripHome());
    context.read<ScheduleHomeBloc>().add(const FetchScheduleHome());

    // Navigate – the API call runs in the background
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const ChatPopup(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double fabSize = 100.0;
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      drawer: AppDrawer(
        onTripHistoryTap: () {
          Navigator.pop(context);
          setState(() => _selectedIndex = 1);
        },
      ),
      // floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // floatingActionButton: InkWell(
      //   splashColor: Colors.transparent,
      //   onTap: (){
      //     Navigator.push(
      //       context,
      //       MaterialPageRoute(
      //         builder: (context) => TripDetailsScreen(),
      //       ),
      //     );
      //   },
      //   child: Transform.translate(
      //     offset: const Offset(0.0, -15.0),
      //     child: SizedBox(
      //       width: fabSize,
      //       height: fabSize,
      //       child: Image.asset(
      //         'assets/images/welcome_add.png',
      //         fit: BoxFit.cover,
      //       ),
      //     ),
      //   ),
      // ),
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
            child: Column(
              children: [
                // Container(
                //   width: double.infinity,
                //   height: 45,
                //   color: Color(0xFFF9F9F9),
                // ),
                _buildBottomNav(),
              ],
            ),
          ),

          // SOS button
          Positioned(
            bottom: 90,
            left: 16,
            child: _buildSOSButton(),
          ),

          // FAB image (sits above the notch)
          Positioned(
            bottom: 36,
            left: 0,
            right: 0,
            child: Center(child: _buildFAB()),
          ),

          // // Left lc.png decoration
          // Positioned(
          //   bottom: 65,
          //   left: MediaQuery.of(context).size.width * 0.322,
          //   child: Center(
          //     child: Image.asset(
          //       'assets/images/lc.png',
          //       width: 24,
          //       height: 24,
          //       fit: BoxFit.cover,
          //     ),
          //   ),
          // ),
          //
          // // Right lc.png decoration (flipped)
          // Positioned(
          //   bottom: 65,
          //   right: MediaQuery.of(context).size.width * 0.322,
          //   child: Transform(
          //     alignment: Alignment.center,
          //     transform: Matrix4.rotationY(3.1416),
          //     child: Center(
          //       child: Image.asset(
          //         'assets/images/lc.png',
          //         width: 24,
          //         height: 24,
          //         fit: BoxFit.cover,
          //       ),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildSchedulesSection();
      case 1:
        return _buildTripHistorySection();
      default:
        return _buildSchedulesSection();
    }
  }

  Widget _buildTripHistorySection() {
    const loginGreen = Color(0xFF3E9B73);
    const logoutMaroon = Color(0xFFB40D1A);
    const completedBlue = Color(0xFF2563EB);

    Widget dateRow(String label) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          dateRow('9th Mar, Monday'),
          _buildTripHistoryCard(
            cardId: 'th0',
            isLogin: true,
            time: '2:03 AM',
            status: _TripHistoryStatus.completed,
            accentLogin: loginGreen,
            accentLogout: logoutMaroon,
            completedBlue: completedBlue,
            onTap: (){
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TripSummaryScreen(),
                ),
              );
            }
          ),
          const SizedBox(height: 10),
          _buildTripHistoryCard(
            cardId: 'th1',
            isLogin: false,
            time: '6:30 PM',
            status: _TripHistoryStatus.noShow,
            accentLogin: loginGreen,
            accentLogout: logoutMaroon,
            completedBlue: completedBlue,
            onTap: (){}
          ),
          const SizedBox(height: 10),
          _buildTripHistoryCard(
            cardId: 'th2',
            isLogin: false,
            time: '7:15 PM',
            status: _TripHistoryStatus.cancelled,
            accentLogin: loginGreen,
            accentLogout: logoutMaroon,
            completedBlue: completedBlue,
            onTap: (){}
          ),
          dateRow('8th Mar, Monday'),
          _buildTripHistoryCard(
            cardId: 'th3',
            isLogin: true,
            time: '2:03 AM',
            status: _TripHistoryStatus.completed,
            accentLogin: loginGreen,
            accentLogout: logoutMaroon,
            completedBlue: completedBlue,
            onTap: (){
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TripSummaryScreen(),
                ),
              );
            }
          ),
          const SizedBox(height: 10),
          _buildTripHistoryCard(
            cardId: 'th4',
            isLogin: false,
            time: '5:45 PM',
            status: _TripHistoryStatus.completed,
            accentLogin: loginGreen,
            accentLogout: logoutMaroon,
            completedBlue: completedBlue,
            onTap: (){
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TripSummaryScreen(),
                ),
              );
            }
          ),
        ],
      ),
    );
  }

  Widget _buildTripHistoryCard({
    required String cardId,
    required bool isLogin,
    required String time,
    required _TripHistoryStatus status,
    required Color accentLogin,
    required Color accentLogout,
    required Color completedBlue,
    required void Function()? onTap
  }) {
    final accentColor = isLogin ? accentLogin : accentLogout;
    final Color tagBgColor =
        isLogin ? const Color(0xFFE8F5EE) : const Color(0xFFFFF0EE);
    final Color tagTextColor = accentColor;
    final IconData arrowIcon = isLogin ? Icons.login : Icons.logout;
    final label = isLogin ? 'Login' : 'Logout';
    final isExpanded = _tripHistoryExpanded.contains(cardId);

    late final String statusLabel;
    late final IconData statusIcon;
    late final Color statusColor;
    switch (status) {
      case _TripHistoryStatus.completed:
        statusLabel = 'Trip Completed';
        statusIcon = Icons.check_circle_outline;
        statusColor = completedBlue;
        break;
      case _TripHistoryStatus.noShow:
        statusLabel = 'No Show';
        statusIcon = Icons.error_outline;
        statusColor = const Color(0xFFDC2626);
        break;
      case _TripHistoryStatus.cancelled:
        statusLabel = 'Trip Cancelled';
        statusIcon = Icons.cancel_outlined;
        statusColor = const Color(0xFFDC2626);
        break;
    }

    void toggle() {
      setState(() {
        if (isExpanded) {
          _tripHistoryExpanded.remove(cardId);
        } else {
          _tripHistoryExpanded.add(cardId);
        }
      });
    }

    return InkWell(
      splashColor: Colors.transparent,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: accentColor, width: 4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                splashColor: Colors.transparent,
                onTap: toggle,
                child: Row(
                  children: [
                    Icon(arrowIcon, color: accentColor, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: tagTextColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: tagBgColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        time,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: tagTextColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Color(0xff596064),
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                splashColor: Colors.transparent,
                onTap: toggle,
                child: Row(
                  children: [
                    const SizedBox(width: 32),
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isExpanded) ...[
                const SizedBox(height: 14),
                Container(height: 1, color: const Color(0xFFE8E8E8)),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text(
                    'Route and timing details will appear here when connected to your trip data.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xff596064),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static const Color _tripHistoryPrimaryGreen = Color(0xFF1A6B3C);

  Widget _buildTripHistoryAppBar() {
    return Material(
      color: const Color(0xFFF5F5F4),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
          child: Row(
            children: [
              Builder(
                builder: (scaffoldContext) => IconButton(
                  icon: const Icon(Icons.menu, color: _tripHistoryPrimaryGreen, size: 26),
                  onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
                ),
              ),
              const Expanded(
                child: Text(
                  'Trip History',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _tripHistoryPrimaryGreen,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Filters coming soon')),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF444444),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                icon: const Icon(Icons.filter_list_rounded, size: 18),
                label: const Text(
                  'Filter',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    if (_selectedIndex == 1) {
      return _buildTripHistoryAppBar();
    }
    return Container(
      height: 150,
      child: Stack(
        children: [
          Image.asset(
            'assets/images/welcome_header.png',
            fit: BoxFit.cover,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Builder(                              // ← add this
                    builder: (scaffoldContext) => InkWell(
                      onTap: () {
                        Scaffold.of(scaffoldContext).openDrawer();  // ← use scaffoldContext
                      },
                      child: const Icon(Icons.menu, color: Colors.white, size: 26),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'HELLO,',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const Text(
                          'Mr. Yash',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    spacing: 16,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _openTransportAssistantChat,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.2),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.assistant_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.2),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.notification_add_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulesSection() {
    return BlocBuilder<TripHomeBloc, TripHomeState>(
      builder: (context, tripState) {
        return BlocBuilder<ScheduleHomeBloc, ScheduleHomeState>(
          builder: (context, scheduleState) {
            return RefreshIndicator(
              onRefresh: () async {
                context.read<TripHomeBloc>().add(const FetchTripHome());
                context
                    .read<ScheduleHomeBloc>()
                    .add(const FetchScheduleHome());
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'Schedules',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF222222),
                          ),
                        ),
                      ),
                    ),
                    _buildHomeTripAndScheduleBody(
                      context,
                      tripState,
                      scheduleState,
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

  Widget _buildHomeTripAndScheduleBody(
    BuildContext context,
    TripHomeState tripState,
    ScheduleHomeState scheduleState,
  ) {
    if (tripState is TripHomeUnauthorized) {
      return _buildSchedulesEmptyState(
        title: 'Session expired',
        subtitle: tripState.message,
        onRetry: () => Navigator.of(context, rootNavigator: true)
            .pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MobileNoVerification()),
          (route) => false,
        ),
        retryLabel: 'Sign in again',
      );
    }
    if (scheduleState is ScheduleHomeUnauthorized) {
      return _buildSchedulesEmptyState(
        title: 'Session expired',
        subtitle: scheduleState.message,
        onRetry: () => Navigator.of(context, rootNavigator: true)
            .pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MobileNoVerification()),
          (route) => false,
        ),
        retryLabel: 'Sign in again',
      );
    }

    final tripLoading =
        tripState is TripHomeLoading || tripState is TripHomeInitial;
    final scheduleLoading = scheduleState is ScheduleHomeLoading ||
        scheduleState is ScheduleHomeInitial;

    if (tripLoading && scheduleLoading) {
      return _buildSectionLoader();
    }

    final children = <Widget>[];

    if (tripLoading) {
      children.add(_buildSectionLoader(compact: true));
    } else if (tripState is TripHomeError) {
      children.add(
        _buildSchedulesEmptyState(
          title: 'Could not load active trips',
          subtitle: tripState.message,
          onRetry: () =>
              context.read<TripHomeBloc>().add(const FetchTripHome()),
          retryLabel: 'Retry',
        ),
      );
    } else if (tripState is TripHomeLoaded) {
      final tripCards = _buildTripHomeGroupWidgets(tripState.groups);
      if (tripCards.isNotEmpty) {
        children.add(_buildSubsectionLabel('Active Trips'));
        children.addAll(tripCards);
        children.add(const SizedBox(height: 16));
      }
    }

    if (scheduleLoading) {
      children.add(_buildSectionLoader(compact: true));
    } else if (scheduleState is ScheduleHomeError) {
      children.add(
        _buildSchedulesEmptyState(
          title: 'Could not load schedules',
          subtitle: scheduleState.message,
          onRetry: () => context
              .read<ScheduleHomeBloc>()
              .add(const FetchScheduleHome()),
          retryLabel: 'Retry',
        ),
      );
    } else if (scheduleState is ScheduleHomeLoaded) {
      final scheduleCards =
          _buildScheduleGroupWidgets(scheduleState.groups);
      if (scheduleCards.isNotEmpty) {
        children.add(_buildSubsectionLabel('Scheduled'));
        children.addAll(scheduleCards);
      }
    }

    if (children.isEmpty) {
      return _buildSchedulesEmptyState(
        title: 'No schedules yet',
        subtitle:
            'You have no active trips or scheduled rides. Pull down to refresh.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildSubsectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A6B3C),
        ),
      ),
    );
  }

  Widget _buildSectionLoader({bool compact = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 20 : 40),
      child: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A6B3C)),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTripHomeGroupWidgets(List<TripDayGroup> groups) {
    final widgets = <Widget>[];

    for (final group in groups) {
      if (group.data.isEmpty) continue;

      final groupCards = <Widget>[];
      for (var i = 0; i < group.data.length; i++) {
        final item = group.data[i];
        final typeKey = (item.tripType ?? 'trip').toLowerCase();
        final key = 'trip_${group.dayName ?? "_"}_${typeKey}_$i';
        groupCards.add(_buildTripCard(
          item: item,
          isExpanded: _tripExpanded.contains(key),
          onTap: () => _toggleTripExpansion(key),
        ));
        groupCards.add(const SizedBox(height: 10));
      }

      if (groupCards.last is SizedBox) {
        groupCards.removeLast();
      }

      widgets.add(_buildTripDateHeader(group));
      widgets.add(const SizedBox(height: 12));
      widgets.addAll(groupCards);
      widgets.add(const SizedBox(height: 8));
    }

    return widgets;
  }

  Widget _buildTripDateHeader(TripDayGroup group) {
    final headerDate = _resolveTripGroupHeaderDate(group);
    final relativeLabel = (group.dayName?.trim().isNotEmpty ?? false)
        ? group.dayName!.trim()
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            headerDate ?? (relativeLabel ?? ''),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          if (relativeLabel != null)
            Text(
              relativeLabel,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
        ],
      ),
    );
  }

  Widget _buildSchedulesEmptyState({
    required String title,
    required String subtitle,
    VoidCallback? onRetry,
    String retryLabel = 'Retry',
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1A6B3C),
                side: const BorderSide(color: Color(0xFFB8DEC9)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Text(retryLabel),
            ),
          ],
        ],
      ),
    );
  }

  void _toggleTripExpansion(String key) {
    setState(() {
      if (_tripExpanded.contains(key)) {
        _tripExpanded.remove(key);
      } else {
        _tripExpanded.add(key);
      }
    });
  }

  void _toggleScheduleExpansion(String key) {
    setState(() {
      if (_scheduleExpanded.contains(key)) {
        _scheduleExpanded.remove(key);
      } else {
        _scheduleExpanded.add(key);
      }
    });
  }

  // ─── Date / time helpers ───────────────────────────────────────────────────

  static const List<String> _monthAbbrev = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const Map<String, int> _monthIndex = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  static const List<String> _weekdayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  String? _resolveTripGroupHeaderDate(TripDayGroup group) {
    DateTime? candidate;
    for (final item in group.data) {
      candidate ??= _parseScheduleDate(item.tripDate);
      if (candidate != null) break;
    }
    if (candidate == null) {
      final tag = group.dayName?.toLowerCase().trim();
      final now = DateTime.now();
      if (tag == 'today') {
        candidate = DateTime(now.year, now.month, now.day);
      } else if (tag == 'tomorrow') {
        final tmrw = now.add(const Duration(days: 1));
        candidate = DateTime(tmrw.year, tmrw.month, tmrw.day);
      }
    }
    if (candidate == null) return null;
    return _formatHeaderDate(candidate);
  }

  List<String> _otpDigits(String? otp) {
    final cleaned = (otp ?? '').trim();
    if (cleaned.isEmpty) {
      return const ['—', '—', '—', '—'];
    }
    final chars = cleaned.split('');
    while (chars.length < 4) {
      chars.add('—');
    }
    return chars.take(4).toList(growable: false);
  }

  ({IconData icon, Color color}) _tripStatusStyle(
    String? statusName,
    bool isLogin,
  ) {
    final status = (statusName ?? '').trim().toLowerCase();
    final accent = isLogin ? const Color(0xFF3E9B73) : const Color(0xFFB40D1A);
    if (status == 'scheduled') {
      return (icon: Icons.access_time, color: const Color(0xFF596064));
    }
    if (status.contains('start') || status.contains('board')) {
      return (icon: Icons.check_circle_outline, color: accent);
    }
    if (status == 'printed' || status.contains('alloc')) {
      return (icon: Icons.check_circle_outline, color: accent);
    }
    return (icon: Icons.info_outline, color: accent);
  }

  String? _plannedPickupLabel(TripHomeItem item) {
    final pickTime = item.pickTime?.trim();
    if (pickTime != null && pickTime.isNotEmpty) {
      return _formatShiftTime(pickTime) ?? pickTime;
    }
    return _formatShiftTime(item.pickShift);
  }

  /// Parses dates in the format the backend ships, e.g. `"21-May-2026"`.
  DateTime? _parseScheduleDate(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final parts = trimmed.split('-');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = _monthIndex[parts[1].toLowerCase()];
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  String _formatHeaderDate(DateTime d) {
    final dayOrd = _ordinalSuffix(d.day);
    final month = _monthAbbrev[d.month - 1];
    final weekday = _weekdayNames[(d.weekday - 1) % 7];
    return '${d.day}$dayOrd $month, $weekday';
  }

  String _ordinalSuffix(int n) {
    if (n >= 11 && n <= 13) return 'th';
    switch (n % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  /// Renders one address line for the expanded trip-detail view.
  ///
  /// The full address is broken into a primary segment (first comma chunk)
  /// and a secondary segment (the remainder) so we keep the same two-line
  /// visual rhythm the design uses, while still showing real backend data.
  Widget _buildAddressBlock({
    required String label,
    required String? address,
  }) {
    final cleaned = address?.trim();
    final hasAddress = cleaned != null && cleaned.isNotEmpty;
    String title;
    String? subtitle;
    if (hasAddress) {
      final idx = cleaned.indexOf(',');
      if (idx < 0) {
        title = cleaned;
        subtitle = null;
      } else {
        title = cleaned.substring(0, idx).trim();
        final rest = cleaned.substring(idx + 1).trim();
        subtitle = rest.isEmpty ? null : rest;
      }
      if (title.isEmpty) title = cleaned;
    } else {
      title = 'Address not available';
      subtitle = null;
    }

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
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: hasAddress
                ? const Color(0xFF2C3437)
                : const Color(0xFF9AA0A6),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xff596064),
            ),
          ),
        ],
      ],
    );
  }

  /// Converts the backend's 24-hour shift time (e.g. `"09:45"`, `"00:00"`)
  /// into the 12-hour format used on the card (`"9:45 AM"`, `"12:00 AM"`).
  /// Returns `null` if the input is null/empty/unparseable.
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

  List<Widget> _buildScheduleGroupWidgets(List<ScheduleDateGroup> groups) {
    final widgets = <Widget>[];

    for (final group in groups) {
      // Find the visible cards in this group first; if there are none we
      // skip the heading too (cleaner UX than a dangling date label).
      final groupCards = <Widget>[];
      for (var i = 0; i < group.data.length; i++) {
        final item = group.data[i];
        if (item.shouldShowLoginCard) {
          final key = '${group.dateIn ?? "_"}_login_$i';
          groupCards.add(_buildScheduleCard(
            type: 'login',
            label: 'Login',
            time: _formatShiftTime(item.loginShiftTime) ?? '--:--',
            isExpanded: _scheduleExpanded.contains(key),
            onTap: () => _toggleScheduleExpansion(key),
            isScheduled: item.isScheduledStatus,
            item: item,
          ));
          groupCards.add(const SizedBox(height: 10));
        }
        if (item.shouldShowLogoutCard) {
          final key = '${group.dateIn ?? "_"}_logout_$i';
          groupCards.add(_buildScheduleCard(
            type: 'logout',
            label: 'Logout',
            time: _formatShiftTime(item.logoutShiftTime) ?? '--:--',
            isExpanded: _scheduleExpanded.contains(key),
            onTap: () => _toggleScheduleExpansion(key),
            isScheduled: item.isScheduledStatus,
            item: item,
          ));
          groupCards.add(const SizedBox(height: 10));
        }

        // Fallback: API row with status but no date/shift fields (common for "Today").
        if (!item.shouldShowLoginCard &&
            !item.shouldShowLogoutCard &&
            item.isScheduledStatus) {
          final key = '${group.dateIn ?? "_"}_login_$i';
          groupCards.add(_buildScheduleCard(
            type: 'login',
            label: 'Login',
            time: _formatShiftTime(item.loginShiftTime) ?? '--:--',
            isExpanded: _scheduleExpanded.contains(key),
            onTap: () => _toggleScheduleExpansion(key),
            isScheduled: true,
            item: item,
          ));
          groupCards.add(const SizedBox(height: 10));
        }
      }

      if (groupCards.isEmpty) continue;

      // Trim trailing spacer.
      if (groupCards.last is SizedBox) {
        groupCards.removeLast();
      }

      widgets.add(_buildScheduleDateHeader(group));
      widgets.add(const SizedBox(height: 12));
      widgets.addAll(groupCards);
      widgets.add(const SizedBox(height: 8));
    }

    return widgets;
  }

  Widget _buildScheduleDateHeader(ScheduleDateGroup group) {
    final headerDate = _resolveGroupHeaderDate(group);
    final relativeLabel = (group.dateIn?.trim().isNotEmpty ?? false)
        ? group.dateIn!.trim()
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            headerDate ?? (relativeLabel ?? ''),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          if (relativeLabel != null)
            Text(
              relativeLabel,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard({
    required String type,
    required String label,
    required String time,
    required bool isExpanded,
    required VoidCallback onTap,
    required ScheduleItem item,
    bool isScheduled = false,
  }) {
    final bool isLogin = type == 'login';
    final Color accentColor =
    isLogin ? const Color(0xFF3E9B73) : const Color(0xFFB40D1A);
    final Color allocatedStatusColor =
    isLogin ? const Color(0xFFE0A309) : const Color(0xFFB40D1A);
    final Color scheduledStatusColor = const Color(0xFF596064);
    final Color statusColor =
        isScheduled ? scheduledStatusColor : allocatedStatusColor;
    final Color tagBgColor =
    isLogin ? const Color(0xFFE8F5EE) : const Color(0xFFFFF0EE);
    final Color tagTextColor =
    isLogin ? const Color(0xFF3E9B73) : const Color(0xFFB40D1A);
    final IconData arrowIcon = isLogin ? Icons.login : Icons.logout;
    final IconData statusIcon =
        isScheduled ? Icons.access_time : Icons.check_circle_outline;
    final String statusLabel = isScheduled ? 'Scheduled' : 'Vehicle Allocated';
    final List<String> otpDigits = ['3', '3', '3', '3'];

    // ─── Disabled "Track Vehicle" styling when in Scheduled state ─────────
    final Color trackBg =
        isScheduled ? const Color(0xFFF1F1F1) : tagBgColor;
    final Color trackFg =
        isScheduled ? const Color(0xFFB0B0B0) : accentColor;
    final VoidCallback? trackVehicleAction = isScheduled
        ? null
        : () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RideTrackingScreen(),
              ),
            );
          };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accentColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              splashColor: Colors.transparent,
              onTap: onTap,
              child: Row(
                children: [
                  Icon(arrowIcon, color: accentColor, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: tagTextColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: tagBgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      time,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: tagTextColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xff596064),
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            InkWell(
              splashColor: Colors.transparent,
              onTap: onTap,
              child: Row(
                children: [
                  const SizedBox(width: 32),
                  Icon(statusIcon, size: 13, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (isExpanded) ...[
              const SizedBox(height: 14),
              Container(height: 1, color: const Color(0xFFE8E8E8)),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'TRIP DETAIL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff596064),
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
                          // Pickup:
                          //   Login  → user's home (UserAddress)
                          //   Logout → office (OfficeAddress)
                          _buildAddressBlock(
                            label: 'PICKUP',
                            address: isLogin
                                ? item.userAddress
                                : item.officeAddress,
                          ),
                          const SizedBox(height: 20),
                          // Drop:
                          //   Login  → office (OfficeAddress)
                          //   Logout → user's home (UserAddress)
                          _buildAddressBlock(
                            label: 'DROP',
                            address: isLogin
                                ? item.officeAddress
                                : item.userAddress,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ─── Planned Pickup + Vehicle Info (hidden when "Scheduled") ──
              if (!isScheduled) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE8E8E8)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Planned Pickup',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xff6B7280),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '06:42 AM',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE8E8E8)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vehicle Info.',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xff6B7280),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'HR-55-AW-0640',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              // ─── Boarding OTP (hidden when "Scheduled") ───────────────────
              if (!isScheduled) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE8E8E8)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Boarding OTP',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xff6B7280),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: otpDigits
                            .map(
                              (digit) => Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F3ED),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              digit,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF002D1C),
                              ),
                            ),
                          ),
                        )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  InkWell(
                    splashColor: Colors.transparent,
                    onTap: () {
                      _showCancelRideDialog(
                        context,
                        isLogin: isLogin,
                        item: item,
                      );
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x33BA1A1A)),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Color(0xFFBA1A1A),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    splashColor: Colors.transparent,
                    onTap: () {
                      _openEditRoster(
                        context,
                        isLogin: isLogin,
                        item: item,
                      );
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE8E8E8)),
                      ),
                      child: Icon(
                        Icons.edit_outlined,
                        color: Colors.grey[600],
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Opacity(
                      opacity: isScheduled ? 0.6 : 1.0,
                      child: GestureDetector(
                        onTap: trackVehicleAction,
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: trackBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.my_location, size: 16, color: trackFg),
                              const SizedBox(width: 6),
                              Text(
                                'Track Vehicle',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: trackFg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (!isScheduled) ...[
              // ─── Collapsed details: OTP + Track Vehicle (Vehicle Allocated) ─
              const SizedBox(height: 12),
              Container(height: 1, color: const Color(0xFFE8E8E8)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 30.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Boarding OTP',
                            style: TextStyle(
                              fontSize: 9,
                              color: Color(0xFF282828),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: otpDigits
                                .map(
                                  (digit) => Container(
                                margin: const EdgeInsets.only(right: 6),
                                width: 23,
                                height: 23,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE6F3ED),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  digit,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF002D1C),
                                  ),
                                ),
                              ),
                            )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(0.0, 10.0),
                      child: GestureDetector(
                        onTap: trackVehicleAction,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: tagBgColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.my_location,
                                  size: 16, color: accentColor),
                              const SizedBox(width: 6),
                              Text(
                                'Track Vehicle',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }


  /// Tries to derive a friendly header date for schedule groups.
  String? _resolveGroupHeaderDate(ScheduleDateGroup group) {
    DateTime? candidate;
    for (final item in group.data) {
      candidate ??= _parseScheduleDate(item.loginScheduleDate);
      candidate ??= _parseScheduleDate(item.logoutScheduleDate);
      if (candidate != null) break;
    }
    if (candidate == null) {
      final tag = group.dateIn?.toLowerCase().trim();
      final now = DateTime.now();
      if (tag == 'today') {
        candidate = DateTime(now.year, now.month, now.day);
      } else if (tag == 'tomorrow') {
        final tmrw = now.add(const Duration(days: 1));
        candidate = DateTime(tmrw.year, tmrw.month, tmrw.day);
      }
    }
    if (candidate == null) return null;
    return _formatHeaderDate(candidate);
  }

  Widget _buildTripCard({
    required TripHomeItem item,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    final bool isLogin = item.isLogin;
    final String label = item.tripType ?? (isLogin ? 'Login' : 'Logout');
    final String time = _formatShiftTime(item.pickShift) ?? '--:--';
    final bool isScheduled = item.isScheduledStatus;
    final statusStyle = _tripStatusStyle(item.tripStatusName, isLogin);
    final Color accentColor =
        isLogin ? const Color(0xFF3E9B73) : const Color(0xFFB40D1A);
    final Color statusColor = statusStyle.color;
    final Color tagBgColor =
        isLogin ? const Color(0xFFE8F5EE) : const Color(0xFFFFF0EE);
    final Color tagTextColor =
        isLogin ? const Color(0xFF3E9B73) : const Color(0xFFB40D1A);
    final IconData arrowIcon = isLogin ? Icons.login : Icons.logout;
    final IconData statusIcon = statusStyle.icon;
    final String statusLabel = item.tripStatusName ?? '—';
    final List<String> otpDigits = _otpDigits(item.otp);
    final plannedPickup = _plannedPickupLabel(item) ?? '--:--';
    final vehicleLabel = (item.vehicleInfo?.trim().isNotEmpty ?? false)
        ? item.vehicleInfo!.trim()
        : 'Not assigned';
    final seqLabel = (item.paxOrder != null && item.paxCount != null)
        ? 'Seq: ${item.paxOrder}/${item.paxCount}'
        : null;
    final ivr = item.userAppIvrNumber?.trim();

    // ─── Disabled "Track Vehicle" styling when in Scheduled state ─────────
    final Color trackBg =
        isScheduled ? const Color(0xFFF1F1F1) : tagBgColor;
    final Color trackFg =
        isScheduled ? const Color(0xFFB0B0B0) : accentColor;
    final VoidCallback? trackVehicleAction = isScheduled
        ? null
        : () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RideTrackingScreen(),
              ),
            );
          };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accentColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              splashColor: Colors.transparent,
              onTap: onTap,
              child: Row(
                children: [
                  Icon(arrowIcon, color: accentColor, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: tagTextColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: tagBgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      time,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: tagTextColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xff596064),
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            InkWell(
              splashColor: Colors.transparent,
              onTap: onTap,
              child: Row(
                children: [
                  const SizedBox(width: 32),
                  Icon(statusIcon, size: 13, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (isExpanded) ...[
              const SizedBox(height: 14),
              Container(height: 1, color: const Color(0xFFE8E8E8)),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'TRIP DETAIL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff596064),
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
                          // Pickup:
                          //   Login  → user's home (UserAddress)
                          //   Logout → office (OfficeAddress)
                          _buildAddressBlock(
                            label: 'PICKUP',
                            address: isLogin
                                ? item.userAddress
                                : item.officeAddress,
                          ),
                          const SizedBox(height: 20),
                          _buildAddressBlock(
                            label: 'DROP',
                            address: isLogin
                                ? item.officeAddress
                                : item.userAddress,
                          ),
                          if (seqLabel != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.event_seat_outlined,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  seqLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xff596064),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isScheduled) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE8E8E8)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Planned Pickup',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xff6B7280),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              plannedPickup,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE8E8E8)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Vehicle Info.',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xff6B7280),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    vehicleLabel,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (ivr != null && ivr.isNotEmpty)
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: tagBgColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.phone,
                                  size: 18,
                                  color: accentColor,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              // ─── Boarding OTP (hidden when "Scheduled") ───────────────────
              if (!isScheduled) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE8E8E8)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Boarding OTP',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xff6B7280),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: otpDigits
                            .map(
                              (digit) => Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F3ED),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              digit,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF002D1C),
                              ),
                            ),
                          ),
                        )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Opacity(
                      opacity: isScheduled ? 0.6 : 1.0,
                      child: GestureDetector(
                        onTap: trackVehicleAction,
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: trackBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.my_location, size: 16, color: trackFg),
                              const SizedBox(width: 6),
                              Text(
                                'Track Vehicle',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: trackFg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (!isScheduled) ...[
              // ─── Collapsed details: OTP + Track Vehicle (Vehicle Allocated) ─
              const SizedBox(height: 12),
              Container(height: 1, color: const Color(0xFFE8E8E8)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 30.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Boarding OTP',
                            style: TextStyle(
                              fontSize: 9,
                              color: Color(0xFF282828),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: otpDigits
                                .map(
                                  (digit) => Container(
                                margin: const EdgeInsets.only(right: 6),
                                width: 23,
                                height: 23,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE6F3ED),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  digit,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF002D1C),
                                  ),
                                ),
                              ),
                            )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(0.0, 10.0),
                      child: GestureDetector(
                        onTap: trackVehicleAction,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: tagBgColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.my_location,
                                  size: 16, color: accentColor),
                              const SizedBox(width: 6),
                              Text(
                                'Track Vehicle',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSOSButton() {
    return GestureDetector(
      onTap: () {},
      child: Image.asset(
        'assets/images/sos.png',
        width: 67,
        height: 67,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildFAB() {
    const fabSize = 100.0;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TripDetailsScreen(),
          ),
        );
      },
      child: SizedBox(
        width: fabSize,
        height: fabSize,
        child: Image.asset(
          'assets/images/welcome_add.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    // The FAB image is 115px tall, positioned bottom: 28
    // So it overlaps the nav bar by roughly: 115 - 28 = 87px from bottom
    // Nav bar height is 86, so the notch needs to accommodate ~57px wide circle
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
                                ? const Color(0xFF1A6B3C)
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
                                  ? const Color(0xFF1A6B3C)
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
                onTap: () => setState(() => _selectedIndex = 1),
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
                                ? const Color(0xFF1A6B3C)
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
                                  ? const Color(0xFF1A6B3C)
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

class _LowerSemicircleBorderPainter extends CustomPainter {
  _LowerSemicircleBorderPainter({
    required this.color,
    required this.strokeWidth,
  });

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, (size.height / 2) + 10);
    final radius = size.shortestSide / 2.3 - strokeWidth / 2.3;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect, 0, pi, false, paint);
  }

  @override
  bool shouldRepaint(covariant _LowerSemicircleBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}


class CancelRideDialog extends StatelessWidget {
  const CancelRideDialog({
    super.key,
    required this.isLogin,
    required this.locCode,
    required this.empId,
    required this.scheduleDate,
  });

  final bool isLogin;
  final int locCode;
  final String empId;
  final String scheduleDate;

  /// TripType: "1" = Login (pickup), "2" = Logout (drop).
  String get _tripType => isLogin ? '1' : '2';

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ShiftBloc>(
      create: (_) => sl<ShiftBloc>(),
      child: _CancelRideDialogView(
        isLogin: isLogin,
        locCode: locCode,
        empId: empId,
        scheduleDate: scheduleDate,
        tripType: _tripType,
      ),
    );
  }
}

class _CancelRideDialogView extends StatelessWidget {
  const _CancelRideDialogView({
    required this.isLogin,
    required this.locCode,
    required this.empId,
    required this.scheduleDate,
    required this.tripType,
  });

  final bool isLogin;
  final int locCode;
  final String empId;
  final String scheduleDate;
  final String tripType;

  void _showSnackBar(BuildContext context, String message,
      {required bool error}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              error ? const Color(0xFFB40D1A) : const Color(0xFF1A5C38),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ShiftBloc, ShiftState>(
      listenWhen: (prev, curr) =>
          curr is ShiftCancelSuccess ||
          curr is ShiftCancelError ||
          curr is ShiftUnauthorized,
      listener: (context, state) {
        if (state is ShiftCancelSuccess) {
          Navigator.of(context).pop(true);
          _showSnackBar(context, state.message, error: false);
        } else if (state is ShiftCancelError) {
          _showSnackBar(context, state.message, error: true);
        } else if (state is ShiftUnauthorized) {
          Navigator.of(context).pop(false);
          _showSnackBar(context, state.message, error: true);
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MobileNoVerification()),
            (route) => false,
          );
        }
      },
      buildWhen: (prev, curr) =>
          curr is ShiftInitial ||
          curr is ShiftCancelInProgress ||
          curr is ShiftCancelSuccess ||
          curr is ShiftCancelError ||
          curr is ShiftUnauthorized,
      builder: (context, state) {
        final isCancelling = state is ShiftCancelInProgress;
        return PopScope(
          canPop: !isCancelling,
          child: Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Warning icon circle
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF0EE),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xffBA1A1A),
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    isLogin
                        ? 'Cancel this Login ride?'
                        : 'Cancel this Logout ride?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xff181C1B),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Subtitle
                  const Text(
                    'Are you sure you want to cancel your trip? You might be charged a cancellation fee.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF888888),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Buttons row
                  Row(
                    children: [
                      // Cancel Ride button — fires the CancelSchedules API.
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFCC2222),
                            side: const BorderSide(
                              color: Color(0xFFFFCCCC),
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                          ),
                          onPressed: isCancelling
                              ? null
                              : () {
                                  debugPrint(
                                    '[WELCOME] CancelRideDialog → '
                                    'dispatching CancelSchedule '
                                    'locCode=$locCode empId="$empId" '
                                    'scheduleDate="$scheduleDate" '
                                    'tripType="$tripType" (isLogin=$isLogin)',
                                  );
                                  context.read<ShiftBloc>().add(
                                        CancelSchedule(
                                          locCode: locCode,
                                          empId: empId,
                                          scheduleDate: scheduleDate,
                                          tripType: tripType,
                                        ),
                                      );
                                },
                          child: isCancelling
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Color(0xFFCC2222),
                                  ),
                                )
                              : const Text(
                                  'Cancel Ride',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Keep Ride button (filled, dark green)
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A5C38),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                          ),
                          onPressed: isCancelling
                              ? null
                              : () => Navigator.of(context).pop(false),
                          child: const Text(
                            'Keep Ride',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
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
      },
    );
  }
}


class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, this.onTripHistoryTap});

  final VoidCallback? onTripHistoryTap;

  void _showLogoutDialog(BuildContext context) {
    Navigator.pop(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF0EE),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFBA1A1A),
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Logout?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xff181C1B),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Are you sure you want to logout from your account?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF888888),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFCC2222),
                        side: const BorderSide(
                          color: Color(0xFFFFCCCC),
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                      onPressed: () async {
                        await sl<AuthLocalStorage>().clearAuthData();
                        if (!dialogContext.mounted) return;
                        Navigator.of(dialogContext, rootNavigator: true)
                            .pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const MobileNoVerification(),
                          ),
                          (route) => false,
                        );
                      },
                      child: const Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A5C38),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
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

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 310,
      backgroundColor: Colors.white,
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────
              _DrawerHeader(),

              const Divider(height: 1, color: Color(0xFFE0E0E0)),

              // ── Environmental Impact Card ────────────────────────────
              _EnvironmentalCard(),

              const SizedBox(height: 8),

              // ── MY SCHEDULE section ──────────────────────────────────
              _SectionLabel('MY SCHEDULE'),
              _DrawerItem(
                icon: Icons.calendar_today_outlined,
                label: 'Create Schedule',
                onTap: () => Navigator.pop(context),
              ),
              _DrawerItem(
                icon: Icons.calendar_month_outlined,
                label: 'Weekly Offs',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WeeklyOffScreen(),
                  ),
                ),
              ),
              _DrawerItem(
                icon: Icons.history,
                label: 'Trip History',
                onTap: () => onTripHistoryTap?.call(),
              ),
              _DrawerItem(
                icon: Icons.people_outline,
                label: 'Team Cab',
                onTap: () => Navigator.pop(context),
              ),

              const SizedBox(height: 4),

              // ── MY ACCOUNT section ───────────────────────────────────
              _SectionLabel('MY ACCOUNT'),
              _DrawerItem(
                icon: Icons.home_outlined,
                label: 'Request Address Change',
                onTap: () => Navigator.pop(context),
              ),

              const SizedBox(height: 4),

              // ── SAFETY section ───────────────────────────────────────
              _SectionLabel('SAFETY'),
              _DrawerItem(
                icon: Icons.shield_outlined,
                label: 'Women Safety',
                onTap: () => Navigator.pop(context),
                iconColor: const Color(0xFFE53935),
                iconBgColor: const Color(0xFFFCECEC),
              ),

              const SizedBox(height: 4),

              // ── SUPPORT section ──────────────────────────────────────
              _SectionLabel('SUPPORT'),
              _DrawerItem(
                icon: Icons.headset_mic_outlined,
                label: 'Call Help Desk',
                onTap: () => Navigator.pop(context),
              ),
              _DrawerItem(
                icon: Icons.directions_bus_outlined,
                label: 'Contact Travel Desk',
                onTap: () => Navigator.pop(context),
              ),
              _DrawerItem(
                icon: Icons.quiz_outlined,
                label: "FAQ's",
                onTap: () => Navigator.pop(context),
              ),

              const SizedBox(height: 4),

              // ── APP section ──────────────────────────────────────────
              _SectionLabel('APP'),
              _DrawerItem(
                icon: Icons.feedback_outlined,
                label: 'App Feedback',
                onTap: () => Navigator.pop(context),
              ),
              _DrawerItem(
                icon: Icons.star_outline,
                label: 'Rate This App',
                onTap: () => Navigator.pop(context),
              ),

              const SizedBox(height: 4),

              // ── ACCOUNT section ──────────────────────────────────────────────
              _SectionLabel('ACCOUNT'),
              _DrawerItem(
                icon: Icons.logout_rounded,
                label: 'Logout',
                iconColor: const Color(0xFFBA1A1A),
                iconBgColor: const Color(0xFFFFF0EE),
                onTap: () => _showLogoutDialog(context),
              ),

              if (kDebugMode) ...[
                const SizedBox(height: 4),
                _SectionLabel('DEBUG'),
                _DrawerItem(
                  icon: Icons.receipt_long_outlined,
                  label: 'API Logger',
                  iconColor: const Color(0xFF9C27B0),
                  iconBgColor: const Color(0xFFF3E5F5),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ApiLoggerScreen(),
                      ),
                    );
                  },
                ),
              ],

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header Widget ────────────────────────────────────────────────────────────

class _DrawerHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Avatar
          InkWell(
            splashColor: Colors.transparent,
            onTap: (){
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(),
                ),
              );
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE8F5F0),
                border: Border.all(color: const Color(0xFF8DCFB8), width: 2),
              ),
              child: const Icon(
                Icons.person_outline,
                color: Color(0xFF8DCFB8),
                size: 30,
              ),
            ),
          ),
          const SizedBox(width: 14),
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Yash Khare',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'EMP ID: 450921',
                  style: TextStyle(fontSize: 13, color: Color(0xFF555555)),
                ),
                Text(
                  'Office : D21',
                  style: TextStyle(fontSize: 13, color: Color(0xFF555555)),
                ),
              ],
            ),
          ),
          // Close / back icon
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Color(0xFF555555)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

// ── Environmental Impact Card ────────────────────────────────────────────────

class _EnvironmentalCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A7A5E),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'ENVIRONMENTAL IMPACT',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '18.4 ',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'kg carbon saved',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF27A87A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.eco, color: Colors.white, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section Label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 18, top: 14, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF999999),
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}

// ── Drawer Menu Item ─────────────────────────────────────────────────────────

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;
  final Color iconBgColor;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = const Color(0xFF1A7A5E),
    this.iconBgColor = const Color(0xFFE8F5F0),
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      splashColor: const Color(0xFFE8F5F0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              // Label
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              // Chevron
              const Icon(
                Icons.chevron_right,
                color: Color(0xFFBBBBBB),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}