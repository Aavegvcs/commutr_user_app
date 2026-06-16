import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../debug/api_logger_interceptor.dart';
import '../error/exceptions.dart';
import '../storage/auth_local_storage.dart';

import '../../features/auth/data/model/otp_verify_response.dart';

/// Dio wrapper shared by feature repositories.
///
/// Auth flows (OTP, verify, refresh) may run on a different host/port than
/// other APIs. When [authApiBaseUrl] is set, token refresh uses that base
/// while requests still use [baseUrl].
class ApiClient {
  final Dio _dio;

  ApiClient({
    required String baseUrl,

    /// Base URL for `/Auth/mobile-refresh-token`
    /// when it differs from [baseUrl].
    String? authApiBaseUrl,
    AuthLocalStorage? authStorage,
    VoidCallback? onLogout,
    Dio? dio,
  }) : _dio =
      dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            ),
          ) {
    final refreshBaseUrl = authApiBaseUrl ?? baseUrl;

    /// IMPORTANT:
    /// Auth interceptor FIRST
    _dio.interceptors.addAll([
      if (authStorage != null)
        _AuthInterceptor(
          authStorage,
          refreshBaseUrl,
          onLogout,
          _dio,
        ),

      _LoggingInterceptor(),

      _ErrorInterceptor(),

      if (kDebugMode) ApiLoggerInterceptor(),
    ]);
  }

  Dio get dio => _dio;

  Future<Map<String, dynamic>> post(
      String path, {
        Object? data,
        Map<String, dynamic>? queryParameters,
        Options? options,
      }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );

      return response.data!;
    } on DioException catch (e) {
      if (e.error is Exception) {
        throw e.error as Exception;
      }

      rethrow;
    }
  }

  Future<Map<String, dynamic>> get(
      String path, {
        Map<String, dynamic>? queryParameters,
        Options? options,
      }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
        options: options,
      );

      return response.data!;
    } on DioException catch (e) {
      if (e.error is Exception) {
        throw e.error as Exception;
      }

      rethrow;
    }
  }

  Future<Map<String, dynamic>> put(
      String path, {
        Object? data,
        Options? options,
      }) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        path,
        data: data,
        options: options,
      );

      return response.data!;
    } on DioException catch (e) {
      if (e.error is Exception) {
        throw e.error as Exception;
      }

      rethrow;
    }
  }

  Future<Map<String, dynamic>> delete(
      String path, {
        Object? data,
        Options? options,
      }) async {
    try {
      final response = await _dio.delete<Map<String, dynamic>>(
        path,
        data: data,
        options: options,
      );

      return response.data!;
    } on DioException catch (e) {
      if (e.error is Exception) {
        throw e.error as Exception;
      }

      rethrow;
    }
  }

  void setAuthToken(String token) {
    final normalized = _normalizeBearerToken(token);
    if (normalized.isEmpty) {
      clearAuthToken();
      return;
    }
    _dio.options.headers['Authorization'] = 'Bearer $normalized';
  }

  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  /// Returns `true` when the auth interceptor attempted (or could not attempt)
  /// the refresh-token flow for a 401 response and ultimately gave up — i.e.
  /// the session is dead and the user must log in again.
  ///
  /// Returns `false` for a 401 that wasn't given the refresh-token treatment
  /// (e.g. a non-401 error wrapped as 401 by something else, or a 401 reached
  /// while the refresh was still being set up).
  static bool refreshFailedFor(Object error) {
    if (error is DioException) {
      return error.requestOptions.extra['_refreshFailed'] == true;
    }
    return false;
  }

  /// Strips a leading `Bearer ` if the stored value already includes it.
  static String _normalizeBearerToken(String token) {
    final trimmed = token.trim();
    if (trimmed.toLowerCase().startsWith('bearer ')) {
      return trimmed.substring(7).trim();
    }
    return trimmed;
  }
}

// ─────────────────────────────────────────────────────────────
// AUTH INTERCEPTOR
// ─────────────────────────────────────────────────────────────

class _AuthInterceptor extends Interceptor {
  final AuthLocalStorage _storage;
  final String _baseUrl;
  final VoidCallback? _onLogout;
  final Dio _dio;

  /// Single refresh for multiple 401s
  Future<void>? _refreshFuture;

  _AuthInterceptor(
      this._storage,
      this._baseUrl,
      this._onLogout,
      this._dio,
      );

