import 'package:equatable/equatable.dart';

abstract class RosterEvent extends Equatable {
  const RosterEvent();

  @override
  List<Object?> get props => [];
}

class FetchRosterUserDetails extends RosterEvent {
  const FetchRosterUserDetails();
}
