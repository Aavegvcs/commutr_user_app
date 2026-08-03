import 'package:commutr_main/app.dart';
import 'package:commutr_main/core/di/injection.dart';
import 'package:commutr_main/ride_tracking/bloc/cab_tracking_bloc.dart';
import 'package:commutr_main/ride_tracking/bloc/cab_tracking_event.dart';
import 'package:commutr_main/ride_tracking/ride_tracking.dart';
import 'package:commutr_main/ride_tracking/service/live_trip_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens [RideTrackingScreen] in response to a tap on the ongoing live-trip
/// notification.
///
/// Payload contract (produced by [LiveTripNotificationContent]):
/// `live_trip:<tripId>:<empId>`.
///
/// Payloads that don't carry the live-trip prefix are ignored, so this is safe
/// to call for every notification tap — existing FCM notifications are
/// unaffected.
void openTrackingFromNotificationPayload(String payload) {
  final ids = _parsePayload(payload);
  if (ids == null) return;

  final navigator = navigatorKey.currentState;
  if (navigator == null) return;

  // Tapping the notification while the tracking screen is already open must not
  // stack a second copy of it (which would open a second SignalR connection).
  // Detect an existing instance by route name and no-op if one is already up.
  var alreadyOpen = false;
  navigator.popUntil((route) {
    if (route.settings.name == _routeName) alreadyOpen = true;
    // Never actually pop — this is being used purely to walk the stack.
    return true;
  });
  if (alreadyOpen) return;

  navigator.push(
    MaterialPageRoute(
      settings: const RouteSettings(name: _routeName),
      builder: (_) => BlocProvider(
        create: (_) => sl<CabTrackingBloc>()
          ..add(FetchCabTracking(empId: ids.empId, tripId: ids.tripId)),
        child: RideTrackingScreen(
          tripId: ids.tripId,
          empId: ids.empId,
        ),
      ),
    ),
  );
}

const String _routeName = 'ride_tracking_from_notification';

class _TrackingIds {
  final int tripId;
  final int empId;
  const _TrackingIds(this.tripId, this.empId);
}

/// Parses `live_trip:<tripId>:<empId>`, returning null unless both ids are
/// present and valid — the tracking screen can't fetch anything without them.
_TrackingIds? _parsePayload(String payload) {
  final parts = payload.split(':');
  if (parts.length != 3) return null;
  if (parts[0] != LiveTripNotificationService.payloadPrefix) return null;
  final tripId = int.tryParse(parts[1]);
  final empId = int.tryParse(parts[2]);
  if (tripId == null || empId == null) return null;
  return _TrackingIds(tripId, empId);
}
