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
    on<FetchAdhocList>(_onFetchList);
    on<CancelAdhocRequest>(_onCancel);
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
      debugPrint(
        '[ADHOC_BLOC] SubmitAdhocRequest response → '
        'errorCode=${response.errorCode} isSuccess=${response.isSuccess} '
        'message="${response.displayMessage}"',
      );
      if (response.errorCode == 0) {
        emit(AdhocSubmitSuccess(response.displayMessage));
      } else {
        emit(AdhocSubmitError(response.displayMessage));
      }
    } catch (e) {
      debugPrint('[ADHOC_BLOC] SubmitAdhocRequest ✖ $e');
      if (_isUnauthorized(e)) {
        emit(const AdhocUnauthorized());
      } else {
        emit(AdhocSubmitError(_friendlyMessage(e)));
      }
    }
  }

  Future<void> _onCancel(CancelAdhocRequest event, Emitter<AdhocState> emit) async {
    emit(AdhocCancelling(event.reqId));
    try {
      await _repository.cancelAdhocRequest(reqId: event.reqId, empId: event.empId);
      emit(const AdhocCancelSuccess());
    } catch (e) {
      debugPrint('[ADHOC_BLOC] CancelAdhocRequest ✖ $e');
      if (_isUnauthorized(e)) {
        emit(const AdhocUnauthorized());
      } else {
        emit(AdhocCancelError(_friendlyMessage(e)));
      }
    }
  }

  Future<void> _onFetchList(FetchAdhocList event, Emitter<AdhocState> emit) async {
    emit(const AdhocListLoading());
    try {
      final response = await _repository.fetchAdhocList(empId: event.empId);
      emit(AdhocListLoaded(response.items));
    } catch (e) {
      debugPrint('[ADHOC_BLOC] FetchAdhocList ✖ $e');
      if (_isUnauthorized(e)) {
        emit(const AdhocUnauthorized());
      } else {
        emit(AdhocListError(_friendlyMessage(e)));
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
