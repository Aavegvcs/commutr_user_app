// presentation/bloc/trip_cancel/trip_cancel_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:commutr_main/core/error/exceptions.dart';

import '../../data/repository/trip_start/cancel_trip_home_repo.dart';
import 'cancel_trip_event.dart';
import 'cancel_trip_state.dart';

class TripCancelBloc extends Bloc<TripCancelEvent, TripCancelState> {
  final TripCancelRepository repository;

  TripCancelBloc(this.repository) : super(TripCancelInitial()) {
    on<CancelTripRequested>(_onCancelTripRequested);
  }

  Future<void> _onCancelTripRequested(
      CancelTripRequested event,
      Emitter<TripCancelState> emit,
      ) async {
    emit(TripCancelLoading());
    try {
      final response = await repository.cancelTrip(
        requestedBy: event.requestedBy,
        requestFor: event.requestFor,
        tripDate: event.tripDate,
        tripType: event.tripType,
        tripId: event.tripId,
      );
      emit(TripCancelSuccess(response.message));
    } on UnauthorizedException catch (e) {
      emit(TripCancelUnauthorized(e.toString()));
    } catch (e) {
      emit(TripCancelError(e.toString()));
    }
  }
}