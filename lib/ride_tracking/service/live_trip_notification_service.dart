import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../model/ride_timeline.dart';

/// Android-only ongoing "live trip" notification (Uber/Zomato style).
///
/// This service renders a single, sticky, silent notification that mirrors the
/// live tracking screen: the ETA to the passenger's own stop, the driver /
/// vehicle line, and a progress bar for route completion. It updates as the
/// trip advances and clears itself once the trip finishes.
///
/// ## Design constraints this service is built around
///
///   * **It must never break live tracking.** Every public method is fully
///     guarded and swallows its own errors, because the caller is on the hot
///     SignalR location path ([`_onSignalRLocation`]). A notification failure
///     is always preferable to a broken map.
///   * **It must not thrash the notification shade.** The tracking screen ticks
///     every 200 ms and SignalR pushes arrive continuously, but Android
///     rate-limits notification updates and a shade that repaints constantly
///     looks broken. [update] therefore *change-detects*: a new notification is
///     only posted when the user-visible content actually changed, and pure ETA
///     drift is additionally throttled to [_etaThrottle]. A phase change
///     (arrived / started / completed) always posts immediately.
///   * **It must be silent.** Updates land on a dedicated low-importance
///     channel ([_channelId]) so no sound or heads-up banner fires per update.
///     This is a *separate* channel from the FCM one on purpose — Android
///     ignores importance changes to an already-created channel, so reusing the
///     existing high-importance channel would make every ETA tick beep.
class LiveTripNotificationService {
  LiveTripNotificationService._();

  static final LiveTripNotificationService instance =
      LiveTripNotificationService._();

  /// Dedicated silent channel for the ongoing trip notification. Must stay
  /// distinct from the FCM channel — see the class doc.
  static const String _channelId = 'commutr_live_trip_channel';
  static const String _channelName = 'Live trip tracking';
  static const String _channelDescription =
      'Ongoing notification showing your cab\'s live location and ETA.';

  /// Fixed notification id — reusing it is what makes Android *replace* the
  /// existing notification instead of stacking a new one per update.
  static const int notificationId = 1010;

  /// Separate id for the final "trip completed" notification, so tearing down the
  /// ongoing notification (id [notificationId]) doesn't also remove it.
  /// 1011 is taken by the foreground service, hence 1012.
  static const int completedNotificationId = 1012;

  /// Payload prefix so the tap handler can tell our notification apart from
  /// any FCM notification that also carries a payload.
  static const String payloadPrefix = 'live_trip';

  /// Minimum gap between posts when only the ETA changed. Status/phase changes
  /// bypass this entirely.
  static const Duration _etaThrottle = Duration(seconds: 15);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _channelCreated = false;

  /// Last content actually posted, used for change detection.
  String? _lastTitle;
  String? _lastBody;
  int? _lastProgress;
  DateTime? _lastPostAt;

  /// True while a notification is currently displayed.
  bool _visible = false;

  bool get isVisible => _visible;

  /// Android-only feature for now — iOS gets Live Activities later.
  bool get _supported => !kIsWeb && Platform.isAndroid;

  void _log(String message) =>
      debugPrint('[LiveTripNotification] $message');

  /// Creates the silent channel. Safe to call repeatedly; only the first call
  /// does work. Called lazily on first [update] so app startup pays nothing.
  Future<void> _ensureChannel() async {
    if (_channelCreated || !_supported) return;
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      // `low` = shows in the shade + status bar, but never plays a sound and
      // never pops a heads-up banner. Exactly right for a per-second ETA feed.
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    _channelCreated = true;
    _log('channel "$_channelId" created');
  }

  /// Posts or updates the ongoing trip notification from the live trip state.
  ///
  /// Fire-and-forget: never throws, never awaits anything the caller needs.
  /// When [content] resolves to a terminal trip state the notification is
  /// cancelled instead of updated.
  Future<void> update(LiveTripNotificationContent content) async {
    if (!_supported) return;

    try {
      // Trip is over — tear the notification down rather than leaving a stale
      // "Pickup in 3 min" pinned in the shade forever.
      if (content.isTerminal) {
        await cancel();
        return;
      }

      final title = content.title;
      final body = content.body;
      final progress = content.progressPercent;

      // ── Change detection ───────────────────────────────────────────────────
      // Nothing user-visible moved → don't touch the shade at all.
      final sameContent = title == _lastTitle &&
          body == _lastBody &&
          progress == _lastProgress;
      if (_visible && sameContent) return;

      // Only the ETA/progress moved (status line unchanged) → throttle, so the
      // 200 ms screen tick can't drive the shade at its own cadence.
      final statusUnchanged = body == _lastBody;
      if (_visible && statusUnchanged) {
        final last = _lastPostAt;
        if (last != null &&
            DateTime.now().difference(last) < _etaThrottle) {
          return;
        }
      }

      await _ensureChannel();

      final details = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.low,
        priority: Priority.low,
        // Sticky: the user can't swipe it away while the trip is live.
        ongoing: true,
        autoCancel: false,
        // Never re-alert on update — without this every post could buzz.
        onlyAlertOnce: true,
        playSound: false,
        enableVibration: false,
        silent: true,
        // Ranks it as transport, which is what keeps it near the top of the
        // shade on most OEM skins.
        category: AndroidNotificationCategory.transport,
        visibility: NotificationVisibility.public,
        showWhen: false,
        icon: '@mipmap/ic_launcher',
        subText: content.subText,
        showProgress: progress != null,
        maxProgress: 100,
        progress: progress ?? 0,
        // Expanded view gets the full multi-line detail block.
        styleInformation: BigTextStyleInformation(
          content.expandedBody,
          contentTitle: title,
        ),
      );

      await _plugin.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(android: details),
        payload: content.payload,
      );

