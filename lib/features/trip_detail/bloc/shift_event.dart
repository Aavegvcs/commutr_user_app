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

/// Schedules a hybrid roster for arbitrary (non-contiguous) dates via
/// `POST /TransRoster/UpdateScheduleHybrid`.
///
/// [selectedDates] is a comma-joined `yyyy-MM-dd` list, e.g.
/// `"2026-06-20,2026-06-21,2026-06-24"`.
class UpdateHybridSchedules extends ShiftEvent {
  final int locCode;
  final String selectedDates;
  final String shiftStart;
  final String shiftEnd;
  final String weekOffs;
  final String userEmpIds;

  const UpdateHybridSchedules({
    required this.locCode,
    required this.selectedDates,
    required this.shiftStart,
    required this.shiftEnd,
    required this.weekOffs,
    required this.userEmpIds,
  });

  @override
  List<Object?> get props => [
        locCode,
        selectedDates,
        shiftStart,
        shiftEnd,
        weekOffs,
        userEmpIds,
      ];
}

/// Cancels a scheduled trip via `POST /TransRoster/CancelSchedules`.
///
/// [tripType] must be `"1"` for a Login (pickup) trip or `"2"` for a Logout
/// (drop) trip per the API contract.
class CancelSchedule extends ShiftEvent {
  final int locCode;
  final String empId;
  final String scheduleDate;
  final String tripType;

  const CancelSchedule({
    required this.locCode,
    required this.empId,
    required this.scheduleDate,
    required this.tripType,
  });

  @override
  List<Object?> get props => [locCode, empId, scheduleDate, tripType];
}
