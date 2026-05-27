import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/exceptions.dart';
import '../data/repository/adhoc_repo.dart';
import 'adhoc_event.dart';
import 'adhoc_state.dart';

class AdhocBloc extends Bloc<AdhocEvent, AdhocState> {
  final AdhocRepository _repository;

  AdhocBloc(this._repository) : super(const AdhocInitial()) {
    on<SubmitAdhocRequest>(_onSubmit);
  }

  @override
  void onTransition(Transition<AdhocEvent, AdhocState> transition) {
    super.onTransition(transition);
    debugPrint(
      '[ADHOC_BLOC] transition: '
      '${transition.currentState.runtimeType} '
      '--(${transition.event.runtimeType})--> '
      '${transition.nextState.runtimeType}',
    );
  }

  Future<void> _onSubmit(SubmitAdhocRequest event, Emitter<AdhocState> emit) async {
    debugPrint(
      '[ADHOC_BLOC] SubmitAdhocRequest → '
      'locCode=${event.locCode} tripDate=${event.tripDate} '
      'tripType=${event.tripType} shiftId=${event.shiftId} '
      'reqBy=${event.reqBy} reqFor="${event.reqFor}"',
    );
    emit(const AdhocSubmitting());
    try {
      final response = await _repository.submitAdhocRequest(
        locCode: event.locCode,
        tripDate: event.tripDate,
        tripType: event.tripType,
        shiftId: event.shiftId,
        reqBy: event.reqBy,
        reqFor: event.reqFor,
        remarks: event.remarks,
      );
      debugPrint('[ADHOC_BLOC] SubmitAdhocRequest ✓ message="${response.message}"');
      emit(AdhocSubmitSuccess(
        response.message.isNotEmpty ? response.message : 'Adhoc request submitted successfully',
      ));
    } catch (e) {
      debugPrint('[ADHOC_BLOC] SubmitAdhocRequest ✖ $e');
      if (_isUnauthorized(e)) {
        emit(const AdhocUnauthorized());
      } else {
        emit(AdhocSubmitError(_friendlyMessage(e)));
      }
    }
  }

  bool _isUnauthorized(Object error) {
    if (error is UnauthorizedException) return true;
    if (error is DioException) {
      if (error.error is UnauthorizedException) return true;
      if (error.response?.statusCode == 401) return true;
    }
    return false;
  }

  String _friendlyMessage(Object error) {
    if (error is DioException && error.error is Exception) {
      return error.error.toString().replaceFirst('Exception: ', '');
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}
