import 'package:commutr_main/features/trip_detail/bloc/roaster_event.dart';
import 'package:commutr_main/features/trip_detail/bloc/roaster_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/exceptions.dart';
import '../data/repository/user_detail_detail_repo.dart';


class RosterBloc extends Bloc<RosterEvent, RosterState> {
  final RosterRepository _repository;

  RosterBloc(this._repository) : super(const RosterInitial()) {
    on<FetchRosterUserDetails>(_onFetch);
  }

  Future<void> _onFetch(
      FetchRosterUserDetails event,
      Emitter<RosterState> emit,
      ) async {
    debugPrint('[ROSTER_BLOC] FetchRosterUserDetails →');
    emit(const RosterLoading());
    try {
      final details = await _repository.getUserDetailsForRoster();
      debugPrint(
        '[ROSTER_BLOC] FetchRosterUserDetails ✓ '
        '(401 ⇒ refresh-token flow handled transparently by ApiClient)',
      );
      emit(RosterLoaded(details));
    } catch (e) {
      debugPrint('[ROSTER_BLOC] FetchRosterUserDetails ✖ $e');
      if (_isUnauthorized(e)) {
        debugPrint(
          '[ROSTER_BLOC] 401 reached bloc ⇒ refresh-token flow exhausted, '
          'session ended.',
        );
        emit(const RosterUnauthorized());
      } else {
        emit(RosterError(e.toString()));
      }
    }
  }

  /// Detects 401 errors regardless of whether the repository uses the wrapped
  /// [ApiClient] helpers (throws [UnauthorizedException]) or raw [Dio]
  /// (throws [DioException] with `error` set to [UnauthorizedException]).
  ///
  /// Note: the refresh-token flow is owned by [ApiClient]'s auth interceptor.
  /// If a 401 still reaches this bloc, it means the auth interceptor already
  /// attempted (and exhausted) the refresh-token flow.
  bool _isUnauthorized(Object error) {
    if (error is UnauthorizedException) return true;
    if (error is DioException) {
      if (error.error is UnauthorizedException) return true;
      if (error.response?.statusCode == 401) return true;
    }
    return false;
  }
}