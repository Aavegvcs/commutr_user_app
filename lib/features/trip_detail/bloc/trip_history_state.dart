import 'package:equatable/equatable.dart';

import '../data/model/trip_history_response.dart';

abstract class TripHistoryState extends Equatable {
  const TripHistoryState();

  @override
  List<Object?> get props => [];
}

class TripHistoryInitial extends TripHistoryState {
  const TripHistoryInitial();
}

class TripHistoryLoading extends TripHistoryState {
  const TripHistoryLoading();
}

class TripHistoryLoaded extends TripHistoryState {
  final List<TripHistoryItem> items;

  const TripHistoryLoaded(this.items);

  @override
  List<Object?> get props => [items];
}

class TripHistoryError extends TripHistoryState {
  final String message;

  const TripHistoryError(this.message);

  @override
  List<Object?> get props => [message];
}

class TripHistoryUnauthorized extends TripHistoryState {
  final String message;

  const TripHistoryUnauthorized([
    this.message = 'Your session has expired. Please log in again.',
  ]);

  @override
  List<Object?> get props => [message];
}
