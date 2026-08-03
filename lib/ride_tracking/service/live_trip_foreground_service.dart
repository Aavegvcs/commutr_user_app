import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Thin wrapper around [FlutterForegroundTask] for the live-trip use case.
///
/// ## What this service is for — and what it is NOT for
///
/// Its ONLY job is to stop Android from suspending the app process while a trip
/// is being tracked without the tracking screen open. All tracking logic —
/// SignalR, ETA, timeline — stays on the **main isolate** in
/// [LiveTripController], where DI, `AuthLocalStorage` and the existing
/// `RouteTrackingSignalRService` already live.
///
/// The alternative (running SignalR inside the plugin's [TaskHandler] isolate)
/// was rejected deliberately: that isolate shares nothing with the app, so it
/// would need its own auth, its own second connection to the same hub, and a
/// duplicate of the entire ETA/timeline derivation. The task handler here is
/// therefore intentionally almost empty.
///
/// ## Google Play declaration — READ BEFORE RELEASING
///
/// This service declares `foregroundServiceType=dataSync`, which requires a
/// **foreground service declaration in the Play Console** (Policy → App content)
/// including a demo video, before a release containing it can ship.
///
/// `dataSync` is capped at **6 cumulative hours per 24 hours** on Android 15+.
/// That is far beyond any realistic commute, but [LiveTripTaskHandler.onDestroy]
/// still handles the timeout path so the app can never be killed by
/// `RemoteServiceException`.
///
/// `location` was deliberately NOT used: the cab's GPS comes from the backend
/// over SignalR, and this app does not read device location for this feature, so
/// declaring a location type would be a mis-declaration.
class LiveTripForegroundService {
  LiveTripForegroundService._();

  static final LiveTripForegroundService instance =
      LiveTripForegroundService._();

  /// Distinct from the local-notification channel in
  /// `LiveTripNotificationService` — the plugin owns this one and ties it to the
  /// service lifetime.
  static const String channelId = 'commutr_live_trip_service_channel';
  static const String _channelName = 'Live trip tracking';
  static const String _channelDescription =
      'Keeps your cab\'s live location and ETA up to date while a trip is '
      'in progress.';

  /// Service id, distinct from the local notification id (1010).
  static const int serviceId = 1011;

  bool _initialized = false;

  bool get _supported => !kIsWeb && Platform.isAndroid;

  /// Mirrors the plugin's own running state. Kept as a local flag because the
  /// plugin's `isRunningService` is async and [LiveTripController] needs a
  /// synchronous answer while choosing a render target.
  bool _running = false;
  bool get isRunning => _running;

  void _log(String message) =>
      debugPrint('[LiveTripForegroundService] $message');

  void _ensureInitialized() {
    if (_initialized || !_supported) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: channelId,
        channelName: _channelName,
        channelDescription: _channelDescription,
        // Silent + low: this notification updates continuously, so it must never
        // buzz or pop a heads-up banner.
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        playSound: false,
        enableVibration: false,
        onlyAlertOnce: true,
        showWhen: false,
        showBadge: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // The main isolate drives all updates via updateService(), so the task
        // isolate has no periodic work of its own to do.
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: true,
        // Never auto-restart or run on boot: a trip is always started by an
        // explicit user action. Auto-start from BOOT_COMPLETED is also a known
        // cause of Play rejections for dataSync services on Android 15+.
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowAutoRestart: false,
        // Kill the service when the user swipes the app away — leaving a tracking
        // service running after an explicit dismissal is user-hostile.
        stopWithTask: true,
      ),
    );
    _initialized = true;
  }

  /// Starts the service. Returns false when unsupported, already running, or
  /// Android refused (e.g. notification permission denied).
  Future<bool> start({
    required String title,
    required String text,
  }) async {
    if (!_supported) return false;

    try {
      _ensureInitialized();

      if (await FlutterForegroundTask.isRunningService) {
        _running = true;
        _log('already running');
        return true;
      }

      final result = await FlutterForegroundTask.startService(
        serviceId: serviceId,
        // `dataSync` — see the Play declaration note in the class doc.
        serviceTypes: const [ForegroundServiceTypes.dataSync],
        notificationTitle: title,
        notificationText: text,
        callback: startLiveTripTask,
      );

      _running = result is ServiceRequestSuccess;
      _log(_running ? 'started' : 'start failed: $result');
      return _running;
    } catch (e) {
      _log('start threw (ignored): $e');
      _running = false;
      return false;
    }
  }

  /// Updates the ongoing service notification's text.
  Future<void> update({
    required String title,
    required String text,
  }) async {
    if (!_supported || !_running) return;
    try {
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );
    } catch (e) {
      _log('update failed (ignored): $e');
    }
  }

  /// Stops the service and removes its notification. Safe to call when not
  /// running.
  Future<void> stop() async {
    if (!_supported) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        final result = await FlutterForegroundTask.stopService();
        _log('stopped: $result');
      }
    } catch (e) {
      _log('stop failed (ignored): $e');
    } finally {
      _running = false;
    }
  }
}

/// Entry point for the foreground task isolate.
///
/// Must be a top-level function annotated with `@pragma('vm:entry-point')` or
/// the AOT compiler will tree-shake it out of release builds and the service
/// will fail to start on a real device while working fine in debug.
@pragma('vm:entry-point')
void startLiveTripTask() {
  FlutterForegroundTask.setTaskHandler(LiveTripTaskHandler());
}

/// Intentionally minimal task handler.
///
/// The main isolate owns SignalR and pushes notification text via
/// `updateService()`, so this handler has no tracking work to perform. It exists
/// only because the plugin requires one to keep the process alive.
class LiveTripTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('[LiveTripTask] started by $starter at $timestamp');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Unused: eventAction is ForegroundTaskEventAction.nothing().
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // isTimeout == true means Android 15+ hit the dataSync 6-hour cap and is
    // tearing us down. The plugin calls stopSelf() for us; logging it is enough,
    // but it must not be ignored silently since it means tracking has ended.
    debugPrint('[LiveTripTask] destroyed (isTimeout=$isTimeout) at $timestamp');
  }

  @override
  void onNotificationPressed() {
    // Tapping the service notification launches the app; the tap is routed by
    // the existing notification router once the UI is up.
    FlutterForegroundTask.launchApp();
  }
}
