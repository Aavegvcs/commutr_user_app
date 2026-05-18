class WeeklyOffResponseModel {
  final List<WeeklyOffResult>? result;
  final bool? isSuccess;
  final String? message;

  WeeklyOffResponseModel({
    this.result,
    this.isSuccess,
    this.message,
  });

  factory WeeklyOffResponseModel.fromJson(Map<String, dynamic> json) {
    return WeeklyOffResponseModel(
      result: (json['result'] as List?)
          ?.map((e) => WeeklyOffResult.fromJson(e))
          .toList(),
      isSuccess: json['isSuccess'],
      message: json['message'],
    );
  }
}

class WeeklyOffResult {
  final String? globalUserID;
  final String? weekOff;
  final int? errorCode;
  final String? dBResponse;

  WeeklyOffResult({
    this.globalUserID,
    this.weekOff,
    this.errorCode,
    this.dBResponse,
  });

  factory WeeklyOffResult.fromJson(Map<String, dynamic> json) {
    return WeeklyOffResult(
      globalUserID: json['globalUserID'],
      weekOff: json['weekOff'],
      errorCode: json['errorCode'],
      dBResponse: json['dB_Response'],
    );
  }
}