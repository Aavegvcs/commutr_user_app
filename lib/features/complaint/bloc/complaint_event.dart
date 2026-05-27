import 'package:equatable/equatable.dart';

abstract class ComplaintEvent extends Equatable {
  const ComplaintEvent();

  @override
  List<Object?> get props => [];
}

class FetchComplaints extends ComplaintEvent {
  final int empId;

  const FetchComplaints({required this.empId});

  @override
  List<Object?> get props => [empId];
}

class FetchComplaintLookup extends ComplaintEvent {
  const FetchComplaintLookup();
}

class FetchComplaintDetail extends ComplaintEvent {
  final int empId;
  final int complaintId;

  const FetchComplaintDetail({required this.empId, required this.complaintId});

  @override
  List<Object?> get props => [empId, complaintId];
}

class FetchComplaintList extends ComplaintEvent {
  final int empId;
  final String fromDate;
  final String toDate;

  const FetchComplaintList({
    required this.empId,
    required this.fromDate,
    required this.toDate,
  });

  @override
  List<Object?> get props => [empId, fromDate, toDate];
}

class SubmitComplaint extends ComplaintEvent {
  final int empId;
  final int tripType;
  final String tripDate;
  final int complaintType;
  final String complaintDetail;

  const SubmitComplaint({
    required this.empId,
    required this.tripType,
    required this.tripDate,
    required this.complaintType,
    required this.complaintDetail,
  });

  @override
  List<Object?> get props =>
      [empId, tripType, tripDate, complaintType, complaintDetail];
}
