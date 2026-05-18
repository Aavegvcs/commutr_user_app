abstract class WeeklyOffEvent {}

class LoadWeeklyOffEvent extends WeeklyOffEvent {}

class UpdateWeeklyOffEvent extends WeeklyOffEvent {
  final String weekOff;

  UpdateWeeklyOffEvent({required this.weekOff});
}

