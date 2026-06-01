/// Wraps the `POST /UserApp/UserAdhocRequest` response.
///
/// `errorCode`: 0 = success, 1 (or non-zero) = error.
class AdhocRequestResponse {
  final bool envelopeSuccess;
  final int errorCode;
  final String dbResponse;
  final String message;

  const AdhocRequestResponse({
    required this.envelopeSuccess,
    required this.errorCode,
    required this.dbResponse,
    required this.message,
  });

  /// Business success when inner `errorCode` is 0.
  bool get isSuccess => errorCode == 0;

  String get displayMessage {
    if (message.isNotEmpty) return message;
    if (dbResponse.isNotEmpty) return dbResponse;
    return isSuccess
        ? 'Adhoc request submitted successfully'
        : 'Failed to submit adhoc request';
  }

  factory AdhocRequestResponse.fromEnvelopeJson(Map<String, dynamic> json) {
    final envelopeSuccess = _readBool(json['isSuccess']);
    final message =
        json['message']?.toString() ?? json['Message']?.toString() ?? '';

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
      errorCode = (json['errorCode'] as num?)?.toInt() ?? errorCode;
      dbResponse =
          (json['dB_Response'] ?? json['dbResponse'] ?? '').toString();
    }

    return AdhocRequestResponse(
      envelopeSuccess: envelopeSuccess,
      errorCode: errorCode,
      dbResponse: dbResponse,
      message: message,
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
