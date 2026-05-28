import 'package:equatable/equatable.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

/// Triggers a fetch of `GET /Users/global/{userId}`.
class FetchUserProfile extends ProfileEvent {
  const FetchUserProfile();
}

/// Submits address change via `POST /AddressChanges`.
class SubmitAddressChange extends ProfileEvent {
  final String address;
  final String city;
  final String state;
  final String pin;
  final double? empLat;
  final double? empLng;

  const SubmitAddressChange({
    required this.address,
    required this.city,
    required this.state,
    required this.pin,
    this.empLat,
    this.empLng,
  });

  @override
  List<Object?> get props => [address, city, state, pin, empLat, empLng];
}
