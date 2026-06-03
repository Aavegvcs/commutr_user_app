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
class SignalRLocationReceived extends CabTrackingEvent {
  final double latitude;
  final double longitude;

  const SignalRLocationReceived({
    required this.latitude,
    required this.longitude,
  });

  @override
  List<Object?> get props => [latitude, longitude];
}
