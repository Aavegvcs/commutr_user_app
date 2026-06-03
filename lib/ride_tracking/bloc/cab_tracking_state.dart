import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../features/trip_detail/data/model/cab_tracking/user_cab_tracking_response.dart';

abstract class CabTrackingState extends Equatable {
  const CabTrackingState();

  @override
  List<Object?> get props => [];
}

class CabTrackingInitial extends CabTrackingState {
  const CabTrackingInitial();
}

class CabTrackingLoading extends CabTrackingState {
  const CabTrackingLoading();
}

/// Unified state that holds all live tracking data for the screen.
class RideTrackingDataState extends CabTrackingState {
  final TrackingStatusResponse? status;
  final CabTrackingData? detail;
  final List<LatLng> plannedPolylinePoints;

  const RideTrackingDataState({
    this.status,
    this.detail,
    this.plannedPolylinePoints = const [],
  });

  RideTrackingDataState copyWith({
    TrackingStatusResponse? status,
    CabTrackingData? detail,
    List<LatLng>? plannedPolylinePoints,
  }) {
    return RideTrackingDataState(
      status: status ?? this.status,
      detail: detail ?? this.detail,
      plannedPolylinePoints:
          plannedPolylinePoints ?? this.plannedPolylinePoints,
    );
  }

  @override
  List<Object?> get props => [status, detail, plannedPolylinePoints];
}

class CabTrackingError extends CabTrackingState {
  final String message;

  const CabTrackingError(this.message);

  @override
  List<Object?> get props => [message];
}

class CabTrackingUnauthorized extends CabTrackingState {
  const CabTrackingUnauthorized();
}
