import 'package:equatable/equatable.dart';

import '../data/model/user_profile_response.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileLoaded extends ProfileState {
  final UserProfileResponse profile;

  const ProfileLoaded(this.profile);

  @override
  List<Object?> get props => [profile];
}

class ProfileError extends ProfileState {
  final String message;

  const ProfileError(this.message);

  @override
  List<Object?> get props => [message];
}

class ProfileUnauthorized extends ProfileState {
  final String message;

  const ProfileUnauthorized([
    this.message = 'Your session has expired. Please log in again.',
  ]);

  @override
  List<Object?> get props => [message];
}

class ProfileAddressChangeSuccess extends ProfileState {
  final String message;

  const ProfileAddressChangeSuccess({
    this.message = 'Address change submitted for approval.',
  });

  @override
  List<Object?> get props => [message];
}

class ProfileAddressChangeFailed extends ProfileState {
  final String message;

  const ProfileAddressChangeFailed(this.message);

  @override
  List<Object?> get props => [message];
}
