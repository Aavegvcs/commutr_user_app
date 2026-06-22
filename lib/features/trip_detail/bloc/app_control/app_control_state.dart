import 'package:equatable/equatable.dart';

import '../../data/model/app_control_settings_response.dart';

abstract class AppControlState extends Equatable {
  const AppControlState();

  @override
  List<Object?> get props => [];
}

class AppControlInitial extends AppControlState {
  const AppControlInitial();
}

class AppControlLoading extends AppControlState {
  const AppControlLoading();
}

class AppControlLoaded extends AppControlState {
  final AppControlSettings settings;

  const AppControlLoaded(this.settings);

  @override
  List<Object?> get props => [settings.adhocRequestEnabledForUser, settings.boardDebaordEnabledForUser];
}

class AppControlError extends AppControlState {
  final String message;

  const AppControlError(this.message);

  @override
  List<Object?> get props => [message];
}
