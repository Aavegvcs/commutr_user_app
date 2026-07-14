import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

import '../../features/auth/data/model/otp_verify_response.dart';

class AuthLocalStorage {
  static const String boxName = 'auth';
  static const _key = 'otp_response';
  static const _dpdcaConsentKey = 'dpdca_consent_seen';

  Box get _box => Hive.box(boxName);

  /// Whether the one-time DPDP consent screen has already been shown after
  /// the first successful OTP verification post-install. The Hive box is wiped
  /// on uninstall, so this naturally resets to `false` on a fresh install.
  bool get hasSeenDpdcaConsent =>
      _box.get(_dpdcaConsentKey, defaultValue: false) as bool;

  Future<void> markDpdcaConsentSeen() async {
    await _box.put(_dpdcaConsentKey, true);
  }

  Future<void> saveAuthData(OtpVerifyResponse response) async {
    await _box.put(_key, jsonEncode(response.toJson()));
  }

  OtpVerifyResponse? getAuthData() {
    final raw = _box.get(_key);
    if (raw == null) return null;
    return OtpVerifyResponse.fromJson(jsonDecode(raw as String));
  }

  String? getAccessToken() => getAuthData()?.data?.accessToken;
  String? getRefreshToken() => getAuthData()?.data?.refreshToken;
  String? getContactNumber() => getAuthData()?.data?.user?.contactNumber;

  Future<void> clearAuthData() async {
    await _box.delete(_key);
  }
}
