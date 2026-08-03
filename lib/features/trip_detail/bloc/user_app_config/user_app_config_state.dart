import 'package:equatable/equatable.dart';

import '../../data/model/user_app_configuration_response.dart';

abstract class UserAppConfigState extends Equatable {
  const UserAppConfigState();

  @override
  List<Object?> get props => [];
}

class UserAppConfigInitial extends UserAppConfigState {
  const UserAppConfigInitial();
}

class UserAppConfigLoading extends UserAppConfigState {
  const UserAppConfigLoading();
}

class UserAppConfigLoaded extends UserAppConfigState {
  final UserAppConfiguration config;

  const UserAppConfigLoaded(this.config);

  @override
  List<Object?> get props => [
        config.scheduleUiConfig.isCancellationScheduledAllowed,
        config.scheduleUiConfig.isEditScheduleAllowed,
        config.scheduleUiConfig.isAlreadyScheduledNoShow,
        config.scheduleUiConfig.isCancelledScheduledAllowedAfterTAT,
        config.scheduleUiConfig.isTrackingScheduledAllowed,
        config.scheduleUiConfig.isCreateScheduleAllowed,
        config.tripUiConfig.isTripTrackingAllowed,
        config.tripUiConfig.isTripChatAllowed,
        config.tripUiConfig.isTripShareCabAllowed,
        config.tripUiConfig.isTripIvrCallAllowed,
        config.tripUiConfig.isTripSafeHomeReach,
        config.tripUiConfig.isTripCancellationAllowed,
        config.tripUiConfig.isTripNoShowAllowed,
        config.tripUiConfig.isDeboardOtpFieldAllowed,
        config.tripUiConfig.isTripSummaryAllowed,
        config.commonUiConfig.isUserUpdateProfile,
      ];
}

class UserAppConfigError extends UserAppConfigState {
  final String message;

  const UserAppConfigError(this.message);

  @override
  List<Object?> get props => [message];
}
