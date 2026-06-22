import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/exceptions.dart';
import '../data/repository/team_cab_repo.dart';
import 'team_cab_event.dart';
import 'team_cab_state.dart';

class TeamCabBloc extends Bloc<TeamCabEvent, TeamCabState> {
  final TeamCabRepository _repository;

  TeamCabBloc(this._repository) : super(const TeamCabInitial()) {
    on<FetchTeamCab>(_onFetch);
  }

  Future<void> _onFetch(
    FetchTeamCab event,
    Emitter<TeamCabState> emit,
  ) async {
    debugPrint('[TEAM_CAB_BLOC] FetchTeamCab → empId=${event.empId}');
    emit(const TeamCabLoading());
    try {
      final data = await _repository.getTeamTrackingPanel(
        empId: event.empId,
        date: event.date,
      );
      emit(TeamCabLoaded(data));
    } catch (e) {
      debugPrint('[TEAM_CAB_BLOC] FetchTeamCab ✖ $e');
      emit(_mapError(e));
    }
  }

  /// Converts raw exceptions (Dio, ServerException, …) into a friendly,
  /// user-facing [TeamCabError] — never leaks the raw Dio/stack text.
  TeamCabError _mapError(Object error) {
    final status = _statusCode(error);

    if (status == 500 || error is ServerException) {
      return const TeamCabError(
        title: 'Something went wrong',
        message:
            "We couldn't load your team's cab schedule right now. "
            'Please try again in a moment.',
      );
    }
    if (status == 401 || error is UnauthorizedException) {
      return const TeamCabError(
        title: 'Session expired',
        message: 'Your session has expired. Please log in again.',
      );
    }
    if (status == 404) {
      return const TeamCabError(
        title: 'No data found',
        message: 'There is no team cab data available for this request.',
      );
    }
    if (_isConnectionIssue(error)) {
      return const TeamCabError(
        title: 'No internet connection',
        message:
            'Please check your network connection and try again.',
      );
    }
    return const TeamCabError(
      title: 'Unable to load',
      message: 'Something went wrong while loading team cab. Please try again.',
    );
  }

  int? _statusCode(Object error) {
    if (error is DioException) return error.response?.statusCode;
    return null;
  }

  bool _isConnectionIssue(Object error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return true;
        default:
          return false;
      }
    }
    return false;
  }
}
