class CallDriverIvrResponse {
  final List<CallDriverIvrResult>? result;
  final bool? isSuccess;
  final String? message;

  CallDriverIvrResponse({this.result, this.isSuccess, this.message});

  factory CallDriverIvrResponse.fromJson(Map<String, dynamic> json) {
    return CallDriverIvrResponse(
      result: (json['result'] as List<dynamic>?)
          ?.map((e) => CallDriverIvrResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      isSuccess: json['isSuccess'] as bool?,
      message: json['message'] as String?,
    );
  }
}

class CallDriverIvrResult {
  final int? sno;
  final String? driverMobileNo;
  final int? errorCode;
  final String? dbResponse;

  CallDriverIvrResult({
    this.sno,
    this.driverMobileNo,
    this.errorCode,
    this.dbResponse,
  });

  factory CallDriverIvrResult.fromJson(Map<String, dynamic> json) {
    return CallDriverIvrResult(
      sno: json['sno'] as int?,
      driverMobileNo: json['driverMobileNo'] as String?,
      errorCode: json['errorCode'] as int?,
      dbResponse: json['dB_Response'] as String?,
    );
  }
}
