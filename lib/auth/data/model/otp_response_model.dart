class OtpResponseModel {
  final bool success;
  final OtpMessageModel message;

  const OtpResponseModel({required this.success, required this.message});

  factory OtpResponseModel.fromJson(Map<String, dynamic> json) {
    return OtpResponseModel(
      success: json['success'] as bool? ?? false,
      message: OtpMessageModel.fromJson(
          json['message'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class OtpMessageModel {
  final String result;
  final bool isSuccess;
  final String? message;

  const OtpMessageModel({
    required this.result,
    required this.isSuccess,
    this.message,
  });

  factory OtpMessageModel.fromJson(Map<String, dynamic> json) {
    return OtpMessageModel(
      result: json['result'] as String? ?? '',
      isSuccess: json['isSuccess'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }
}
