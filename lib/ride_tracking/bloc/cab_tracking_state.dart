import 'package:equatable/equatable.dart';

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

class CabTrackingLoaded extends CabTrackingState {
  final CabTrackingData data;

  const CabTrackingLoaded(this.data);

  @override
  List<Object?> get props => [data];
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
