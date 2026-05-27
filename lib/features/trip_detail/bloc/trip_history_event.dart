import 'package:equatable/equatable.dart';

abstract class TripHistoryEvent extends Equatable {
  const TripHistoryEvent();

  @override
  List<Object?> get props => [];
}

class FetchTripHistory extends TripHistoryEvent {
  final int empId;
  final String fromDate;
  final String toDate;
  final String searchBy;

  const FetchTripHistory({
    required this.empId,
    required this.fromDate,
    required this.toDate,
    this.searchBy = 'All',
  });

  @override
  List<Object?> get props => [empId, fromDate, toDate, searchBy];
}
