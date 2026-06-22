/// Response model for `GET /Tracking/team-tracking-panel`.
class TeamTrackingPanelResponse {
  final bool isSuccess;
  final String message;
  final int requestedEmpId;
  final DateTime? requestedDate;
  final List<TeamTripModel> trips;

  const TeamTrackingPanelResponse({
    required this.isSuccess,
    required this.message,
    required this.requestedEmpId,
    required this.requestedDate,
    required this.trips,
});

  factory TeamTrackingPanelResponse.fromJson(Map<String, dynamic> json) {
    return TeamTrackingPanelResponse(
      isSuccess: json['isSuccess'] as bool? ?? false,
      message: json['message']?.toString() ?? '',
      requestedEmpId: (json['requestedEmpId'] as num?)?.toInt() ?? 0,
    requestedDate: _parseDate(json['requestedDate']),
      trips: (json['trips'] as List<dynamic>?)
              ?.map((e) => TeamTripModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  } 
}

class TeamTripModel {
  final int empId;
  final int dsId;
  final String fullName;
  final int tripType;
  final String tripTypeName;
  final int tripStatusCode;
  final String tripStatusName;
  final DateTime? dsDate;
  final DateTime? scheduledStartTime;

  const TeamTripModel({
    required this.empId,
    required this.dsId,
    required this.fullName,
    required this.tripType,
    required this.tripTypeName,
    required this.tripStatusCode,
    required this.tripStatusName,
    required this.dsDate,
    required this.scheduledStartTime,
  });

  factory TeamTripModel.fromJson(Map<String, dynamic> json) {
    return TeamTripModel(
      empId: (json['empId'] as num?)?.toInt() ?? 0,
      dsId: (json['dsId'] as num?)?.toInt() ?? 0,
      fullName: json['fullName']?.toString() ?? '',
      tripType: (json['tripType'] as num?)?.toInt() ?? 0,
      tripTypeName: json['tripTypeName']?.toString() ?? '',
      tripStatusCode: (json['tripStatusCode'] as num?)?.toInt() ?? 0,
      tripStatusName: json['tripStatusName']?.toString() ?? '',
      dsDate: _parseDate(json['dsDate']),
      scheduledStartTime: _parseDate(json['scheduledStartTime']),
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
