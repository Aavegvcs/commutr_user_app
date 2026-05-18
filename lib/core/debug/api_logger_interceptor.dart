import 'package:dio/dio.dart';
import 'api_log_entry.dart';
import 'api_logger_service.dart';

class ApiLoggerInterceptor extends Interceptor {
  final _startTimes = <String, DateTime>{};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final id = _entryId(options);
    _startTimes[id] = DateTime.now();

    ApiLoggerService.instance.addEntry(
      ApiLogEntry(
        id: id,
        timestamp: DateTime.now(),
        method: options.method,
        url: options.uri.toString(),
        requestHeaders: Map<String, dynamic>.from(options.headers),
        requestBody: options.data,
      ),
    );

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final id = _entryId(response.requestOptions);
    final duration = _elapsed(id);

    final existing = ApiLoggerService.instance.entries
        .where((e) => e.id == id)
        .firstOrNull;

    if (existing != null) {
      ApiLoggerService.instance.updateEntry(
        id,
        existing.copyWith(
          statusCode: response.statusCode,
          responseBody: response.data,
          duration: duration,
          status: ApiLogStatus.success,
        ),
      );
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final id = _entryId(err.requestOptions);
    final duration = _elapsed(id);

    final existing = ApiLoggerService.instance.entries
        .where((e) => e.id == id)
        .firstOrNull;

    if (existing != null) {
      ApiLoggerService.instance.updateEntry(
        id,
        existing.copyWith(
          statusCode: err.response?.statusCode,
          responseBody: err.response?.data,
          duration: duration,
          errorMessage: err.message,
          status: ApiLogStatus.error,
        ),
      );
    }

    handler.next(err);
  }

  String _entryId(RequestOptions options) =>
      '${options.method}-${options.uri}-${options.hashCode}';

  Duration _elapsed(String id) {
    final start = _startTimes.remove(id);
    return start != null ? DateTime.now().difference(start) : Duration.zero;
  }
}
