/// Wraps the `POST /TransRoster/CancelSchedules` response.
///
/// Observed shape:
/// ```json
/// {
///   "result": [
///     { "errorCode": 0, "dB_Response": "Roster cancelled successfully" }
///   ],
///   "isSuccess": true,
///   "message": "Scheduling Cancelled successfully!"
/// }
/// ```
class CancelSchedulesResponse {
  /// Top-level success flag from the envelope.
  final bool envelopeSuccess;

  /// Top-level human-readable message from the envelope.
  final String message;

  /// First item's `errorCode` from the `result` array (defaults to -1 if absent).
  final int errorCode;

  /// First item's `dB_Response` from the `result` array.
  final String dbResponse;

  const CancelSchedulesResponse({
    required this.envelopeSuccess,
    required this.message,
    required this.errorCode,
    required this.dbResponse,
  });

  /// True when both the envelope flags success *and* the inner row reports
  /// a non-error `errorCode` (0).
  bool get isSuccess => envelopeSuccess && errorCode == 0;

  /// Best-effort message for UI / logs.
  /// On error (errorCode != 0) always shows dB_Response because the envelope
  /// message can be misleading even when the DB reports a failure.
  String get displayMessage {
    if (errorCode != 0 && dbResponse.isNotEmpty) return dbResponse;
    if (message.isNotEmpty) return message;
    if (dbResponse.isNotEmpty) return dbResponse;
    return 'Ride cancelled';
  }

  factory CancelSchedulesResponse.fromJson(Map<String, dynamic> json) {
    final envelopeSuccess = _readBool(json['isSuccess']);
    final message = json['message']?.toString() ?? '';

    int errorCode = -1;
    String dbResponse = '';

    final rawResult = json['result'];
    Map<String, dynamic>? first;

    if (rawResult is List && rawResult.isNotEmpty) {
      final item = rawResult.first;
      if (item is Map<String, dynamic>) {
        first = item;
      } else if (item is Map) {
        first = Map<String, dynamic>.from(item);
      }
    } else if (rawResult is Map<String, dynamic>) {
      first = rawResult;
    } else if (rawResult is Map) {
      first = Map<String, dynamic>.from(rawResult);
    }

    if (first != null) {
      errorCode = (first['errorCode'] as num?)?.toInt() ?? -1;
      dbResponse =
          (first['dB_Response'] ?? first['dbResponse'] ?? '').toString();
    } else {
      // Fall back to top-level fields when the result envelope is missing.
      errorCode = (json['errorCode'] as num?)?.toInt() ?? errorCode;
      dbResponse =
          (json['dB_Response'] ?? json['dbResponse'] ?? '').toString();
    }

    return CancelSchedulesResponse(
      envelopeSuccess: envelopeSuccess,
      message: message,
      errorCode: errorCode,
      dbResponse: dbResponse,
    );
  }

  static bool _readBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.toLowerCase();
      return v == 'true' || v == '1' || v == 'yes';
    }
    return false;
  }
}
