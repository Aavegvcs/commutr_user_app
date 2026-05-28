import 'package:commutr_main/profile/data/model/user_profile_response.dart';

/// Single source of profile fields used by profile and edit screens.
class ProfileUserData {
  const ProfileUserData({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.gender,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    required this.office,
    required this.nodalPoint,
    this.empId,
  });

  final String fullName;
  final String email;

  /// Shown as user id / mobile on the profile card and editable as mobile.
  final String phone;
  final String gender;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String office;
  final String nodalPoint;

  /// Numeric employee ID from the API.
  final int? empId;

  /// Build from the profile API response.
  factory ProfileUserData.fromApiResponse(UserProfileResponse r) {
    return ProfileUserData(
      fullName: r.fullName,
      email: r.emailId ?? '',
      phone: r.mobileNo ?? '',
      gender: r.genderLabel,
      address: r.address ?? '',
      city: r.city ?? '',
      state: r.stateName ?? '',
      pincode: r.pin ?? '',
      office: r.locationName ?? '',
      nodalPoint: r.resolvedNodalPoint,
      empId: r.empId,
    );
  }

  /// Split [fullName] into first and last (remainder joins after first word).
  (String, String) get firstAndLastName {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return ('', '');
    final space = trimmed.indexOf(' ');
    if (space == -1) return (trimmed, '');
    return (trimmed.substring(0, space), trimmed.substring(space + 1).trim());
  }

  String get formattedPhone {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)}-${digits.substring(5)}';
    }
    return phone.startsWith('+') ? phone : '+91 $phone';
  }
}

/// Fallback / placeholder used only before the API responds.
const ProfileUserData kProfileUserDataFallback = ProfileUserData(
  fullName: '',
  email: '',
  phone: '',
  gender: 'Other',
  address: '',
  city: '',
  state: '',
  pincode: '',
  office: '',
  nodalPoint: '',
);
