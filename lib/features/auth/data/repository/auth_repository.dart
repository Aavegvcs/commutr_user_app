import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
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

  /// Returns the FCM token, or an empty string if it can't be obtained.
  ///
  /// On iOS, `getToken()` throws `apns-token-not-set` if the APNS token hasn't
  /// arrived yet (always the case on the simulator, and possible early in app
  /// launch on a device). We wait for the APNS token first and swallow any
  /// failure so OTP verification is never blocked by push setup.
  Future<String> _getFcmToken() async {
    try {
      if (Platform.isIOS) {
        // On a real device the APNS token can be null for a moment right after
        // launch while iOS registers with APNS; retry briefly. On the simulator
        // it stays null (no push support), so we give up and skip the FCM token.
        var apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        for (var i = 0; apnsToken == null && i < 3; i++) {
          await Future.delayed(const Duration(seconds: 1));
          apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        }
        if (apnsToken == null) {
          // No APNS token (e.g. simulator) — skip FCM token rather than throw.
          return '';
        }
      }
      return await FirebaseMessaging.instance.getToken() ?? '';
    } catch (e) {
      debugPrint('[AuthRepository] FCM token unavailable: $e');
      return '';
    }
  }

  Future<({OtpVerifyResponse? data, Failure? failure})> verifyOtp(
      String contact, String otp) async {
    const url = '/Auth/otp/verify';

    final fcmToken = await _getFcmToken();
    final packageInfo = await PackageInfo.fromPlatform();
    final deviceInfo = DeviceInfoPlugin();

    final int platform;
    final String modelName;
    final String modelVersion;

    if (Platform.isAndroid) {
      platform = 1;
      final info = await deviceInfo.androidInfo;
      modelName = info.model;
      modelVersion = info.version.release;
    } else if (Platform.isIOS) {
      platform = 2;
      final info = await deviceInfo.iosInfo;
      modelName = info.utsname.machine;
      modelVersion = info.systemVersion;
    } else {
      platform = 0;
      modelName = '';
      modelVersion = '';
    }

    final payload = {
      'contactNumber': contact,
      'otp': otp,
      'fcmToken': fcmToken,
      'platform': platform,
      'modelName': modelName,
      'appVersion': packageInfo.version,
      'modelVersion': modelVersion,
    };
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
