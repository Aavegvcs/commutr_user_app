import 'package:equatable/equatable.dart';

abstract class BoardTripEvent extends Equatable {
  const BoardTripEvent();

  @override
  List<Object?> get props => [];
}

class BoardTripRequested extends BoardTripEvent {
  final int empId;
  final int tripId;
  final int tripType;
  final String boardingType;

  const BoardTripRequested({
    required this.empId,
    required this.tripId,
    required this.tripType,
    this.boardingType = 'B',
  });

  @override
  List<Object?> get props => [empId, tripId, tripType, boardingType];
}
