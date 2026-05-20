import 'package:equatable/equatable.dart';

abstract class ScheduleHomeEvent extends Equatable {
  const ScheduleHomeEvent();

  @override
  List<Object?> get props => [];
}

/// Triggers a fetch of `GET /UserApp/GetScheduleHomePage`.
class FetchScheduleHome extends ScheduleHomeEvent {
  const FetchScheduleHome();
}
