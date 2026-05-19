import 'dart:convert';

class RosterUserDetailsResponse {
  final int errorCode;
  final String dbResponse;
  final RosterUserDetails? details;

  const RosterUserDetailsResponse({
    required this.errorCode,
    required this.dbResponse,
    this.details,
  });

  bool get isSuccess =>
      errorCode == 0 && dbResponse.toLowerCase() == 'success';

  factory RosterUserDetailsResponse.fromJson(Map<String, dynamic> json) {
    RosterUserDetails? details;
    final resultRaw = json['result'];
    if (resultRaw is String && resultRaw.isNotEmpty) {
      try {
        details = RosterUserDetails.fromJson(
          jsonDecode(resultRaw) as Map<String, dynamic>,
        );
      } catch (_) {}
    }

    return RosterUserDetailsResponse(
      errorCode: (json['errorCode'] as num?)?.toInt() ?? -1,
      dbResponse: json['dB_Response']?.toString() ?? '',
      details: details,
    );
  }
}

class RosterUserDetails {
  final List<LocationModel> locations;
  final List<TripTypeModel> tripTypes;
  final List<DriverModel> drivers;
  final int locCode;
  final int empId;
  final String gender;
  final String helpDeskContactNumber;
  final String driverIvrNumber;
  final String sosContactNumber;

  const RosterUserDetails({
    required this.locations,
    required this.tripTypes,
    required this.drivers,
    required this.locCode,
    required this.empId,
    required this.gender,
    required this.helpDeskContactNumber,
    required this.driverIvrNumber,
    required this.sosContactNumber,
  });

  factory RosterUserDetails.fromJson(Map<String, dynamic> json) {
    return RosterUserDetails(
      locations: (json['locations'] as List<dynamic>?)
          ?.map((e) => LocationModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      tripTypes: (json['TripTypes'] as List<dynamic>?)
          ?.map((e) => TripTypeModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      drivers: (json['DrList'] as List<dynamic>?)
          ?.map((e) => DriverModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      locCode: (json['LocCode'] as num?)?.toInt() ?? 0,
      empId: (json['EmpId'] as num?)?.toInt() ?? 0,
      gender: json['Gender']?.toString() ?? '',
      helpDeskContactNumber: json['HelpDeskContactNumber']?.toString() ?? '',
      driverIvrNumber: json['DriverIVRNumber']?.toString() ?? '',
      sosContactNumber: json['SOSContactNumber']?.toString() ?? '',
    );
  }
}

class LocationModel {
  final int locCode;
  final String locName;

  const LocationModel({required this.locCode, required this.locName});

  factory LocationModel.fromJson(Map<String, dynamic> json) => LocationModel(
    locCode: (json['loccode'] as num?)?.toInt() ?? 0,
    locName: json['locname']?.toString() ?? '',
  );
}

class TripTypeModel {
  final int empTripTypeId;
  final String empTripType;

  const TripTypeModel({required this.empTripTypeId, required this.empTripType});

  factory TripTypeModel.fromJson(Map<String, dynamic> json) => TripTypeModel(
    empTripTypeId: (json['EmpTripTypeID'] as num?)?.toInt() ?? 0,
    empTripType: json['EmpTripType']?.toString() ?? '',
  );
}

class DriverModel {
  final int empId;
  final String empName;

  const DriverModel({required this.empId, required this.empName});

  factory DriverModel.fromJson(Map<String, dynamic> json) => DriverModel(
    empId: (json['EMPID'] as num?)?.toInt() ?? 0,
    empName: json['EmpName']?.toString() ?? '',
  );
}