import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/error/exceptions.dart';
import '../../features/trip_detail/data/repository/cab_tracking/user_cab_tracking_repo.dart';
import 'cab_tracking_event.dart';
import 'cab_tracking_state.dart';

class CabTrackingBloc extends Bloc<CabTrackingEvent, CabTrackingState> {
  final UserCabTrackingRepo _repository;

  int? _lastEmpId;
  int? _lastTripId;

  // Cache polyline so refresh doesn't re-fetch it every 15 s.
  List<LatLng> _cachedPolyline = const [];

  CabTrackingBloc(this._repository) : super(const CabTrackingInitial()) {
    on<FetchCabTracking>(_onFetch);
    on<RefreshCabTracking>(_onRefresh);
    on<SignalRLocationReceived>(_onSignalRLocation);
  }

  Future<void> _onFetch(
    FetchCabTracking event,
    Emitter<CabTrackingState> emit,
  ) async {
    _lastEmpId = event.empId;
    _lastTripId = event.tripId;
    emit(const CabTrackingLoading());

    try {
      // Fetch status, detail, and GPS route in parallel.
      final results = await Future.wait([
        _repository.getTrackingStatus(tripId: event.tripId),
        _repository.getUserCabTracking(
            empId: event.empId, tripId: event.tripId),
        _repository.getGpsRoute(tripId: event.tripId),
      ]);

      final status = results[0] as dynamic;
      final detail = results[1] as dynamic;
      final gpsRoute = results[2] as dynamic;

      _cachedPolyline = _decodePolyline(gpsRoute.plannedRoutePolyline as String?);

      emit(RideTrackingDataState(
        status: status,
        detail: detail,
        plannedPolylinePoints: _cachedPolyline,
      ));
    } catch (e) {
      if (_isUnauthorized(e)) {
        emit(const CabTrackingUnauthorized());
      } else {
        emit(CabTrackingError(_friendlyMessage(e)));
      }
    }
  }

  Future<void> _onRefresh(
    RefreshCabTracking event,
    Emitter<CabTrackingState> emit,
  ) async {
    final empId = _lastEmpId;
    final tripId = _lastTripId;
    if (empId == null || tripId == null) return;

    final current =
        state is RideTrackingDataState ? state as RideTrackingDataState : null;

    try {
      final results = await Future.wait([
        _repository.getTrackingStatus(tripId: tripId),
        _repository.getUserCabTracking(empId: empId, tripId: tripId),
      ]);

      emit(RideTrackingDataState(
        status: results[0] as dynamic,
        detail: results[1] as dynamic,
        plannedPolylinePoints: _cachedPolyline,
      ));
    } catch (_) {
      // On refresh failure keep showing last good data.
      if (current != null) emit(current);
    }
  }

  List<LatLng> _decodePolyline(String? encoded) {
    if (encoded == null || encoded.trim().isEmpty) return const [];
    try {
      return PolylinePoints()
          .decodePolyline(encoded)
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  void _onSignalRLocation(
    SignalRLocationReceived event,
    Emitter<CabTrackingState> emit,
  ) {
    final current =
        state is RideTrackingDataState ? state as RideTrackingDataState : null;
    if (current == null) return;

    // Patch only the driver lat/lng into the existing status; keep everything else.
    final patchedStatus = current.status?.withLocation(
      lat: event.latitude,
      lng: event.longitude,
    );

    emit(current.copyWith(status: patchedStatus ?? current.status));
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
