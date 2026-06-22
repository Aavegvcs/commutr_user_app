import 'package:equatable/equatable.dart';

abstract class TeamCabEvent extends Equatable {
  const TeamCabEvent();

  @override
  List<Object?> get props => [];
}

class FetchTeamCab extends TeamCabEvent {
  final int empId;
  final DateTime date;

  const FetchTeamCab({required this.empId, required this.date});

  @override
  List<Object?> get props => [empId, date];
}
