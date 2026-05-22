import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/exceptions.dart';
import '../data/repository/trip_home_repo.dart';
import 'trip_home_event.dart';
import 'trip_home_state.dart';

class TripHomeBloc extends Bloc<TripHomeEvent, TripHomeState> {
  final TripHomeRepo _repository;

  TripHomeBloc(this._repository) : super(const TripHomeInitial()) {
    on<FetchTripHome>(_onFetch);
  }

  @override
  void onTransition(Transition<TripHomeEvent, TripHomeState> transition) {
    super.onTransition(transition);
    debugPrint(
      '[TRIP_HOME_BLOC] ${transition.currentState.runtimeType} '
      '--(${transition.event.runtimeType})--> '
      '${transition.nextState.runtimeType}',
    );
  }

  Future<void> _onFetch(
    FetchTripHome event,
    Emitter<TripHomeState> emit,
  ) async {
    debugPrint('[TRIP_HOME_BLOC] FetchTripHome →');
    emit(const TripHomeLoading());
    try {
      final groups = await _repository.getTripHomePage();
      debugPrint('[TRIP_HOME_BLOC] FetchTripHome ✓ groups=${groups.length}');
      emit(TripHomeLoaded(groups));
    } catch (e) {
      debugPrint('[TRIP_HOME_BLOC] FetchTripHome ✖ $e');
      if (_isUnauthorized(e)) {
        emit(const TripHomeUnauthorized());
      } else {
        emit(TripHomeError(_friendlyMessage(e)));
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
