// presentation/bloc/trip_cancel/trip_cancel_state.dart

import 'package:equatable/equatable.dart';

import '../../data/model/cancel_schedule_confirmation_response.dart';

abstract class TripCancelState extends Equatable {
  const TripCancelState();

  @override
  List<Object?> get props => [];
}

class TripCancelInitial extends TripCancelState {}

class TripCancelLoading extends TripCancelState {}

class TripCancelSuccess extends TripCancelState {
  final String message;
  const TripCancelSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class TripCancelError extends TripCancelState {
  final String message;
  const TripCancelError(this.message);

  @override
  List<Object?> get props => [message];
}

class TripCancelUnauthorized extends TripCancelState {
  final String message;
  const TripCancelUnauthorized(this.message);

  @override
  List<Object?> get props => [message];
}

// ─── Cancel / No-show confirmation popup states ─────────────────────────────

/// The confirmation popup config is being fetched.
class TripCancelConfirmLoading extends TripCancelState {
  const TripCancelConfirmLoading();
}

/// The backend returned a usable popup config (`errorCode == 0`).
class TripCancelConfirmLoaded extends TripCancelState {
  final CancelSchedulePopup popup;

  const TripCancelConfirmLoaded(this.popup);

  @override
  List<Object?> get props => [popup.popupId, popup.buttons.length];
}

/// The backend explicitly refused cancellation (`errorCode != 0`). The dialog
/// must not be opened; [message] is the `dB_Response` to surface to the user
/// (e.g. "User boarded, cancellation not permitted.").
class TripCancelConfirmRefused extends TripCancelState {
  final String message;

  const TripCancelConfirmRefused(this.message);

  @override
  List<Object?> get props => [message];
}

/// A transport/parse failure prevented fetching the popup config. The UI falls
/// back to the existing hardcoded dialog so there is no regression. [message]
/// carries the error for logging/diagnostics.
class TripCancelConfirmFallback extends TripCancelState {
  final String message;

  const TripCancelConfirmFallback(this.message);

  @override
  List<Object?> get props => [message];
}