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
        // Without this, a payload where ONLY the icon campaign changed would
        // compare equal to the previous state and BlocListener would not fire,
        // so the launcher icon would never update.
        config.commonUiConfig.appIcon,
        config.commonUiConfig.isAreaDdlEnabled,
        config.commonUiConfig.isZoneDdlEnabled,
        config.commonUiConfig.boardingType,
        config.commonUiConfig.deboardingType,
      ];
}

class UserAppConfigError extends UserAppConfigState {
  final String message;

  const UserAppConfigError(this.message);

  @override
  List<Object?> get props => [message];
}
