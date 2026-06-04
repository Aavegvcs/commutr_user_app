import 'package:commutr_main/ride_tracking/service/route_tracking_signalr_service.dart';
import 'package:equatable/equatable.dart';

abstract class CabTrackingEvent extends Equatable {
  const CabTrackingEvent();

  @override
  List<Object?> get props => [];
}

/// Initial fetch — loads status + detail + GPS route in parallel.
class FetchCabTracking extends CabTrackingEvent {
  final int empId;
  final int tripId;

  const FetchCabTracking({
    required this.empId,
    required this.tripId,
  });

  @override
  List<Object?> get props => [empId, tripId];
}

/// Periodic refresh — re-fetches status and detail (polyline stays cached).
class RefreshCabTracking extends CabTrackingEvent {
  const RefreshCabTracking();
}

/// Fired by SignalR whenever the server pushes a new driver location.
/// Carries the full payload so all fields (speed, status, panic, etc.) are updated.
class SignalRLocationReceived extends CabTrackingEvent {
  final RouteLocationPayload payload;

  const SignalRLocationReceived(this.payload);

  @override
  List<Object?> get props => [
        payload.latitude,
        payload.longitude,
        payload.speed,
        payload.tripStatusCode,
        payload.gpsTime,
        payload.panic,
      ];
}
