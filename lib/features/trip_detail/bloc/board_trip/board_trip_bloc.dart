import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/error/exceptions.dart';
import '../../data/repository/trip_start/board_trip_repo.dart';
import 'board_trip_event.dart';
import 'board_trip_state.dart';

class BoardTripBloc extends Bloc<BoardTripEvent, BoardTripState> {
  final BoardTripRepository _repository;

  BoardTripBloc(this._repository) : super(BoardTripInitial()) {
    on<BoardTripRequested>(_onBoardTripRequested);
  }

  Future<void> _onBoardTripRequested(
    BoardTripRequested event,
    Emitter<BoardTripState> emit,
  ) async {
    emit(BoardTripLoading());
    try {
      final position = await _resolveCurrentPosition();
      if (position == null) {
        emit(const BoardTripError(
          'Location permission is required to board. Please enable GPS and try again.',
        ));
        return;
      }

      final response = await _repository.userBoardDeboard(
        empId: event.empId,
        tripId: event.tripId,
        tripType: event.tripType,
        empLat: position.latitude,
        empLng: position.longitude,
        boardingType: event.boardingType,
      );

      final result =
          response.result.isNotEmpty ? response.result.first : null;
      final message = (result?.dbResponse ?? '').trim().isNotEmpty
          ? result!.dbResponse
          : (response.message.trim().isNotEmpty
              ? response.message
              : 'Boarded successfully.');

      emit(BoardTripSuccess(message));
    } on UnauthorizedException catch (e) {
      emit(BoardTripUnauthorized(e.toString()));
    } catch (e) {
      emit(BoardTripError(_friendlyMessage(e)));
    }
  }

  Future<Position?> _resolveCurrentPosition() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      Position? lastKnown;
      try {
        lastKnown = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return lastKnown;
      }

      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 25),
          ),
        );
      } catch (_) {
        return lastKnown;
      }
    } catch (_) {
      return null;
    }
  }

  String _friendlyMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }
}
