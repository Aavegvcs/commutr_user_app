import 'dart:async';
import 'dart:io';
import 'dart:math' show pi;

import 'package:commutr_main/features/trip_detail/data/model/app_control_settings_response.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:in_app_review/in_app_review.dart';

import 'package:url_launcher/url_launcher.dart';

import 'package:commutr_main/core/debug/api_logger_screen.dart';
import 'package:commutr_main/features/trip_detail/bloc/board_trip/board_trip_bloc.dart';
import 'package:commutr_main/features/trip_detail/bloc/board_trip/board_trip_event.dart';
import 'package:commutr_main/features/trip_detail/bloc/board_trip/board_trip_state.dart';
import 'package:commutr_main/features/trip_detail/bloc/cancel_trip/cancel_trip_bloc.dart';
import 'package:commutr_main/features/trip_detail/bloc/cancel_trip/cancel_trip_event.dart';
import 'package:commutr_main/features/trip_detail/bloc/cancel_trip/cancel_trip_state.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:commutr_main/core/di/injection.dart';
import 'package:commutr_main/core/services/dynamic_app_icon/dynamic_app_icon_coordinator.dart';
import 'package:commutr_main/core/utils/error_message.dart';
import 'package:commutr_main/core/storage/auth_local_storage.dart';
import 'package:commutr_main/features/auth/presentation/screens/mobile_no_verification.dart';
import 'package:commutr_main/features/trip_detail/bloc/app_control/app_control_bloc.dart';
import 'package:commutr_main/features/trip_detail/bloc/app_control/app_control_event.dart';
import 'package:commutr_main/features/trip_detail/bloc/app_control/app_control_state.dart';
import 'package:commutr_main/features/trip_detail/bloc/user_app_config/user_app_config_bloc.dart';
import 'package:commutr_main/features/trip_detail/bloc/user_app_config/user_app_config_event.dart';
import 'package:commutr_main/features/trip_detail/bloc/user_app_config/user_app_config_state.dart';
import 'package:commutr_main/features/trip_detail/data/model/user_app_configuration_response.dart';
import 'package:commutr_main/features/trip_detail/bloc/roaster_bloc.dart';
import 'package:commutr_main/features/trip_detail/bloc/roaster_event.dart';
import 'package:commutr_main/features/trip_detail/bloc/roaster_state.dart';
import 'package:commutr_main/features/trip_detail/data/model/user_details_roaster_response.dart';
import 'package:commutr_main/features/trip_detail/bloc/trip_history_bloc.dart';
import 'package:commutr_main/features/trip_detail/bloc/trip_history_event.dart';
import 'package:commutr_main/features/trip_detail/bloc/trip_history_state.dart';
import 'package:commutr_main/features/trip_detail/data/model/trip_history_response.dart';
import 'package:commutr_main/features/trip_detail/bloc/schedule_home_bloc.dart';
import 'package:commutr_main/features/trip_detail/bloc/schedule_home_event.dart';
import 'package:commutr_main/features/trip_detail/bloc/schedule_home_state.dart';
import 'package:commutr_main/features/trip_detail/bloc/trip_home_bloc.dart';
import 'package:commutr_main/features/trip_detail/bloc/trip_home_event.dart';
import 'package:commutr_main/features/trip_detail/bloc/trip_home_state.dart';
import 'package:commutr_main/features/trip_detail/bloc/shift_bloc.dart';
import 'package:commutr_main/features/trip_detail/bloc/shift_event.dart';
import 'package:commutr_main/features/trip_detail/bloc/shift_state.dart';
import 'package:commutr_main/features/trip_detail/data/model/cancel_schedule_confirmation_response.dart';
import 'package:commutr_main/features/trip_detail/data/model/schedule_home_response.dart';
import 'package:commutr_main/features/trip_detail/data/model/trip_home_response.dart';
import 'package:commutr_main/features/trip_detail/model/trip_schedule_flow_args.dart';
import 'package:commutr_main/profile/bloc/profile_bloc.dart';
import 'package:commutr_main/profile/bloc/profile_event.dart';
import 'package:commutr_main/profile/bloc/profile_state.dart';
import 'package:commutr_main/profile/presentation/screen/profile.dart';
import 'package:commutr_main/ride_tracking/bloc/cab_tracking_bloc.dart';
import 'package:commutr_main/ride_tracking/bloc/cab_tracking_event.dart';
import 'package:commutr_main/ride_tracking/config/tracking_config.dart';
import 'package:commutr_main/ride_tracking/service/dummy_tracking_service.dart';
import 'package:commutr_main/ride_tracking/ride_tracking.dart';
import 'package:commutr_main/ride_tracking/service/ivr_call_repo.dart';
import 'package:commutr_main/trip_summary/trip_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/ai_chatbot/chat_popup.dart';
import '../../../features/complaint/presentation/screen/raise_complaint_screen.dart';
import '../../../features/notification/notification_screen.dart';
import '../../../features/trip_chat/presentation/trip_group_chat_screen.dart';
import '../../../features/trip_detail/data/model/cab_tracking/user_cab_tracking_response.dart';
import '../../../features/trip_detail/data/repository/cab_tracking/user_cab_tracking_repo.dart';
import '../../../features/trip_detail/presentation/screen/trip_detail.dart';
import '../../../trip_summary/trip_summary_welcome.dart';
import '../../../features/adhoc/presentation/screen/adhoc_request_screen.dart';
import '../../../features/sos/bloc/sos_bloc.dart';
import '../../../features/sos/bloc/sos_event.dart';
import '../../../features/sos/bloc/sos_state.dart';
import '../../../features/team_cab/bloc/team_cab_bloc.dart';
import '../../../features/team_cab/bloc/team_cab_event.dart';
import '../../../features/team_cab/bloc/team_cab_state.dart';
import '../../../features/team_cab/presentation/screen/team_cab_screen.dart';
import '../../../weekly_off/presentation/screen/weekly_off.dart';
import '../../../features/trip_detail/data/repository/user_feedback_repo.dart';
import '../../../features/trip_detail/data/repository/roaster_shift_repo.dart';
import '../../../features/share_cab/data/repository/share_cab_repo.dart';
import '../../../profile/presentation/screen/edit_profile.dart';
import 'package:geolocator/geolocator.dart';

enum _TripHistoryStatus {
  completed,
  inProgress,
  upcoming,
  noShow,
  cancelled,
  expired,
}

enum _TripHistoryFilterCategory { tripStatus, tripRating, tripDate }

class _TripHistoryFilterResult {
  const _TripHistoryFilterResult({
    required this.statusAll,
    required this.statuses,
    required this.ratingAll,
    required this.ratings,
    required this.includeUnrated,
    this.fromDate,
    this.toDate,
  });

  final bool statusAll;
  final Set<_TripHistoryStatus> statuses;
  final bool ratingAll;
  final Set<int> ratings;
  final bool includeUnrated;
  final DateTime? fromDate;
  final DateTime? toDate;
}

class _TripHistoryItem {
  const _TripHistoryItem({
    required this.cardId,
    required this.dateGroupLabel,
    required this.tripDate,
    required this.isLogin,
    required this.time,
    required this.status,
    required this.apiItem,
    this.rating,
    this.navigateOnTap = false,
  });

