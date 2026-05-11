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

/// App-wide demo / current user snapshot for profile flows.
const ProfileUserData kProfileUserData = ProfileUserData(
  fullName: 'Yash Khare',
  email: 'yash.khare@asndtechnology.com',
  phone: '9314420102',
  gender: 'Male',
  address:
      'Shastri Nagar, Near Metro Pillar no - 196, Opp. HP Petrol Pump, Delhi',
  city: 'Delhi',
  state: 'New Delhi',
  pincode: '110103',
  office: 'Del24',
  nodalPoint:
      'Shastri Nagar, Near Metro Pillar no - 196, Opp. HP Petrol...',
);
