/// Central API host and port configuration.

/// - Port **5000** — auth (`/Auth/*`, `/Users/check-exists`, token refresh)
/// - Port **5001** — app APIs (`/UserStages`, `/Otp/*`, weekly off, etc.)
abstract final class ApiConstants {
  ApiConstants._();

  // static const String host = '13.235.144.192';
  // static const String baseHost = 'http://$host';

   // static const String authBaseUrl = 'https://dev-auth.commutr.in/api/v1';
  static const String authBaseUrl = 'https://identity.commutr.in/api/v1';
  static const String appBasePath = 'https://core.commutr.in';
  // static const String appBasePath = 'https://dev-core.commutr.in';
  static const String appBaseUrl = '$appBasePath/api/v1';
  //  static const String appBaseUrl = 'https://dev-core.commutr.in/api/v1';

  /// SignalR chat hub — negotiate endpoint and WebSocket base.
  static const String chatHubUrl = '$appBasePath/hubs/chat';

  /// SignalR route-tracking hub for live cab GPS updates.
  static const String routeTrackingHubUrl = '$appBasePath/hubs/route-tracking';

  /// ETS in-app chat host (scheme + host + port, no trailing slash) — separate
  /// service from the core/auth APIs above.
  static const String etsChatHost = 'http://13.205.219.46';
  static const String etsChatBaseUrl = '$etsChatHost:5050';
}
