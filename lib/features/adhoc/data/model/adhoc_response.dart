class AdhocRequestResponse {
  final int errorCode;
  final String dbResponse;
  final String message;

  const AdhocRequestResponse({
    required this.errorCode,
    required this.dbResponse,
    required this.message,
  });

  bool get isSuccess =>
      errorCode == 0 && dbResponse.toLowerCase() == 'success';

  factory AdhocRequestResponse.fromJson(Map<String, dynamic> json) {
    return AdhocRequestResponse(
      errorCode: (json['errorCode'] as num?)?.toInt() ?? -1,
      dbResponse: json['dB_Response']?.toString() ?? '',
      message: json['message']?.toString() ?? json['Message']?.toString() ?? '',
    );
  }
}
