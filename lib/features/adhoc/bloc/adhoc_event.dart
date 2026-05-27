import 'package:equatable/equatable.dart';

abstract class AdhocEvent extends Equatable {
  const AdhocEvent();

  @override
  List<Object?> get props => [];
}

class SubmitAdhocRequest extends AdhocEvent {
  final int locCode;
  final String tripDate;
  final int tripType;
  final int shiftId;
  final int reqBy;
  final String reqFor;
  final String remarks;

  const SubmitAdhocRequest({
    required this.locCode,
    required this.tripDate,
    required this.tripType,
    required this.shiftId,
    required this.reqBy,
    required this.reqFor,
    required this.remarks,
  });

  @override
  List<Object?> get props => [locCode, tripDate, tripType, shiftId, reqBy, reqFor, remarks];
}
