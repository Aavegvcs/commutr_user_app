/// Central API host and port configuration.
///
/// - Port **5000** — auth (`/Auth/*`, `/Users/check-exists`, token refresh)
/// - Port **5001** — app APIs (`/UserStages`, `/Otp/*`, weekly off, etc.)
abstract final class ApiConstants {
  ApiConstants._();

  // static const String host = '13.235.144.192';
  // static const String baseHost = 'http://$host';

  static const String authBaseUrl = 'https://dev-auth.commutr.in/api/v1';
  static const String appBaseUrl = 'https://dev-core.commutr.in/api/v1';
}
