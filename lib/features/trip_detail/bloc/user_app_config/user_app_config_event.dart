import 'package:equatable/equatable.dart';

abstract class UserAppConfigEvent extends Equatable {
  const UserAppConfigEvent();

  @override
  List<Object?> get props => [];
}

class FetchUserAppConfig extends UserAppConfigEvent {
  final int locCode;

  const FetchUserAppConfig(this.locCode);

  @override
  List<Object?> get props => [locCode];
}
