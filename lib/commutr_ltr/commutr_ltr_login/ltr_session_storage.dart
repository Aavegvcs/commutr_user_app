import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// Persists the LTR guest-login session (access/refresh tokens) in Hive.
///
/// The login endpoint (`/Auth/login`) returns a `result` object with an
/// `accessToken` and `refreshToken`. We store both and treat the presence of
/// a non-empty `accessToken` as "logged in".
class LtrSessionStorage {
  static const String boxName = 'ltr_session';

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _mobileKey = 'mobile_number';
  static const _nameKey = 'name';
  static const _empIdKey = 'employee_code';

  Box get _box => Hive.box(boxName);

  /// Store the successful login response plus the details it was made with.
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    String? mobileNumber,
    String? name,
    String? employeeCode,
  }) async {
    await _box.putAll(<String, dynamic>{
      _accessTokenKey: accessToken,
      _refreshTokenKey: refreshToken,
      if (mobileNumber != null) _mobileKey: mobileNumber,
      if (name != null) _nameKey: name,
      if (employeeCode != null) _empIdKey: employeeCode,
    });
  }

  String? get accessToken => _box.get(_accessTokenKey) as String?;
  String? get refreshToken => _box.get(_refreshTokenKey) as String?;
  String? get mobileNumber => _box.get(_mobileKey) as String?;
  String? get name => _box.get(_nameKey) as String?;
  String? get employeeCode => _box.get(_empIdKey) as String?;

  /// A session exists when we have a non-empty access token.
  bool get isLoggedIn => (accessToken?.isNotEmpty ?? false);

  /// True when a session exists AND its access token is a well-formed JWT that
  /// has not yet expired. Falls back to `false` for a missing/malformed token.
  bool get hasValidSession {
    final token = accessToken;
    if (token == null || token.isEmpty) return false;
    final expiry = _jwtExpiry(token);
    if (expiry == null) return false;
    // Treat tokens expiring within the next 30s as already expired to avoid
    // handing a near-dead token to the next screen.
    return expiry.isAfter(DateTime.now().add(const Duration(seconds: 30)));
  }

  /// Decodes the `exp` (seconds since epoch) claim from a JWT and returns it as
  /// a [DateTime]. Returns `null` if the token isn't a decodable JWT with an
  /// integer `exp` claim.
  DateTime? _jwtExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final claims = jsonDecode(payload);
      if (claims is! Map) return null;

      final exp = claims['exp'];
      if (exp is! int) return null;

      return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    await _box.clear();
  }
}
