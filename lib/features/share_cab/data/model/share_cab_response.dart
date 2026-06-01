class ShareCabResponse {
  final List<ShareCabResult>? result;
  final bool? isSuccess;
  final String? message;

  ShareCabResponse({this.result, this.isSuccess, this.message});

  factory ShareCabResponse.fromJson(Map<String, dynamic> json) {
    return ShareCabResponse(
      result: (json['result'] as List<dynamic>?)
          ?.map((e) => ShareCabResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      isSuccess: json['isSuccess'] as bool?,
      message: json['message'] as String?,
    );
  }
}

class ShareCabResult {
  final int? errorCode;
  final String? dbResponse;
  final String? userMobileNo;
  final String? recepientMobileNo;
  final String? name;
  final String? urlWithPara;

  ShareCabResult({
    this.errorCode,
    this.dbResponse,
    this.userMobileNo,
    this.recepientMobileNo,
    this.name,
    this.urlWithPara,
  });

  factory ShareCabResult.fromJson(Map<String, dynamic> json) {
    return ShareCabResult(
      errorCode: json['errorCode'] as int?,
      dbResponse: json['dB_Response'] as String?,
      userMobileNo: json['userMobileNo'] as String?,
      recepientMobileNo: json['recepientMobileNo'] as String?,
      name: json['name'] as String?,
      urlWithPara: json['urlWithPara'] as String?,
    );
  }
}
