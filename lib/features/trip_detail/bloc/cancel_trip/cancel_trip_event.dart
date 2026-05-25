// presentation/bloc/trip_cancel/trip_cancel_event.dart

import 'package:equatable/equatable.dart';

abstract class TripCancelEvent extends Equatable {
  const TripCancelEvent();

  @override
  List<Object?> get props => [];
}

class CancelTripRequested extends TripCancelEvent {
  final int requestedBy;
  final int requestFor;
  final String tripDate;
  final int tripType;
  final int tripId;

  const CancelTripRequested({
    required this.requestedBy,
    required this.requestFor,
    required this.tripDate,
    required this.tripType,
    required this.tripId,
  });

  @override
  List<Object?> get props => [requestedBy, requestFor, tripDate, tripType, tripId];
}