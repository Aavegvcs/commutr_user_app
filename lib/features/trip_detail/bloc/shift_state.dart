import 'package:equatable/equatable.dart';

import '../data/model/cancel_schedule_confirmation_response.dart';
import '../data/model/roaster_shifts_response.dart';

abstract class ShiftState extends Equatable {
  const ShiftState();

  @override
  List<Object?> get props => [];
}

class ShiftInitial extends ShiftState {
  const ShiftInitial();
}

class ShiftLoading extends ShiftState {
  const ShiftLoading();
}

class ShiftLoaded extends ShiftState {
  final ShiftResult result;

  const ShiftLoaded(this.result);

  @override
  List<Object?> get props => [result];
}

class ShiftError extends ShiftState {
  final String message;

  const ShiftError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Emitted when the shift API responds with HTTP 401 and the auth
/// interceptor was unable to refresh the session.
class ShiftUnauthorized extends ShiftState {
  final String message;

  const ShiftUnauthorized([
    this.message = 'Your session has expired. Please log in again.',
  ]);

  @override
  List<Object?> get props => [message];
}

class ShiftUpdateInProgress extends ShiftState {
  const ShiftUpdateInProgress();
}

class ShiftUpdateSuccess extends ShiftState {
  final String message;

  const ShiftUpdateSuccess([this.message = 'Schedule updated successfully']);

  @override
  List<Object?> get props => [message];
}

class ShiftUpdateError extends ShiftState {
  final String message;

  const ShiftUpdateError(this.message);

  @override
  List<Object?> get props => [message];
}

// ─── Cancel ride states ─────────────────────────────────────────────────────

class ShiftCancelInProgress extends ShiftState {
  const ShiftCancelInProgress();
}

class ShiftCancelSuccess extends ShiftState {
  final String message;

  const ShiftCancelSuccess([this.message = 'Ride cancelled successfully']);

  @override
  List<Object?> get props => [message];
}

class ShiftCancelError extends ShiftState {
  final String message;

  const ShiftCancelError(this.message);

  @override
  List<Object?> get props => [message];
}

// ─── Cancel / No-show confirmation popup states ─────────────────────────────

class ShiftCancelConfirmLoading extends ShiftState {
  const ShiftCancelConfirmLoading();
}

/// The backend returned a usable popup config (`ErrorCode == 0`).
class ShiftCancelConfirmLoaded extends ShiftState {
  final CancelSchedulePopup popup;

  const ShiftCancelConfirmLoaded(this.popup);

  @override
  List<Object?> get props => [popup.popupId, popup.buttons.length];
}

/// The backend refused the popup (`ErrorCode != 0`) — [message] is the
/// `DB_Response` to surface to the user; the dialog must not be opened.
class ShiftCancelConfirmError extends ShiftState {
  final String message;

  const ShiftCancelConfirmError(this.message);

  @override
  List<Object?> get props => [message];
}
