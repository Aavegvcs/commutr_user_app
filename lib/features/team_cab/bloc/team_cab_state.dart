import 'package:equatable/equatable.dart';

import '../data/model/team_tracking_panel_response.dart';

abstract class TeamCabState extends Equatable {
  const TeamCabState();

  @override
  List<Object?> get props => [];
}

class TeamCabInitial extends TeamCabState {
  const TeamCabInitial();
}

class TeamCabLoading extends TeamCabState {
  const TeamCabLoading();
}

class TeamCabLoaded extends TeamCabState {
  final TeamTrackingPanelResponse data;

  const TeamCabLoaded(this.data);

  @override
  List<Object?> get props => [data];
}

class TeamCabError extends TeamCabState {
  /// Short headline (e.g. "Something went wrong").
  final String title;

  /// Friendly explanation shown under the title.
  final String message;

  const TeamCabError({required this.title, required this.message});

  @override
  List<Object?> get props => [title, message];
}