  final String cardId;
  final String dateGroupLabel;
  final DateTime tripDate;
  final bool isLogin;
  final String time;
  final _TripHistoryStatus status;
  final TripHistoryItem apiItem;
  final int? rating;
  final bool navigateOnTap;
}

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
          create: (_) => sl<ScheduleHomeBloc>()..add(const FetchScheduleHome()),
        ),
        BlocProvider<RosterBloc>(
          create: (_) => sl<RosterBloc>()..add(const FetchRosterUserDetails()),
        ),
        BlocProvider<TeamCabBloc>(
          create: (_) => sl<TeamCabBloc>(),
        ),
        BlocProvider<AppControlBloc>(
          create: (_) => sl<AppControlBloc>(),
        ),
        BlocProvider<UserAppConfigBloc>(
          create: (_) => sl<UserAppConfigBloc>(),
        ),
        BlocProvider<TripHistoryBloc>(
          create: (_) => sl<TripHistoryBloc>(),
        ),
        BlocProvider<SosBloc>(
          create: (_) => sl<SosBloc>(),
        ),
        BlocProvider<ProfileBloc>(
          create: (_) => sl<ProfileBloc>()..add(const FetchUserProfile()),
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
  bool _tripHistoryFetchDispatched = false;
  Timer? _pollingTimer;

  /// True while a pull-to-refresh cascade is in flight. Used so the schedules
  /// section keeps rendering the previously-loaded cards (with the single
  /// [RefreshIndicator] spinner on top) instead of swapping in its own inline
  /// loader — the user should ever see only one loader during a refresh.
  bool _isRefreshing = false;

  /// Last successfully-loaded active-trip / schedule groups, retained so the UI
  /// can keep showing them while a refresh reloads in the background.
  List<TripDayGroup>? _lastTripGroups;
  List<ScheduleDateGroup>? _lastScheduleGroups;

  @override
  void initState() {
    super.initState();
    // BlocListener does not replay the current state; fetch if roster already loaded.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _ensureTripHistoryFetched());
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 500000), (_) {
      if (!mounted) return;
      context.read<TripHomeBloc>().add(const FetchTripHome());
      context.read<ScheduleHomeBloc>().add(const FetchScheduleHome());
      context.read<RosterBloc>().add(const FetchRosterUserDetails());
      context.read<ProfileBloc>().add(const FetchUserProfile());
      final rosterState = context.read<RosterBloc>().state;
      if (rosterState is RosterLoaded) {
        context.read<TripHistoryBloc>().add(FetchTripHistory(
              empId: rosterState.details.empId,
              fromDate: _defaultFromDate(),
              toDate: _defaultToDate(),
            ));
        _fetchTeamCab(rosterState.details.empId);
        _maybeFetchUserAppConfig(rosterState.details.locCode);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _ensureTripHistoryFetched() {
    final rosterState = context.read<RosterBloc>().state;
    if (rosterState is RosterLoaded) {
      _maybeDispatchTripHistoryFetch(rosterState.details.empId);
      _maybeFetchAppControlSettings(rosterState.details.locCode);
      _fetchTeamCab(rosterState.details.empId);
    }
  }

  /// Fetches the team-tracking-panel so the side-nav can decide whether to show
  /// the Team Cab module (only when the API returns `isSuccess == true`).
  void _fetchTeamCab(int empId) {
    if (empId == 0) return;
    context
        .read<TeamCabBloc>()
        .add(FetchTeamCab(empId: empId, date: DateTime.now()));
  }

  /// Fetches per-location app-control settings (which home-screen features are
  /// enabled) whenever the roster — and therefore [locCode] — is available.
  /// Called on every screen load (and on each roster refresh) so the settings
  /// are always re-fetched fresh; no locCode de-dupe.
  void _maybeFetchAppControlSettings(int locCode) {
    if (locCode == 0) return;
    context.read<AppControlBloc>().add(FetchAppControlSettings(locCode));
    _maybeFetchUserAppConfig(locCode);
  }

  /// Fetches per-location UI-gating config (schedule/trip action buttons) from
  /// `GetUserAppConfigurationByLocCode`, keyed off the roster [locCode].
  /// Re-fetched fresh on every screen load, pull-to-refresh, and poll tick.
  void _maybeFetchUserAppConfig(int locCode) {
    if (locCode == 0) return;
    context.read<UserAppConfigBloc>().add(FetchUserAppConfig(locCode));
  }

  /// Reloads the home screen data (active trips + schedules) so the UI — whose
  /// feature visibility is gated by [UserAppConfiguration] — re-evaluates
  /// against freshly-loaded config. Invoked when the user-app-config finishes
  /// loading. Does NOT re-dispatch the config fetch, so there is no loop.
  void _reloadHomeDataForUserAppConfig() {
    if (!mounted) return;
    context.read<TripHomeBloc>().add(const FetchTripHome());
    context.read<ScheduleHomeBloc>().add(const FetchScheduleHome());
  }

  /// Drives pull-to-refresh: dispatches the roster fetch (which cascades through
  /// AppControl → UserAppConfig → TripHome + ScheduleHome via the BlocListeners)
  /// and returns a Future that completes only once the FINAL data — the active
  /// trips and schedules — has finished reloading. This keeps the single
  /// [RefreshIndicator] spinner up for the whole cascade instead of dismissing
  /// it the instant the roster event is enqueued.
  Future<void> _refreshHomeData() async {
    final tripBloc = context.read<TripHomeBloc>();
    final scheduleBloc = context.read<ScheduleHomeBloc>();

    bool isTerminal(Object state) =>
        state is! TripHomeLoading &&
        state is! TripHomeInitial &&
        state is! ScheduleHomeLoading &&
        state is! ScheduleHomeInitial;

    // Wait for the next terminal (loaded / error / unauthorized) state that the
    // reload cascade produces. Listen BEFORE dispatching so a fast emission is
    // never missed. A timeout guards against the spinner hanging if the cascade
    // stalls (e.g. roster never re-emits RosterLoaded).
    final tripDone = tripBloc.stream
        .firstWhere(isTerminal)
        .timeout(const Duration(seconds: 30), onTimeout: () => tripBloc.state);
    final scheduleDone = scheduleBloc.stream.firstWhere(isTerminal).timeout(
        const Duration(seconds: 30),
        onTimeout: () => scheduleBloc.state);

    // Suppress the inline section loader for the duration of the refresh so the
    // RefreshIndicator spinner is the only loader on screen.
    if (mounted) setState(() => _isRefreshing = true);

    // Kick off the cascade.
    context.read<RosterBloc>().add(const FetchRosterUserDetails());

    try {
      await Future.wait([tripDone, scheduleDone]);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  /// Current per-location hybrid-schedule flag from the loaded AppControl
  /// settings (defaults to `false` until/unless settings are loaded).
  bool get _hybridScheduleEnabled {
    final s = context.read<AppControlBloc>().state;
    return s is AppControlLoaded && s.settings.hybridScheduleEnabled;
  }

  /// Current per-location flag gating the "Both" (Login + Logout) toggle on the
  /// trip-details screen (defaults to `false` until/unless settings are loaded).
  bool get _isScheduleFillForLoginAndLogoutBoth {
    final s = context.read<AppControlBloc>().state;
    return s is AppControlLoaded &&
        s.settings.isScheduleFillForLoginAndLogoutBoth;
  }

  // ---------------------------------------------------------------------------
  // UserAppConfiguration — highest-priority per-location feature gate.
  //
  // These getters read the per-location UI-gating config from
  // `GetUserAppConfigurationByLocCode` (see [UserAppConfigBloc]). Each one
  // returns whether a given feature is *allowed* to be shown.
  //
  // The gate has the HIGHEST priority: when the config is loaded and a flag is
  // `false`, the corresponding UI element must always be hidden regardless of
  // trip status, TAT, AppControl, backend flags, or any existing visibility
  // logic. When the flag is `true`, the existing logic is preserved exactly.
  //
  // While the config is NOT loaded (initial / loading / error), the gate falls
  // back to `true` so existing behaviour is preserved unchanged — the gate only
  // ever hides on an explicit loaded `false`.
  // ---------------------------------------------------------------------------

  /// The loaded per-location UI-gating config, or `null` when not yet loaded.
  UserAppConfiguration? get _userAppConfig {
    final s = context.read<UserAppConfigBloc>().state;
    return s is UserAppConfigLoaded ? s.config : null;
  }

  // Schedule feature gates.
  bool get _gateScheduleCancel =>
      _userAppConfig?.scheduleUiConfig.isCancellationScheduledAllowed ?? true;
  bool get _gateScheduleEdit =>
      _userAppConfig?.scheduleUiConfig.isEditScheduleAllowed ?? true;
  bool get _gateScheduleNoShow =>
      _userAppConfig?.scheduleUiConfig.isAlreadyScheduledNoShow ?? true;
  bool get _gateScheduleTracking =>
      _userAppConfig?.scheduleUiConfig.isTrackingScheduledAllowed ?? true;
  bool get _gateCreateSchedule =>
      _userAppConfig?.scheduleUiConfig.isCreateScheduleAllowed ?? true;
  // NOTE: isCreateScheduleAllowed is ALSO gated inline in [AppDrawer] (a
  // separate StatelessWidget without access to these getters).
  bool get _gateScheduleCancelAfterTAT =>
      _userAppConfig?.scheduleUiConfig.isCancelledScheduledAllowedAfterTAT ??
      true;

  // Trip feature gates.
  bool get _gateTripTracking =>
      _userAppConfig?.tripUiConfig.isTripTrackingAllowed ?? true;
  bool get _gateTripChat =>
      _userAppConfig?.tripUiConfig.isTripChatAllowed ?? true;
  bool get _gateTripShareCab =>
      _userAppConfig?.tripUiConfig.isTripShareCabAllowed ?? true;
  bool get _gateTripIvrCall =>
      _userAppConfig?.tripUiConfig.isTripIvrCallAllowed ?? true;
  bool get _gateTripSafeHomeReach =>
      _userAppConfig?.tripUiConfig.isTripSafeHomeReach ?? true;
  bool get _gateTripCancellation =>
      _userAppConfig?.tripUiConfig.isTripCancellationAllowed ?? true;
  bool get _gateTripNoShow =>
      _userAppConfig?.tripUiConfig.isTripNoShowAllowed ?? true;
  bool get _gateDeboardOtpField =>
      _userAppConfig?.tripUiConfig.isDeboardOtpFieldAllowed ?? true;
  bool get _gateTripSummary =>
      _userAppConfig?.tripUiConfig.isTripSummaryAllowed ?? true;

  void _maybeDispatchTripHistoryFetch(int empId) {
    if (_tripHistoryFetchDispatched) return;
    _tripHistoryFetchDispatched = true;
    context.read<TripHistoryBloc>().add(FetchTripHistory(
          empId: empId,
          fromDate: _defaultFromDate(),
          toDate: _defaultToDate(),
        ));
  }

  void _selectTripHistoryTab() {
    setState(() => _selectedIndex = 1);
    _forceFetchTripHistory();
  }

  void _forceFetchTripHistory() {
    final rosterState = context.read<RosterBloc>().state;
    if (rosterState is RosterLoaded) {
      _tripHistoryFetchDispatched = false;
      _maybeDispatchTripHistoryFetch(rosterState.details.empId);
    }
  }

  /// Keys for which active-trip cards are expanded (prefix `trip_`).
  final Set<String> _tripExpanded = {};

  /// Keys for which schedule cards are expanded
  /// (e.g. `"Today_login_0"`, `"Tomorrow_logout_0"`).
  final Set<String> _scheduleExpanded = {};

  /// Keys for which trip-history cards are expanded (e.g. `"0"`, `"1"`).
  final Set<String> _tripHistoryExpanded = {};

  bool _tripHistoryStatusAll = true;
  Set<_TripHistoryStatus> _tripHistoryStatusFilters = {};
  bool _tripHistoryRatingAll = true;
  Set<int> _tripHistoryRatingFilters = {};
  bool _tripHistoryIncludeUnrated = false;
  DateTime? _tripHistoryFromDate;
  DateTime? _tripHistoryToDate;

  // Trip history items are loaded from the API; no static list needed.

  void _showCancelRideDialog(
    BuildContext context, {
    required bool isLogin,
    required ScheduleItem item,
  }) {
    final rosterState = context.read<RosterBloc>().state;
    final locCode =
        rosterState is RosterLoaded ? rosterState.details.locCode : null;
    final scheduleDateIso = _scheduleDateIsoForCancel(item, isLogin);
    // Use the logged-in user's empId from the roster response as the primary
    // source; fall back to the schedule item's own empId fields.
    final rosterEmpId =
        rosterState is RosterLoaded ? rosterState.details.empId : null;
    final empIdStr = (rosterEmpId != null && rosterEmpId != 0)
        ? rosterEmpId.toString()
        : _empIdForCancelPayload(item);

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
      showBar(
          'Office location not available. Pull to refresh or try again later.');
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

    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (dialogContext) => CancelRideDialog(
        isLogin: isLogin,
        locCode: locCode,
        empId: empIdStr,
        scheduleDate: scheduleDateIso,
      ),
    ).then((cancelled) {
      if (cancelled == true && context.mounted) {
        context.read<ScheduleHomeBloc>().add(const FetchScheduleHome());
      }
    });
  }

  /// Active trip cancel via `POST /UserApp/UserCancelTrip`.
  void _showCancelActiveTripDialog(
    BuildContext context, {
    required TripHomeItem item,
    bool isNoShow = false,
  }) {
    void showBar(String msg) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    }

    final empId = item.empId;
    final tripId = item.tripId;
    final tripDateIso = scheduleDateToIso(item.tripDate);

    if (empId == null || empId == 0) {
      showBar('Employee ID is missing. Pull to refresh.');
      return;
    }
    if (tripId == null || tripId == 0) {
      showBar('Trip ID is missing. Pull to refresh.');
      return;
    }
    if (tripDateIso == null || tripDateIso.isEmpty) {
      showBar('Trip date is missing. Pull to refresh.');
      return;
    }

    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (dialogContext) => CancelActiveTripDialog(
        isLogin: item.isLogin,
        requestedBy: empId,
        requestFor: empId,
        tripDate: tripDateIso,
        tripType: item.isLogin ? 1 : 2,
        tripId: tripId,
        showNoShowWording: isNoShow,
      ),
    ).then((cancelled) {
      if (cancelled == true && context.mounted) {
        context.read<TripHomeBloc>().add(const FetchTripHome());
        context.read<ScheduleHomeBloc>().add(const FetchScheduleHome());
      }
    });
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
        builder: (_) => TripDetailsScreen(
          flowArgs: args,
          hybridScheduleEnabled: _hybridScheduleEnabled,
          isScheduleFillForLoginAndLogoutBoth:
              _isScheduleFillForLoginAndLogoutBoth,
        ),
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

  Future<void> _openTripGroupChat(TripHomeItem item) async {
    final tripId = item.tripId;
    if (tripId == null || tripId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip ID is not available.')),
      );
      return;
    }

    final rosterState = context.read<RosterBloc>().state;
    final myEmpId = rosterState is RosterLoaded
        ? rosterState.details.empId
        : (item.empId ?? 0);

    // Use the first driver in drList as the chat recipient; fall back to 0
    // (the chat API treats 0 as a broadcast to the whole trip group).
    final driver =
        rosterState is RosterLoaded && rosterState.details.drList.isNotEmpty
            ? rosterState.details.drList.first
            : null;
    final otherEmpId = driver?.empId ?? 0;
    final otherName = driver?.empName.isNotEmpty == true
        ? driver!.empName
        : 'Trip Group Chat';

    // Build participants subtitle from the logged-in user's name + pax count.
    final userName = item.userName?.trim() ?? '';
    final paxCount = item.paxCount ?? 0;
    final extra = paxCount > 1 ? ' +${paxCount - 1}' : '';
    final participants =
        userName.isNotEmpty ? '$userName$extra' : 'Trip passengers';

    // The chat screen resolves other passengers' names (sender/receiver) from
    // the trip's passenger list. The trip card has no cab-tracking data loaded,
    // so fetch the tracking status here to get the passengers before opening
    // the chat. On failure fall back to an empty list (names then resolve from
    // drList / senderName as before).
    List<TripPassenger> passengers = const [];
    try {
      final status =
          await sl<UserCabTrackingRepo>().getTrackingStatus(tripId: tripId);
      passengers = status.passengers;
    } catch (_) {
      // Ignore — chat still opens without pre-resolved passenger names.
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TripGroupChatScreen(
          tripId: tripId,
          myEmpId: myEmpId,
          // otherEmpId: otherEmpId,
          otherEmpId: 373,
          otherName: otherName,
          participants: participants,
          myName: userName.isNotEmpty ? userName : 'You',
          drList: rosterState is RosterLoaded
              ? rosterState.details.drList
              : const [],
          passengers: passengers,
        ),
      ),
    );
  }

  Future<void> _shareActiveTrip(TripHomeItem item) async {
    final empId = item.empId;
    final tripId = item.tripId;

    if (empId == null || empId == 0 || tripId == null || tripId == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip details are not available.'),
          ),
        );
      }
      return;
    }

    try {
      /// Request contacts permission
      final permissionStatus =
          await FlutterContacts.permissions.request(PermissionType.read);
      final hasPermission = permissionStatus == PermissionStatus.granted ||
          permissionStatus == PermissionStatus.limited;

      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contacts permission denied.'),
            ),
          );
        }
        return;
      }

      /// Open native contact picker safely
      Contact? pickedContact;

      try {
        pickedContact = await FlutterContacts.native.showPicker();
      } catch (e) {
        debugPrint('openExternalPick error: $e');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  ErrorMessage.from(e, fallback: 'Failed to open contacts.')),
            ),
          );
        }
        return;
      }

      final pickedContactId = pickedContact?.id;
      if (pickedContactId == null || pickedContactId.isEmpty || !mounted) {
        return;
      }

      /// Reload full contact safely
      Contact? fullContact;

      try {
        fullContact = await FlutterContacts.get(
          pickedContactId,
          properties: {ContactProperty.phone},
        );
      } catch (e) {
        debugPrint('getContact error: $e');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ErrorMessage.from(e,
                  fallback: 'Failed to read contact details.')),
            ),
          );
        }
        return;
      }

      /// Extract phone number safely
      String? phone;

      if (fullContact != null && fullContact.phones.isNotEmpty) {
        final rawPhone = fullContact.phones.first.number;

        phone = rawPhone.replaceAll(RegExp(r'\s+|-|\(|\)'), '').trim();

        if (phone.isEmpty) {
          phone = null;
        }
      }

      if (phone == null || phone.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Selected contact has no valid phone number.',
              ),
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      /// Get logged-in user info
      final authStorage = sl<AuthLocalStorage>();

      final userMobileNo = authStorage.getContactNumber() ?? '';

      final userName = authStorage.getAuthData()?.data?.user?.name?.trim() ??
          item.userName?.trim() ??
          '';

      /// Show loader
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        final repo = sl<ShareCabRepository>();

        final response = await repo.shareCabToFamily(
          empId: empId,
          tripId: tripId,
          name: userName,
          userMobileNo: userMobileNo,
          recepientMobileNo: phone,
        );

        if (!mounted) return;

        Navigator.of(context, rootNavigator: true).pop();

        if (response.isSuccess == true) {
          final url = response.result?.firstOrNull?.urlWithPara;

          _showShareCabSuccessDialog(
            message: response.message ?? 'Cab location shared successfully.',
            url: url,
          );
        } else {
          _showShareCabErrorDialog(
            message: response.message ?? 'Failed to share cab location.',
          );
        }
      } catch (e) {
        debugPrint('shareCabToFamily error: $e');

        if (!mounted) return;

        Navigator.of(context, rootNavigator: true).pop();

        _showShareCabErrorDialog(
          message: 'Something went wrong. Please try again.',
        );
      }
    } catch (e) {
      debugPrint('_shareActiveTrip error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to access contacts right now.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _callDriverIvr(TripHomeItem item) async {
    final empId = item.empId;
    final tripId = item.tripId;
    if (empId == null || empId == 0 || tripId == null || tripId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip details are not available.')),
      );
      return;
    }

    final phoneNo = item.userAppIvrNumber?.trim();
    if (phoneNo == null || phoneNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver phone number not available')),
      );
      return;
    }

    // Confirmation dialog before calling
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5EE),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.phone, color: Color(0xFF1A6B3C), size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'Call Driver',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'We\'ll connect you to the driver via IVR. Do you want to proceed?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF555555)),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF444444),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A6B3C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text('Call',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    String? virtualNumber;
    try {
      final response = await sl<IvrCallRepo>().initiate(
        dsId: tripId,
        empId: empId,
        phoneNo: phoneNo,
        callerType: 'E',
      );
      virtualNumber = response.ivrVirtualNumber?.trim();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorMessage.from(e, fallback: 'Unable to start call')),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // dismiss loader

    if (virtualNumber == null || virtualNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start call')),
      );
      return;
    }

    final sanitized = virtualNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: sanitized);
    // Attempt directly — canLaunchUrl is unreliable for tel: on iOS.
    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (launched) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to start call')),
    );
  }

  void _showShareCabSuccessDialog({required String message, String? url}) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5EE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline,
                  color: Color(0xFF1A6B3C), size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Shared Successfully',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF555555)),
            ),
            if (url != null && url.isNotEmpty) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final uri = Uri.tryParse(url);
                  if (uri != null && await canLaunchUrl(uri)) {
                    launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                  Clipboard.setData(ClipboardData(text: url));
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Link copied to clipboard')),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link,
                          size: 16, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          url,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF2563EB),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A6B3C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text('Done',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showShareCabErrorDialog({required String message}) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0EE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline,
                  color: Color(0xFFB40D1A), size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Share Failed',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF555555)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB40D1A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text('Close',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openRideTracking(
    BuildContext context, {
    required int? empId,
    required int? tripId,
    String? userName,
    String? boardingOtp,
  }) {
    if (empId == null || tripId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip details are not available for tracking yet.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<CabTrackingBloc>()
            ..add(FetchCabTracking(empId: empId, tripId: tripId)),
          child: RideTrackingScreen(
            userName: userName,
            tripId: tripId,
            empId: empId,
            boardingOtp: boardingOtp,
            gateChat: _gateTripChat,
            gateIvrCall: _gateTripIvrCall,
          ),
        ),
      ),
    );
  }

  void _onBoardTrip(TripHomeItem item) {
    _showBoardTripDialog(context, item: item, boardingType: 'B');
  }

  void _onDeboardTrip(TripHomeItem item) {
    _showBoardTripDialog(context, item: item, boardingType: 'D');
  }

  void _showBoardTripDialog(
    BuildContext context, {
    required TripHomeItem item,
    required String boardingType,
  }) {
    void showBar(String msg) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    }

    final empId = item.empId;
    final tripId = item.tripId;
    final tripType = item.tripTypeCode ?? (item.isLogin ? 1 : 2);

    if (empId == null || empId == 0) {
      showBar('Employee ID is missing. Pull to refresh.');
      return;
    }
    if (tripId == null || tripId == 0) {
      showBar('Trip ID is missing. Pull to refresh.');
      return;
    }

    showDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (dialogContext) => BoardTripDialog(
        item: item,
        empId: empId,
        tripId: tripId,
        tripType: tripType,
        boardingType: boardingType,
      ),
    ).then((result) {
      if (result is String && result.isNotEmpty && context.mounted) {
        showBar(result);
        context.read<TripHomeBloc>().add(const FetchTripHome());
        // Safe Home Reach flow applies only to Logout (DROP) trips, and only
        // when the backend requests it (ReachedHomeReq == 1).
        if (boardingType == 'D' && !item.isLogin && item.reachedHomeReq == 1) {
          _callReachedHomeAndShowRateDialog(
            context,
            empId: empId,
            tripId: tripId,
            showBar: showBar,
          );
        }
      }
    });
  }

  Future<void> _callReachedHomeAndShowRateDialog(
    BuildContext context, {
    required int empId,
    required int tripId,
    required void Function(String) showBar,
  }) async {
    if (!context.mounted) return;

    // Step 1: Show "Reached Home Safely?" confirmation dialog.
    //
    // Tapping "Need Help" fires an SOS. A BlocListener wrapped around the
    // confirmation dialog watches the SosBloc and shows a success/error result
    // popup once the SOS API responds (errorCode == 0 → success, else error).
    final sosBloc = context.read<SosBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogContext) => BlocProvider.value(
        value: sosBloc,
        child: BlocListener<SosBloc, SosState>(
          listener: (_, state) {
            if (state is SosLoading) return;
            if (state is SosSuccess ||
                state is SosError ||
                state is SosUnauthorized) {
              // Close the confirmation dialog before showing the result.
              if (Navigator.of(dialogContext).canPop()) {
                Navigator.of(dialogContext).pop(false);
              }
              final isSuccess = state is SosSuccess;
              final msg = state is SosSuccess
                  ? 'SOS alert triggered successfully. Our safety team has '
                      'been notified and will reach out to you shortly.'
                  : state is SosError
                      ? state.message
                      : (state as SosUnauthorized).message;
              if (!context.mounted) return;
              showDialog<void>(
                context: context,
                barrierDismissible: true,
                barrierColor: Colors.black.withValues(alpha: 0.5),
                builder: (_) => _SosResultDialog(
                  message: msg,
                  success: isSuccess,
                ),
              );
            }
          },
          child: _ReachedHomeSafelyDialog(
            onNeedHelp: () => sosBloc.add(TriggerSos(empId: empId)),
          ),
        ),
      ),
    );

    // "Need Help" or dismissed — don't proceed
    if (confirmed != true || !context.mounted) return;

    // Show a blocking loader while we resolve location and call the
    // ReachedHome API. It is dismissed inside showResultDialog (every result
    // path routes through there) just before the success/error popup appears.
    var loaderShown = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    void dismissLoader() {
      if (loaderShown && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loaderShown = false;
      }
    }

    // Step 2: Get current location
    double lat = 0;
    double lng = 0;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.deniedForever &&
          permission != LocationPermission.denied) {
        Position? lastKnown;
        try {
          lastKnown = await Geolocator.getLastKnownPosition();
        } catch (_) {}
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled && lastKnown != null) {
          lat = lastKnown.latitude;
          lng = lastKnown.longitude;
        } else {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings:
                const LocationSettings(accuracy: LocationAccuracy.high),
          );
          lat = pos.latitude;
          lng = pos.longitude;
        }
      }
    } catch (e) {
      debugPrint('[REACHED_HOME] location error: $e');
    }

    // Step 3: Call ReachedHome API
    Future<void> showResultDialog(String msg, {required bool success}) async {
      dismissLoader();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.5),
        builder: (_) =>
            _ReachedHomeResultDialog(message: msg, success: success),
      );
    }

    try {
      final repo = sl<RoasterShiftRepo>();
      final response = await repo.reachedHome(
        empId: empId,
        tripId: tripId,
        empLat: lat,
        empLng: lng,
      );
      if (response.isSuccess) {
        await showResultDialog(
          response.message.trim().isNotEmpty
              ? response.message
              : 'Marked reached home successfully.',
          success: true,
        );
        // Refresh so the Safe Home Reach button hides (IsReached becomes 1).
        if (context.mounted) {
          context.read<TripHomeBloc>().add(const FetchTripHome());
        }
      } else {
        debugPrint('[REACHED_HOME] API not success: ${response.message}');
        await showResultDialog(
          response.message.trim().isNotEmpty
              ? response.message
              : 'Could not mark reached home. Please try again.',
          success: false,
        );
      }
    } catch (e) {
      debugPrint('[REACHED_HOME] API error: $e');
      await showResultDialog(
        ErrorMessage.from(e,
            fallback: 'Could not mark reached home. Please try again.'),
        success: false,
      );
    }

    // Step 4: Show Rate App dialog (best-effort — open regardless of API result)
    if (context.mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.5),
        builder: (_) => _RateAppDialog(empId: empId, tripId: tripId),
      );
    }
  }

  /// Tapping the "Safe Home Reach" CTA on the active trip card opens the
  /// Reached-Home-Safely confirmation dialog and runs the reached-home flow.
  void _onSafeHomeReachTap(TripHomeItem item) {
    void showBar(String msg) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    }

    final empId = item.empId;
    final tripId = item.tripId;

    if (empId == null || empId == 0) {
      showBar('Employee ID is missing. Pull to refresh.');
      return;
    }
    if (tripId == null || tripId == 0) {
      showBar('Trip ID is missing. Pull to refresh.');
      return;
    }

    _callReachedHomeAndShowRateDialog(
      context,
      empId: empId,
      tripId: tripId,
      showBar: showBar,
    );
  }

  Widget _buildTripCircleAction({
    required VoidCallback? onTap,
    required IconData icon,
    required Color iconColor,
    Color backgroundColor = const Color(0xFFE8F5EE),
    Color? borderColor,
  }) {
    return InkWell(
      splashColor: Colors.transparent,
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: borderColor != null ? Border.all(color: borderColor) : null,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
    );
  }

  /// Active-trip No-Show action rendered as a text pill ("No Show") rather than
  /// an icon, matching the schedule-card No-Show button styling.
  Widget _buildTripNoShowTextButton({required VoidCallback? onTap}) {
    return InkWell(
      splashColor: Colors.transparent,
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x33BA1A1A)),
        ),
        child: const Text(
          'No Show',
          style: TextStyle(
            color: Color(0xFFBA1A1A),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildTripStartedExpandedActions({
    required TripHomeItem item,
    required Color accentColor,
    required Color tagBgColor,
    required Color trackBg,
    required Color trackFg,
    required VoidCallback? trackVehicleAction,
  }) {
    // Board/Deboard CTA depends only on the user's boarding state, for both
    // Login (PICK) and Logout (DROP) trips:
    //   isBoarded == false                  -> show Board
    //   isBoarded == true && !isDeBoarded    -> show Deboard
    final bool showDeboard = item.isBoardedNotDeboarded;
    // The Board/Deboard CTA is additionally gated by the per-location
    // AppControl setting (boardDebaordEnabledForUser).
    final appControlState = context.read<AppControlBloc>().state;
    final bool boardDeboardEnabled = appControlState is AppControlLoaded &&
        appControlState.settings.boardDebaordEnabledForUser;
    // The active-trip card shows independent No-Show and Cancel action buttons.
    //   • No-Show: only relevant after TAT — gated by the per-location AppControl
    //     flag (isCancelTripByUserAfterTAT), the UserAppConfiguration No-Show
    //     gate, and the per-trip `isTripNoShowButtonShow` flag.
    //   • Cancel: gated by the UserAppConfiguration Cancel gate and the per-trip
    //     `isTripCancellationButtonShow` flag.
    // Both may appear at once (mirrors the schedule-card button model).
    final bool isCancelTripByUserAfterTAT =
        appControlState is AppControlLoaded &&
            appControlState.settings.isCancelTripByUserAfterTAT;
    final bool showTripNoShowButton = _gateTripNoShow &&
        isCancelTripByUserAfterTAT &&
        (item.tripButtonUiConfig?.isTripNoShowButtonShow ?? false);
    final bool showTripCancelButton = _gateTripCancellation &&
        (item.tripButtonUiConfig?.isTripCancellationButtonShow ?? false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (showTripNoShowButton) ...[
              _buildTripNoShowTextButton(
                onTap: () => _showCancelActiveTripDialog(
                  context,
                  item: item,
                  isNoShow: true,
                ),
              ),
              const SizedBox(width: 10),
            ],
            if (showTripCancelButton) ...[
              _buildTripCircleAction(
                onTap: () => _showCancelActiveTripDialog(context, item: item),
                icon: Icons.close,
                iconColor: const Color(0xFFBA1A1A),
                backgroundColor: Colors.white,
                borderColor: const Color(0x33BA1A1A),
              ),
              const SizedBox(width: 10),
            ],
            if (_gateTripShareCab) ...[
              _buildTripCircleAction(
                onTap: () => _shareActiveTrip(item),
                icon: Icons.share_outlined,
                iconColor: accentColor,
                backgroundColor: tagBgColor,
              ),
              const SizedBox(width: 10),
            ],
            if (_gateTripChat) ...[
              _buildTripCircleAction(
                onTap: () => _openTripGroupChat(item),
                icon: Icons.chat_bubble_outline,
                iconColor: accentColor,
                backgroundColor: tagBgColor,
              ),
              const SizedBox(width: 10),
            ],
            if (_gateTripTracking)
              Expanded(
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
          ],
        ),
        if (boardDeboardEnabled &&
            (item.canShowBoardButton || showDeboard)) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: showDeboard
                ? () => _onDeboardTrip(item)
                : () => _onBoardTrip(item),
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: showDeboard
                    ? const Color(0xFFB40D1A)
                    : const Color(0xFF1A5C38),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                showDeboard ? 'Deboard' : 'Board',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ],
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
          _selectTripHistoryTab();
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
      body: MultiBlocListener(
        listeners: [
          BlocListener<RosterBloc, RosterState>(
            listener: (context, state) {
              if (state is RosterLoaded) {
                _ensureTripHistoryFetched();
                _maybeFetchAppControlSettings(state.details.locCode);
                _fetchTeamCab(state.details.empId);
              }
            },
          ),
          // When the per-location UI-gating config finishes loading, reload the
          // home data so the gated UI re-evaluates against the fresh config.
          BlocListener<UserAppConfigBloc, UserAppConfigState>(
            listener: (context, state) {
              if (state is UserAppConfigLoaded) {
                _reloadHomeDataForUserAppConfig();

                // Backend-driven launcher icon. Fire-and-forget: the
                // coordinator resolves the campaign, ignores unknown values and
                // logs its own failures, so this can never affect the home
                // screen. The actual swap is deferred until the app is
                // backgrounded to avoid OEM launchers ejecting the user.
                // sl<DynamicAppIconCoordinator>()
                //     .applyFromConfig(state.config.commonUiConfig.appIcon);
                sl<DynamicAppIconCoordinator>()
                    .applyFromConfig('independence_day');
              }
            },
          ),
        ],
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                BlocBuilder<RosterBloc, RosterState>(
                  builder: (context, state) {
                    // Hide the no-show banner on the Trip History module.
                    if (state is RosterLoaded && _selectedIndex != 1) {
                      return _buildNoShowBanner(state.details);
                    }
                    return const SizedBox.shrink();
                  },
                ),
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
            // UserAppConfiguration highest-priority gate: hide the Create
            // Schedule plus icon entirely when isCreateScheduleAllowed is
            // `false`.
            // Wrapped in a BlocBuilder so the gate re-evaluates whenever
            // UserAppConfigBloc emits (e.g. after pull-to-refresh re-fetches
            // the config). `_gateCreateSchedule` reads via context.read, which
            // does not subscribe, so without this the FAB would not rebuild on
            // config changes.
            BlocBuilder<UserAppConfigBloc, UserAppConfigState>(
              builder: (context, _) {
                if (!_gateCreateSchedule) return const SizedBox.shrink();
                return Positioned(
                  bottom: 36,
                  left: 0,
                  right: 0,
                  child: Center(child: _buildFAB()),
                );
              },
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
      ),
    );
  }

  /// No-show status banner shown below the welcome header.
  ///
  /// Visibility rule: only rendered when [RosterUserDetails.noShowCountIsActive]
  /// is true. The banner type and message are derived from
  /// [RosterUserDetails.noShowMessage], a comma-separated string where the first
  /// value is the type (`Info`/`Error`) and the second value is the message to
  /// display (e.g. `"Info,NoShowLeft,0,0"`).
  Widget _buildNoShowBanner(RosterUserDetails details) {
    if (!details.noShowCountIsActive) {
      return const SizedBox.shrink();
    }

    final parts = details.noShowMessage.split(',');
    final type = parts.isNotEmpty ? parts[0].trim().toLowerCase() : '';
    final message = parts.length > 1 ? parts.sublist(1).join(',').trim() : '';

    if (message.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool isError = type == 'error';

    final Color bgColor;
    final Color borderColor;
    final Color accentColor;
    final IconData icon;
    final String title;

    if (isError) {
      bgColor = const Color(0xFFFDECEA);
      borderColor = const Color(0xFFF5C2C0);
      accentColor = const Color(0xFFD32F2F);
      icon = Icons.block;
      title = 'Roster Access Restricted';
    } else {
      bgColor = const Color(0xFFFFF8E1);
      borderColor = const Color(0xFFFFE082);
      accentColor = const Color(0xFFF57F17);
      icon = Icons.info_outline;
      title = 'No-Show Status';
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF444444),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Formats an ISO suspension date string (e.g. `2026-07-04T00:18:33.813`)
  /// into a readable `04 Jul 2026`. Returns null when missing/unparseable.
  static String? _formatSuspensionDate(String raw) {
    if (raw.trim().isEmpty) return null;
    final dt = DateTime.tryParse(raw);
    if (dt == null) return null;
    const months = [
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
    final day = dt.day.toString().padLeft(2, '0');
    return '$day ${months[dt.month - 1]} ${dt.year}';
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

  static DateTime _tripHistoryDateOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  bool _tripHistoryMatchesDateRange(_TripHistoryItem item) {
    if (_tripHistoryFromDate == null && _tripHistoryToDate == null) {
      return true;
    }
    final tripDay = _tripHistoryDateOnly(item.tripDate);
    if (_tripHistoryFromDate != null &&
        tripDay.isBefore(_tripHistoryDateOnly(_tripHistoryFromDate!))) {
      return false;
    }
    if (_tripHistoryToDate != null &&
        tripDay.isAfter(_tripHistoryDateOnly(_tripHistoryToDate!))) {
      return false;
    }
    return true;
  }

  List<_TripHistoryItem> _filteredItems(List<_TripHistoryItem> all) {
    return all.where((item) {
      // Upcoming and In Progress trips are never shown in trip history.
      if (item.status == _TripHistoryStatus.upcoming ||
          item.status == _TripHistoryStatus.inProgress) {
        return false;
      }
      if (!_tripHistoryStatusAll &&
          !_tripHistoryStatusFilters.contains(item.status)) {
        return false;
      }
      if (!_tripHistoryRatingAll) {
        final rated = item.rating != null;
        if (!rated && !_tripHistoryIncludeUnrated) return false;
        if (rated && !_tripHistoryRatingFilters.contains(item.rating!)) {
          return false;
        }
      }
      if (!_tripHistoryMatchesDateRange(item)) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _openTripHistoryFilters(List<_TripHistoryItem> allItems) async {
    final initial = _TripHistoryFilterResult(
      statusAll: _tripHistoryStatusAll,
      statuses: Set<_TripHistoryStatus>.from(_tripHistoryStatusFilters),
      ratingAll: _tripHistoryRatingAll,
      ratings: Set<int>.from(_tripHistoryRatingFilters),
      includeUnrated: _tripHistoryIncludeUnrated,
      fromDate: _tripHistoryFromDate,
      toDate: _tripHistoryToDate,
    );

    final result = await Navigator.of(context).push<_TripHistoryFilterResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _TripHistoryFilterPage(
          items: allItems,
          initial: initial,
        ),
      ),
    );
    if (result == null || !mounted) return;

    final prevFrom = _tripHistoryFromDate;
    final prevTo = _tripHistoryToDate;

    setState(() {
      _tripHistoryStatusAll = result.statusAll;
      _tripHistoryStatusFilters = Set<_TripHistoryStatus>.from(result.statuses);
      _tripHistoryRatingAll = result.ratingAll;
      _tripHistoryRatingFilters = Set<int>.from(result.ratings);
      _tripHistoryIncludeUnrated = result.includeUnrated;
      _tripHistoryFromDate = result.fromDate;
      _tripHistoryToDate = result.toDate;
    });

    final datesChanged = prevFrom != result.fromDate || prevTo != result.toDate;
    if (datesChanged) {
      final rosterState = context.read<RosterBloc>().state;
      if (rosterState is RosterLoaded) {
        String dateStr(DateTime d) =>
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        _tripHistoryFetchDispatched = false;
        context.read<TripHistoryBloc>().add(FetchTripHistory(
              empId: rosterState.details.empId,
              fromDate: result.fromDate != null
                  ? dateStr(result.fromDate!)
                  : _defaultFromDate(),
              toDate: result.toDate != null
                  ? dateStr(result.toDate!)
                  : _defaultToDate(),
            ));
        _tripHistoryFetchDispatched = true;
      }
    }
  }

  /// Default date range: today back 15 days.
  static String _defaultFromDate() {
    final d = DateTime.now().subtract(const Duration(days: 15));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String _defaultToDate() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// Maps a backend [TripHistoryItem] (UserTripHistory API) to UI card data.
  _TripHistoryItem _toUiItem(TripHistoryItem api, int index) {
    final tripDate = _parseScheduleDate(api.tripDate) ?? DateTime.now();
    final dateGroupLabel = _formatHeaderDate(tripDate);
    final time = _formatShiftTime(api.pickTime ?? api.shiftTime) ?? '--:--';

    final _TripHistoryStatus status;
    if (api.isNoShow) {
      status = _TripHistoryStatus.noShow;
    } else if (api.isCancelled) {
      status = _TripHistoryStatus.cancelled;
    } else if (api.isCompleted) {
      status = _TripHistoryStatus.completed;
    } else {
      final s = (api.tripStatus ?? '').trim().toLowerCase();
      if (s.contains('expir')) {
        status = _TripHistoryStatus.expired;
      } else if (s == 'end' || s.contains('complet')) {
        status = _TripHistoryStatus.completed;
      } else if (s.contains('start') ||
          s.contains('progress') ||
          api.isBoarded) {
        // Trip in motion: started by driver or this passenger is already boarded
        status = _TripHistoryStatus.inProgress;
      } else if (s.isEmpty ||
          s == 'created' ||
          s == 'printed' ||
          s == 'planned' ||
          s.contains('plan') ||
          s.contains('schedul')) {
        // Yet to start (Created / Printed / Planned / Scheduled / unknown)
        status = _TripHistoryStatus.upcoming;
      } else {
        // Unknown status — keep it visible as upcoming so the user can still
        // see the trip and decide.
        status = _TripHistoryStatus.upcoming;
      }
    }

    // Allow the user to open the trip summary for any trip that has a real
    // route (i.e. not no-show / cancelled).
    final canNavigate = status == _TripHistoryStatus.completed ||
        status == _TripHistoryStatus.inProgress ||
        status == _TripHistoryStatus.upcoming;

    return _TripHistoryItem(
      cardId: 'api_${api.tripId ?? index}_${api.empId ?? index}',
      dateGroupLabel: dateGroupLabel,
      tripDate: tripDate,
      isLogin: api.isLogin,
      time: time,
      status: status,
      apiItem: api,
      rating: api.rating,
      navigateOnTap: canNavigate,
    );
  }

  Widget _buildTripHistorySection() {
    return BlocBuilder<TripHistoryBloc, TripHistoryState>(
      builder: (context, historyState) {
        Widget body;

        if (historyState is TripHistoryInitial ||
            historyState is TripHistoryLoading) {
          body = _buildSectionLoader();
        } else if (historyState is TripHistoryUnauthorized) {
          body = _buildSchedulesEmptyState(
            title: 'Session expired',
            subtitle: _friendlyErrorMessage(historyState.message),
            onRetry: () =>
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MobileNoVerification()),
              (route) => false,
            ),
            retryLabel: 'Sign in again',
          );
        } else if (historyState is TripHistoryError) {
          final rosterState = context.read<RosterBloc>().state;
          body = _buildSchedulesEmptyState(
            title: 'Could not load trip history',
            subtitle: _friendlyErrorMessage(historyState.message),
            onRetry: rosterState is RosterLoaded
                ? () {
                    _tripHistoryFetchDispatched = false;
                    _maybeDispatchTripHistoryFetch(rosterState.details.empId);
                  }
                : null,
            retryLabel: 'Retry',
          );
        } else {
          final apiItems = historyState is TripHistoryLoaded
              ? historyState.items
              : <TripHistoryItem>[];

          final allUiItems = apiItems
              .asMap()
              .entries
              .map((e) => _toUiItem(e.value, e.key))
              .toList();

          body = _buildTripHistoryList(allUiItems);
        }

        final isScrollable = historyState is TripHistoryLoaded ||
            historyState is TripHistoryInitial ||
            historyState is TripHistoryLoading;

        return RefreshIndicator(
          onRefresh: () async => _forceFetchTripHistory(),
          child: isScrollable
              ? body
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: body,
                ),
        );
      },
    );
  }

  Widget _buildTripHistoryList(List<_TripHistoryItem> allItems) {
    const loginGreen = Color(0xFF3E9B73);
    const logoutMaroon = Color(0xFFB40D1A);
    const completedBlue = Color(0xFF2563EB);

    final filtered = _filteredItems(allItems);

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

    if (filtered.isEmpty) {
      final hasActiveFilters = !_tripHistoryStatusAll ||
          !_tripHistoryRatingAll ||
          _tripHistoryFromDate != null ||
          _tripHistoryToDate != null;
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 48, 32, 100),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  hasActiveFilters
                      ? Icons.filter_list_off_outlined
                      : Icons.history_toggle_off_outlined,
                  size: 48,
                  color: _tripHistoryPrimaryGreen.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  hasActiveFilters
                      ? 'No trips match your filters'
                      : 'No trip history found',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hasActiveFilters
                      ? 'Try adjusting or resetting the filters.'
                      : 'No trips found for the selected date range.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                if (hasActiveFilters) ...[
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () => _openTripHistoryFilters(allItems),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _tripHistoryPrimaryGreen,
                      side: const BorderSide(color: Color(0xFFB8DEC9)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text('Change filters'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final children = <Widget>[];
    String? currentGroup;
    for (final item in filtered) {
      if (item.dateGroupLabel != currentGroup) {
        currentGroup = item.dateGroupLabel;
        if (children.isNotEmpty) {
          children.add(const SizedBox(height: 6));
        }
        children.add(dateRow(item.dateGroupLabel));
      } else {
        children.add(const SizedBox(height: 10));
      }
      children.add(
        _buildTripHistoryCard(
          cardId: item.cardId,
          isLogin: item.isLogin,
          time: item.time,
          status: item.status,
          accentLogin: loginGreen,
          accentLogout: logoutMaroon,
          completedBlue: completedBlue,
          apiItem: item.apiItem,
          tripDate: item.tripDate,
          rating: item.rating,
          onTap: item.navigateOnTap
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          TripSummaryScreen(tripItem: item.apiItem),
                    ),
                  );
                }
              : () {},
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildTripHistoryCard(
      {required String cardId,
      required bool isLogin,
      required String time,
      required _TripHistoryStatus status,
      required Color accentLogin,
      required Color accentLogout,
      required Color completedBlue,
      required TripHistoryItem apiItem,
      required DateTime tripDate,
      int? rating,
      required void Function()? onTap}) {
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
      case _TripHistoryStatus.inProgress:
        statusLabel = 'In Progress';
        statusIcon = Icons.directions_car_filled_outlined;
        statusColor = const Color(0xFFEA580C); // amber-orange
        break;
      case _TripHistoryStatus.upcoming:
        statusLabel = 'Upcoming';
        statusIcon = Icons.event_available_outlined;
        statusColor = _tripHistoryPrimaryGreen;
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
      case _TripHistoryStatus.expired:
        statusLabel = 'Expired';
        statusIcon = Icons.schedule_outlined;
        statusColor = const Color(0xFF888888);
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
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
                const SizedBox(height: 14),
                _buildTripHistoryDetails(
                  apiItem: apiItem,
                  isLogin: isLogin,
                  tripDate: tripDate,
                  rating: rating,
                  accentColor: accentColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static const Color _tripHistoryPrimaryGreen = Color(0xFF1A6B3C);

  /// Detailed body shown when a Trip History card is expanded. Renders every
  /// field we have from the API so the user never sees a stale placeholder.
  Widget _buildTripHistoryDetails({
    required TripHistoryItem apiItem,
    required bool isLogin,
    required DateTime tripDate,
    required int? rating,
    required Color accentColor,
  }) {
    String orDash(String? raw) {
      final s = raw?.trim();
      return (s == null || s.isEmpty) ? '—' : s;
    }

    final pickupAddr = orDash(apiItem.pickupAddress);
    final officeAddr = orDash(apiItem.officeAddress);
    final fromLabel = isLogin ? 'Pickup' : 'Office';
    final toLabel = isLogin ? 'Office' : 'Drop';
    final fromAddress = isLogin ? pickupAddr : officeAddr;
    final toAddress = isLogin ? officeAddr : pickupAddr;

    final shiftTime =
        _formatShiftTime(apiItem.shiftTime) ?? orDash(apiItem.shiftTime);
    // The per-passenger time is a boarding time. It only makes sense on the
    // matching trip type: a pickup time for login trips, a drop time for
    // logout trips. We never show a drop time on a login card or a pickup
    // time on a logout card.
    final stopTime = _formatShiftTime(apiItem.pickTime);
    final stopTimeLabel = isLogin ? 'Pickup' : 'Drop';
    final vehicle = orDash(apiItem.vehicleRegistrationNo);
    final tripTypeLabel = isLogin ? 'Login (Pickup)' : 'Logout (Drop)';

    TripHistoryPassenger? selfPax;
    final passengers = apiItem.passengers ?? const <TripHistoryPassenger>[];
    if (apiItem.empId != null) {
      for (final p in passengers) {
        if (p.empId == apiItem.empId) {
          selfPax = p;
          break;
        }
      }
    }
    final paxOrder = selfPax?.paxOrder;
    final totalPax = passengers.length;
    final String sequence;
    if (paxOrder != null && totalPax > 0) {
      sequence = 'P$paxOrder / $totalPax';
    } else if (paxOrder != null) {
      sequence = 'P$paxOrder';
    } else if (totalPax > 0) {
      sequence = '$totalPax pax';
    } else {
      sequence = '—';
    }

    final dateLabel =
        '${tripDate.day.toString().padLeft(2, '0')}/${tripDate.month.toString().padLeft(2, '0')}/${tripDate.year}';
    final reason = (apiItem.noShowOrCancelled ?? '').trim();
    final statusLabel = orDash(apiItem.tripStatus);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tripHistoryRouteRow(
          accentColor: accentColor,
          fromLabel: fromLabel,
          fromAddress: fromAddress,
          toLabel: toLabel,
          toAddress: toAddress,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _tripHistoryDetailChip(Icons.event_outlined, 'Date', dateLabel),
            if (stopTime != null)
              _tripHistoryDetailChip(
                  Icons.alarm_on_outlined, stopTimeLabel, stopTime),
            _tripHistoryDetailChip(Icons.schedule_outlined, 'Shift', shiftTime),
            _tripHistoryDetailChip(
                Icons.directions_car_outlined, 'Vehicle', vehicle),
            _tripHistoryDetailChip(
                Icons.format_list_numbered, 'Sequence', sequence),
            _tripHistoryDetailChip(
                Icons.swap_vert_circle_outlined, 'Type', tripTypeLabel),
            _tripHistoryDetailChip(Icons.info_outline, 'Status', statusLabel),
            if (rating != null)
              _tripHistoryDetailChip(Icons.star_rounded, 'Rating', '$rating/5'),
          ],
        ),
        if (reason.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFEE2E2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 16, color: Color(0xFFDC2626)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    reason,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB91C1C),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _tripHistoryRouteRow({
    required Color accentColor,
    required String fromLabel,
    required String fromAddress,
    required String toLabel,
    required String toAddress,
  }) {
    Widget node(Color color, IconData icon) => Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 14, color: color),
        );

    Widget line() => Container(
          width: 2,
          height: 22,
          margin: const EdgeInsets.symmetric(vertical: 2),
          color: const Color(0xFFE5E7EB),
        );

    Widget block(String label, String address, Widget leading) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9CA3AF),
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  address,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1F2937),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        block(fromLabel, fromAddress,
            node(accentColor, Icons.radio_button_checked)),
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: line(),
        ),
        block(toLabel, toAddress,
            node(const Color(0xFF2563EB), Icons.location_on)),
      ],
    );
  }

  Widget _tripHistoryDetailChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF4B5563)),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF111827),
                fontWeight: FontWeight.w700,
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
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
          child: Row(
            children: [
              Builder(
                builder: (scaffoldContext) => IconButton(
                  icon: const Icon(Icons.menu,
                      color: _tripHistoryPrimaryGreen, size: 26),
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
                  final historyState = context.read<TripHistoryBloc>().state;
                  final apiItems = historyState is TripHistoryLoaded
                      ? historyState.items
                      : <TripHistoryItem>[];
                  final allUiItems = apiItems
                      .asMap()
                      .entries
                      .map((e) => _toUiItem(e.value, e.key))
                      .toList();
                  _openTripHistoryFilters(allUiItems);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF444444),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  Builder(
                    // ← add this
                    builder: (scaffoldContext) => InkWell(
                      onTap: () {
                        Scaffold.of(scaffoldContext)
                            .openDrawer(); // ← use scaffoldContext
                      },
                      customBorder: const CircleBorder(),
                      child: Padding(
                        // ≥12px tap area on all sides of the menu icon
                        padding: EdgeInsets.all(12),
                        child: Transform.translate(
                            offset: Offset(-12.0, 0.0),
                            child: Icon(Icons.menu,
                                color: Colors.white, size: 26)),
                      ),
                    ),
                  ),
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
                        BlocBuilder<ProfileBloc, ProfileState>(
                          builder: (context, state) {
                            final firstName = state is ProfileLoaded
                                ? (state.profile.firstName?.trim() ?? '')
                                : '';
                            return Text(
                              firstName.isNotEmpty ? '$firstName' : '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: Platform.isAndroid ? 24 : 22,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Row(
                    spacing: 16,
                    children: [
                      // GestureDetector(
                      //   behavior: HitTestBehavior.opaque,
                      //   onTap: _openTransportAssistantChat,
                      //   child: Container(
                      //     width: 40,
                      //     height: 40,
                      //     decoration: BoxDecoration(
                      //       shape: BoxShape.circle,
                      //       color: Colors.white.withOpacity(0.2),
                      //       border: Border.all(
                      //         color: Colors.white.withOpacity(0.5),
                      //         width: 1,
                      //       ),
                      //     ),
                      //     child: const Icon(
                      //       Icons.assistant_outlined,
                      //       color: Colors.white,
                      //       size: 20,
                      //     ),
                      //   ),
                      // ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NotificationsScreen(),
                            ),
                          );
                        },
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
                            Icons.notification_add_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
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
    // Rebuild when AppControl settings arrive so the Board/Deboard CTA
    // (gated by boardDebaordEnabledForUser) appears/hides correctly.
    return BlocBuilder<AppControlBloc, AppControlState>(
      builder: (context, _) {
        return BlocBuilder<TripHomeBloc, TripHomeState>(
          builder: (context, tripState) {
            return BlocBuilder<ScheduleHomeBloc, ScheduleHomeState>(
              builder: (context, scheduleState) {
                return RefreshIndicator(
                  // Re-fetch only the roster; the BlocListener<RosterBloc> chain
                  // re-runs the rest (AppControl + UserAppConfig → TripHome +
                  // ScheduleHome). The returned Future keeps this single spinner
                  // up until the trips + schedules have finished reloading.
                  onRefresh: _refreshHomeData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          // child: Center(
                          //   child: Text(
                          //     'Schedules',
                          //     style: TextStyle(
                          //       fontSize: 18,
                          //       fontWeight: FontWeight.w600,
                          //       color: Color(0xFF222222),
                          //     ),
                          //   ),
                          // ),
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
        onRetry: () =>
            Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
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
        onRetry: () =>
            Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MobileNoVerification()),
          (route) => false,
        ),
        retryLabel: 'Sign in again',
      );
    }

    // Retain the latest loaded groups so a background refresh can keep showing
    // them instead of flashing the inline loader.
    if (tripState is TripHomeLoaded) {
      _lastTripGroups = tripState.groups;
    }
    if (scheduleState is ScheduleHomeLoaded) {
      _lastScheduleGroups = scheduleState.groups;
    }

    // During a pull-to-refresh, fall back to the retained groups so only the
    // single RefreshIndicator spinner is shown — never a second inline loader.
    final tripLoadingRaw =
        tripState is TripHomeLoading || tripState is TripHomeInitial;
    final scheduleLoadingRaw = scheduleState is ScheduleHomeLoading ||
        scheduleState is ScheduleHomeInitial;

    final tripGroups = tripState is TripHomeLoaded
        ? tripState.groups
        : (_isRefreshing ? _lastTripGroups : null);
    final scheduleGroups = scheduleState is ScheduleHomeLoaded
        ? scheduleState.groups
        : (_isRefreshing ? _lastScheduleGroups : null);

    // Only treat a section as "loading" (i.e. show its loader) when we have no
    // cached groups to display in its place.
    final tripLoading = tripLoadingRaw && tripGroups == null;
    final scheduleLoading = scheduleLoadingRaw && scheduleGroups == null;

    if (tripLoading && scheduleLoading) {
      return _buildSectionLoader();
    }

    final children = <Widget>[];

    if (tripLoading) {
      children.add(_buildSectionLoader(compact: true));
    } else if (tripGroups == null && tripState is TripHomeError) {
      children.add(
        _buildSchedulesEmptyState(
          title: 'Could not load active trips',
          subtitle: _friendlyErrorMessage(tripState.message),
          onRetry: () =>
              context.read<TripHomeBloc>().add(const FetchTripHome()),
          retryLabel: 'Retry',
        ),
      );
    } else if (tripGroups != null) {
      final tripCards = _buildTripHomeGroupWidgets(tripGroups);
      if (tripCards.isNotEmpty) {
        children.add(_buildSubsectionLabel('Active Trips'));
        // children.add(_buildSubsectionLabel('Yash shorebird patch'));
        children.addAll(tripCards);
        children.add(const SizedBox(height: 16));
      }
    }

    // Build a set of (dateIso, isLogin) keys from active trips so that schedule
    // cards with the same date and trip type are suppressed.
    final activeTripKeys = <String>{};
    if (tripGroups != null) {
      for (final group in tripGroups) {
        for (final item in group.data) {
          final iso = scheduleDateToIso(item.tripDate);
          if (iso != null && iso.isNotEmpty) {
            activeTripKeys.add('${iso}_${item.isLogin}');
          }
        }
      }
    }

    if (scheduleLoading) {
      children.add(_buildSectionLoader(compact: true));
    } else if (scheduleGroups == null && scheduleState is ScheduleHomeError) {
      children.add(
        _buildSchedulesEmptyState(
          title: 'Could not load schedules',
          subtitle: _friendlyErrorMessage(scheduleState.message),
          onRetry: () =>
              context.read<ScheduleHomeBloc>().add(const FetchScheduleHome()),
          retryLabel: 'Retry',
        ),
      );
    } else if (scheduleGroups != null) {
      final scheduleCards = _buildScheduleGroupWidgets(
        scheduleGroups,
        activeTripKeys: activeTripKeys,
      );
      if (scheduleCards.isNotEmpty) {
        children.add(_buildSubsectionLabel('Scheduled'));
        // children.add(_buildSubsectionLabel('Yash shorebird patch'));
        children.addAll(scheduleCards);
      }
    }

    if (children.isEmpty) {
      return _buildSchedulesEmptyState(
        title: 'No schedules yet',
        subtitle:
            'You have no active trips or scheduled rides. Pull down to refresh.',
        isError: false,
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

  /// Converts raw error objects / exception strings into a friendly,
  /// user-facing message. Prevents leaking internals like
  /// "Instance of 'ServerException'" to the UI.
  String _friendlyErrorMessage(String? raw) {
    final message = raw?.trim() ?? '';

    final looksTechnical = message.isEmpty ||
        message.startsWith("Instance of") ||
        message.contains('Exception') ||
        message.contains('Error:') ||
        message.contains('SocketException') ||
        message.contains('TimeoutException') ||
        message.contains('FormatException') ||
        message.length > 120;

    if (looksTechnical) {
      return 'Something went wrong while connecting to the server. '
          'Please check your connection and try again.';
    }
    return message;
  }

  Widget _buildSchedulesEmptyState({
    required String title,
    required String subtitle,
    VoidCallback? onRetry,
    String retryLabel = 'Retry',
    bool isError = true,
  }) {
    final accent = const Color(0xFF1A6B3C);
    final IconData icon =
        isError ? Icons.cloud_off_rounded : Icons.event_busy_rounded;
    final Color iconBg =
        isError ? const Color(0xFFFDECEC) : const Color(0xFFEAF4EE);
    final Color iconColor = isError ? const Color(0xFFD64545) : accent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEDEDED)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Color(0xFF777777),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: Icon(
                    retryLabel == 'Retry'
                        ? Icons.refresh_rounded
                        : Icons.login_rounded,
                    size: 18,
                  ),
                  label: Text(
                    retryLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFFB8DEC9)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _toggleTripExpansion(String key) {
    setState(() {
      if (_tripExpanded.contains(key)) {
        _tripExpanded.remove(key);
      } else {
        // Only one active card open at a time.
        _tripExpanded
          ..clear()
          ..add(key);
      }
    });
  }

  void _toggleScheduleExpansion(String key) {
    setState(() {
      if (_scheduleExpanded.contains(key)) {
        _scheduleExpanded.remove(key);
      } else {
        // Only one schedule card open at a time.
        _scheduleExpanded
          ..clear()
          ..add(key);
      }
    });
  }

  // ─── Date / time helpers ───────────────────────────────────────────────────

  static const List<String> _monthAbbrev = [
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

  static const Map<String, int> _monthIndex = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  static const List<String> _weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
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

  /// A single OTP display card with a label above a row of digit boxes.
  Widget _buildOtpField({
    required String label,
    required List<String> digits,
    bool compact = false,
  }) {
    Widget digitBox(String digit) => Container(
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
        );

    // In compact mode (two fields side by side) the boxes flex to share the
    // halved width; otherwise they keep their fixed 36px size.
    final Widget digitsRow = compact
        ? Row(
            children: [
              for (var i = 0; i < digits.length; i++) ...[
                Expanded(child: digitBox(digits[i])),
                if (i != digits.length - 1) const SizedBox(width: 6),
              ],
            ],
          )
        : Row(
            children: digits
                .map(
                  (digit) => Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 36,
                    child: digitBox(digit),
                  ),
                )
                .toList(),
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xff6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          digitsRow,
        ],
      ),
    );
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
  // Full-width "Vehicle Info." box matching the active-card style. Used by the
  // Completed / Cancelled / No-show branches where no other info box is shown.
  Widget _buildVehicleInfoBox(String vehicleLabel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
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
    );
  }

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
            color:
                hasAddress ? const Color(0xFF2C3437) : const Color(0xFF9AA0A6),
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

  List<Widget> _buildScheduleGroupWidgets(
    List<ScheduleDateGroup> groups, {
    Set<String> activeTripKeys = const {},
  }) {
    final widgets = <Widget>[];

    // When cancel-schedule-after-TAT is enabled, a cancelled / no-show schedule
    // leg must still render as a schedule card even if an active trip exists
    // for the same date — so the active-trip de-dup is bypassed for that leg.
    // UserAppConfiguration highest-priority gate: when
    // isCancelledScheduledAllowedAfterTAT is `false` the after-TAT behaviour is
    // fully disabled, ignoring the AppControl/TAT flag entirely.
    final appControlState = context.read<AppControlBloc>().state;
    final bool cancelScheduleAfterTAT = _gateScheduleCancelAfterTAT &&
        appControlState is AppControlLoaded &&
        appControlState.settings.isCancelScheduleByUserAfterTAT;
    bool hasText(String? v) => v != null && v.trim().isNotEmpty;

    // Counter that is unique across every group so each schedule card gets its
    // own expansion key. Using only the per-group index `i` caused collisions
    // when two date groups shared the same (or null) `dateIn` label, which made
    // all matching Login (or Logout) cards expand together.
    var cardIndex = 0;

    for (var g = 0; g < groups.length; g++) {
      final group = groups[g];
      // Find the visible cards in this group first; if there are none we
      // skip the heading too (cleaner UX than a dangling date label).
      final groupCards = <Widget>[];
      for (var i = 0; i < group.data.length; i++) {
        final item = group.data[i];
        final bool loginCancelledOrNoShow = cancelScheduleAfterTAT &&
            (hasText(item.loginNoshow) || hasText(item.loginCancelled));
        // A login card is hidden only when LoginShiftTime, LoginCancelled and
        // LoginNoshow are all null/empty (see [shouldShowLoginCard]); if any one
        // is non-empty the card is shown. The extra OR keeps the cancelled /
        // no-show leg visible for the de-dup bypass below.
        final bool showLoginCard = item.shouldShowLoginCard ||
            (loginCancelledOrNoShow && item.hasLoginSchedule);
        if (showLoginCard) {
          final loginIso = scheduleDateToIso(item.loginScheduleDate);
          final activeKey = '${loginIso}_true';
          if (loginIso != null &&
              activeTripKeys.contains(activeKey) &&
              !loginCancelledOrNoShow) {
            // Already shown as an active trip — skip this schedule card.
          } else {
            final key = '${group.dateIn ?? "_"}_${g}_login_${i}_$cardIndex';
            cardIndex++;
            groupCards.add(_buildScheduleCard(
              type: 'login',
              label: 'Login',
              time: _formatShiftTime(item.loginShiftTime) ?? '',
              isExpanded: _scheduleExpanded.contains(key),
              onTap: () => _toggleScheduleExpansion(key),
              isScheduled: item.isScheduledStatus,
              item: item,
            ));
            groupCards.add(const SizedBox(height: 10));
          }
        }
        final bool logoutCancelledOrNoShow = cancelScheduleAfterTAT &&
            (hasText(item.logoutNoshow) || hasText(item.logoutCancelled));
        // A logout card is hidden only when LogoutShiftTime, LogoutCancelled and
        // LogoutNoshow are all null/empty (see [shouldShowLogoutCard]); if any
        // one is non-empty the card is shown. The extra OR keeps the cancelled /
        // no-show leg visible for the de-dup bypass below.
        final bool showLogoutCard = item.shouldShowLogoutCard ||
            (logoutCancelledOrNoShow && item.hasLogoutSchedule);
        if (showLogoutCard) {
          final logoutIso = scheduleDateToIso(item.logoutScheduleDate);
          final activeKey = '${logoutIso}_false';
          if (logoutIso != null &&
              activeTripKeys.contains(activeKey) &&
              !logoutCancelledOrNoShow) {
            // Already shown as an active trip — skip this schedule card.
          } else {
            final key = '${group.dateIn ?? "_"}_${g}_logout_${i}_$cardIndex';
            cardIndex++;
            groupCards.add(_buildScheduleCard(
              type: 'logout',
              label: 'Logout',
              time: _formatShiftTime(item.logoutShiftTime) ?? '',
              isExpanded: _scheduleExpanded.contains(key),
              onTap: () => _toggleScheduleExpansion(key),
              isScheduled: item.isScheduledStatus,
              item: item,
            ));
            groupCards.add(const SizedBox(height: 10));
          }
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
    Color statusColor =
        isScheduled ? scheduledStatusColor : allocatedStatusColor;
    final Color tagBgColor =
        isLogin ? const Color(0xFFE8F5EE) : const Color(0xFFFFF0EE);
    final Color tagTextColor =
        isLogin ? const Color(0xFF3E9B73) : const Color(0xFFB40D1A);
    final IconData arrowIcon = isLogin ? Icons.login : Icons.logout;
    final IconData statusIcon =
        isScheduled ? Icons.access_time : Icons.check_circle_outline;

    // ─── Status label ─────────────────────────────────────────────────────
    // The noshow/cancelled fields always take precedence over tripStatusName
    // (noshow first, then cancelled), regardless of the AppControl
    // isCancelScheduleByUserAfterTAT flag (`true` OR `false`). When neither is
    // present the label comes straight from tripStatusName.
    final appControlState = context.read<AppControlBloc>().state;

    bool isNotEmpty(String? v) => v != null && v.trim().isNotEmpty;

    final String? tripStatusName = item.tripStatusName;
    String statusLabel = tripStatusName ?? '';
    {
      final String? noshow = isLogin ? item.loginNoshow : item.logoutNoshow;
      final String? cancelled =
          isLogin ? item.loginCancelled : item.logoutCancelled;
      if (isNotEmpty(noshow)) {
        statusLabel = noshow!;
        // No-Show / Cancelled statuses are always shown in red.
        statusColor = const Color(0xFFB40D1A);
      } else if (isNotEmpty(cancelled)) {
        statusLabel = cancelled!;
        statusColor = const Color(0xFFB40D1A);
      } else {
        statusLabel = tripStatusName ?? '';
      }
    }
    final List<String> otpDigits = ['3', '3', '3', '3'];

    // ─── Disabled "Track Vehicle" styling when in Scheduled state ─────────
    final Color trackBg = isScheduled ? const Color(0xFFF1F1F1) : tagBgColor;
    final Color trackFg = isScheduled ? const Color(0xFFB0B0B0) : accentColor;
    final VoidCallback? trackVehicleAction = isScheduled
        ? null
        : () => _openRideTracking(
              context,
              empId: item.empId,
              tripId: null,
              userName: item.userName,
            );

    // ─── Action-button visibility ─────────────────────────────────────────
    // Priority: Cancelled → No-Show → ButtonUiConfig.
    //   • If this side is already Cancelled (Login/LogoutCancelled non-empty) or
    //     No-Show (Login/LogoutNoshow non-empty), hide ALL action buttons for
    //     this card (Cancel, No-Show, Edit and Track Vehicle) and ignore the
    //     ButtonUiConfig flags entirely.
    //   • Otherwise, per-direction ButtonUiConfig flags drive each button
    //     (all default false when the config/field is missing).
    final bool sideCancelled =
        isNotEmpty(isLogin ? item.loginCancelled : item.logoutCancelled);
    final bool sideNoShow =
        isNotEmpty(isLogin ? item.loginNoshow : item.logoutNoshow);
    // Per-location AppControl flag (isCancelScheduleByUserAfterTAT), read raw
    // (independent of the UserAppConfiguration after-TAT gate).
    final bool isCancelScheduleByUserAfterTAT =
        appControlState is AppControlLoaded &&
            appControlState.settings.isCancelScheduleByUserAfterTAT;
    // When this side is Cancelled (Login/LogoutCancelled non-empty), the action
    // buttons are always driven purely by ButtonUiConfig — the Cancelled /
    // No-Show "hide all actions" override is ignored for this card.
    // Otherwise the existing behaviour is preserved:
    //   • isCancelScheduleByUserAfterTAT `false` → drive buttons from
    //     ButtonUiConfig (override ignored).
    //   • isCancelScheduleByUserAfterTAT `true`  → a No-Show leg suppresses
    //     every action button.
    final bool hideAllActions =
        !sideCancelled && isCancelScheduleByUserAfterTAT && sideNoShow;

    final ButtonUiConfig uiConfig =
        item.buttonUiConfig ?? const ButtonUiConfig();
    // UserAppConfiguration highest-priority gate: when a schedule feature flag
    // is `false` the corresponding button is always hidden, regardless of the
    // per-schedule ButtonUiConfig / cancelled / no-show logic below.
    final bool showNoShowButton = _gateScheduleNoShow &&
        !hideAllActions &&
        (isLogin
            ? uiConfig.cancelSchedulePickupNoShowButtonShow
            : uiConfig.cancelScheduleDropNoShowButtonShow);
    final bool showCancelButton = _gateScheduleCancel &&
        !hideAllActions &&
        (isLogin
            ? uiConfig.cancelSchedulePickupButtonShow
            : uiConfig.cancelScheduleDropButtonShow);
    final bool showEditButton = _gateScheduleEdit &&
        !hideAllActions &&
        (isLogin
            ? uiConfig.editSchedulePickupButtonShow
            : uiConfig.editScheduleDropButtonShow);
    // Track Vehicle keeps its existing always-shown behaviour unless the side
    // is Cancelled / No-Show, in which case it stays hidden — unaffected by the
    // isCancelScheduleByUserAfterTAT ButtonUiConfig override above.
    final bool showTrackButton =
        _gateScheduleTracking && !(sideCancelled || sideNoShow);

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
                  // Shift-time chip is hidden when there is no shift time
                  // (e.g. a cancelled / no-show schedule with an empty time).
                  if (time.trim().isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
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
                  ],
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
                            address:
                                isLogin ? item.userAddress : item.officeAddress,
                          ),
                          const SizedBox(height: 20),
                          // Drop:
                          //   Login  → office (OfficeAddress)
                          //   Logout → user's home (UserAddress)
                          _buildAddressBlock(
                            label: 'DROP',
                            address:
                                isLogin ? item.officeAddress : item.userAddress,
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
                  if (showNoShowButton) ...[
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
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0x33BA1A1A)),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'No-Show',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFBA1A1A),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (showCancelButton) ...[
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
                  ],
                  if (showEditButton) ...[
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
                  ],
                  if (showTrackButton)
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
                                Icon(Icons.my_location,
                                    size: 16, color: trackFg),
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
                    if (showTrackButton)
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
    final String time = isLogin
        ? _formatShiftTime(item.pickShift) ?? '--:--'
        : _formatShiftTime(item.dropShift) ?? '--:--';
    final bool isScheduled = item.isScheduledStatus;
    final bool isCompleted = item.isCompleted;
    final bool showBoardDeboardActions =
        item.showBoardDeboardActions && !isCompleted;
    final bool isFullyDeboarded = item.isBoarded && item.isDeBoarded;
    // The active-trip card shows independent No-Show and Cancel action buttons.
    //   • No-Show: only relevant after TAT — gated by the per-location AppControl
    //     flag (isCancelTripByUserAfterTAT), the UserAppConfiguration No-Show
    //     gate, and the per-trip `isTripNoShowButtonShow` flag.
    //   • Cancel: gated by the UserAppConfiguration Cancel gate and the per-trip
    //     `isTripCancellationButtonShow` flag.
    // Both may appear at once (mirrors the schedule-card button model). When
    // absent, the config/gate defaults hide each button.
    final appControlStateForCancel = context.read<AppControlBloc>().state;
    final bool isCancelTripByUserAfterTAT =
        appControlStateForCancel is AppControlLoaded &&
            appControlStateForCancel.settings.isCancelTripByUserAfterTAT;
    final bool showTripNoShowButton = _gateTripNoShow &&
        isCancelTripByUserAfterTAT &&
        (item.tripButtonUiConfig?.isTripNoShowButtonShow ?? false);
    final bool showTripCancelButton = _gateTripCancellation &&
        (item.tripButtonUiConfig?.isTripCancellationButtonShow ?? false);
    final String? cancelOrNoShow = item.cancelorNoshow?.trim();
    // Trip is cancelled or a no-show: only TRIP DETAIL + Trip Summary should be
    // shown — no planned pickup, OTP, vehicle info, board/deboard, or actions.
    final bool isCancelledOrNoShow =
        cancelOrNoShow == 'Cancelled' || cancelOrNoShow == 'Noshow';
    final statusStyle = isCancelledOrNoShow
        ? (icon: Icons.cancel_outlined, color: const Color(0xFFB40D1A))
        : isCompleted
            ? (icon: Icons.check_circle_outline, color: const Color(0xFF2563EB))
            : _tripStatusStyle(item.tripStatusName, isLogin);
    final Color accentColor =
        isLogin ? const Color(0xFF3E9B73) : const Color(0xFFB40D1A);
    final Color statusColor = statusStyle.color;
    final Color tagBgColor =
        isLogin ? const Color(0xFFE8F5EE) : const Color(0xFFFFF0EE);
    final Color tagTextColor =
        isLogin ? const Color(0xFF3E9B73) : const Color(0xFFB40D1A);
    final IconData arrowIcon = isLogin ? Icons.login : Icons.logout;
    final IconData statusIcon = statusStyle.icon;
    final String statusLabel = cancelOrNoShow == 'Cancelled'
        ? 'Cancelled'
        : cancelOrNoShow == 'Noshow'
            ? 'No Show'
            : (isCompleted ? 'Trip Completed' : (item.tripStatusName ?? '—'));
    // Boarding OTP comes from `item.otp`; once the user has boarded (but not
    // yet deboarded) we show the deboard OTP from `item.deBoardOtp` instead.
    final List<String> otpDigits = item.isBoardedNotDeboarded
        ? _otpDigits(item.deBoardOtp?.toString())
        : _otpDigits(item.otp);
    final plannedPickup = _plannedPickupLabel(item) ?? '--:--';
    final vehicleLabel = (item.vehicleInfo?.trim().isNotEmpty ?? false)
        ? item.vehicleInfo!.trim()
        : 'Not assigned';
    final seqLabel = (item.paxOrder != null && item.paxCount != null)
        ? 'Seq: ${item.paxOrder}/${item.paxCount}'
        : null;
    final ivr = item.userAppIvrNumber?.trim();

    final bool isPrinted =
        (item.tripStatusName ?? '').trim().toLowerCase() == 'printed';

    // ─── Safe Home Reach button ──────────────────────────────────────────
    // Shown only when the trip is in the Started (code 3) state, the backend
    // requests it (ReachedHomeReq == 1) and the user has not already reached
    // home (IsReached != 1). It must never appear in the Printed state.
    //   - boardDebaordEnabledForUser == false -> show as soon as requested.
    //   - boardDebaordEnabledForUser == true  -> show only after the user has
    //     both boarded and deboarded.
    final appControlState = context.read<AppControlBloc>().state;
    final bool boardDeboardEnabled = appControlState is AppControlLoaded &&
        appControlState.settings.boardDebaordEnabledForUser;
    // UserAppConfiguration highest-priority gate: hide Safe Home Reach entirely
    // when isTripSafeHomeReach is `false`, ignoring the conditions below.
    final bool showSafeHomeReachButton = _gateTripSafeHomeReach &&
        item.isStarted &&
        item.reachedHomeReq == 1 &&
        item.isReached != 1 &&
        item.isBoarded &&
        item.isDeBoarded &&
        (boardDeboardEnabled ? (item.isBoarded && item.isDeBoarded) : true);

    // Same Safe Home Reach visibility logic reused for the Trip Completed
    // (End) card. Conditions are identical to showSafeHomeReachButton above,
    // with the state gate switched from Started (code 3) to Completed (code 4)
    // since the two states are mutually exclusive. Nothing else changes.
    final bool showSafeHomeReachButtonCompleted = _gateTripSafeHomeReach &&
        item.isCompleted &&
        item.reachedHomeReq == 1 &&
        item.isReached != 1 &&
        item.isBoarded &&
        item.isDeBoarded &&
        (boardDeboardEnabled ? (item.isBoarded && item.isDeBoarded) : true);

    // ─── Disabled "Track Vehicle" styling when in Scheduled state ─────────
    final Color trackBg = isScheduled ? const Color(0xFFF1F1F1) : tagBgColor;
    final Color trackFg = isScheduled ? const Color(0xFFB0B0B0) : accentColor;
    final VoidCallback? trackVehicleAction = isScheduled
        ? null
        : () => _openRideTracking(
              context,
              empId: item.empId,
              tripId: item.tripId,
              userName: item.userName,
              boardingOtp: item.otp,
            );

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
                  // Status badge (only while TripStatusCode == 3 / Started):
                  //   isBoarded && isDeBoarded -> "DeBoarded"
                  //   isStarted && isBoarded   -> "Boarded"
                  // Shown on both Login (PICK) and Logout (DROP) trips.
                  if (isCancelledOrNoShow || item.tripStatusCode != 3) ...[
                    // No board/deboard badge for cancelled / no-show trips or
                    // when the trip is not in the Started (code 3) state.
                  ] else if (item.isBoarded && item.isDeBoarded) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5EE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'DeBoarded',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A6B3C),
                        ),
                      ),
                    ),
                  ] else if (item.isStarted && item.isBoarded) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5EE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Boarded',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A6B3C),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isExpanded) ...[
              const SizedBox(height: 14),
              Container(height: 1, color: const Color(0xFFE8E8E8)),
              const SizedBox(height: 14),
              const Padding(
                padding: EdgeInsets.only(left: 4),
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
                          _buildAddressBlock(
                            label: 'PICKUP',
                            address:
                                isLogin ? item.userAddress : item.officeAddress,
                          ),
                          const SizedBox(height: 20),
                          _buildAddressBlock(
                            label: 'DROP',
                            address:
                                isLogin ? item.officeAddress : item.userAddress,
                          ),
                          if (seqLabel != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.event_seat_outlined,
                                    size: 16, color: Colors.grey[600]),
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
              if (isCompleted) ...[
                // ─── Completed: Pickup + Drop Timing boxes ────────────────
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Drop Time box — hidden for completed Logout trips.
                    isLogin
                        ? Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFE8E8E8)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isLogin ? 'Pickup Time' : 'Drop Time',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xff6B7280),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isLogin
                                        // ? plannedPickup
                                        ? (_formatShiftTime(item.pickTime) ??
                                            '--:--')
                                        : (_formatShiftTime(item.dropShift) ??
                                            '--:--'),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox(),
                    isLogin ? const SizedBox(width: 10) : const SizedBox(),
                    !isLogin
                        ? Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFE8E8E8)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  !isLogin
                                      ? Text(
                                          isLogin ? 'Drop Time' : 'Pickup Time',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xff6B7280),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        )
                                      : SizedBox(),
                                  const SizedBox(height: 4),
                                  !isLogin
                                      ? Text(
                                          isLogin
                                              ? (_formatShiftTime(
                                                      item.dropShift) ??
                                                  '--:--')
                                              : plannedPickup,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1A1A1A),
                                          ),
                                        )
                                      : SizedBox(),
                                ],
                              ),
                            ),
                          )
                        : SizedBox(),
                  ],
                ),
                // ─── Vehicle Info (also shown when Completed) ──────────────
                const SizedBox(height: 10),
                _buildVehicleInfoBox(vehicleLabel),
                // ─── Trip Summary button ──────────────────────────────────
                // UserAppConfiguration highest-priority gate: hide Trip Summary
                // entirely when isTripSummaryAllowed is `false`.
                if (_gateTripSummary) ...[
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TripSummaryWelcomeScreen(item: item),
                      ),
                    ),
                    child: Container(
                      width: double.infinity,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5EE),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Trip Summary',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A6B3C),
                        ),
                      ),
                    ),
                  ),
                ],
              ] else if (isCancelledOrNoShow) ...[
                // ─── Cancelled / No-show: Vehicle Info + Trip Summary ─────
                // When the trip was Started and the user was a No-show, also
                // surface the planned pickup time.
                if ((item.tripStatusName ?? '').trim().toLowerCase() ==
                        'started' &&
                    cancelOrNoShow == 'Noshow') ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
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
                        const Text(
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
                ],
                const SizedBox(height: 16),
                _buildVehicleInfoBox(vehicleLabel),
                // UserAppConfiguration highest-priority gate: hide Trip Summary
                // entirely when isTripSummaryAllowed is `false`.
                if (_gateTripSummary) ...[
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TripSummaryWelcomeScreen(item: item),
                      ),
                    ),
                    child: Container(
                      width: double.infinity,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5EE),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Trip Summary',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A6B3C),
                        ),
                      ),
                    ),
                  ),
                ],
              ] else if (!isScheduled) ...[
                // ─── Non-completed: Planned Pickup + Vehicle Info ─────────
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
                            const Text(
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
                                  const Text(
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
                            if (_gateTripIvrCall &&
                                ivr != null &&
                                ivr.isNotEmpty &&
                                !isFullyDeboarded)
                              InkWell(
                                splashColor: Colors.transparent,
                                onTap: () => _callDriverIvr(item),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: tagBgColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.phone,
                                      size: 18, color: accentColor),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // ─── Boarding / Deboard OTP ───────────────────────────────
                // When the trip is "Started", show the Boarding OTP together
                // with the Deboard OTP. In all other (non fully-deboarded)
                // states, show the single relevant OTP field.
                if (!isFullyDeboarded) ...[
                  const SizedBox(height: 14),
                  if (item.isStarted)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildOtpField(
                            label: 'Boarding OTP',
                            digits: _otpDigits(item.otp),
                            compact: true,
                          ),
                        ),
                        // UserAppConfiguration highest-priority gate: hide the
                        // Deboard OTP field when isDeboardOtpFieldAllowed is
                        // `false`.
                        if (_gateDeboardOtpField) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildOtpField(
                              label: 'Deboard OTP',
                              digits: _otpDigits(item.deBoardOtp?.toString()),
                              compact: true,
                            ),
                          ),
                        ],
                      ],
                    )
                  // The single OTP field is a Deboard OTP field once the user
                  // has boarded (isBoardedNotDeboarded); gate that case only.
                  else if (!item.isBoardedNotDeboarded || _gateDeboardOtpField)
                    _buildOtpField(
                      label: item.isBoardedNotDeboarded
                          ? 'Deboard OTP'
                          : 'Boarding OTP',
                      digits: otpDigits,
                    ),
                ],
              ],
              if (!isCancelledOrNoShow) const SizedBox(height: 14),
              if (isCancelledOrNoShow)
                const SizedBox.shrink()
              else if (showSafeHomeReachButton)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Live Tracking must always be available while the trip is
                    // "Started" — even when the Safe Home Reach CTA is shown.
                    // UserAppConfiguration highest-priority gate: hidden when
                    // isTripTrackingAllowed is `false`.
                    if (_gateTripTracking && item.isStarted) ...[
                      GestureDetector(
                        onTap: trackVehicleAction,
                        child: Container(
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: trackBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.my_location, size: 18, color: trackFg),
                              const SizedBox(width: 8),
                              Text(
                                'Live Tracking',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: trackFg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    GestureDetector(
                      onTap: () => _onSafeHomeReachTap(item),
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A5C38),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.home_outlined,
                                size: 18, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Safe Home Reach',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              else if (showSafeHomeReachButtonCompleted)
                // Trip Completed (End) card reuses the exact same Safe Home
                // Reach button widget and callback as the Started card.
                GestureDetector(
                  onTap: () => _onSafeHomeReachTap(item),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A5C38),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.home_outlined,
                            size: 18, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Safe Home Reach',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (isCompleted)
                const SizedBox.shrink()
              else if (isPrinted)
                Row(
                  children: [
                    if (showTripNoShowButton) ...[
                      _buildTripNoShowTextButton(
                        onTap: () => _showCancelActiveTripDialog(
                          context,
                          item: item,
                          isNoShow: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (showTripCancelButton)
                      InkWell(
                        splashColor: Colors.transparent,
                        onTap: () =>
                            _showCancelActiveTripDialog(context, item: item),
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
                  ],
                )
              else if (showBoardDeboardActions)
                _buildTripStartedExpandedActions(
                  item: item,
                  accentColor: accentColor,
                  tagBgColor: tagBgColor,
                  trackBg: trackBg,
                  trackFg: trackFg,
                  trackVehicleAction: trackVehicleAction,
                )
              else if (!isFullyDeboarded && !isPrinted)
                Row(
                  children: [
                    if (!isScheduled && showTripNoShowButton) ...[
                      _buildTripNoShowTextButton(
                        onTap: () => _showCancelActiveTripDialog(
                          context,
                          item: item,
                          isNoShow: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (!isScheduled && showTripCancelButton) ...[
                      InkWell(
                        splashColor: Colors.transparent,
                        onTap: () => _showCancelActiveTripDialog(
                          context,
                          item: item,
                        ),
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
                    ],
                    if (_gateTripTracking)
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
                                  Icon(Icons.my_location,
                                      size: 16, color: trackFg),
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
            ] else if (isCompleted) ...[
              // ─── Collapsed: inline "Trip Completed" (no extra chip border) ─
              const SizedBox(height: 8),
            ] else if (!isScheduled &&
                !isFullyDeboarded &&
                !isPrinted &&
                !isCancelledOrNoShow) ...[
              // ─── Collapsed: Boarding OTP + Track Vehicle ─
              const SizedBox(height: 12),
              Container(height: 1, color: const Color(0xFFE8E8E8)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 30.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // UserAppConfiguration highest-priority gate: when this is
                    // the Deboard OTP field (isBoardedNotDeboarded) hide it if
                    // isDeboardOtpFieldAllowed is `false`; a Spacer keeps the
                    // Track Vehicle button right-aligned.
                    if (!item.isBoardedNotDeboarded || _gateDeboardOtpField)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.isBoardedNotDeboarded
                                  ? 'Deboard OTP'
                                  : 'Boarding OTP',
                              style: const TextStyle(
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
                      )
                    else
                      const Spacer(),
                    if (_gateTripTracking && !isFullyDeboarded)
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
    return _SosHoldButton(onActivated: _showSOSDialog);
  }

  void _showSOSDialog() {
    final rosterState = context.read<RosterBloc>().state;
    final empId =
        rosterState is RosterLoaded ? rosterState.details.empId : null;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<SosBloc>(),
        child: BlocListener<SosBloc, SosState>(
          listener: (_, state) {
            if (state is SosSuccess) {
              Navigator.of(dialogContext).pop();
              showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => const _SosResultDialog(
                  success: true,
                  message: 'SOS alert triggered successfully. Our safety team '
                      'has been notified and your live location is being shared.',
                ),
              );
            } else if (state is SosError || state is SosUnauthorized) {
              Navigator.of(dialogContext).pop();
              final msg = state is SosError
                  ? state.message
                  : (state as SosUnauthorized).message;
              showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => _SosResultDialog(
                  success: false,
                  message: msg,
                ),
              );
            }
          },
          child: BlocBuilder<SosBloc, SosState>(
            builder: (dialogCtx, sosState) {
              final isLoading = sosState is SosLoading;
              return Dialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                insetPadding: const EdgeInsets.symmetric(horizontal: 32),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.center,
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
                        ],
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
                        'Are you sure you want to trigger an emergency alert? This will immediately notify our safety team and share your live location with local authorities.',
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
                              onTap: isLoading
                                  ? null
                                  : () {
                                      if (empId == null) {
                                        Navigator.of(dialogContext).pop();
                                        ScaffoldMessenger.of(context)
                                          ..hideCurrentSnackBar()
                                          ..showSnackBar(const SnackBar(
                                            content: Text(
                                                'Employee data not loaded. Please try again.'),
                                            behavior: SnackBarBehavior.floating,
                                          ));
                                        return;
                                      }
                                      dialogCtx
                                          .read<SosBloc>()
                                          .add(TriggerSos(empId: empId));
                                    },
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFB40D1A),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                alignment: Alignment.center,
                                child: isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
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
                              onTap: isLoading
                                  ? null
                                  : () => Navigator.of(dialogContext).pop(),
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                      color: const Color(0xFFE0E0E0)),
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
              );
            },
          ),
        ),
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
            builder: (context) => TripDetailsScreen(
              hybridScheduleEnabled: _hybridScheduleEnabled,
              isScheduleFillForLoginAndLogoutBoth:
                  _isScheduleFillForLoginAndLogoutBoth,
            ),
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
                onTap: _selectTripHistoryTab,
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

/// Board confirmation dialog — calls `POST /UserApp/UserBoardDeboard`.
class BoardTripDialog extends StatelessWidget {
  const BoardTripDialog({
    super.key,
    required this.item,
    required this.empId,
    required this.tripId,
    required this.tripType,
    this.boardingType = 'B',
  });

  final TripHomeItem item;
  final int empId;
  final int tripId;
  final int tripType;
  final String boardingType;

  bool get _isDeboard => boardingType == 'D';

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BoardTripBloc>(
      create: (_) => sl<BoardTripBloc>(),
      child: _BoardTripDialogView(
        plateNumber: item.vehicleInfo?.trim().isNotEmpty == true
            ? item.vehicleInfo!.trim()
            : 'Not assigned',
        empId: empId,
        tripId: tripId,
        tripType: tripType,
        boardingType: boardingType,
        title: _isDeboard ? 'Ready to deboard?' : 'Ready to board?',
        description: _isDeboard
            ? 'Please confirm you have reached your destination and are ready to deboard.'
            : 'Please confirm you have reached the vehicle and are ready to start your trip.',
        confirmColor:
            _isDeboard ? const Color(0xFFB40D1A) : const Color(0xFF1A5C38),
        successFallback:
            _isDeboard ? 'Deboarded successfully.' : 'Boarded successfully.',
      ),
    );
  }
}

class _BoardTripDialogView extends StatefulWidget {
  const _BoardTripDialogView({
    required this.plateNumber,
    required this.empId,
    required this.tripId,
    required this.tripType,
    required this.boardingType,
    required this.title,
    required this.description,
    required this.confirmColor,
    required this.successFallback,
  });

  final String plateNumber;
  final int empId;
  final int tripId;
  final int tripType;
  final String boardingType;
  final String title;
  final String description;
  final Color confirmColor;
  final String successFallback;

  @override
  State<_BoardTripDialogView> createState() => _BoardTripDialogViewState();
}

class _BoardTripDialogViewState extends State<_BoardTripDialogView> {
  bool _isClosing = false;

  void _closeDialog([String? result]) {
    if (_isClosing || !mounted) return;
    _isClosing = true;
    Navigator.of(context).pop(result);
  }

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

  String _friendlyMessage(String raw) {
    return ErrorMessage.from(raw,
        fallback: 'Something went wrong. Please try again.');
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BoardTripBloc, BoardTripState>(
      listenWhen: (prev, curr) =>
          curr is BoardTripSuccess ||
          curr is BoardTripError ||
          curr is BoardTripUnauthorized,
      listener: (context, state) {
        if (state is BoardTripSuccess) {
          final message =
              state.message.isNotEmpty ? state.message : widget.successFallback;
          _closeDialog(message);
        } else if (state is BoardTripError) {
          _showSnackBar(context, _friendlyMessage(state.message), error: true);
        } else if (state is BoardTripUnauthorized) {
          _closeDialog();
          _showSnackBar(context, _friendlyMessage(state.message), error: true);
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MobileNoVerification()),
            (route) => false,
          );
        }
      },
      buildWhen: (prev, curr) =>
          curr is BoardTripInitial ||
          curr is BoardTripLoading ||
          curr is BoardTripSuccess ||
          curr is BoardTripError ||
          curr is BoardTripUnauthorized,
      builder: (context, state) {
        final isSubmitting = state is BoardTripLoading;
        return PopScope(
          canPop: !isSubmitting,
          child: Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PLATE NUMBER',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A5C38),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.plateNumber,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: isSubmitting
                              ? null
                              : () {
                                  context.read<BoardTripBloc>().add(
                                        BoardTripRequested(
                                          empId: widget.empId,
                                          tripId: widget.tripId,
                                          tripType: widget.tripType,
                                          boardingType: widget.boardingType,
                                        ),
                                      );
                                },
                          child: Container(
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSubmitting
                                  ? widget.confirmColor.withValues(alpha: 0.6)
                                  : widget.confirmColor,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Confirm',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: isSubmitting ? null : _closeDialog,
                          child: Container(
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              border:
                                  Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: const Text(
                              'Go Back',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A5C38),
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
      },
    );
  }
}

/// Cancel dialog for active trips (`UserCancelTrip` via [TripCancelBloc]).
class CancelActiveTripDialog extends StatelessWidget {
  const CancelActiveTripDialog({
    super.key,
    required this.isLogin,
    required this.requestedBy,
    required this.requestFor,
    required this.tripDate,
    required this.tripType,
    required this.tripId,
    this.showNoShowWording = false,
  });

  final bool isLogin;
  final int requestedBy;
  final int requestFor;
  final String tripDate;
  final int tripType;
  final int tripId;

  /// When true (driven by `isCancelTripByUserAfterTat == 1`), the primary
  /// action wording reads "No-Show this Ride" instead of the current
  /// cancellation wording. All behaviour, callbacks and API calls are
  /// unchanged.
  final bool showNoShowWording;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TripCancelBloc>(
      create: (_) => sl<TripCancelBloc>(),
      child: _CancelActiveTripDialogView(
        isLogin: isLogin,
        requestedBy: requestedBy,
        requestFor: requestFor,
        tripDate: tripDate,
        tripType: tripType,
        tripId: tripId,
        showNoShowWording: showNoShowWording,
      ),
    );
  }
}

class _CancelActiveTripDialogView extends StatefulWidget {
  const _CancelActiveTripDialogView({
    required this.isLogin,
    required this.requestedBy,
    required this.requestFor,
    required this.tripDate,
    required this.tripType,
    required this.tripId,
    this.showNoShowWording = false,
  });

  final bool isLogin;
  final int requestedBy;
  final int requestFor;
  final String tripDate;
  final int tripType;
  final int tripId;
  final bool showNoShowWording;

  @override
  State<_CancelActiveTripDialogView> createState() =>
      _CancelActiveTripDialogViewState();
}

class _CancelActiveTripDialogViewState
    extends State<_CancelActiveTripDialogView> {
  /// The last successfully loaded popup, retained so the API-driven dialog
  /// keeps rendering while a cancel/no-show request is in progress.
  CancelSchedulePopup? _lastPopup;

  /// True once the API returned an unusable config (or failed) and we've
  /// switched to the hardcoded dialog. Once we fall back we stay on the
  /// hardcoded dialog for the rest of the dialog's lifetime.
  bool _useFallback = false;

  /// True once a backend refusal has been surfaced so the dialog pops exactly
  /// once (guards against a rebuild firing the listener twice).
  bool _handledRefusal = false;

  @override
  void initState() {
    super.initState();
    // The API is the source of truth for the popup content. Fetch it before
    // rendering; on failure / invalid data we fall back to the hardcoded
    // dialog so there is no regression in functionality.
    debugPrint(
      '[WELCOME] CancelActiveTripDialog → dispatching '
      'FetchCancelActiveTripConfirmation requestFor=${widget.requestFor} '
      'tripType=${widget.tripType} tripId=${widget.tripId} '
      '(isLogin=${widget.isLogin})',
    );
    context.read<TripCancelBloc>().add(
          FetchCancelActiveTripConfirmation(
            requestFor: widget.requestFor,
            tripType: widget.tripType,
            tripId: widget.tripId,
          ),
        );
  }

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

  String _friendlyMessage(String raw) {
    return ErrorMessage.from(raw,
        fallback: 'Something went wrong. Please try again.');
  }

  /// Maps the API's icon keyword to a Material icon. Falls back to the previous
  /// hardcoded warning icon for anything unrecognised.
  IconData _iconFor(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'error':
      case 'cancel':
      case 'cancel_schedule':
        return Icons.cancel_outlined;
      case 'info':
        return Icons.info_outline;
      case 'success':
        return Icons.check_circle_outline;
      case 'no_show':
      case 'noshow':
        return Icons.person_off_outlined;
      case 'warning':
      default:
        return Icons.warning_amber_rounded;
    }
  }

  /// Dispatches the existing active-trip cancel / no-show flow.
  void _dispatchCancel(BuildContext context) {
    context.read<TripCancelBloc>().add(
          CancelTripRequested(
            requestedBy: widget.requestedBy,
            requestFor: widget.requestFor,
            tripDate: widget.tripDate,
            tripType: widget.tripType,
            tripId: widget.tripId,
          ),
        );
  }

  /// Runs the action for a button returned by the API.
  void _onButtonAction(BuildContext context, CancelScheduleAction action) {
    switch (action) {
      case CancelScheduleAction.dismiss:
        Navigator.of(context).pop(false);
        break;
      case CancelScheduleAction.markNoShow:
      case CancelScheduleAction.cancelSchedule:
      case CancelScheduleAction.unknown:
        // The primary (non-dismiss) action runs the existing active-trip
        // cancel / no-show flow (POST /UserApp/UserCancelTrip via
        // CancelTripRequested). `unknown` is treated as a cancel too: this
        // handler is only reached from a non-dismiss button, so an
        // unrecognised backend action must still cancel rather than silently
        // do nothing.
        _dispatchCancel(context);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TripCancelBloc, TripCancelState>(
      listenWhen: (prev, curr) =>
          curr is TripCancelSuccess ||
          curr is TripCancelError ||
          curr is TripCancelUnauthorized ||
          curr is TripCancelConfirmRefused ||
          curr is TripCancelConfirmFallback,
      listener: (context, state) {
        if (state is TripCancelConfirmRefused) {
          // Backend explicitly refused cancellation → close and surface the
          // message; do not open any dialog.
          if (_handledRefusal) return;
          _handledRefusal = true;
          Navigator.of(context).pop(false);
          _showSnackBar(context, _friendlyMessage(state.message), error: true);
        } else if (state is TripCancelConfirmFallback) {
          // API refused / failed → render the existing hardcoded dialog.
          debugPrint(
            '[WELCOME] CancelActiveTripDialog → falling back to hardcoded '
            'dialog (reason="${state.message}")',
          );
          if (!_useFallback) {
            setState(() => _useFallback = true);
          }
        } else if (state is TripCancelSuccess) {
          Navigator.of(context).pop(true);
          _showSnackBar(
            context,
            state.message.isNotEmpty
                ? state.message
                : 'Trip cancelled successfully.',
            error: false,
          );
        } else if (state is TripCancelError) {
          _showSnackBar(context, _friendlyMessage(state.message), error: true);
        } else if (state is TripCancelUnauthorized) {
          Navigator.of(context).pop(false);
          _showSnackBar(context, _friendlyMessage(state.message), error: true);
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MobileNoVerification()),
            (route) => false,
          );
        }
      },
      buildWhen: (prev, curr) =>
          curr is TripCancelInitial ||
          curr is TripCancelLoading ||
          curr is TripCancelSuccess ||
          curr is TripCancelError ||
          curr is TripCancelUnauthorized ||
          curr is TripCancelConfirmLoading ||
          curr is TripCancelConfirmLoaded ||
          curr is TripCancelConfirmRefused ||
          curr is TripCancelConfirmFallback,
      builder: (context, state) {
        final isCancelling = state is TripCancelLoading;

        // Fall back to the existing hardcoded dialog on API failure / invalid
        // data so all existing functionality keeps working exactly as today.
        if (_useFallback) {
          return _buildHardcodedDialog(context, isCancelling);
        }

        // While the confirmation config is loading render a lightweight loader.
        if (state is! TripCancelConfirmLoaded &&
            !(isCancelling && _lastPopup != null)) {
          return const PopScope(
            canPop: true,
            child: Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(24)),
              ),
              insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 80),
              child: Padding(
                padding: EdgeInsets.all(36),
                child: SizedBox(
                  height: 48,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Color(0xFF1A5C38),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        // Keep showing the last loaded popup while a cancel/no-show request is
        // in flight so the button spinner can render.
        final CancelSchedulePopup popup =
            state is TripCancelConfirmLoaded ? state.popup : _lastPopup!;
        _lastPopup = popup;

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
                  // Icon circle (icon driven by the API).
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF0EE),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        _iconFor(popup.icon),
                        color: const Color(0xffBA1A1A),
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title (from API).
                  Text(
                    popup.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff181C1B),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Message (from API).
                  Text(
                    popup.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF888888),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Buttons (rendered in ascending `order`, already sorted).
                  Row(
                    children: _buildActionButtons(
                      context,
                      popup.buttons,
                      isCancelling,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the button row from the API config, preserving the existing look:
  /// the primary action (cancel / no-show) uses the red outlined style, and a
  /// `dismiss` action uses the filled green style.
  List<Widget> _buildActionButtons(
    BuildContext context,
    List<CancelScheduleButton> buttons,
    bool isCancelling,
  ) {
    final widgets = <Widget>[];
    for (var i = 0; i < buttons.length; i++) {
      final button = buttons[i];
      final bool isDismiss = button.action == CancelScheduleAction.dismiss;
      final bool isPrimaryAction =
          button.action == CancelScheduleAction.cancelSchedule ||
              button.action == CancelScheduleAction.markNoShow;

      final Widget child;
      if (isDismiss) {
        child = ElevatedButton(
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
              : () => _onButtonAction(context, button.action),
          child: Text(
            button.text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        );
      } else {
        child = OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFCC2222),
            side: const BorderSide(color: Color(0xFFFFCCCC), width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
          ),
          onPressed: isCancelling
              ? null
              : () => _onButtonAction(context, button.action),
          child: isCancelling && isPrimaryAction
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Color(0xFFCC2222),
                  ),
                )
              : Text(
                  button.text,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        );
      }

      widgets.add(Expanded(child: child));
      if (i != buttons.length - 1) {
        widgets.add(const SizedBox(width: 14));
      }
    }
    return widgets;
  }

  /// The original hardcoded dialog, rendered when the API fails / returns
  /// invalid data. Behaviour, callbacks and API calls are unchanged.
  Widget _buildHardcodedDialog(BuildContext context, bool isCancelling) {
    return PopScope(
      canPop: !isCancelling,
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
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
                    Icons.warning_amber_rounded,
                    color: Color(0xffBA1A1A),
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.isLogin
                    ? 'Cancel this Login trip?'
                    : 'Cancel this Logout trip?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff181C1B),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'You are about to cancel this ride. Do you want to continue?',
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
                      onPressed:
                          isCancelling ? null : () => _dispatchCancel(context),
                      child: isCancelling
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Color(0xFFCC2222),
                              ),
                            )
                          : Text(
                              widget.showNoShowWording
                                  ? 'No-Show this Ride'
                                  : 'Cancel Trip',
                              style: const TextStyle(
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
                      onPressed: isCancelling
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text(
                        'Keep Trip',
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

class _CancelRideDialogView extends StatefulWidget {
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

  @override
  State<_CancelRideDialogView> createState() => _CancelRideDialogViewState();
}

class _CancelRideDialogViewState extends State<_CancelRideDialogView> {
  /// True once the confirmation-error message has been surfaced so the dialog
  /// pops exactly once (guards against a rebuild firing the listener twice).
  bool _handledConfirmError = false;

  @override
  void initState() {
    super.initState();
    // The API is the single source of truth for the popup content. Fetch it
    // before rendering; if it fails we close and surface the DB_Response.
    debugPrint(
      '[WELCOME] CancelRideDialog → dispatching '
      'FetchCancelScheduleConfirmation locCode=${widget.locCode} '
      'empId="${widget.empId}" scheduleDate="${widget.scheduleDate}" '
      'tripType="${widget.tripType}" (isLogin=${widget.isLogin})',
    );
    context.read<ShiftBloc>().add(
          FetchCancelScheduleConfirmation(
            locCode: widget.locCode,
            empId: widget.empId,
            scheduleDate: widget.scheduleDate,
            tripType: widget.tripType,
          ),
        );
  }

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

  /// Maps the API's icon keyword to a Material icon. Falls back to the previous
  /// hardcoded warning icon for anything unrecognised.
  IconData _iconFor(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'error':
      case 'cancel':
      case 'cancel_schedule':
        return Icons.cancel_outlined;
      case 'info':
        return Icons.info_outline;
      case 'success':
        return Icons.check_circle_outline;
      case 'no_show':
      case 'noshow':
        return Icons.person_off_outlined;
      case 'warning':
      default:
        return Icons.warning_amber_rounded;
    }
  }

  /// Runs the action for a button returned by the API.
  void _onButtonAction(BuildContext context, CancelScheduleAction action) {
    switch (action) {
      case CancelScheduleAction.dismiss:
        Navigator.of(context).pop(false);
        break;
      case CancelScheduleAction.cancelSchedule:
      case CancelScheduleAction.markNoShow:
      case CancelScheduleAction.unknown:
        // Both cancel-schedule and mark-no-show run the existing cancel flow.
        // `unknown` is treated the same: this handler is only reached from a
        // non-dismiss button, so an unrecognised backend action must still
        // cancel rather than silently do nothing.
        // TODO: point markNoShow at a dedicated no-show endpoint when available.
        debugPrint(
          '[WELCOME] CancelRideDialog → dispatching CancelSchedule '
          '(action=$action) locCode=${widget.locCode} empId="${widget.empId}" '
          'scheduleDate="${widget.scheduleDate}" tripType="${widget.tripType}" '
          '(isLogin=${widget.isLogin})',
        );
        context.read<ShiftBloc>().add(
              CancelSchedule(
                locCode: widget.locCode,
                empId: widget.empId,
                scheduleDate: widget.scheduleDate,
                tripType: widget.tripType,
              ),
            );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ShiftBloc, ShiftState>(
      listenWhen: (prev, curr) =>
          curr is ShiftCancelSuccess ||
          curr is ShiftCancelError ||
          curr is ShiftCancelConfirmError ||
          curr is ShiftUnauthorized,
      listener: (context, state) {
        if (state is ShiftCancelConfirmError) {
          // ErrorCode != 0 → do not open the dialog; surface DB_Response.
          if (_handledConfirmError) return;
          _handledConfirmError = true;
          Navigator.of(context).pop(false);
          _showSnackBar(context, state.message, error: true);
        } else if (state is ShiftCancelSuccess) {
          Navigator.of(context).pop(true);
          _showSnackBar(context, state.message, error: false);
        } else if (state is ShiftCancelError) {
          // Cancel failed (e.g. "Schedule has already been canceled.") — close
          // the popup as well and surface the backend message.
          Navigator.of(context).pop(false);
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
          curr is ShiftCancelConfirmLoading ||
          curr is ShiftCancelConfirmLoaded ||
          curr is ShiftCancelConfirmError ||
          curr is ShiftCancelInProgress ||
          curr is ShiftCancelSuccess ||
          curr is ShiftCancelError ||
          curr is ShiftUnauthorized,
      builder: (context, state) {
        final isCancelling = state is ShiftCancelInProgress;

        // While the confirmation config is loading (or the popup couldn't be
        // shown) render a lightweight loader. The listener pops the dialog on
        // ShiftCancelConfirmError, so this is transient in that case. The
        // `_lastPopup == null` guard keeps the loader if a cancel somehow
        // started before any popup was loaded (state-machine shouldn't allow it).
        if (state is! ShiftCancelConfirmLoaded &&
            !(isCancelling && _lastPopup != null)) {
          return const PopScope(
            canPop: true,
            child: Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(24)),
              ),
              insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 80),
              child: Padding(
                padding: EdgeInsets.all(36),
                child: SizedBox(
                  height: 48,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Color(0xFF1A5C38),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        // Keep showing the last loaded popup while a cancel/no-show request is
        // in flight so the button spinner can render.
        final CancelSchedulePopup popup =
            state is ShiftCancelConfirmLoaded ? state.popup : _lastPopup!;
        _lastPopup = popup;

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
                  // Icon circle (icon driven by the API).
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF0EE),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        _iconFor(popup.icon),
                        color: const Color(0xffBA1A1A),
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title (from API).
                  Text(
                    popup.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff181C1B),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Message (from API).
                  Text(
                    popup.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF888888),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Buttons (rendered in ascending `order`, already sorted).
                  Row(
                    children: _buildActionButtons(
                      context,
                      popup.buttons,
                      isCancelling,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// The last successfully loaded popup, retained so the dialog keeps rendering
  /// while a cancel/no-show request is in progress.
  CancelSchedulePopup? _lastPopup;

  /// Builds the button row from the API config, preserving the existing look:
  /// the primary action (cancel / no-show) uses the red outlined style, and a
  /// `dismiss` action uses the filled green style.
  List<Widget> _buildActionButtons(
    BuildContext context,
    List<CancelScheduleButton> buttons,
    bool isCancelling,
  ) {
    final widgets = <Widget>[];
    for (var i = 0; i < buttons.length; i++) {
      final button = buttons[i];
      final bool isDismiss = button.action == CancelScheduleAction.dismiss;
      final bool isPrimaryAction =
          button.action == CancelScheduleAction.cancelSchedule ||
              button.action == CancelScheduleAction.markNoShow;

      final Widget child;
      if (isDismiss) {
        child = ElevatedButton(
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
              : () => _onButtonAction(context, button.action),
          child: Text(
            button.text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        );
      } else {
        child = OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFCC2222),
            side: const BorderSide(color: Color(0xFFFFCCCC), width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
          ),
          onPressed: isCancelling
              ? null
              : () => _onButtonAction(context, button.action),
          child: isCancelling && isPrimaryAction
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Color(0xFFCC2222),
                  ),
                )
              : Text(
                  button.text,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        );
      }

      widgets.add(Expanded(child: child));
      if (i != buttons.length - 1) {
        widgets.add(const SizedBox(width: 14));
      }
    }
    return widgets;
  }
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, this.onTripHistoryTap});

  final VoidCallback? onTripHistoryTap;

  void _showHelpDeskCallDialog(BuildContext context) {
    final rosterState = context.read<RosterBloc>().state;
    final phone = rosterState is RosterLoaded
        ? rosterState.details.helpDeskContactNumber.trim()
        : '';

    if (phone.isEmpty) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Help desk number not available. Try again later.'),
          behavior: SnackBarBehavior.floating,
        ));
      return;
    }

    Navigator.pop(context);
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _HelpDeskCallDialog(phoneNumber: phone),
    );
  }

  Future<void> _showRateAppDialog(BuildContext context) async {
    Navigator.pop(context);
    try {
      final inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
      } else {
        await inAppReview.openStoreListing();
      }
    } catch (_) {
      // Plugin not available on this build/device — fail silently.
    }
  }

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
              // _EnvironmentalCard(),

              const SizedBox(height: 8),

              // ── MY SCHEDULE section ──────────────────────────────────
              _SectionLabel('MY SCHEDULE'),
              // UserAppConfiguration highest-priority gate: hide the Create
              // Schedule entry entirely when isCreateScheduleAllowed is `false`.
              // Falls back to the existing (always-shown) behaviour until the
              // config is loaded.
              if (() {
                final configState = context.read<UserAppConfigBloc>().state;
                return configState is UserAppConfigLoaded
                    ? configState
                        .config.scheduleUiConfig.isCreateScheduleAllowed
                    : true;
              }())
                _DrawerItem(
                  icon: Icons.calendar_today_outlined,
                  label: 'Create Schedule',
                  onTap: () {
                    final appControl = context.read<AppControlBloc>().state;
                    final hybridEnabled = appControl is AppControlLoaded &&
                        appControl.settings.hybridScheduleEnabled;
                    final bothEnabled = appControl is AppControlLoaded &&
                        appControl.settings.isScheduleFillForLoginAndLogoutBoth;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TripDetailsScreen(
                          hybridScheduleEnabled: hybridEnabled,
                          isScheduleFillForLoginAndLogoutBoth: bothEnabled,
                        ),
                      ),
                    );
                  },
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
              // Team Cab is shown only when the team-tracking-panel API
              // responds with isSuccess == true for this employee.
              BlocBuilder<TeamCabBloc, TeamCabState>(
                builder: (context, state) {
                  final bool teamCabEnabled =
                      state is TeamCabLoaded && state.data.isSuccess;
                  if (!teamCabEnabled) return const SizedBox.shrink();
                  return _DrawerItem(
                    icon: Icons.people_outline,
                    label: 'Team Cab',
                    onTap: () {
                      // UserAppConfiguration highest-priority gate: pass the
                      // Trip Summary flag into the pushed Team Cab screen (which
                      // does not inherit the config provider).
                      final configState =
                          context.read<UserAppConfigBloc>().state;
                      final bool gateTripSummary = configState
                              is UserAppConfigLoaded
                          ? configState.config.tripUiConfig.isTripSummaryAllowed
                          : true;
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TeamCabScreen(
                            gateTripSummary: gateTripSummary,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              // ADHOC Request is shown only when enabled for the user's
              // location (AppControl settings).
              BlocBuilder<AppControlBloc, AppControlState>(
                builder: (context, state) {
                  final bool adhocEnabled = state is AppControlLoaded &&
                      state.settings.adhocRequestEnabledForUser;
                  if (!adhocEnabled) return const SizedBox.shrink();
                  return _DrawerItem(
                    icon: Icons.people_outline,
                    label: 'ADHOC Request',
                    onTap: () {
                      final rosterState = context.read<RosterBloc>().state;
                      final empId = rosterState is RosterLoaded
                          ? rosterState.details.empId
                          : 0;
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdhocRequestScreen(empId: empId),
                        ),
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 4),

              // ── MY ACCOUNT section ───────────────────────────────────
              _SectionLabel('MY ACCOUNT'),
              _DrawerItem(
                icon: Icons.home_outlined,
                label: 'Request Address Change',
                onTap: () {
                  Navigator.pop(context);
                  showAddressChangeDialog(context);
                },
              ),

              const SizedBox(height: 4),

              // ── SAFETY section ───────────────────────────────────────
              // _SectionLabel('SAFETY'),
              // _DrawerItem(
              //   icon: Icons.shield_outlined,
              //   label: 'Women Safety',
              //   onTap: () => Navigator.pop(context),
              //   iconColor: const Color(0xFFE53935),
              //   iconBgColor: const Color(0xFFFCECEC),
              // ),

              const SizedBox(height: 4),

              // ── SUPPORT section ──────────────────────────────────────
              _SectionLabel('SUPPORT'),
              _DrawerItem(
                icon: Icons.headset_mic_outlined,
                label: 'Call Help Desk',
                onTap: () => _showHelpDeskCallDialog(context),
              ),
              // _DrawerItem(
              //   icon: Icons.directions_bus_outlined,
              //   label: 'Contact Travel Desk',
              //   onTap: () => Navigator.pop(context),
              // ),
              _DrawerItem(
                icon: Icons.directions_bus_outlined,
                label: 'Raise Complaint',
                onTap: () {
                  final rosterState = context.read<RosterBloc>().state;
                  final empId = rosterState is RosterLoaded
                      ? rosterState.details.empId
                      : 0;
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RaiseComplaintScreen(empId: empId),
                    ),
                  );
                },
              ),
              // _DrawerItem(
              //   icon: Icons.quiz_outlined,
              //   label: "FAQ's",
              //   onTap: () => Navigator.pop(context),
              // ),

              const SizedBox(height: 4),

              // ── APP section ──────────────────────────────────────────
              // _SectionLabel('APP'),
              // _DrawerItem(
              //   icon: Icons.feedback_outlined,
              //   label: 'App Feedback',
              //   onTap: () => Navigator.pop(context),
              // ),
              // _DrawerItem(
              //   icon: Icons.star_outline,
              //   label: 'Rate This App',
              //   onTap: () => _showRateAppDialog(context),
              // ),

              // const SizedBox(height: 4),

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
                _DrawerItem(
                  icon: Icons.navigation_outlined,
                  label: TrackingConfig.useDummyTracking
                      ? 'Dummy Tracking (ON)'
                      : 'Dummy Tracking',
                  iconColor: const Color(0xFFF59E0B),
                  iconBgColor: const Color(0xFFFFF4E0),
                  onTap: () {
                    Navigator.pop(context);
                    if (!TrackingConfig.useDummyTracking) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Dummy mode is OFF. Re-run with '
                            '--dart-define=DUMMY_TRACKING=true to simulate.',
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BlocProvider(
                          // No fetch dispatched — the dummy simulator seeds the
                          // screen locally and the bloc stays idle.
                          create: (_) => sl<CabTrackingBloc>(),
                          child: const RideTrackingScreen(
                            userName: 'Diya',
                            tripId: 999001,
                            empId: dummyMeEmpId,
                          ),
                        ),
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
  String _initialsFromName(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Avatar
          InkWell(
            splashColor: Colors.transparent,
            onTap: () {
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
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE8F5F0),
                border: Border.all(color: const Color(0xFF8DCFB8), width: 2),
              ),
              child: BlocBuilder<ProfileBloc, ProfileState>(
                builder: (context, state) {
                  final fullName =
                      state is ProfileLoaded ? state.profile.fullName : '';
                  final initials = _initialsFromName(fullName);
                  if (initials.isEmpty) {
                    return const Icon(
                      Icons.person_outline,
                      color: Color(0xFF8DCFB8),
                      size: 30,
                    );
                  }
                  return Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A7A5E),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 14),
          // User info
          Expanded(
            child: InkWell(
              splashColor: Colors.transparent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
              child: BlocBuilder<ProfileBloc, ProfileState>(
                builder: (context, state) {
                  final fullName =
                      state is ProfileLoaded ? state.profile.fullName : '';
                  final empId = state is ProfileLoaded
                      ? (state.profile.employeeId?.toString() ?? '')
                      : '';
                  final office = state is ProfileLoaded
                      ? (state.profile.locationName?.trim() ?? '')
                      : '';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (empId.isNotEmpty)
                        Text(
                          'Emp Id: $empId',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF555555)),
                        ),
                      if (office.isNotEmpty)
                        Text(
                          'Office : $office',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF555555)),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          // Close / back icon
          // IconButton(
          //   icon: const Icon(Icons.chevron_left, color: Color(0xFF555555)),
          //   onPressed: () => Navigator.pop(context),
          // ),
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

// ─── Reached Home Safely Dialog ──────────────────────────────────────────────

class _ReachedHomeSafelyDialog extends StatelessWidget {
  const _ReachedHomeSafelyDialog({required this.onNeedHelp});

  final VoidCallback onNeedHelp;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Reached Home Safely?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please confirm you have reached home safely',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF888888)),
            ),
            const SizedBox(height: 28),
            // While the SOS request is in flight, disable both buttons and show
            // a spinner on "Need Help" so the user gets feedback and can't fire
            // a duplicate SOS.
            BlocBuilder<SosBloc, SosState>(
              builder: (context, sosState) {
                final isSosLoading = sosState is SosLoading;
                return Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        // Fire SOS but DON'T pop here — the BlocListener
                        // wrapping this dialog closes it and shows the result
                        // popup once the SOS API responds. Popping now would
                        // tear down that listener before the result arrives.
                        onPressed: isSosLoading ? null : onNeedHelp,
                        icon: isSosLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFFBA1A1A)),
                                ),
                              )
                            : const Icon(Icons.warning_amber_rounded,
                                size: 18, color: Color(0xFFBA1A1A)),
                        label: const Text(
                          'Need Help',
                          style: TextStyle(
                            color: Color(0xFFBA1A1A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(
                              color: Color(0xFFBA1A1A), width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isSosLoading
                            ? null
                            : () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A5C38),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Yes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Rate App Dialog ─────────────────────────────────────────────────────────

class _RateAppDialog extends StatefulWidget {
  const _RateAppDialog({required this.empId, required this.tripId});

  final int empId;
  final int tripId;

  @override
  State<_RateAppDialog> createState() => _RateAppDialogState();
}

class _RateAppDialogState extends State<_RateAppDialog> {
  int _rating = 0;
  bool _isSubmitting = false;
  final TextEditingController _remarksController = TextEditingController();

  static const _labels = [
    '',
    'Poor',
    'Fair',
    'Average',
    'Good Quality',
    'Excellent'
  ];
  static const _primaryGreen = Color(0xFF1A5C38);

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    setState(() => _isSubmitting = true);
    try {
      await sl<UserFeedbackRepo>().createUserFeedback(
        empId: widget.empId,
        tripId: widget.tripId,
        rating: _rating,
        remarks: _remarksController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.5),
        builder: (_) => const _FeedbackSuccessDialog(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorMessage.from(e,
              fallback: 'Could not submit feedback. Please try again.')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'How was your ride?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF181C1B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your feedback helps us keep the flow smooth.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF888888),
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final starIndex = i + 1;
                  return GestureDetector(
                    onTap: () => setState(() => _rating = starIndex),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        starIndex <= _rating ? Icons.star : Icons.star_border,
                        color: starIndex <= _rating
                            ? _primaryGreen
                            : const Color(0xFFCCCCCC),
                        size: 40,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),
              Text(
                _rating > 0 ? _labels[_rating].toUpperCase() : '',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _primaryGreen,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _remarksController,
                minLines: 3,
                maxLines: 5,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Add Remarks',
                  hintStyle: const TextStyle(color: Color(0xFF9AA0A6)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFB8DEC9)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: _primaryGreen, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      (_rating == 0 || _isSubmitting) ? null : _submitFeedback,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    disabledBackgroundColor: const Color(0xFFB0C4B8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  label: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              'Submit Feedback',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.send, size: 18),
                          ],
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

// ─── Feedback Success Dialog ─────────────────────────────────────────────────

class _FeedbackSuccessDialog extends StatelessWidget {
  const _FeedbackSuccessDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFF1A5C38),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 24),
            const Text(
              'Feedback Submitted\nSuccessfully',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF181C1B),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A5C38),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: const Text(
                  'Go Back',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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

/// Success / error result dialog for the "Reached Home" API call.
class _ReachedHomeResultDialog extends StatelessWidget {
  const _ReachedHomeResultDialog({
    required this.message,
    required this.success,
  });

  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final Color accent =
        success ? const Color(0xFF1A5C38) : const Color(0xFFB40D1A);
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                success ? Icons.check : Icons.close,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              success ? 'Reached Home' : 'Something Went Wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF181C1B),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF5C5F5E),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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

/// Result popup shown after an SOS trigger completes.
///
/// [success] is true when the API responds with `errorCode == 0`; otherwise the
/// error message from the API response is shown.
class _SosResultDialog extends StatelessWidget {
  const _SosResultDialog({
    required this.message,
    required this.success,
  });

  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final Color accent =
        success ? const Color(0xFF1A5C38) : const Color(0xFFB40D1A);
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                success ? Icons.check : Icons.close,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              success ? 'SOS Triggered' : 'SOS Request Failed',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF181C1B),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF5C5F5E),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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

// ─── Trip History Filters (full-screen) ─────────────────────────────────────

class _TripHistoryFilterPage extends StatefulWidget {
  const _TripHistoryFilterPage({
    required this.items,
    required this.initial,
  });

  final List<_TripHistoryItem> items;
  final _TripHistoryFilterResult initial;

  @override
  State<_TripHistoryFilterPage> createState() => _TripHistoryFilterPageState();
}

class _TripHistoryFilterPageState extends State<_TripHistoryFilterPage> {
  static const Color _primaryGreen = Color(0xFF1A6B3C);
  static const Color _mintBg = Color(0xFFE8F5EE);
  static const Color _sidebarInactive = Color(0xFF6B7280);

  _TripHistoryFilterCategory _category = _TripHistoryFilterCategory.tripStatus;

  late bool _statusAll;
  late Set<_TripHistoryStatus> _statuses;
  late bool _ratingAll;
  late Set<int> _ratings;
  late bool _includeUnrated;
  DateTime? _fromDate;
  DateTime? _toDate;

  static const List<String> _monthLabels = [
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

  @override
  void initState() {
    super.initState();
    _applyResult(widget.initial);
  }

  void _applyResult(_TripHistoryFilterResult r) {
    _statusAll = r.statusAll;
    _statuses = Set.from(r.statuses);
    _ratingAll = r.ratingAll;
    _ratings = Set.from(r.ratings);
    _includeUnrated = r.includeUnrated;
    _fromDate = r.fromDate;
    _toDate = r.toDate;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _formatMonthYear(DateTime? date) {
    if (date == null) return 'Select date';
    return '${date.day} ${_monthLabels[date.month - 1]} ${date.year}';
  }

  bool _matchesDateRange(_TripHistoryItem item) {
    if (_fromDate == null && _toDate == null) return true;
    final tripDay = _dateOnly(item.tripDate);
    if (_fromDate != null && tripDay.isBefore(_dateOnly(_fromDate!))) {
      return false;
    }
    if (_toDate != null && tripDay.isAfter(_dateOnly(_toDate!))) {
      return false;
    }
    return true;
  }

  Future<void> _pickDate({required bool isFrom}) async {
    // Trip history is historical: never allow selecting a future date.
    final today = _dateOnly(DateTime.now());
    var initial =
        isFrom ? (_fromDate ?? today) : (_toDate ?? _fromDate ?? today);
    if (initial.isAfter(today)) initial = today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: today,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primaryGreen,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF333333),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _fromDate = _dateOnly(picked);
        if (_toDate != null && _fromDate!.isAfter(_toDate!)) {
          _toDate = _dateOnly(picked);
        }
      } else {
        _toDate = _dateOnly(picked);
        if (_fromDate != null && _toDate!.isBefore(_fromDate!)) {
          _fromDate = _dateOnly(picked);
        }
      }
    });
  }

  bool _matchesStatus(_TripHistoryItem item) {
    if (_statusAll) return true;
    return _statuses.contains(item.status);
  }

  bool _matchesRating(_TripHistoryItem item) {
    if (_ratingAll) return true;
    final rated = item.rating != null;
    if (!rated) return _includeUnrated;
    return _ratings.contains(item.rating);
  }

  /// Upcoming and In Progress trips are excluded everywhere in trip history,
  /// so filter counts must ignore them too.
  bool _isShownInHistory(_TripHistoryItem i) =>
      i.status != _TripHistoryStatus.upcoming &&
      i.status != _TripHistoryStatus.inProgress;

  List<_TripHistoryItem> _itemsForStatusCounts() {
    return widget.items
        .where((i) =>
            _isShownInHistory(i) && _matchesRating(i) && _matchesDateRange(i))
        .toList();
  }

  List<_TripHistoryItem> _itemsForRatingCounts() {
    return widget.items
        .where((i) =>
            _isShownInHistory(i) && _matchesStatus(i) && _matchesDateRange(i))
        .toList();
  }

  int _statusCount(_TripHistoryStatus? status) {
    final pool = _itemsForStatusCounts();
    if (status == null) return pool.length;
    return pool.where((i) => i.status == status).length;
  }

  int _ratingCount({int? stars, bool unrated = false}) {
    final pool = _itemsForRatingCounts();
    if (stars != null) {
      return pool.where((i) => i.rating == stars).length;
    }
    if (unrated) return pool.where((i) => i.rating == null).length;
    return pool.length;
  }

  _TripHistoryFilterResult _currentResult() => _TripHistoryFilterResult(
        statusAll: _statusAll,
        statuses: Set.from(_statuses),
        ratingAll: _ratingAll,
        ratings: Set.from(_ratings),
        includeUnrated: _includeUnrated,
        fromDate: _fromDate,
        toDate: _toDate,
      );

  void _clearAllFilters() {
    setState(() {
      _statusAll = true;
      _statuses.clear();
      _ratingAll = true;
      _ratings.clear();
      _includeUnrated = false;
      _fromDate = null;
      _toDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: _mintBg,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: _primaryGreen, size: 26),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Filters',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _primaryGreen,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history, color: _primaryGreen, size: 24),
            onPressed: () => setState(() => _applyResult(widget.initial)),
            tooltip: 'Reset to last applied',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: MediaQuery.of(context).size.width * 0.34,
          decoration: BoxDecoration(
            color: _mintBg,
            border: Border(
              right: BorderSide(
                color: Colors.grey.shade300,
                width: 1.0,
              ),
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _sidebarItem(
                  'Trip Status', _TripHistoryFilterCategory.tripStatus),
              _sidebarItem(
                  'Trip Rating', _TripHistoryFilterCategory.tripRating),
              _sidebarItem('Trip Date', _TripHistoryFilterCategory.tripDate),
            ],
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: Colors.white,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              children: _buildOptionsForCategory(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sidebarItem(String label, _TripHistoryFilterCategory cat) {
    final selected = _category == cat;
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _category = cat),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? _primaryGreen : _sidebarInactive,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildOptionsForCategory() {
    switch (_category) {
      case _TripHistoryFilterCategory.tripStatus:
        return [
          _checkRow(
            label: 'All',
            count: _statusCount(null),
            checked: _statusAll,
            enabled: _statusCount(null) > 0 || _statusAll,
            onTap: () => setState(() {
              _statusAll = true;
              _statuses.clear();
            }),
          ),
          _checkRow(
            label: 'Completed',
            count: _statusCount(_TripHistoryStatus.completed),
            checked:
                !_statusAll && _statuses.contains(_TripHistoryStatus.completed),
            enabled: _statusCount(_TripHistoryStatus.completed) > 0,
            onTap: () => setState(() {
              _statusAll = false;
              if (_statuses.contains(_TripHistoryStatus.completed)) {
                _statuses.remove(_TripHistoryStatus.completed);
                if (_statuses.isEmpty) _statusAll = true;
              } else {
                _statuses.add(_TripHistoryStatus.completed);
              }
            }),
          ),
          // 'In Progress' and 'Upcoming' filters are intentionally hidden —
          // those trips are excluded from the trip history list (see
          // _filteredItems).
          _checkRow(
            label: 'No Show',
            count: _statusCount(_TripHistoryStatus.noShow),
            checked:
                !_statusAll && _statuses.contains(_TripHistoryStatus.noShow),
            enabled: _statusCount(_TripHistoryStatus.noShow) > 0,
            onTap: () => setState(() {
              _statusAll = false;
              if (_statuses.contains(_TripHistoryStatus.noShow)) {
                _statuses.remove(_TripHistoryStatus.noShow);
                if (_statuses.isEmpty) _statusAll = true;
              } else {
                _statuses.add(_TripHistoryStatus.noShow);
              }
            }),
          ),
          _checkRow(
            label: 'Cancelled',
            count: _statusCount(_TripHistoryStatus.cancelled),
            checked:
                !_statusAll && _statuses.contains(_TripHistoryStatus.cancelled),
            enabled: _statusCount(_TripHistoryStatus.cancelled) > 0,
            onTap: () => setState(() {
              _statusAll = false;
              if (_statuses.contains(_TripHistoryStatus.cancelled)) {
                _statuses.remove(_TripHistoryStatus.cancelled);
                if (_statuses.isEmpty) _statusAll = true;
              } else {
                _statuses.add(_TripHistoryStatus.cancelled);
              }
            }),
          ),
          _checkRow(
            label: 'Expired',
            count: _statusCount(_TripHistoryStatus.expired),
            checked:
                !_statusAll && _statuses.contains(_TripHistoryStatus.expired),
            enabled: _statusCount(_TripHistoryStatus.expired) > 0,
            onTap: () => setState(() {
              _statusAll = false;
              if (_statuses.contains(_TripHistoryStatus.expired)) {
                _statuses.remove(_TripHistoryStatus.expired);
                if (_statuses.isEmpty) _statusAll = true;
              } else {
                _statuses.add(_TripHistoryStatus.expired);
              }
            }),
          ),
        ];
      case _TripHistoryFilterCategory.tripRating:
        return [
          _checkRow(
            label: 'All',
            count: _ratingCount(),
            checked: _ratingAll,
            enabled: _ratingCount() > 0 || _ratingAll,
            onTap: () => setState(() {
              _ratingAll = true;
              _ratings.clear();
              _includeUnrated = false;
            }),
          ),
          for (final stars in [5, 4, 3, 2, 1])
            _checkRow(
              label: '$stars Star${stars == 1 ? '' : 's'}',
              count: _ratingCount(stars: stars),
              checked: !_ratingAll && _ratings.contains(stars),
              enabled: _ratingCount(stars: stars) > 0,
              onTap: () => setState(() {
                _ratingAll = false;
                if (_ratings.contains(stars)) {
                  _ratings.remove(stars);
                  if (_ratings.isEmpty && !_includeUnrated) {
                    _ratingAll = true;
                  }
                } else {
                  _ratings.add(stars);
                }
              }),
            ),
          _checkRow(
            label: 'Not Rated',
            count: _ratingCount(unrated: true),
            checked: !_ratingAll && _includeUnrated,
            enabled: _ratingCount(unrated: true) > 0,
            onTap: () => setState(() {
              _ratingAll = false;
              _includeUnrated = !_includeUnrated;
              if (!_includeUnrated && _ratings.isEmpty) {
                _ratingAll = true;
              }
            }),
          ),
        ];
      case _TripHistoryFilterCategory.tripDate:
        return [_buildTripDateRangeSection()];
    }
  }

  Widget _buildTripDateRangeSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildDatePickerField(
            label: 'FROM DATE',
            date: _fromDate,
            onTap: () => _pickDate(isFrom: true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildDatePickerField(
            label: 'TO DATE',
            date: _toDate,
            onTap: () => _pickDate(isFrom: false),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    final hasDate = date != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD1D5DB)),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatMonthYear(date),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: hasDate
                              ? const Color(0xFF1A1A1A)
                              : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: hasDate ? _primaryGreen : const Color(0xFF9CA3AF),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _checkRow({
    required String label,
    required int count,
    required bool checked,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final textColor =
        enabled ? const Color(0xFF1A1A1A) : const Color(0xFFBDBDBD);
    final countColor =
        enabled ? const Color(0xFF6B7280) : const Color(0xFFBDBDBD);

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              _FilterCheckbox(checked: checked && enabled, enabled: enabled),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
              Text(
                '($count)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: countColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Row(
        children: [
          TextButton(
            onPressed: _clearAllFilters,
            style: TextButton.styleFrom(
              foregroundColor: _primaryGreen,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            child: const Text(
              'Clear Filters',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 140,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _currentResult()),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: const Text(
                'Apply',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterCheckbox extends StatelessWidget {
  const _FilterCheckbox({
    required this.checked,
    required this.enabled,
  });

  final bool checked;
  final bool enabled;

  static const Color _primaryGreen = Color(0xFF1A6B3C);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: checked ? _primaryGreen : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: checked
              ? _primaryGreen
              : (enabled ? const Color(0xFFD1D5DB) : const Color(0xFFE5E7EB)),
          width: 1.5,
        ),
      ),
      child: checked
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }
}

class _HelpDeskCallDialog extends StatelessWidget {
  const _HelpDeskCallDialog({required this.phoneNumber});

  final String phoneNumber;

  Future<void> _makeCall(BuildContext context) async {
    // Capture the navigator + messenger from the rootmost (still-mounted)
    // context BEFORE any async gap, so popping the dialog can't leave us
    // referencing a deactivated element.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Sanitize: keep only digits and a leading '+', so formatted numbers like
    // "+91 98765 43210" produce a valid tel: URI.
    final sanitized = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: sanitized);

    // Attempt the launch directly — canLaunchUrl() is unreliable for tel: on
    // iOS. Try externalApplication first, then fall back to platformDefault
    // (some iOS configs reject externalApplication for the tel: scheme).
    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (!launched) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {
        launched = false;
      }
    }

    // Close the dialog once the launch attempt is done.
    if (navigator.canPop()) navigator.pop();

    if (!launched) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Could not launch the dialer. Please try manually.'),
          behavior: SnackBarBehavior.floating,
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
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
                color: Color(0xFFE8F5EE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.headset_mic_outlined,
                color: Color(0xFF1A6B3C),
                size: 30,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Call Help Desk',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
                fontFamily: 'Manrope',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Do you want to call the help desk?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF596064),
                height: 1.5,
                fontFamily: 'Manrope',
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone, size: 18, color: Color(0xFF1A6B3C)),
                  const SizedBox(width: 8),
                  Text(
                    phoneNumber,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: 0.5,
                      fontFamily: 'Manrope',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _makeCall(context),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A5C38),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Call Now',
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
                    onTap: () => Navigator.of(context).pop(),
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
    );
  }
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
