import 'package:equatable/equatable.dart';

abstract class AppControlEvent extends Equatable {
  const AppControlEvent();

  @override
  List<Object?> get props => [];
}

class FetchAppControlSettings extends AppControlEvent {
  final int locCode;

  const FetchAppControlSettings(this.locCode);

  @override
  List<Object?> get props => [locCode];
}
