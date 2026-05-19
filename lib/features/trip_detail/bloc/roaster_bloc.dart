import 'package:commutr_main/features/trip_detail/bloc/roaster_event.dart';
import 'package:commutr_main/features/trip_detail/bloc/roaster_state.dart';
import 'package:dio/dio.dart';
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
    emit(const RosterLoading());
    try {
      final details = await _repository.getUserDetailsForRoster();
      emit(RosterLoaded(details));
    } catch (e) {
      if (_isUnauthorized(e)) {
        emit(const RosterUnauthorized());
      } else {
        emit(RosterError(e.toString()));
      }
    }
  }

  /// Detects 401 errors regardless of whether the repository uses the wrapped
  /// [ApiClient] helpers (throws [UnauthorizedException]) or raw [Dio]
  /// (throws [DioException] with `error` set to [UnauthorizedException]).
  bool _isUnauthorized(Object error) {
    if (error is UnauthorizedException) return true;
    if (error is DioException) {
      if (error.error is UnauthorizedException) return true;
      if (error.response?.statusCode == 401) return true;
    }
    return false;
  }
}