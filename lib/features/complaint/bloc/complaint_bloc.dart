import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/exceptions.dart';
import '../data/repository/complaint_repo.dart';
import 'complaint_event.dart';
import 'complaint_state.dart';

class ComplaintBloc extends Bloc<ComplaintEvent, ComplaintState> {
  final ComplaintRepository _repository;

  ComplaintBloc(this._repository) : super(const ComplaintInitial()) {
    on<FetchComplaints>(_onFetch);
    on<SubmitComplaint>(_onSubmit);
    on<FetchComplaintLookup>(_onFetchLookup);
    on<FetchComplaintList>(_onFetchComplaintList);
    on<FetchComplaintDetail>(_onFetchComplaintDetail);
  }

  Future<void> _onFetch(
    FetchComplaints event,
    Emitter<ComplaintState> emit,
  ) async {
    debugPrint('[COMPLAINT_BLOC] FetchComplaints → empId=${event.empId}');
    emit(const ComplaintLoading());
    try {
      final items = await _repository.getComplaints(empId: event.empId);
      debugPrint('[COMPLAINT_BLOC] FetchComplaints ✓ items=${items.length}');
      emit(ComplaintLoaded(items));
    } catch (e) {
      debugPrint('[COMPLAINT_BLOC] FetchComplaints ✖ $e');
      if (_isUnauthorized(e)) {
        emit(const ComplaintUnauthorized());
      } else {
        emit(ComplaintError(_friendlyMessage(e)));
      }
    }
  }

  Future<void> _onSubmit(
    SubmitComplaint event,
    Emitter<ComplaintState> emit,
  ) async {
    debugPrint('[COMPLAINT_BLOC] SubmitComplaint → empId=${event.empId}');
    emit(const ComplaintSubmitting());
    try {
      await _repository.raiseComplaint(
        empId: event.empId,
        tripType: event.tripType,
        tripDate: event.tripDate,
        complaintType: event.complaintType,
        complaintDetail: event.complaintDetail,
      );
      debugPrint('[COMPLAINT_BLOC] SubmitComplaint ✓');
      emit(const ComplaintSubmitSuccess());
    } catch (e) {
      debugPrint('[COMPLAINT_BLOC] SubmitComplaint ✖ $e');
      if (_isUnauthorized(e)) {
        emit(const ComplaintUnauthorized());
      } else {
        emit(ComplaintSubmitError(_friendlyMessage(e)));
      }
    }
  }

  Future<void> _onFetchLookup(
    FetchComplaintLookup event,
    Emitter<ComplaintState> emit,
  ) async {
    debugPrint('[COMPLAINT_BLOC] FetchComplaintLookup');
    emit(const ComplaintLookupLoading());
    try {
      final items = await _repository.getComplaintLookup();
      debugPrint('[COMPLAINT_BLOC] FetchComplaintLookup ✓ items=${items.length}');
      emit(ComplaintLookupLoaded(items));
    } catch (e) {
      debugPrint('[COMPLAINT_BLOC] FetchComplaintLookup ✖ $e');
      if (_isUnauthorized(e)) {
        emit(const ComplaintUnauthorized());
      } else {
        emit(ComplaintLookupError(_friendlyMessage(e)));
      }
    }
  }

  Future<void> _onFetchComplaintDetail(
    FetchComplaintDetail event,
    Emitter<ComplaintState> emit,
  ) async {
    debugPrint('[COMPLAINT_BLOC] FetchComplaintDetail → complaintId=${event.complaintId}');
    emit(const ComplaintDetailLoading());
    try {
      final detail = await _repository.getComplaintDetail(
        empId: event.empId,
        complaintId: event.complaintId,
      );
      if (detail == null) {
        emit(const ComplaintDetailError('No detail found.'));
      } else {
        debugPrint('[COMPLAINT_BLOC] FetchComplaintDetail ✓');
        emit(ComplaintDetailLoaded(detail));
      }
    } catch (e) {
      debugPrint('[COMPLAINT_BLOC] FetchComplaintDetail ✖ $e');
      if (_isUnauthorized(e)) {
        emit(const ComplaintUnauthorized());
      } else {
        emit(ComplaintDetailError(_friendlyMessage(e)));
      }
    }
  }

  Future<void> _onFetchComplaintList(
    FetchComplaintList event,
    Emitter<ComplaintState> emit,
  ) async {
    debugPrint('[COMPLAINT_BLOC] FetchComplaintList → empId=${event.empId}');
    emit(const ComplaintListLoading());
    try {
      final items = await _repository.getComplaintList(
        empId: event.empId,
        fromDate: event.fromDate,
        toDate: event.toDate,
      );
      debugPrint('[COMPLAINT_BLOC] FetchComplaintList ✓ items=${items.length}');
      emit(ComplaintListLoaded(items));
    } catch (e) {
      debugPrint('[COMPLAINT_BLOC] FetchComplaintList ✖ $e');
      if (_isUnauthorized(e)) {
        emit(const ComplaintUnauthorized());
      } else {
        emit(ComplaintListError(_friendlyMessage(e)));
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
