import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
    debugPrint(
      '[WEEKLY_OFF_BLOC] LoadWeeklyOff → '
      '(401 ⇒ refresh-token flow handled transparently by ApiClient)',
    );
    try {
      emit(WeeklyOffLoading());
      final response = await repository.showWeeklyOff();
      emit(WeeklyOffLoaded(response));
    } catch (e) {
      debugPrint('[WEEKLY_OFF_BLOC] LoadWeeklyOff ✖ $e');
      if (_isUnauthorized(e)) {
        debugPrint(
          '[WEEKLY_OFF_BLOC] 401 reached bloc ⇒ refresh-token flow exhausted, '
          'session ended.',
        );
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
    debugPrint(
      '[WEEKLY_OFF_BLOC] UpdateWeeklyOff → weekOff="${event.weekOff}" '
      '(401 ⇒ refresh-token flow handled transparently by ApiClient)',
    );
    try {
      emit(WeeklyOffLoading());

      final response = await repository.updateWeeklyOff(
        weekOff: event.weekOff,
      );

      emit(WeeklyOffSaved(response));
    } catch (e) {
      debugPrint('[WEEKLY_OFF_BLOC] UpdateWeeklyOff ✖ $e');
      if (_isUnauthorized(e)) {
        debugPrint(
          '[WEEKLY_OFF_BLOC] 401 reached bloc ⇒ refresh-token flow exhausted, '
          'session ended.',
        );
        emit(WeeklyOffUnauthorized());
      } else {
        emit(WeeklyOffFailure(e.toString()));
      }
    }
  }

  /// Detects 401 errors regardless of whether the repository uses the wrapped
  /// [ApiClient] helpers (throws [UnauthorizedException]) or raw [Dio]
  /// (throws [DioException] with `error` set to [UnauthorizedException]).
  ///
  /// Note: the refresh-token flow is owned by [ApiClient]'s auth interceptor.
  /// If a 401 still reaches this bloc, it means the auth interceptor already
  /// attempted (and exhausted) the refresh-token flow.
  bool _isUnauthorized(Object error) {
    if (error is UnauthorizedException) return true;
    if (error is DioException) {
      if (error.error is UnauthorizedException) return true;
      if (error.response?.statusCode == 401) return true;
    }
    return false;
  }
}
