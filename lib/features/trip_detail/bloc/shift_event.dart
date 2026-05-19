import 'package:equatable/equatable.dart';

abstract class ShiftEvent extends Equatable {
  const ShiftEvent();

  @override
  List<Object?> get props => [];
}

class FetchShifts extends ShiftEvent {
  final int locCode;
  final int empId;

  const FetchShifts({required this.locCode, required this.empId});

  @override
  List<Object?> get props => [locCode, empId];
}

class UpdateShiftSchedules extends ShiftEvent {
  final int locCode;
  final String fromDate;
  final String toDate;
  final String shiftStart;
  final String shiftEnd;
  final String weekOffs;
  final String userEmpIds;

  const UpdateShiftSchedules({
    required this.locCode,
    required this.fromDate,
    required this.toDate,
    required this.shiftStart,
    required this.shiftEnd,
    required this.weekOffs,
    required this.userEmpIds,
  });

  @override
  List<Object?> get props => [
        locCode,
        fromDate,
        toDate,
        shiftStart,
        shiftEnd,
        weekOffs,
        userEmpIds,
      ];
}
