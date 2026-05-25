import 'package:equatable/equatable.dart';

abstract class BoardTripState extends Equatable {
  const BoardTripState();

  @override
  List<Object?> get props => [];
}

class BoardTripInitial extends BoardTripState {}

class BoardTripLoading extends BoardTripState {}

class BoardTripSuccess extends BoardTripState {
  final String message;

  const BoardTripSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class BoardTripError extends BoardTripState {
  final String message;

  const BoardTripError(this.message);

  @override
  List<Object?> get props => [message];
}

class BoardTripUnauthorized extends BoardTripState {
  final String message;

  const BoardTripUnauthorized(this.message);

  @override
  List<Object?> get props => [message];
}
