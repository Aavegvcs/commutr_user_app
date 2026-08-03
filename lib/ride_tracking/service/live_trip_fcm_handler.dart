import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'live_trip_notification_service.dart';

/// Handles the backend's data-only `live_trip_update` FCM message (Ask 5b).
///
/// ## Why this exists alongside SignalR
///
/// SignalR needs a live socket, which needs a live process. When Android kills
/// the app — an aggressive OEM battery manager, or the user swiping it away —
/// the socket dies and the ongoing notification freezes at its last ETA. A
/// data-only FCM push is the ONLY thing that can still reach the device in that
/// state, so it is the fallback that keeps the notification honest.
///
/// ## Contract
///
/// The message must be **data-only** (no `notification` block). If the backend
/// includes a `notification` block, Android renders its own banner *in addition*
/// to the ongoing notification and the user sees two. All FCM data values arrive
/// as strings, hence the string parsing below.
///
/// ```jsonc
/// { "data": {
///     "type": "live_trip_update",
///     "dsId": "12345", "empId": "777",
///     "etaMinutes": "7",
///     "paxTrackingStatus": "Not Picked Up",
///     "tripStatusName": "In Progress",
///     "isTerminal": "false",
///     "vehicleNo": "DL01AB3453", "vehicleModelName": "Honda City",
///     "driverName": "Rahul"
/// } }
/// ```
class LiveTripFcmHandler {
  const LiveTripFcmHandler._();

  /// `data.type` value that marks a live-trip update.
  static const String messageType = 'live_trip_update';

  static void _log(String m) => debugPrint('[LiveTripFCM] $m');

  /// True when [message] is a live-trip update this handler owns.
  ///
  /// Everything else (ordinary push notifications) must fall through to the
  /// existing FCM handling untouched.
  static bool handles(RemoteMessage message) =>
      message.data['type'] == messageType;

  /// Renders/updates/clears the ongoing notification from an FCM payload.
  ///
  /// Safe to call from the background isolate: it only touches
  /// `flutter_local_notifications`, never DI or the widget tree.
  ///
  /// Returns true when the message was handled.
  static Future<bool> handle(RemoteMessage message) async {
    if (!handles(message)) return false;
    // Android-only feature for now.
    if (kIsWeb || !Platform.isAndroid) return true;

    final data = message.data;
    _log('received: $data');

    try {
      final isTerminal = _parseBool(data['isTerminal']?.toString()) ?? false;

      if (isTerminal) {
        // Trip ended while we were offline/killed — clear the ongoing
        // notification and post the dismissible completion one.
        await LiveTripNotificationService.instance.cancel();
        await LiveTripNotificationService.instance.showCompleted(
          title: 'Trip completed',
          body: 'Thanks for riding with Commutr.',
        );
        return true;
      }

      final content = _buildContent(data);
      if (content == null) {
        _log('payload missing required ids — ignoring');
        return true;
      }

      await LiveTripNotificationService.instance.update(content);
      return true;
    } catch (e, st) {
      // Never let a malformed push crash the background isolate.
      _log('handle failed (ignored): $e\n$st');
      return true;
    }
  }

  /// Builds notification content directly from the FCM data map.
  ///
  /// This deliberately does NOT reuse
  /// [LiveTripNotificationContent.fromTrackingState]: that factory needs a
  /// [RideTimeline], which requires the full passenger list. An FCM payload
  /// carries only the pre-computed headline values, so the content is assembled
  /// from them directly. The backend is the source of truth here.
  static LiveTripNotificationContent? _buildContent(Map<String, dynamic> data) {
    // FCM data values are strings by contract, but coerce defensively — a
    // backend using the Admin SDK's typed payloads could send numbers.
    String? str(String key) => data[key]?.toString();

    final tripId = int.tryParse(str('dsId') ?? '');
    final empId = int.tryParse(str('empId') ?? '');
    // Without both ids the notification can't be tapped through to the trip.
    if (tripId == null || empId == null) return null;

    final etaMinutes = int.tryParse(str('etaMinutes') ?? '');
    final paxStatus = str('paxTrackingStatus')?.trim();
    final tripStatus = str('tripStatusName')?.trim();

    final title = _title(
      etaMinutes: etaMinutes,
      paxStatus: paxStatus,
      tripStatus: tripStatus,
    );

    final reg = _clean(str('vehicleNo'));
    final model = _clean(str('vehicleModelName'));
    final driver = _clean(str('driverName'));

    final vehicle = switch ((reg, model)) {
      (final r?, final m?) => '$r • $m',
      (final r?, null) => r,
      (null, final m?) => m,
      _ => null,
    };

    final parts = <String>[
      if (vehicle != null) vehicle,
      if (driver != null) 'Driver: $driver',
    ];
    final body =
        parts.isEmpty ? 'Tap to view live tracking' : parts.join(' · ');

    final expanded = <String>[
      if (vehicle != null) 'Vehicle: $vehicle',
      if (driver != null) 'Driver: $driver',
      if (tripStatus != null && tripStatus.isNotEmpty) 'Status: $tripStatus',
    ];

    return LiveTripNotificationContent(
      title: title,
      body: body,
      expandedBody: expanded.isEmpty
          ? 'Tap to view live tracking'
          : expanded.join('\n'),
      payload: '${LiveTripNotificationService.payloadPrefix}:$tripId:$empId',
    );
  }

  /// Headline, preferring an explicit status over a raw ETA countdown.
  static String _title({
    required int? etaMinutes,
    required String? paxStatus,
    required String? tripStatus,
  }) {
    final s = (paxStatus ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'[-_]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (s == 'arrived' || s == 'reached' || s == 'cab reached') {
      return 'Driver has arrived';
    }
    if (s == 'picked up') return 'On the way to office';
    if (s == 'no show') return 'Pickup marked as no-show';

    if (etaMinutes != null) {
      if (etaMinutes <= 0) return 'Pickup in less than a min';
      return 'Pickup in $etaMinutes min';
    }
    if (tripStatus != null && tripStatus.isNotEmpty) return tripStatus;
    return 'Tracking your trip';
  }

  static String? _clean(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  static bool? _parseBool(String? v) {
    if (v == null) return null;
    final s = v.trim().toLowerCase();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
    return null;
  }
}

/// Initialises `flutter_local_notifications` inside the FCM **background**
/// isolate.
///
/// The background handler runs in a fresh isolate where `main()` never executed,
/// so the plugin instance there is uninitialised. Without this the
/// `show()` call silently no-ops — the classic "works in foreground, nothing when
/// killed" bug.
Future<void> initLocalNotificationsForBackgroundIsolate() async {
  if (kIsWeb || !Platform.isAndroid) return;
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await FlutterLocalNotificationsPlugin().initialize(
    settings: const InitializationSettings(android: android),
  );
}
