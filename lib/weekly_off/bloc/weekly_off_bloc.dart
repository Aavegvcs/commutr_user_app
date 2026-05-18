import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/repository/weekly_off_repository.dart';
import 'weekly_off_event.dart';
import 'weekly_off_state.dart';

class WeeklyOffBloc extends Bloc<WeeklyOffEvent, WeeklyOffState> {
  final WeeklyOffRepository repository;

  WeeklyOffBloc({required this.repository}) : super(WeeklyOffInitial()) {
    on<LoadWeeklyOffEvent>(_loadWeeklyOff);
    on<UpdateWeeklyOffEvent>(_updateWeeklyOff);
  }

  Future<void> _loadWeeklyOff(
    LoadWeeklyOffEvent event,
    Emitter<WeeklyOffState> emit,
  ) async {
    try {
      emit(WeeklyOffLoading());
      final response = await repository.showWeeklyOff();
      emit(WeeklyOffLoaded(response));
    } catch (e) {
      emit(WeeklyOffFailure(e.toString()));
    }
  }

  Future<void> _updateWeeklyOff(
    UpdateWeeklyOffEvent event,
    Emitter<WeeklyOffState> emit,
  ) async {
    try {
      emit(WeeklyOffLoading());

      final response = await repository.updateWeeklyOff(
        weekOff: event.weekOff,
      );

      emit(WeeklyOffSaved(response));
    } catch (e) {
      emit(WeeklyOffFailure(e.toString()));
    }
  }
}
