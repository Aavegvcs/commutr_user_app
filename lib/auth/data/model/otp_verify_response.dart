class OtpVerifyResponse {
  final User user;
  final String accessToken;
  final List<dynamic> roles;

  OtpVerifyResponse({
    required this.user,
    required this.accessToken,
    required this.roles,
  });

  factory OtpVerifyResponse.fromJson(Map<String, dynamic> json) {
    return OtpVerifyResponse(
      user: User.fromJson(json['user']),
      accessToken: json['accessToken'],
      roles: json['roles'] ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'accessToken': accessToken,
      'roles': roles,
    };
  }
}

class User {
  final String userId;
  final String tenantId;
  final String email;
  final String name;
  final String contactNumber;

  User({
    required this.userId,
    required this.tenantId,
    required this.email,
    required this.name,
    required this.contactNumber,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
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