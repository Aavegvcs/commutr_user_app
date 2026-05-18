import 'package:flutter/foundation.dart';

enum ApiLogStatus { pending, success, error }

@immutable
class ApiLogEntry {
  const ApiLogEntry({
    required this.id,
    required this.timestamp,
    required this.method,
    required this.url,
    this.requestHeaders,
    this.requestBody,
    this.statusCode,
    this.responseBody,
    this.duration,
    this.errorMessage,
    this.status = ApiLogStatus.pending,
  });

  final String id;
  final DateTime timestamp;
  final String method;
  final String url;
  final Map<String, dynamic>? requestHeaders;
  final dynamic requestBody;
  final int? statusCode;
  final dynamic responseBody;
  final Duration? duration;
  final String? errorMessage;
  final ApiLogStatus status;

  ApiLogEntry copyWith({
    int? statusCode,
    dynamic responseBody,
    Duration? duration,
    String? errorMessage,
    ApiLogStatus? status,
  }) {
    return ApiLogEntry(
      id: id,
      timestamp: timestamp,
      method: method,
      url: url,
      requestHeaders: requestHeaders,
      requestBody: requestBody,
      statusCode: statusCode ?? this.statusCode,
      responseBody: responseBody ?? this.responseBody,
      duration: duration ?? this.duration,
      errorMessage: errorMessage ?? this.errorMessage,
      status: status ?? this.status,
    );
  }
}
