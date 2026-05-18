import 'package:flutter/foundation.dart';
import 'package:commutr_main/core/error/exceptions.dart';
import 'package:commutr_main/core/error/failures.dart';
import 'package:commutr_main/core/network/api_client.dart';

import '../model/otp_response_model.dart';
import '../model/otp_verify_response.dart';

class AuthRepository {
  final ApiClient apiClient;

  AuthRepository({required this.apiClient});

  Future<({bool success, String message, Failure? failure})> requestOtp(
      String contactNumber) async {
    const url = '/Auth/otp/request';
    final payload = {'contactNumber': contactNumber};
    debugPrint('[AuthRepository] requestOtp url: $url');
    debugPrint('[AuthRepository] requestOtp payload: $payload');
    try {
      final json = await apiClient.post(url, data: payload);
      debugPrint('[AuthRepository] requestOtp response: $json');
      final model = OtpResponseModel.fromJson(json);
      return (
        success: model.message.isSuccess,
        message: model.message.result,
        failure: null
      );
    } on NetworkException catch (e) {
      debugPrint('[AuthRepository] requestOtp NetworkException: ${e.message}');
      return (
        success: false,
        message: e.message,
        failure: NetworkFailure(e.message)
      );
    } on UnauthorizedException catch (e) {
      debugPrint(
          '[AuthRepository] requestOtp UnauthorizedException: ${e.message}');
      return (
        success: false,
        message: e.message,
        failure: ServerFailure(e.message)
      );
    } on BadRequestException catch (e) {
      debugPrint(
          '[AuthRepository] requestOtp BadRequestException: ${e.message}');
      return (
        success: false,
        message: e.message,
        failure: ServerFailure(e.message)
      );
    } on ServerException catch (e) {
      debugPrint('[AuthRepository] requestOtp ServerException: ${e.title}');
      return (
        success: false,
        message: e.title,
        failure: ServerFailure(e.title)
      );
    } catch (e) {
      debugPrint('[AuthRepository] requestOtp error: $e');
      return (
        success: false,
        message: e.toString(),
        failure: ServerFailure(e.toString())
      );
    }
  }

  Future<({OtpVerifyResponse? data, Failure? failure})> verifyOtp(
      String contact, String otp) async {
    const url = '/Auth/otp/verify';
    final payload = {'contactNumber': contact, 'otp': otp};
    debugPrint('[AuthRepository] verifyOtp url: $url');
    debugPrint('[AuthRepository] verifyOtp payload: $payload');
    try {
      final json = await apiClient.post(url, data: payload);
      debugPrint('[AuthRepository] verifyOtp response: $json');
      final model = OtpVerifyResponse.fromJson(json);
      return (data: model, failure: null);
    } on NetworkException catch (e) {
      debugPrint('[AuthRepository] verifyOtp NetworkException: ${e.message}');
      return (data: null, failure: NetworkFailure(e.message));
    } on ServerException catch (e) {
      debugPrint('[AuthRepository] verifyOtp ServerException: ${e.title}');
      return (data: null, failure: ServerFailure(e.title));
    } catch (e) {
      debugPrint('[AuthRepository] verifyOtp error: $e');
      return (data: null, failure: const ServerFailure('Otp Verified failed!'));
    }
  }
}