  @override
  void onRequest(
      RequestOptions options,
      RequestInterceptorHandler handler,
      ) {
    /// Skip auth attach for refresh API
    final isRefreshCall =
        options.extra['_refreshCall'] == true;

    if (isRefreshCall) {
      return handler.next(options);
    }

    final token = _storage.getAccessToken();

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] =
          'Bearer ${ApiClient._normalizeBearerToken(token)}';
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
      DioException err,
      ErrorInterceptorHandler handler,
      ) async {
    final requestOptions = err.requestOptions;

    final isRetry =
        requestOptions.extra['_retry'] == true;

    final isRefreshCall =
        requestOptions.extra['_refreshCall'] == true;

    debugPrint(
      '[AUTH] onError: ${requestOptions.path} '
      '→ status=${err.response?.statusCode} '
      'isRefreshCall=$isRefreshCall isRetry=$isRetry',
    );

    /// Prevent refresh recursion
    if (isRefreshCall) {
      debugPrint('[AUTH] onError: skipping (refresh call itself failed)');
      return handler.next(err);
    }

    if (err.response?.statusCode != 401 || isRetry) {
      debugPrint('[AUTH] onError: not a 401 or already retried — passing through');
      return handler.next(err);
    }

    final refreshToken = _storage.getRefreshToken();

    final contactNumber =
    _storage.getContactNumber();

    debugPrint(
      '[AUTH] 401 detected — '
      'hasRefreshToken=${refreshToken != null} '
      'hasContactNumber=${contactNumber != null}',
    );

    /// No session
    if (refreshToken == null ||
        contactNumber == null) {
      debugPrint('[AUTH] No session data — passing 401 through (no logout)');
      requestOptions.extra['_refreshFailed'] = true;
      return handler.next(err);
    }

    try {
      debugPrint('[AUTH] Starting token refresh…');

      /// Multiple 401s wait for same refresh
      await (_refreshFuture ??=
          _refreshSession(
            refreshToken,
            contactNumber,
          ).whenComplete(
                () => _refreshFuture = null,
          ));

      final newToken =
      _storage.getAccessToken();

      debugPrint('[AUTH] Refresh done — newToken=${newToken != null ? "present" : "null"}');

      if (newToken == null ||
          newToken.isEmpty) {
        debugPrint('[AUTH] No new token after refresh — passing 401 through');
        requestOptions.extra['_refreshFailed'] = true;
        return handler.next(err);
      }

      debugPrint('[AUTH] Retrying original request: ${requestOptions.path}');

      /// Retry request
      requestOptions.extra['_retry'] = true;

      requestOptions.headers['Authorization'] =
          'Bearer ${ApiClient._normalizeBearerToken(newToken)}';

      /// IMPORTANT: do not constrain the response type here.
      /// Different repos call the underlying Dio with `<List<dynamic>>`,
      /// `<Map<String, dynamic>>`, or `<dynamic>` — forcing a generic type
      /// causes a `TypeError` on the retry when the server response shape
      /// doesn't match, which would otherwise silently drop the
      /// successfully-refreshed session.
      final retryResponse =
      await _dio.fetch<dynamic>(
        requestOptions,
      );

      debugPrint(
        '[AUTH] Retry succeeded: ${retryResponse.statusCode} '
        '(dataType=${retryResponse.data.runtimeType})',
      );

      return handler.resolve(retryResponse);
    } catch (e) {
      debugPrint('[AUTH] Refresh/retry failed: $e — passing original 401 through');
      requestOptions.extra['_refreshFailed'] = true;
      return handler.next(err);
    }
  }

  Future<void> _refreshSession(
      String refreshToken,
      String contactNumber,
      ) async {
    try {
      final refreshUri = RequestOptions(
        baseUrl: _baseUrl,
        path: '/Auth/mobile-refresh-token',
      ).uri;

      debugPrint('[AUTH] _refreshSession → POST $refreshUri');
      debugPrint('[AUTH] _refreshSession → body keys: [refreshToken, contactNumber]');

      final response = await _dio.post(
        refreshUri.toString(),
        data: {
          'refreshToken': refreshToken,
          'contactNumber': contactNumber,
        },
        options: Options(
          extra: {
            '_refreshCall': true,
          },
        ),
      );

      final raw = response.data;

      debugPrint('[AUTH] _refreshSession → HTTP ${response.statusCode}');
      debugPrint('[AUTH] _refreshSession → response type: ${raw.runtimeType}');
      debugPrint('[AUTH] _refreshSession → response body: $raw');

      if (raw is! Map) {
        debugPrint('[AUTH] _refreshSession → LOGOUT: response is not a Map (got ${raw.runtimeType})');
        await _storage.clearAuthData();

        _onLogout?.call();

        throw StateError(
          'Invalid refresh response shape',
        );
      }

      final newAuthData =
      OtpVerifyResponse.fromJson(
        Map<String, dynamic>.from(raw),
      );

      debugPrint('[AUTH] _refreshSession → parsed: success=${newAuthData.success} hasData=${newAuthData.data != null}');
      debugPrint('[AUTH] _refreshSession → accessToken=${newAuthData.data?.accessToken != null ? "present" : "null"} refreshToken=${newAuthData.data?.refreshToken != null ? "present" : "null"}');

      await _storage.saveAuthData(newAuthData);

      final newAccessToken =
          newAuthData.data?.accessToken;

      if (newAccessToken == null ||
          newAccessToken.isEmpty) {
        debugPrint('[AUTH] _refreshSession → LOGOUT: accessToken is null/empty after parsing');
        await _storage.clearAuthData();

        _onLogout?.call();

        throw StateError(
          'Missing access token after refresh',
        );
      }

      debugPrint('[AUTH] _refreshSession → SUCCESS: tokens saved');
      _dio.options.headers['Authorization'] =
          'Bearer ${ApiClient._normalizeBearerToken(newAccessToken)}';
    } on DioException catch (e) {
      debugPrint('[AUTH] _refreshSession → DioException: type=${e.type} status=${e.response?.statusCode}');
      debugPrint('[AUTH] _refreshSession → DioException body: ${e.response?.data}');
      debugPrint('[AUTH] _refreshSession → sessionEnded=${_refreshFailureMeansSessionEnded(e)}');

      if (_refreshFailureMeansSessionEnded(e)) {
        debugPrint('[AUTH] _refreshSession → LOGOUT: refresh DioException classified as session-ended');
        await _storage.clearAuthData();

        _onLogout?.call();
      }

      rethrow;
    } catch (e) {
      debugPrint('[AUTH] _refreshSession → unexpected error: $e');
      rethrow;
    }
  }

  /// Logout ONLY if refresh token/session expired.
  bool _refreshFailureMeansSessionEnded(
      DioException e,
      ) {
    if (e.type != DioExceptionType.badResponse) {
      return false;
    }

    final code =
        e.response?.statusCode ?? 0;

    if (code == 401 || code == 403) {
      return true;
    }

    if (code == 400) {
      final msg =
      (_apiMessageFromBody(
        e.response?.data,
      ) ??
          '')
          .toLowerCase();

      return msg.contains('expired') ||
          msg.contains('revoked') ||
          msg.contains('refresh token') ||
          msg.contains('invalid refresh') ||
          msg.contains('token expired') ||
          msg.contains('invalid token');
    }

    return false;
  }

  String? _apiMessageFromBody(dynamic data) {
    if (data is Map) {
      // Backend envelope: dB_Response is the authoritative message.
      final dbResponse = (data['dB_Response'] ?? data['dbResponse'])?.toString();
      if (dbResponse != null && dbResponse.isNotEmpty && dbResponse.toLowerCase() != 'success') {
        return dbResponse;
      }

      final m = (data['message'] ?? data['title'])?.toString();
      if (m != null && m.isNotEmpty) return m;

      final errors = data['errors'];
      if (errors is Map) {
        for (final v in errors.values) {
          if (v is List && v.isNotEmpty) return v.first.toString();
          if (v != null) return v.toString();
        }
      }
    }

    return data?.toString();
  }
}

