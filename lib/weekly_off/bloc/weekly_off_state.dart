
import '../data/model/weekly_off_response_model.dart';

abstract class WeeklyOffState {}

class WeeklyOffInitial extends WeeklyOffState {}

class WeeklyOffLoading extends WeeklyOffState {}

/// Fetched existing preferences (no snackbar).
class WeeklyOffLoaded extends WeeklyOffState {
  final WeeklyOffResponseModel response;

  WeeklyOffLoaded(this.response);
}

/// Save completed (show confirmation).
class WeeklyOffSaved extends WeeklyOffState {
  final WeeklyOffResponseModel response;

  WeeklyOffSaved(this.response);
}

class WeeklyOffFailure extends WeeklyOffState {
  final String message;

  WeeklyOffFailure(this.message);
}

/// Emitted when the weekly-off API responds with HTTP 401 and the auth
/// interceptor was unable to refresh the session.
class WeeklyOffUnauthorized extends WeeklyOffState {
  final String message;

  WeeklyOffUnauthorized([
    this.message = 'Your session has expired. Please log in again.',
  ]);
}
