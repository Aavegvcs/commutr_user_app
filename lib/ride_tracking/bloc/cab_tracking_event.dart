import 'package:equatable/equatable.dart';

abstract class CabTrackingEvent extends Equatable {
  const CabTrackingEvent();

  @override
  List<Object?> get props => [];
}

class FetchCabTracking extends CabTrackingEvent {
  final int empId;
  final int tripId;

  const FetchCabTracking({
    required this.empId,
    required this.tripId,
  });

  @override
  List<Object?> get props => [empId, tripId];
}
