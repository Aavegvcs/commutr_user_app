import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/exceptions.dart';
import '../data/repository/roaster_shift_repo.dart';
import 'shift_event.dart';
import 'shift_state.dart';

class ShiftBloc extends Bloc<ShiftEvent, ShiftState> {
  final RoasterShiftRepo _repository;

  ShiftBloc(this._repository) : super(const ShiftInitial()) {
    on<FetchShifts>(_onFetch);
    on<UpdateShiftSchedules>(_onUpdateSchedules);
  }

  @override
  void onTransition(Transition<ShiftEvent, ShiftState> transition) {
    super.onTransition(transition);
    debugPrint(
      '[SHIFT_BLOC] transition: '
      '${transition.currentState.runtimeType} '
      '--(${transition.event.runtimeType})--> '
      '${transition.nextState.runtimeType}',
    );
  }

  Future<void> _onFetch(FetchShifts event, Emitter<ShiftState> emit) async {
    debugPrint(
      '[SHIFT_BLOC] FetchShifts → locCode=${event.locCode} empId=${event.empId}',
    );
    emit(const ShiftLoading());
    try {
      final result = await _repository.getRoasterShiftDetail(
        locCode: event.locCode,
        empId: event.empId,
      );
      debugPrint(
        '[SHIFT_BLOC] FetchShifts ✓ '
        'pick=${result.pickShifts.length} drop=${result.dropShifts.length}',
      );
      emit(ShiftLoaded(result));
    } catch (e) {
      debugPrint('[SHIFT_BLOC] FetchShifts ✖ $e');
      if (_isUnauthorized(e)) {
        emit(const ShiftUnauthorized());
      } else {
        emit(ShiftError(e.toString()));
      }
    }
  }

  Future<void> _onUpdateSchedules(
    UpdateShiftSchedules event,
    Emitter<ShiftState> emit,
  ) async {
    debugPrint(
      '[SHIFT_BLOC] UpdateShiftSchedules → '
      'locCode=${event.locCode} '
      'fromDate=${event.fromDate} '
      'toDate=${event.toDate} '
      'shiftStart="${event.shiftStart}" '
      'shiftEnd="${event.shiftEnd}" '
      'weekOffs="${event.weekOffs}" '
      'userEmpIds="${event.userEmpIds}"',
    );
    emit(const ShiftUpdateInProgress());
    try {
      final response = await _repository.updateSchedules(
        locCode: event.locCode,
        fromDate: event.fromDate,
        toDate: event.toDate,
        shiftStart: event.shiftStart,
        shiftEnd: event.shiftEnd,
        weekOffs: event.weekOffs,
        userEmpIds: event.userEmpIds,
      );
      debugPrint(
        '[SHIFT_BLOC] UpdateShiftSchedules ✓ '
        'message="${response.message}" dbResponse="${response.dbResponse}"',
      );
      emit(ShiftUpdateSuccess(response.displayMessage));
    } catch (e) {
      debugPrint('[SHIFT_BLOC] UpdateShiftSchedules ✖ $e');
      if (_isUnauthorized(e)) {
        emit(const ShiftUnauthorized());
      } else {
        emit(ShiftUpdateError(_friendlyMessage(e)));
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

  String _friendlyMessage(Object error) {
    if (error is DioException && error.error is Exception) {
      return error.error.toString().replaceFirst('Exception: ', '');
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}
