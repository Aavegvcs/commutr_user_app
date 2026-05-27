import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/error/exceptions.dart';
import '../data/repository/sos_repo.dart';
import 'sos_event.dart';
import 'sos_state.dart';

class SosBloc extends Bloc<SosEvent, SosState> {
  final SosRepository _repository;

  SosBloc(this._repository) : super(const SosInitial()) {
    on<TriggerSos>(_onTrigger);
  }

  Future<void> _onTrigger(TriggerSos event, Emitter<SosState> emit) async {
    debugPrint('[SOS_BLOC] TriggerSos → empId=${event.empId}');
    emit(const SosLoading());

    try {
      final position = await _resolveCurrentPosition();
      final lat = position?.latitude ?? 0.0;
      final lng = position?.longitude ?? 0.0;

      debugPrint('[SOS_BLOC] location → lat=$lat lng=$lng (hasGps=${position != null})');

      await _repository.triggerSos(empId: event.empId, lat: lat, lng: lng);

      debugPrint('[SOS_BLOC] TriggerSos ✓');
      emit(const SosSuccess());
    } catch (e) {
      debugPrint('[SOS_BLOC] TriggerSos ✖ $e');
      if (_isUnauthorized(e)) {
        emit(const SosUnauthorized());
      } else {
        emit(SosError(_friendlyMessage(e)));
      }
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
      if (!serviceEnabled) return lastKnown;

      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (_) {
        return lastKnown;
      }
    } catch (_) {
      return null;
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