// ─────────────────────────────────────────────────────────────
// LOGGING INTERCEPTOR
// ─────────────────────────────────────────────────────────────

class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(
      RequestOptions options,
      RequestInterceptorHandler handler,
      ) {
    print(
      '→ [${options.method}] ${options.uri}',
    );
    if (kDebugMode && options.data != null) {
      print('→ body: ${options.data}');
    }

    handler.next(options);
  }

  @override
  void onResponse(
      Response response,
      ResponseInterceptorHandler handler,
      ) {
    print(
      '← [${response.statusCode}] ${response.requestOptions.path}',
    );

    handler.next(response);
  }

  @override
  void onError(
      DioException err,
      ErrorInterceptorHandler handler,
      ) {
    print(
      '✖ [${err.response?.statusCode}] ${err.requestOptions.path}',
    );
    if (kDebugMode) {
      if (err.requestOptions.data != null) {
        print('✖ request body: ${err.requestOptions.data}');
      }
      if (err.response?.data != null) {
        print('✖ response body: ${err.response?.data}');
      }
    }

    handler.next(err);
  }
}

// ─────────────────────────────────────────────────────────────
// ERROR INTERCEPTOR
// ─────────────────────────────────────────────────────────────

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    /// Skip refresh API error conversion
    final isRefreshCall = err.requestOptions.extra['_refreshCall'] == true;

    if (isRefreshCall) {
      return handler.next(err);
    }

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return handler.reject(
          err.copyWith(
            error: NetworkException(
              'Request timed out',
            ),
          ),
        );

      case DioExceptionType.connectionError:
        return handler.reject(
          err.copyWith(
            error: NetworkException(
              'No internet connection',
            ),
          ),
        );

      case DioExceptionType.badResponse:
        final status = err.response?.statusCode ?? 0;

        final msg = _extractMessage(err.response?.data) ?? 'Unknown error';

        final appEx = switch (status) {
          400 => BadRequestException(msg),
          401 => UnauthorizedException(msg),
          404 => NotFoundException(msg),
          409 => ConflictException(msg),
          _ => ServerException(
              'Server error ($status): $msg',
            ),
        };

        return handler.reject(
          err.copyWith(error: appEx),
        );

      default:
        return handler.next(err);
    }
  }

  String? _extractMessage(dynamic data) {
    if (data is Map) {
      // Check backend envelope field first (dB_Response / dbResponse),
      // then fall back to standard REST error fields.
      final dbResponse =
          (data['dB_Response'] ?? data['dbResponse'])?.toString();
      if (dbResponse != null &&
          dbResponse.isNotEmpty &&
          dbResponse.toLowerCase() != 'success') {
        return dbResponse;
      }
      return (data['message'] ?? data['title'])?.toString();
    }

    return data?.toString();
  }
}
