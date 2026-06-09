/// Response for `POST /Ivr/initiate`.
class IvrInitiateResponse {
  final int? ivrCallLogId;
  final String? ivrVirtualNumber;
  final String? calleeMobileNo;

  IvrInitiateResponse({
    this.ivrCallLogId,
    this.ivrVirtualNumber,
    this.calleeMobileNo,
  });

  factory IvrInitiateResponse.fromJson(Map<String, dynamic> json) {
    return IvrInitiateResponse(
      ivrCallLogId: json['ivrCallLogId'] as int?,
      ivrVirtualNumber: json['ivrVirtualNumber'] as String?,
      calleeMobileNo: json['calleeMobileNo'] as String?,
    );
  }
}
