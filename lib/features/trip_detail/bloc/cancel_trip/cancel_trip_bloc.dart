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
    on<FetchCancelActiveTripConfirmation>(_onFetchCancelActiveTripConfirmation);
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

  Future<void> _onFetchCancelActiveTripConfirmation(
    FetchCancelActiveTripConfirmation event,
    Emitter<TripCancelState> emit,
  ) async {
    emit(const TripCancelConfirmLoading());
    try {
      final response = await repository.cancelTripConfirmation(
        requestFor: event.requestFor,
        tripType: event.tripType,
        tripId: event.tripId,
      );
      if (response.isSuccess) {
        emit(TripCancelConfirmLoaded(response.popup!));
      } else if (response.errorCode != 0) {
        // The backend explicitly refused cancellation (e.g. user boarded, TAT
        // over). Do not open the dialog — surface the DB_Response instead.
        emit(TripCancelConfirmRefused(
          response.dbResponse.isNotEmpty
              ? response.dbResponse
              : 'Cancellation not permitted.',
        ));
      } else {
        // errorCode == 0 but no usable popup config → fall back to the
        // hardcoded dialog so there is no regression in functionality.
        emit(TripCancelConfirmFallback(response.dbResponse));
      }
    } on UnauthorizedException catch (e) {
      emit(TripCancelUnauthorized(e.toString()));
    } catch (e) {
      // Any transport/parse failure → fall back to the hardcoded dialog so
      // there is no regression in functionality.
      emit(TripCancelConfirmFallback(e.toString()));
    }
  }
}