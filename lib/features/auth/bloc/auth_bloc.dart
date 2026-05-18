import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:commutr_main/core/storage/auth_local_storage.dart';

import '../data/repository/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;
  final AuthLocalStorage authStorage;

  AuthBloc({required this.authRepository, required this.authStorage})
      : super(const AuthInitial()) {
    on<RequestOtpEvent>(_onRequestOtp);
    on<OtpVerifyEvent>(_onVerifyOtp);
  }

  Future<void> _onRequestOtp(
      RequestOtpEvent event, Emitter<AuthState> emit) async {
    emit(const OtpRequestLoading());
    final result = await authRepository.requestOtp(event.contactNumber);
    print('yash otp request result: $result');
    if (result.failure != null) {
      emit(OtpRequestFailure(
          message: result.message, failure: result.failure!));
    } else {
      emit(OtpRequestSuccess(
          contactNumber: event.contactNumber, message: result.message));
    }
  }

  // otp verify
  Future<void> _onVerifyOtp(
      OtpVerifyEvent event, Emitter<AuthState> emit) async {
    emit(const OtpRequestLoading());
    final result = await authRepository.verifyOtp(event.contactNumber, event.otp);
    if (result.failure != null) {
      emit(OtpVerifyFailure(
          message: result.failure!.message, failure: result.failure!));
    } else {
      await authStorage.saveAuthData(result.data!);
      emit(OtpVerifySuccess(data: result.data!));
    }
  }
}
