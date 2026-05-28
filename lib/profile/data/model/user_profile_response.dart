import 'dart:convert';

/// Unwraps common API envelopes (`result` map or JSON string).
Map<String, dynamic> unwrapProfilePayload(Map<String, dynamic> json) {
  final result = json['result'];
  if (result is Map) {
    return Map<String, dynamic>.from(result);
  }
  if (result is String && result.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(result);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
  }
  return json;
}

int? _readInt(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is num) return value.toInt();
    if (value is String && value.trim().isNotEmpty) {
      return int.tryParse(value.trim());
    }
  }
  return null;
}

double? _readDouble(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is num) return value.toDouble();
    if (value is String && value.trim().isNotEmpty) {
      return double.tryParse(value.trim());
    }
  }
  return null;
}

String? _readString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

class UserProfileResponse {
  final String? userId;
  final int? empId;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? gender;
  final String? address;
  final String? city;
  final int? stateCode;
  final String? stateName;
  final String? pin;
  final String? mobileNo;
  final String? emailId;
  final String? employeeId;
  final int? locCode;
  final String? locationName;
  final String? depCode;
  final String? proCode;
  final String? lobCode;
  final String? lobName;
  final double? empLat;
  final double? empLng;
  final String? nodalPick;
  final String? nodalDrop;
  final String? nodalPoint;
  final String? emerContactNo;
  final int? geocodeId;
  final bool? isActive;
  final bool? transport;

  const UserProfileResponse({
    this.userId,
    this.empId,
    this.firstName,
    this.middleName,
    this.lastName,
    this.gender,
    this.address,
    this.city,
    this.stateCode,
    this.stateName,
    this.pin,
    this.mobileNo,
    this.emailId,
    this.employeeId,
    this.locCode,
    this.locationName,
    this.depCode,
    this.proCode,
    this.lobCode,
    this.lobName,
    this.empLat,
    this.empLng,
    this.nodalPick,
    this.nodalDrop,
    this.nodalPoint,
    this.emerContactNo,
    this.geocodeId,
    this.isActive,
    this.transport,
  });

  factory UserProfileResponse.fromJson(Map<String, dynamic> json) {
    final data = unwrapProfilePayload(json);
    return UserProfileResponse(
      userId: _readString(data, ['user_Id', 'userId', 'User_Id', 'UserId']),
      empId: _readInt(data, ['empId', 'empID', 'EmpID', 'EmpId', 'Empid']),
      firstName: _readString(data, ['firstName', 'FirstName']),
      middleName: _readString(data, ['middleName', 'MiddleName']),
      lastName: _readString(data, ['lastName', 'LastName']),
      gender: _readString(data, ['gender', 'Gender']),
      address: _readString(data, ['address', 'Address']),
      city: _readString(data, ['city', 'City']),
      stateCode: _readInt(data, ['stateCode', 'StateCode']),
      stateName: _readString(data, ['stateName', 'StateName', 'state', 'State']),
      pin: _readString(data, ['pin', 'Pin', 'pincode', 'Pincode']),
      mobileNo: _readString(data, ['mobileNo', 'MobileNo', 'phoneNo', 'PhoneNo']),
      emailId: _readString(data, ['emailId', 'EmailId', 'email', 'Email']),
      employeeId: _readString(data, ['employeeId', 'EmployeeId', 'EmployeeID']),
      locCode: _readInt(data, ['locCode', 'LocCode']),
      locationName:
          _readString(data, ['locationName', 'LocationName', 'office', 'Office']),
      depCode: _readString(data, ['depCode', 'DepCode']),
      proCode: _readString(data, ['proCode', 'ProCode']),
      lobCode: _readString(data, ['lobCode', 'LobCode']),
      lobName: _readString(data, ['lobName', 'LobName']),
      empLat: _readDouble(data, ['emp_Lat', 'empLat', 'Emp_Lat', 'EmpLat']),
      empLng: _readDouble(data, ['emp_Lng', 'empLng', 'Emp_Lng', 'EmpLng']),
      nodalPick: _readString(data, ['nodal_Pick', 'nodalPick', 'Nodal_Pick']),
      nodalDrop: _readString(data, ['nodal_Drop', 'nodalDrop', 'Nodal_Drop']),
      nodalPoint: _readString(
        data,
        ['nodal_Point', 'nodalPoint', 'Nodal_Point', 'NodalPoint'],
      ),
      emerContactNo: _readString(data, [
        'emerContactNo',
        'EmerContactNo',
        'emer_ContactNo',
      ]),
      geocodeId: _readInt(data, ['geocodeID', 'geocodeId', 'GeocodeID']),
      isActive: data['isActive'] as bool? ?? data['IsActive'] as bool?,
      transport: data['transport'] as bool? ?? data['Transport'] as bool?,
    );
  }

  /// Full name combining first + middle (if any) + last.
  String get fullName {
    final parts = [
      firstName?.trim() ?? '',
      if (middleName != null && middleName!.trim().isNotEmpty)
        middleName!.trim(),
      lastName?.trim() ?? '',
    ].where((p) => p.isNotEmpty).toList();
    return parts.join(' ');
  }

  /// Resolved nodal point label.
  /// Preference: pick -> drop -> nodal point.
  String get resolvedNodalPoint {
    final pick = nodalPick?.trim() ?? '';
    if (pick.isNotEmpty) return pick;
    final drop = nodalDrop?.trim() ?? '';
    if (drop.isNotEmpty) return drop;
    final nodal = nodalPoint?.trim() ?? '';
    if (nodal.isNotEmpty) return nodal;
    return '';
  }

  /// Gender code → display label.
  String get genderLabel {
    switch ((gender ?? '').trim().toUpperCase()) {
      case 'M':
        return 'Male';
      case 'F':
        return 'Female';
      default:
        return 'Other';
    }
  }
}
