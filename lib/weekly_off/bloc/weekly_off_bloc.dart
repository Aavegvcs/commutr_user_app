import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/exceptions.dart';
import '../data/repository/weekly_off_repository.dart';
import 'weekly_off_event.dart';
import 'weekly_off_state.dart';

class WeeklyOffBloc extends Bloc<WeeklyOffEvent, WeeklyOffState> {
  final WeeklyOffRepository repository;

  WeeklyOffBloc({required this.repository}) : super(WeeklyOffInitial()) {
    on<LoadWeeklyOffEvent>(_loadWeeklyOff);
    on<UpdateWeeklyOffEvent>(_updateWeeklyOff);
  }

  Future<void> _loadWeeklyOff(
    LoadWeeklyOffEvent event,
    Emitter<WeeklyOffState> emit,
  ) async {
    try {
      emit(WeeklyOffLoading());
      final response = await repository.showWeeklyOff();
      emit(WeeklyOffLoaded(response));
    } catch (e) {
      if (_isUnauthorized(e)) {
        emit(WeeklyOffUnauthorized());
      } else {
        emit(WeeklyOffFailure(e.toString()));
      }
    }
  }

  Future<void> _updateWeeklyOff(
    UpdateWeeklyOffEvent event,
    Emitter<WeeklyOffState> emit,
  ) async {
    try {
      emit(WeeklyOffLoading());

      final response = await repository.updateWeeklyOff(
        weekOff: event.weekOff,
      );

      emit(WeeklyOffSaved(response));
    } catch (e) {
      if (_isUnauthorized(e)) {
        emit(WeeklyOffUnauthorized());
      } else {
        emit(WeeklyOffFailure(e.toString()));
      }
    }
  }

  /// Detects 401 errors regardless of whether the repository uses the wrapped
  /// [ApiClient] helpers (throws [UnauthorizedException]) or raw [Dio]
  /// (throws [DioException] with `error` set to [UnauthorizedException]).
  bool _isUnauthorized(Object error) {
    if (error is UnauthorizedException) return true;
    if (error is DioException) {
      if (error.error is UnauthorizedException) return true;
      if (error.response?.statusCode == 401) return true;
    }
    return false;
  }
}
