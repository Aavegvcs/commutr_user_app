import 'package:commutr_main/features/notification/data/model/notification_model.dart';
import 'package:commutr_main/features/notification/data/repository/notification_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/exceptions.dart';

part 'notification_event.dart';
part 'notification_state.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final NotificationRepository _repository;

  NotificationBloc(this._repository) : super(const NotificationInitial()) {
    on<FetchNotifications>(_onFetch);
  }

  @override
  void onTransition(Transition<NotificationEvent, NotificationState> transition) {
    super.onTransition(transition);
    debugPrint(
      '[NOTIF_BLOC] transition: '
      '${transition.currentState.runtimeType} '
      '--(${transition.event.runtimeType})--> '
      '${transition.nextState.runtimeType}',
    );
  }

  Future<void> _onFetch(FetchNotifications event, Emitter<NotificationState> emit) async {
    emit(const NotificationLoading());
    try {
      final response = await _repository.fetchNotifications(userId: event.contactNumber);
      emit(NotificationLoaded(response.items));
    } catch (e) {
      debugPrint('[NOTIF_BLOC] FetchNotifications ✖ $e');
      if (_isUnauthorized(e)) {
        emit(const NotificationError('Session expired. Please log in again.'));
      } else {
        emit(NotificationError(_friendlyMessage(e)));
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
