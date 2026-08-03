import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/storage/auth_local_storage.dart';
import '../../features/trip_detail/data/model/cab_tracking/user_cab_tracking_response.dart';
import '../model/ride_timeline.dart';
import 'live_trip_foreground_service.dart';
import 'live_trip_notification_service.dart';
import 'route_tracking_signalr_service.dart';

/// Identifies the trip a live session is tracking.
@immutable
class LiveTripSession {
  final int tripId;
  final int empId;

  /// SignalR group id. Usually equal to [tripId] but the backend can differ.
  final int dsId;

  const LiveTripSession({
    required this.tripId,
    required this.empId,
    required this.dsId,
  });

  @override
  bool operator ==(Object other) =>
      other is LiveTripSession &&
      other.tripId == tripId &&
      other.empId == empId &&
      other.dsId == dsId;

  @override
  int get hashCode => Object.hash(tripId, empId, dsId);

  @override
  String toString() =>
      'LiveTripSession(tripId=$tripId, empId=$empId, dsId=$dsId)';
}

/// App-lifetime owner of the live-trip notification.
///
/// ## Why this exists
///
/// Before this controller, the SignalR connection and every derived value (ETA,
/// timeline, driver/vehicle) lived inside `_RideTrackingScreenState`. That meant
/// closing the tracking screen tore down the GPS feed, so an ongoing
/// notification could never outlive the screen. This controller is a singleton
/// that owns the notification independently of any widget, so the notification
/// survives navigation and app backgrounding.
///
/// ## What it deliberately does NOT do
///
/// It does **not** open its own SignalR connection while the tracking screen is
/// alive. The screen already has one, and a second connection to the same hub
/// would double the server's push load and could disagree with the map. Instead
/// the screen *feeds* this controller ([updateFromScreen]), and the controller
/// only takes over the connection itself once the screen goes away
/// ([detachScreen]) — see [_adoptConnection].
///
/// ## Isolate note
///
/// Everything here runs on the **main** isolate, where DI, [AuthLocalStorage]
/// and the existing SignalR service already live. The foreground service is used
/// purely to stop Android suspending this process; it does not run the tracking
/// logic in its own isolate. See [LiveTripForegroundService].
class LiveTripController {
  LiveTripController._();

  static final LiveTripController instance = LiveTripController._();

  /// The trip currently being tracked, or null when idle.
  LiveTripSession? _session;

  /// True while a [RideTrackingScreen] is mounted and feeding us. While set, the
  /// controller stays passive and never touches SignalR itself.
  bool _screenAttached = false;

  /// Our own SignalR connection, created ONLY after the screen detaches.
  RouteTrackingSignalRService? _ownConnection;

  /// Latest state, whether it arrived from the screen or from our own feed.
  RideTimeline _timeline = RideTimeline.empty;
  int? _etaMinutes;
  TrackingStatusResponse? _status;

  /// Server-provided "cab is at my stop" flag (backend Ask 2), when available.
  ///
  /// Null means the backend hasn't told us either way, in which case the renderer
  /// falls back to parsing `paxTrackingStatus` strings.
  bool? _hasCabArrived;

  LiveTripSession? get session => _session;
  bool get isActive => _session != null;

  void _log(String message) => debugPrint('[LiveTripController] $message');

  // ── Screen-driven path (screen is open) ────────────────────────────────────

  /// Called by the tracking screen on every meaningful update while it is
  /// mounted. The controller mirrors the state and renders the notification, but
  /// leaves the SignalR connection to the screen.
  Future<void> updateFromScreen({
    required LiveTripSession session,
    required RideTimeline timeline,
    required int? etaMinutes,
    required TrackingStatusResponse? status,
    bool? hasCabArrived,
  }) async {
    _screenAttached = true;
    if (hasCabArrived != null) _hasCabArrived = hasCabArrived;

    // The screen is back (user navigated into tracking again). If we adopted the
    // feed while it was closed, hand ownership back: keeping our own connection
    // alive alongside the screen's would double the hub's push load, and the
    // screen's ETA is richer than ours (it has the route polyline).
    await _releaseConnection();

    // A different trip means the previous session is over — clear its
    // notification before adopting the new one.
    if (_session != null && _session != session) {
      _log('session changed $_session → $session');
      await _clearNotification();
    }
    _session = session;
    _timeline = timeline;
    _etaMinutes = etaMinutes;
    _status = status;

    await _render();
  }