      _lastTitle = title;
      _lastBody = body;
      _lastProgress = progress;
      _lastPostAt = DateTime.now();
      _visible = true;
      _log('shown → "$title" / "$body" (progress=$progress)');
    } catch (e, st) {
      // Swallow: this runs on the live-tracking path and must never surface.
      _log('update failed (ignored): $e\n$st');
    }
  }

  /// Posts a final, **dismissible** "trip completed" notification.
  ///
  /// Called instead of silently cancelling so the trip gets visible closure. Uses
  /// a different notification id so it isn't replaced by the ongoing
  /// notification's teardown, and is deliberately NOT `ongoing`, so the user can
  /// swipe it away.
  Future<void> showCompleted({
    required String title,
    required String body,
  }) async {
    if (!_supported) return;
    try {
      await _ensureChannel();
      await _plugin.show(
        id: completedNotificationId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.low,
            priority: Priority.low,
            ongoing: false,
            autoCancel: true,
            onlyAlertOnce: true,
            playSound: false,
            enableVibration: false,
            silent: true,
            icon: '@mipmap/ic_launcher',
            // Clears itself after a few minutes so a finished trip doesn't linger
            // in the shade indefinitely.
            timeoutAfter: const Duration(minutes: 5).inMilliseconds,
          ),
        ),
      );
      _log('completion notification shown');
    } catch (e) {
      _log('showCompleted failed (ignored): $e');
    }
  }

  /// Removes the notification and resets change-detection state so a later trip
  /// starts clean.
  Future<void> cancel() async {
    if (!_supported) return;
    try {
      // Cancel unconditionally rather than gating on [_visible]: a notification
      // can survive a Dart isolate restart (hot restart, process respawn) with
      // our in-memory flag reset to false, and that stale notification would
      // otherwise be un-cancellable.
      await _plugin.cancel(id: notificationId);
      _log('cancelled');
    } catch (e) {
      _log('cancel failed (ignored): $e');
    } finally {
      _visible = false;
      _lastTitle = null;
      _lastBody = null;
      _lastProgress = null;
      _lastPostAt = null;
    }
  }
}

/// Immutable, already-formatted content for one render of the live trip
/// notification.
///
/// Kept as a plain value object (no widget/BuildContext dependency) so the
/// formatting logic is unit-testable and so a background isolate could build it
/// later without touching the widget tree.
@immutable
class LiveTripNotificationContent {
  /// Headline — e.g. `Pickup in 7 min`, `Driver arrived`, `Trip started`.
  final String title;

  /// Single-line collapsed detail — e.g. `DL01AB3453 · Driver: Rahul`.
  final String body;

  /// Multi-line detail shown when the notification is expanded.
  final String expandedBody;

  /// Small text next to the app name — the route/stop context.
  final String? subText;

  /// Route completion 0–100, or null to hide the progress bar.
  final int? progressPercent;

  /// Tap payload: `live_trip:<tripId>:<empId>`.
  final String payload;

  /// True once the trip has finished, telling the service to clear.
  final bool isTerminal;

  const LiveTripNotificationContent({
    required this.title,
    required this.body,
    required this.expandedBody,
    required this.payload,
    this.subText,
    this.progressPercent,
    this.isTerminal = false,
  });

