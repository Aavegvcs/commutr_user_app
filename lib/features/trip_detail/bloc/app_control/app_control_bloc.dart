import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repository/app_control_repo.dart';
import 'app_control_event.dart';
import 'app_control_state.dart';

class AppControlBloc extends Bloc<AppControlEvent, AppControlState> {
  final AppControlRepository _repository;

  AppControlBloc(this._repository) : super(const AppControlInitial()) {
    on<FetchAppControlSettings>(_onFetch);
  }

  Future<void> _onFetch(
    FetchAppControlSettings event,
    Emitter<AppControlState> emit,
  ) async {
    debugPrint('[APP_CONTROL_BLOC] FetchAppControlSettings → ${event.locCode}');
    emit(const AppControlLoading());
    try {
      final settings =
          await _repository.getAppControlSettingsByLocCode(event.locCode);
      debugPrint(
        '[APP_CONTROL_BLOC] ✓ adhoc=${settings.adhocRequestEnabledForUser} '
        'boardDeboard=${settings.boardDebaordEnabledForUser}',
      );
      emit(AppControlLoaded(settings));
    } catch (e) {
      debugPrint('[APP_CONTROL_BLOC] ✖ $e');
      emit(AppControlError(e.toString()));
    }
  }
}