  /// Called from the tracking screen's `dispose`.
  ///
  /// The screen is going away but the trip may still be live, so instead of
  /// cancelling (Phase 1's behaviour) the controller now *adopts* the feed: it
  /// opens its own SignalR connection and starts the foreground service so the
  /// notification keeps updating.
  Future<void> detachScreen() async {
    _screenAttached = false;
    final session = _session;
    if (session == null) return;

    // Trip already finished while the screen was open — nothing to keep alive.
    if (_isTerminal()) {
      _log('screen detached on a finished trip — stopping');
      await stop();
      return;
    }

    _log('screen detached — adopting the live feed for $session');
    await _adoptConnection(session);
  }

  // ── Controller-driven path (screen is closed) ─────────────────────────────

  /// Opens our own SignalR connection and starts the foreground service, so the
  /// notification keeps updating without the tracking screen.
  Future<void> _adoptConnection(LiveTripSession session) async {
    // The screen re-attached between detachScreen() and here (fast back-and-forth
    // navigation). It owns the feed again, so abandon the adopt.
    if (_screenAttached) {
      _log('screen re-attached mid-adopt — aborting');
      return;
    }

    // Start the service FIRST. If Android refuses (permission denied, OEM
    // restriction), there's no point holding a socket open that will be
    // suspended seconds later.
    final started = await LiveTripForegroundService.instance.start(
      title: _lastTitle ?? 'Tracking your trip',
      text: _lastBody ?? 'Live trip in progress',
    );
    if (!started) {
      _log('foreground service refused to start — stopping live session');
      await stop();
      return;
    }

    if (_ownConnection != null) {
      _log('already own a connection — skipping adopt');
      return;
    }

    final token = AuthLocalStorage().getAccessToken();
    if (token == null || token.isEmpty) {
      _log('no access token — cannot adopt connection');
      await stop();
      return;
    }

    final connection = RouteTrackingSignalRService();
    _ownConnection = connection;
    connection.addLocationListener(_onOwnLocation);
    // Trip lifecycle (started/completed/cancelled). Essential while the screen is
    // closed: when a trip completes GPS pushes stop, so without this event the
    // notification would stay pinned at its last ETA forever.
    connection.addStatusListener(_onTripStatusChange);

    try {
      await connection.connect(accessToken: token);
      await connection.joinTrackingGroup(session.dsId);
      _log('adopted SignalR feed for dsId=${session.dsId}');
    } catch (e) {
      _log('adopt failed: $e');
      // Keep the service + last-known notification rather than yanking it: the
      // SignalR service runs its own reconnect loop and may recover.
    }
  }

  /// Handles a trip lifecycle change from the backend.
  ///
  /// A terminal status (completed/cancelled) is the authoritative end-of-trip
  /// signal and tears the whole live session down. Previously the client could
  /// only infer this by polling REST, which meant a trip finishing while the app
  /// was backgrounded left the notification pinned until the next poll.
  void _onTripStatusChange(TripStatusChangePayload payload) {
    // Ignore events for a different trip (shouldn't happen — we only join one
    // group — but a stale group membership after reconnect would be silent
    // corruption otherwise).
    final session = _session;
    if (session == null) return;
    if (payload.dsId != null && payload.dsId != session.dsId) {
      _log('ignoring status change for dsId=${payload.dsId} '
          '(tracking ${session.dsId})');
      return;
    }

    _log('trip status → ${payload.tripStatusName} '
        '(terminal=${payload.isTerminal})');

    if (payload.isTerminal) {
      unawaited(stop(showCompleted: true));
    }
  }

  /// Location updates from our OWN connection (screen is closed).
  ///
  /// The server-computed ETA (backend Ask 1) is adopted here when present. That
  /// is what makes the screen-closed notification a real countdown: the client
  /// cannot compute an ETA itself without the map's route polyline, so before the
  /// server ETA existed this path could only show coarse status text.
  void _onOwnLocation(RouteLocationPayload payload) {
    final status = _status;
    if (status == null) return;

    // Adopt the server ETA + explicit arrival flag for the logged-in passenger.
    final meEmpId = _session?.empId;
    if (meEmpId != null) {
      for (final p in payload.passengers) {
        if (p.empId != meEmpId) continue;
        if (p.etaMinutesToStop != null) _etaMinutes = p.etaMinutesToStop;
        if (p.hasCabArrivedAtStop != null) {
          _hasCabArrived = p.hasCabArrivedAtStop!;
        }
        break;
      }
    }

    if (payload.passengers.isNotEmpty) {
      // Merge live passenger status into the cached status so the timeline
      // advances (Picked Up → In Cab → Dropped) while the screen is closed.
      final byEmpId = {
        for (final p in payload.passengers)
          if (p.empId != null) p.empId!: p,
      };
      final merged = status.passengers.map((cached) {
        final live = byEmpId[cached.empId];
        if (live == null) return cached;
        return cached.copyWith(
          paxTrackingStatus: live.paxTrackingStatus,
          etaDeviationMinutes: live.etaDeviationMinutes,
          plannedScheduleTime: live.plannedScheduleTime,
          empSigninTime: live.empSigninTime,
          empSignOutTime: live.empSignOutTime,
          cabReachedTime: live.cabReachedTime,
          reachedHomeTime: live.reachedHomeTime,
          noShow: live.noShow,
        );
      }).toList();

      _status = status.withPassengers(merged);
      _timeline = RideTimeline.fromStatus(
        _status,
        meEmpId: _session?.empId,
      );
    }

    // The backend also reports overall trip status on the payload; a completed
    // trip must tear everything down.
    unawaited(_render());
  }

