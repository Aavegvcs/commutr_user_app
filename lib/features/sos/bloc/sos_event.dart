import 'package:equatable/equatable.dart';

abstract class SosEvent extends Equatable {
  const SosEvent();

  @override
  List<Object?> get props => [];
}

class TriggerSos extends SosEvent {
  final int empId;

  const TriggerSos({required this.empId});

  @override
  List<Object?> get props => [empId];
}
