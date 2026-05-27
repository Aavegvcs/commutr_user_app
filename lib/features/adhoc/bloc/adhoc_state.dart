import 'package:equatable/equatable.dart';

abstract class AdhocState extends Equatable {
  const AdhocState();

  @override
  List<Object?> get props => [];
}

class AdhocInitial extends AdhocState {
  const AdhocInitial();
}

class AdhocSubmitting extends AdhocState {
  const AdhocSubmitting();
}

class AdhocSubmitSuccess extends AdhocState {
  final String message;

  const AdhocSubmitSuccess([this.message = 'Adhoc request submitted successfully']);

  @override
  List<Object?> get props => [message];
}

class AdhocSubmitError extends AdhocState {
  final String message;

  const AdhocSubmitError(this.message);

  @override
  List<Object?> get props => [message];
}

class AdhocUnauthorized extends AdhocState {
  final String message;

  const AdhocUnauthorized([this.message = 'Your session has expired. Please log in again.']);

  @override
  List<Object?> get props => [message];
}