  // ── Rendering ─────────────────────────────────────────────────────────────

  String? _lastTitle;
  String? _lastBody;

  bool _isTerminal() {
    if (_status?.isCompleted == true) return true;
    return _timeline.stops.isNotEmpty && _timeline.target == null;
  }

  Future<void> _render() async {
    final session = _session;
    if (session == null) return;

    final content = LiveTripNotificationContent.fromTrackingState(
      timeline: _timeline,
      etaMinutes: _etaMinutes,
      tripId: session.tripId,
      empId: session.empId,
      vehicleNo: _status?.vehicleNo,
      vehicleModelName: _status?.vehicleModelName,
      driverName: _status?.driverName,
      tripCompleted: _status?.isCompleted ?? false,
      hasCabArrived: _hasCabArrived,
    );
    if (content == null) return;

    _lastTitle = content.title;
    _lastBody = content.body;

    if (content.isTerminal) {
      _log('trip finished — tearing down');
      await stop(showCompleted: true);
      return;
    }

    // Route the render to whichever surface currently owns the notification.
    //
    // While the foreground service is running, the SERVICE owns the ongoing
    // notification (Android ties it to the service lifetime and it cannot be
    // replaced by a separate local notification with a different id). So we
    // update through the service. Otherwise we use the local-notification path.
    if (LiveTripForegroundService.instance.isRunning) {
      await LiveTripForegroundService.instance.update(
        title: content.title,
        text: content.body,
      );
    } else {
      await LiveTripNotificationService.instance.update(content);
    }
  }

  Future<void> _clearNotification() async {
    await LiveTripNotificationService.instance.cancel();
    await LiveTripForegroundService.instance.stop();
  }

  /// Closes the connection this controller opened (if any) and stops the
  /// foreground service, WITHOUT ending the session.
  ///
  /// Used when the tracking screen takes ownership of the feed back. The
  /// notification is intentionally left in place — the screen will keep updating
  /// it via [updateFromScreen], so there is no flicker.
  Future<void> _releaseConnection() async {
    final connection = _ownConnection;
    if (connection == null) return;

    _log('releasing own connection back to the screen');
    _ownConnection = null;
    connection.removeLocationListener(_onOwnLocation);
    final dsId = _session?.dsId;
    if (dsId != null) {
      try {
        await connection.leaveTrackingGroup(dsId);
      } catch (_) {
        // Best-effort — we're closing the socket next anyway.
      }
    }
    await connection.disconnect();

    // The service exists only to keep the process alive while no UI is present.
    // With the screen back, Flutter's own activity keeps us alive.
    await LiveTripForegroundService.instance.stop();
  }

  /// Ends the live session: closes our connection, stops the service, and clears
  /// the notification.
  ///
  /// [showCompleted] briefly posts a final "Trip completed" notification on the
  /// normal (dismissible) channel so the user gets closure rather than the
  /// notification silently vanishing.
  Future<void> stop({bool showCompleted = false}) async {
    _log('stopping live session (showCompleted=$showCompleted)');

    // Shares the connection teardown with the screen-reattach path so there is
    // exactly one place that closes a socket we opened.
    await _releaseConnection();
    await _clearNotification();

    if (showCompleted) {
      await LiveTripNotificationService.instance.showCompleted(
        title: 'Trip completed',
        body: 'Thanks for riding with Commutr.',
      );
    }

    _session = null;
    _screenAttached = false;
    _timeline = RideTimeline.empty;
    _etaMinutes = null;
    _status = null;
    _hasCabArrived = null;
    _lastTitle = null;
    _lastBody = null;
  }
}
