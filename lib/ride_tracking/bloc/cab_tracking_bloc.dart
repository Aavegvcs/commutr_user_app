import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/exceptions.dart';
import '../../features/trip_detail/data/repository/cab_tracking/user_cab_tracking_repo.dart';
import 'cab_tracking_event.dart';
import 'cab_tracking_state.dart';

class CabTrackingBloc extends Bloc<CabTrackingEvent, CabTrackingState> {
  final UserCabTrackingRepo _repository;

  CabTrackingBloc(this._repository) : super(const CabTrackingInitial()) {
    on<FetchCabTracking>(_onFetch);
  }

  Future<void> _onFetch(
    FetchCabTracking event,
    Emitter<CabTrackingState> emit,
  ) async {
    emit(const CabTrackingLoading());
    try {
      final data = await _repository.getUserCabTracking(
        empId: event.empId,
        tripId: event.tripId,
      );
      emit(CabTrackingLoaded(data));
    } catch (e) {
      if (_isUnauthorized(e)) {
        emit(const CabTrackingUnauthorized());
      } else {
        emit(CabTrackingError(_friendlyMessage(e)));
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
