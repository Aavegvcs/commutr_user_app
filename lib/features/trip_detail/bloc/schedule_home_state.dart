import 'package:equatable/equatable.dart';

import '../data/model/schedule_home_response.dart';

abstract class ScheduleHomeState extends Equatable {
  const ScheduleHomeState();

  @override
  List<Object?> get props => [];
}

class ScheduleHomeInitial extends ScheduleHomeState {
  const ScheduleHomeInitial();
}

class ScheduleHomeLoading extends ScheduleHomeState {
  const ScheduleHomeLoading();
}

class ScheduleHomeLoaded extends ScheduleHomeState {
  final List<ScheduleDateGroup> groups;

  const ScheduleHomeLoaded(this.groups);

  @override
  List<Object?> get props => [groups];
}

class ScheduleHomeError extends ScheduleHomeState {
  final String message;

  const ScheduleHomeError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Emitted when the API responds with HTTP 401 and the auth interceptor
/// has exhausted its refresh-token flow.
class ScheduleHomeUnauthorized extends ScheduleHomeState {
  final String message;

  const ScheduleHomeUnauthorized([
    this.message = 'Your session has expired. Please log in again.',
  ]);

  @override
  List<Object?> get props => [message];
}
