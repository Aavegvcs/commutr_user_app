import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class RequestOtpEvent extends AuthEvent {
  final String contactNumber;

  const RequestOtpEvent(this.contactNumber);

  @override
  List<Object?> get props => [contactNumber];
}

class OtpVerifyEvent extends AuthEvent {
  final String contactNumber;
  final String otp;

  const OtpVerifyEvent(this.contactNumber, this.otp);

  @override
  List<Object?> get props => [contactNumber, otp];
}
