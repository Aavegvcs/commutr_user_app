/// Wraps the `POST {appBasePath}/qr-board` response.
///
/// The backend may answer with a flat object, the standard `result` envelope
/// used elsewhere in the app, or a bare list — all three are normalised here.
///
/// ```json
/// { "errorCode": 0, "dB_Response": "Success" }
/// ```
class QrBoardResponse {
  final int? errorCode;
  final String message;

  /// HTTP status of the `/qr-board` call. Drives [isSuccess]: a 2xx response
  /// is a successful boarding (green popup), anything else is a failure (red).
  final int? statusCode;

  const QrBoardResponse({this.errorCode, this.message = '', this.statusCode});

  bool get isSuccess {
    final status = statusCode;
    if (status != null) return status >= 200 && status < 300;
    if (errorCode != null) return errorCode == 0;
    return message.toLowerCase() == 'success';
  }

  QrBoardResponse copyWith({int? statusCode}) => QrBoardResponse(
        errorCode: errorCode,
        message: message,
        statusCode: statusCode ?? this.statusCode,
      );

  factory QrBoardResponse.fromJson(Map<String, dynamic> json) {
    return QrBoardResponse(
      errorCode: (json['errorCode'] ?? json['ErrorCode']) is num
          ? ((json['errorCode'] ?? json['ErrorCode']) as num).toInt()
          : null,
      message: _readMessage(json),
    );
  }

  /// Pulls the payload out of whichever envelope the API used.
  static QrBoardResponse fromRaw(Object? raw, {int? statusCode}) {
    return _parse(raw).copyWith(statusCode: statusCode);
  }

  static QrBoardResponse _parse(Object? raw) {
    if (raw is List) {
      final first = raw.whereType<Map>().firstOrNull;
      return first == null
          ? const QrBoardResponse()
          : _parse(Map<String, dynamic>.from(first));
    }
    if (raw is! Map) return const QrBoardResponse();

    final map = Map<String, dynamic>.from(raw);
    final result = map['result'] ?? map['Result'];
    if (result is List) {
      final first = result.whereType<Map>().firstOrNull;
      if (first != null) {
        return QrBoardResponse.fromJson(Map<String, dynamic>.from(first));
      }
    } else if (result is Map) {
      return QrBoardResponse.fromJson(Map<String, dynamic>.from(result));
    }
    return QrBoardResponse.fromJson(map);
  }

  static String _readMessage(Map<String, dynamic> json) {
    for (final key in const [
      'dB_Response',
      'dbResponse',
      'message',
      'Message',
      'title',
    ]) {
      final v = json[key]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return '';
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
