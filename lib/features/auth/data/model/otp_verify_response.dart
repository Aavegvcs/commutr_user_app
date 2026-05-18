class OtpVerifyResponse {
  final bool? success;
  final LoginData? data;

  OtpVerifyResponse({
    this.success,
    this.data,
  });

  factory OtpVerifyResponse.fromJson(Map<String, dynamic> json) {
    return OtpVerifyResponse(
      success: json['success'],
      data: json['data'] != null
          ? LoginData.fromJson(json['data'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'data': data?.toJson(),
    };
  }
}

class LoginData {
  final UserModel? user;
  final String? accessToken;
  final List<dynamic>? roles;
  final String? refreshToken;

  LoginData({
    this.user,
    this.accessToken,
    this.roles,
    this.refreshToken,
  });

  factory LoginData.fromJson(Map<String, dynamic> json) {
    return LoginData(
      user: json['user'] != null
          ? UserModel.fromJson(json['user'])
          : null,
      accessToken: json['accessToken'],
      roles: json['roles'] as List<dynamic>?,
      refreshToken: json['refreshToken'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user?.toJson(),
      'accessToken': accessToken,
      'roles': roles,
      'refreshToken': refreshToken,
    };
  }
}

class UserModel {
  final String? userId;
  final String? tenantId;
  final String? email;
  final String? name;
  final String? contactNumber;

  UserModel({
    this.userId,
    this.tenantId,
    this.email,
    this.name,
    this.contactNumber,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['userId'],
      tenantId: json['tenantId'],
      email: json['email'],
      name: json['name'],
      contactNumber: json['contactNumber'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'tenantId': tenantId,
      'email': email,
      'name': name,
      'contactNumber': contactNumber,
    };
  }
}