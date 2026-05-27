import 'package:equatable/equatable.dart';

abstract class SosState extends Equatable {
  const SosState();

  @override
  List<Object?> get props => [];
}

class SosInitial extends SosState {
  const SosInitial();
}

class SosLoading extends SosState {
  const SosLoading();
}

class SosSuccess extends SosState {
  const SosSuccess();
}

class SosError extends SosState {
  final String message;

  const SosError(this.message);

  @override
  List<Object?> get props => [message];
}

class SosUnauthorized extends SosState {
  final String message;

  const SosUnauthorized([this.message = 'Your session has expired. Please log in again.']);

  @override
  List<Object?> get props => [message];
}
