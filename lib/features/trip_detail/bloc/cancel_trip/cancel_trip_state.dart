// presentation/bloc/trip_cancel/trip_cancel_state.dart

import 'package:equatable/equatable.dart';

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