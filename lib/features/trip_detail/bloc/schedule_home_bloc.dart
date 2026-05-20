import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/exceptions.dart';
import '../data/repository/schedule_home_repo.dart';
import 'schedule_home_event.dart';
import 'schedule_home_state.dart';

class ScheduleHomeBloc extends Bloc<ScheduleHomeEvent, ScheduleHomeState> {
  final ScheduleHomeRepo _repository;

  ScheduleHomeBloc(this._repository) : super(const ScheduleHomeInitial()) {
    on<FetchScheduleHome>(_onFetch);
  }

  @override
  void onTransition(
    Transition<ScheduleHomeEvent, ScheduleHomeState> transition,
  ) {
    super.onTransition(transition);
    debugPrint(
      '[SCHEDULE_HOME_BLOC] ${transition.currentState.runtimeType} '
      '--(${transition.event.runtimeType})--> '
      '${transition.nextState.runtimeType}',
    );
  }

  Future<void> _onFetch(
    FetchScheduleHome event,
    Emitter<ScheduleHomeState> emit,
  ) async {
    debugPrint('[SCHEDULE_HOME_BLOC] FetchScheduleHome →');
    emit(const ScheduleHomeLoading());
    try {
      final groups = await _repository.getScheduleHomePage();
      debugPrint('[SCHEDULE_HOME_BLOC] FetchScheduleHome ✓ groups=${groups.length}');
      emit(ScheduleHomeLoaded(groups));
    } catch (e) {
      debugPrint('[SCHEDULE_HOME_BLOC] FetchScheduleHome ✖ $e');
      if (_isUnauthorized(e)) {
        emit(const ScheduleHomeUnauthorized());
      } else {
        emit(ScheduleHomeError(_friendlyMessage(e)));
      }
    }
  }

  bool _isUnauthorized(Object error) {
    if (error is UnauthorizedException) return true;
    if (error is DioException) {
      if (error.error is UnauthorizedException) return true;
      if (error.response?.statusCode == 401) return true;
    }
    return false;
  }

  String _friendlyMessage(Object error) {
    if (error is DioException && error.error is Exception) {
      return error.error.toString().replaceFirst('Exception: ', '');
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}
