// models/cancel_trip_response.dart

class CancelTripResponse {
  final bool isSuccess;
  final String message;
  final List<CancelTripResult> result;

  CancelTripResponse({
    required this.isSuccess,
    required this.message,
    required this.result,
  });

  factory CancelTripResponse.fromJson(Map<String, dynamic> json) {
    final resultList = json['result'] as List? ?? [];
    return CancelTripResponse(
      isSuccess: json['isSuccess'] ?? false,
      message: json['message'] ?? '',
      result: resultList.map((e) => CancelTripResult.fromJson(e)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isSuccess': isSuccess,
      'message': message,
      'result': result.map((e) => e.toJson()).toList(),
    };
  }
}

class CancelTripResult {
  final int errorCode;
  final String dBResponse;

  CancelTripResult({
    required this.errorCode,
    required this.dBResponse,
  });

  factory CancelTripResult.fromJson(Map<String, dynamic> json) {
    return CancelTripResult(
      errorCode: json['errorCode'] ?? 0,
      dBResponse: json['dB_Response'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'errorCode': errorCode,
      'dB_Response': dBResponse,
    };
  }
}