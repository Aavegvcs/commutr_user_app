import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repository/user_app_configuration_repo.dart';
import 'user_app_config_event.dart';
import 'user_app_config_state.dart';

class UserAppConfigBloc extends Bloc<UserAppConfigEvent, UserAppConfigState> {
  final UserAppConfigurationRepository _repository;

  UserAppConfigBloc(this._repository)
      : super(const UserAppConfigInitial()) {
    on<FetchUserAppConfig>(_onFetch);
  }

  Future<void> _onFetch(
    FetchUserAppConfig event,
    Emitter<UserAppConfigState> emit,
  ) async {
    debugPrint('[USER_APP_CONFIG_BLOC] FetchUserAppConfig → ${event.locCode}');
    emit(const UserAppConfigLoading());
    try {
      final config =
          await _repository.getUserAppConfigurationByLocCode(event.locCode);
      debugPrint(
        '[USER_APP_CONFIG_BLOC] ✓ '
        'schedule.cancel=${config.scheduleUiConfig.isCancellationScheduledAllowed} '
        'trip.tracking=${config.tripUiConfig.isTripTrackingAllowed} '
        'appIcon=${config.commonUiConfig.appIcon ?? "(absent)"}',
      );
      emit(UserAppConfigLoaded(config));
    } catch (e) {
      debugPrint('[USER_APP_CONFIG_BLOC] ✖ $e');
      emit(UserAppConfigError(e.toString()));
    }
  }
}
