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

/// Fetches the active-trip cancel / no-show confirmation popup config via
/// `POST /UserApp/UserTripCancelConfirmation`.
///
/// The response decides the popup's icon/title/message/buttons. On failure the
/// UI falls back to the existing hardcoded dialog.
class FetchCancelActiveTripConfirmation extends TripCancelEvent {
  final int requestFor;
  final int tripType;
  final int tripId;

  const FetchCancelActiveTripConfirmation({
    required this.requestFor,
    required this.tripType,
    required this.tripId,
  });

  @override
  List<Object?> get props => [requestFor, tripType, tripId];
}