import 'package:equatable/equatable.dart';
import 'package:commutr_main/auth/data/model/otp_verify_response.dart';
import 'package:commutr_main/core/error/failures.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class OtpRequestLoading extends AuthState {
  const OtpRequestLoading();
}

class OtpRequestSuccess extends AuthState {
  final String contactNumber;
  final String message;

  const OtpRequestSuccess({required this.contactNumber, required this.message});

  @override
  List<Object?> get props => [contactNumber, message];
}

class OtpRequestFailure extends AuthState {
  final String message;
  final Failure failure;

  const OtpRequestFailure({required this.message, required this.failure});

  @override
  List<Object?> get props => [message, failure];
}

// otp verify
class OtpVerifySuccess extends AuthState {
  final OtpVerifyResponse data;

  const OtpVerifySuccess({required this.data});

  @override
  List<Object?> get props => [data];
}

class OtpVerifyFailure extends AuthState {
  final String message;
  final Failure failure;

  const OtpVerifyFailure({required this.message, required this.failure});

  @override
  List<Object?> get props => [message, failure];
}
