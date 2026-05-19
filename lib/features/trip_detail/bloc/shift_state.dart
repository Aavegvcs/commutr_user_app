import 'package:equatable/equatable.dart';

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
