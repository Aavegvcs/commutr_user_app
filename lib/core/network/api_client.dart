import 'package:dio/dio.dart';
import '../error/exceptions.dart';

/// Singleton Dio wrapper.
/// All features share this client — interceptors live here once, not per-feature.
class ApiClient {
  final Dio _dio;

  ApiClient({required String baseUrl, Dio? dio})
      : _dio = dio ??
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
    _dio.interceptors.addAll([
      _LoggingInterceptor(),
      _ErrorInterceptor(),
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
      if (e.error is Exception) throw e.error as Exception;
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
      if (e.error is Exception) throw e.error as Exception;
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
      if (e.error is Exception) throw e.error as Exception;
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
      if (e.error is Exception) throw e.error as Exception;
      rethrow;
    }
  }

  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }
}

// ── Interceptors ─────────────────────────────────────────────────────────────

class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // ignore: avoid_print
    print('→ [${options.method}] ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // ignore: avoid_print
    print('← [${response.statusCode}] ${response.requestOptions.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // ignore: avoid_print
    print('✖ [${err.response?.statusCode}] ${err.requestOptions.path}');
    handler.next(err);
  }
}

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return handler.reject(
          err.copyWith(error: NetworkException('Request timed out')),
        );
      case DioExceptionType.connectionError:
        return handler.reject(
          err.copyWith(error: NetworkException('No internet connection')),
        );
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode ?? 0;
        final msg = _extractMessage(err.response?.data) ?? 'Unknown error';
        final appEx = switch (status) {
          400 => BadRequestException(msg),
          401 => UnauthorizedException(msg),
          404 => NotFoundException(msg),
          _ => ServerException('Server error ($status): $msg'),
        };
        return handler.reject(err.copyWith(error: appEx));
      default:
        return handler.next(err);
    }
  }

  String? _extractMessage(dynamic data) {
    if (data is Map) {
      return (data['message'] ?? data['title'])?.toString();
    }
    return data?.toString();
  }
}
