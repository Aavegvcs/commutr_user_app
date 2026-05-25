class UserBoardDeboardResponse {
  final bool isSuccess;
  final String message;
  final List<UserBoardDeboardResult> result;

  const UserBoardDeboardResponse({
    required this.isSuccess,
    required this.message,
    this.result = const [],
  });

  factory UserBoardDeboardResponse.fromJson(Map<String, dynamic> json) {
    final resultList = json['result'] as List? ?? [];
    return UserBoardDeboardResponse(
      isSuccess: json['isSuccess'] == true,
      message: json['message']?.toString() ?? '',
      result: resultList
          .whereType<Map>()
          .map((e) => UserBoardDeboardResult.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList(growable: false),
    );
  }
}

class UserBoardDeboardResult {
  final int errorCode;
  final String dbResponse;

  const UserBoardDeboardResult({
    required this.errorCode,
    required this.dbResponse,
  });

  factory UserBoardDeboardResult.fromJson(Map<String, dynamic> json) {
    return UserBoardDeboardResult(
      errorCode: (json['errorCode'] as num?)?.toInt() ?? -1,
      dbResponse:
          json['dB_Response']?.toString() ?? json['dbResponse']?.toString() ?? '',
    );
  }

  bool get isOk => errorCode == 0;
}
