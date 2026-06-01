import 'dart:convert';

class AdhocListResponse {
  final int errorCode;
  final String dbResponse;
  final List<AdhocRequestItem> items;

  const AdhocListResponse({
    required this.errorCode,
    required this.dbResponse,
    required this.items,
  });

  bool get isSuccess =>
      errorCode == 0 && dbResponse.toLowerCase() == 'success';

  factory AdhocListResponse.fromJson(Map<String, dynamic> json) {
    List<AdhocRequestItem> items = [];
    final resultRaw = json['result'];
    if (resultRaw is String && resultRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(resultRaw);
        if (decoded is List) {
          items = decoded
              .whereType<Map<String, dynamic>>()
              .map(AdhocRequestItem.fromJson)
              .toList();
        }
      } catch (_) {}
    }

    return AdhocListResponse(
      errorCode: (json['errorCode'] as num?)?.toInt() ?? -1,
      dbResponse: json['dB_Response']?.toString() ?? '',
      items: items,
    );
  }
}

class AdhocRequestItem {
  final int reqId;
  final int empId;
  final String userName;
  final String requestDate;
  final String tripType;
  final String shiftTime;
  final String status;

  const AdhocRequestItem({
    required this.reqId,
    required this.empId,
    required this.userName,
    required this.requestDate,
    required this.tripType,
    required this.shiftTime,
    required this.status,
  });

  bool get isLogin => tripType.trim().toLowerCase() == 'pick';

  factory AdhocRequestItem.fromJson(Map<String, dynamic> json) {
    return AdhocRequestItem(
      reqId: (json['ReqId'] as num?)?.toInt() ?? 0,
      empId: (json['EmpId'] as num?)?.toInt() ?? 0,
      userName: json['UserName']?.toString() ?? '',
      requestDate: json['RequestDate']?.toString() ?? '',
      tripType: json['TripType']?.toString() ?? '',
      shiftTime: json['ShiftTime']?.toString() ?? '',
      status: json['STATUS']?.toString() ?? '',
    );
  }
}
