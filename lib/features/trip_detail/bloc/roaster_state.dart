import 'package:equatable/equatable.dart';

import '../data/model/user_details_roaster_response.dart';


abstract class RosterState extends Equatable {
  const RosterState();

  @override
  List<Object?> get props => [];
}

class RosterInitial extends RosterState {
  const RosterInitial();
}

class RosterLoading extends RosterState {
  const RosterLoading();
}

class RosterLoaded extends RosterState {
  final RosterUserDetails details;

  const RosterLoaded(this.details);

  @override
  List<Object?> get props => [details];
}

class RosterError extends RosterState {
  final String message;

  const RosterError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Emitted when the roster API responds with HTTP 401 and the auth
/// interceptor was unable to refresh the session.
class RosterUnauthorized extends RosterState {
  final String message;

  const RosterUnauthorized([
    this.message = 'Your session has expired. Please log in again.',
  ]);

  @override
  List<Object?> get props => [message];
}