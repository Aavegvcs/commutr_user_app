import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/exceptions.dart';
import '../data/repository/trip_history_repo.dart';
import 'trip_history_event.dart';
import 'trip_history_state.dart';

class TripHistoryBloc extends Bloc<TripHistoryEvent, TripHistoryState> {
  final TripHistoryRepo _repository;

  TripHistoryBloc(this._repository) : super(const TripHistoryInitial()) {
    on<FetchTripHistory>(_onFetch);
  }

  Future<void> _onFetch(
    FetchTripHistory event,
    Emitter<TripHistoryState> emit,
  ) async {
    debugPrint(
      '[TRIP_HISTORY_BLOC] FetchTripHistory → empId=${event.empId} '
      'from=${event.fromDate} to=${event.toDate} searchBy=${event.searchBy}',
    );
    emit(const TripHistoryLoading());
    try {
      final items = await _repository.getTripHistory(
        empId: event.empId,
        fromDate: event.fromDate,
        toDate: event.toDate,
        searchBy: event.searchBy,
      );
      debugPrint('[TRIP_HISTORY_BLOC] FetchTripHistory ✓ items=${items.length}');
      emit(TripHistoryLoaded(items));
    } catch (e) {
      debugPrint('[TRIP_HISTORY_BLOC] FetchTripHistory ✖ $e');
      if (_isUnauthorized(e)) {
        emit(const TripHistoryUnauthorized());
      } else {
        emit(TripHistoryError(_friendlyMessage(e)));
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