  /// Builds notification content from the live tracking state.
  ///
  /// This intentionally consumes the *same* inputs the tracking screen already
  /// derives — the personalised [RideTimeline], the client-computed
  /// [etaMinutes], and the driver/vehicle fields — so the notification can
  /// never disagree with the map.
  ///
  /// Returns null when there isn't enough information to render anything
  /// meaningful yet (no stops resolved), so the caller simply does nothing.
  static LiveTripNotificationContent? fromTrackingState({
    required RideTimeline timeline,
    required int? etaMinutes,
    required int? tripId,
    required int? empId,
    String? vehicleNo,
    String? driverName,
    bool tripCompleted = false,
    /// Server-provided arrival flag (backend Ask 2). When non-null it is
    /// authoritative and overrides the `paxTrackingStatus` string heuristic.
    bool? hasCabArrived,
    /// Server-provided vehicle model (backend Ask 4), e.g. "Honda City".
    String? vehicleModelName,
  }) {
    final payload = '${LiveTripNotificationService.payloadPrefix}'
        ':${tripId ?? ''}:${empId ?? ''}';

    // Backend-reported completion, or every stop on my personalised timeline is
    // resolved — either way there is nothing left to track.
    final allStopsDone = timeline.stops.isNotEmpty && timeline.target == null;
    if (tripCompleted || allStopsDone) {
      return LiveTripNotificationContent(
        title: 'Trip completed',
        body: 'Thanks for riding with Commutr.',
        expandedBody: 'Thanks for riding with Commutr.',
        payload: payload,
        isTerminal: true,
      );
    }

    if (timeline.stops.isEmpty) return null;

    final isLogout = timeline.isLogout;
    final target = timeline.target;

    // ── Headline ────────────────────────────────────────────────────────────
    // Prefer the live server-side pax status for the *phase* wording, and fall
    // back to the ETA countdown. `paxTrackingStatus` is the same field the
    // on-screen status pill uses, so the two always agree.
    final String title;
    if (timeline.meBoarded) {
      // Login: I'm in the cab heading to office. Logout: I've been dropped
      // (which is terminal and handled above), so this is the office leg.
      title = etaMinutes != null
          ? 'Reaching office in ${_etaText(etaMinutes)}'
          : 'On the way to office';
    } else if (target != null && target.isMe) {
      // The cab is actively coming to MY stop — the headline case.
      // Prefer the server's explicit flag; fall back to the status-string
      // heuristic only when the backend didn't supply one.
      final arrived = hasCabArrived ?? _hasArrivedAtMyStop(target);
      if (arrived) {
        title = isLogout ? 'Reaching your drop point' : 'Driver has arrived';
      } else {
        final noun = isLogout ? 'Drop' : 'Pickup';
        title = etaMinutes != null
            ? '$noun in ${_etaText(etaMinutes)}'
            : '$noun scheduled';
      }
    } else {
      // Cab is servicing someone ahead of me in the route.
      final ahead = timeline.stopsBeforeMe;
      if (ahead > 0) {
        title = ahead == 1
            ? '1 stop before you'
            : '$ahead stops before you';
      } else {
        title = isLogout ? 'Drop scheduled' : 'Pickup scheduled';
      }
    }

    // ── Detail lines ────────────────────────────────────────────────────────
    // Renders "DL01AB3453 • Honda City" when the backend supplies
    // `vehicleModelName` (Ask 4), degrading to the registration number alone when
    // it doesn't.
    final reg = (vehicleNo?.trim().isNotEmpty == true)
        ? vehicleNo!.trim()
        : null;
    final model = (vehicleModelName?.trim().isNotEmpty == true)
        ? vehicleModelName!.trim()
        : null;
    final vehicle = switch ((reg, model)) {
      (final r?, final m?) => '$r • $m',
      (final r?, null) => r,
      (null, final m?) => m,
      _ => null,
    };
    final driver = (driverName?.trim().isNotEmpty == true)
        ? driverName!.trim()
        : null;

    final parts = <String>[
      if (vehicle != null) vehicle,
      if (driver != null) 'Driver: $driver',
    ];
    final body = parts.isEmpty ? 'Tap to view live tracking' : parts.join(' · ');

    final expandedLines = <String>[
      if (vehicle != null) 'Vehicle: $vehicle',
      if (driver != null) 'Driver: $driver',
      if (target != null) '${isLogout ? "Next drop" : "Next stop"}: '
          '${target.isMe ? "Your stop" : target.title}',
    ];
    final expandedBody = expandedLines.isEmpty
        ? 'Tap to view live tracking'
        : expandedLines.join('\n');

    return LiveTripNotificationContent(
      title: title,
      body: body,
      expandedBody: expandedBody,
      subText: _subText(timeline),
      progressPercent: _progress(timeline),
      payload: payload,
    );
  }

  /// `7 min` / `1 min` / `Arriving now`.
  static String _etaText(int minutes) {
    if (minutes <= 0) return 'less than a min';
    return '$minutes min';
  }

  /// True when the cab has reached my stop but I haven't boarded/deboarded yet.
  /// Reuses the shared [paxRoutePhaseFromStatus] parser so the inconsistent
  /// backend spellings ('En-Route', 'in_cab', …) are handled in exactly one
  /// place.
  static bool _hasArrivedAtMyStop(RideStop target) {
    final raw = (target.paxTrackingStatus ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[-_]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    return raw == 'arrived' || raw == 'reached' || raw == 'cab reached';
  }

  /// `Stop 2 of 5` style context line.
  static String? _subText(RideTimeline timeline) {
    final total = timeline.stops.length;
    if (total == 0) return null;
    final done = timeline.stops
        .where((s) =>
            s.state == StopState.completed || s.state == StopState.noShow)
        .length;
    return 'Stop ${(done + 1).clamp(1, total)} of $total';
  }

  /// Route completion as a percentage of resolved stops.
  static int? _progress(RideTimeline timeline) {
    final total = timeline.stops.length;
    if (total == 0) return null;
    final done = timeline.stops
        .where((s) =>
            s.state == StopState.completed || s.state == StopState.noShow)
        .length;
    return ((done / total) * 100).round().clamp(0, 100);
  }
}
