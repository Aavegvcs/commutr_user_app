import 'package:equatable/equatable.dart';

abstract class TripHomeEvent extends Equatable {
  const TripHomeEvent();

  @override
  List<Object?> get props => [];
}

/// Triggers a fetch of `GET /UserApp/GetTripHomePage`.
class FetchTripHome extends TripHomeEvent {
  const FetchTripHome();
}
