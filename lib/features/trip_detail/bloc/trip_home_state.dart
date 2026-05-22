import 'package:equatable/equatable.dart';

import '../data/model/trip_home_response.dart';

abstract class TripHomeState extends Equatable {
  const TripHomeState();

  @override
  List<Object?> get props => [];
}

class TripHomeInitial extends TripHomeState {
  const TripHomeInitial();
}

class TripHomeLoading extends TripHomeState {
  const TripHomeLoading();
}

class TripHomeLoaded extends TripHomeState {
  final List<TripDayGroup> groups;

  const TripHomeLoaded(this.groups);

  @override
  List<Object?> get props => [groups];
}

class TripHomeError extends TripHomeState {
  final String message;

  const TripHomeError(this.message);

  @override
  List<Object?> get props => [message];
}

class TripHomeUnauthorized extends TripHomeState {
  final String message;

  const TripHomeUnauthorized([
    this.message = 'Your session has expired. Please log in again.',
  ]);

  @override
  List<Object?> get props => [message];
}
