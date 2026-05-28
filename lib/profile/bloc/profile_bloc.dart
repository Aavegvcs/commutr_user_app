import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/exceptions.dart';
import '../data/repository/profile_repository.dart';
import 'profile_event.dart';
import 'profile_state.dart';

String? _apiErrorMessageFromBody(dynamic data) {
  if (data is Map) {
    final message = (data['message'] ?? data['title'])?.toString();
    if (message != null && message.isNotEmpty) return message;

    final errors = data['errors'];
    if (errors is Map) {
      final parts = <String>[];
      for (final entry in errors.entries) {
        final v = entry.value;
        if (v is List && v.isNotEmpty) {
          parts.add('${entry.key}: ${v.first}');
        } else if (v != null) {
          parts.add('${entry.key}: $v');
        }
      }
      if (parts.isNotEmpty) return parts.join('\n');
    }
  }
  return data?.toString();
}

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final ProfileRepository _repository;

  ProfileBloc(this._repository) : super(const ProfileInitial()) {
    on<FetchUserProfile>(_onFetch);
    on<SubmitAddressChange>(_onSubmitAddressChange);
  }

  @override
  void onTransition(Transition<ProfileEvent, ProfileState> transition) {
    super.onTransition(transition);
    debugPrint(
      '[PROFILE_BLOC] ${transition.currentState.runtimeType} '
      '--(${transition.event.runtimeType})--> '
      '${transition.nextState.runtimeType}',
    );
  }

  Future<void> _onSubmitAddressChange(
    SubmitAddressChange event,
    Emitter<ProfileState> emit,
  ) async {
    final current = state;
    if (current is! ProfileLoaded) {
      emit(const ProfileError('Profile not loaded. Please try again.'));
      return;
    }

    final profile = current.profile;

    debugPrint('[PROFILE_BLOC] SubmitAddressChange →');

    try {
      await _repository.submitAddressChange(
        profile: profile,
        address: event.address,
        city: event.city,
        state: event.state,
        pin: event.pin,
        empLat: event.empLat,
        empLng: event.empLng,
      );
      debugPrint('[PROFILE_BLOC] SubmitAddressChange ✓');
      emit(
        const ProfileAddressChangeSuccess(
          message: 'Address change submitted for approval.',
        ),
      );
      emit(ProfileLoaded(profile));
    } on ConflictException catch (e) {
      debugPrint('[PROFILE_BLOC] SubmitAddressChange ⚠ duplicate: ${e.message}');
      emit(const ProfileAddressChangeFailed('Address change request already sent'));
      emit(ProfileLoaded(profile));
    } catch (e) {
      debugPrint('[PROFILE_BLOC] SubmitAddressChange ✖ $e');
      if (_isUnauthorized(e)) {
        emit(const ProfileUnauthorized());
        return;
      }
      emit(ProfileAddressChangeFailed(_friendlyMessage(e)));
      emit(ProfileLoaded(profile));
    }
  }

  Future<void> _onFetch(
    FetchUserProfile event,
    Emitter<ProfileState> emit,
  ) async {
    debugPrint('[PROFILE_BLOC] FetchUserProfile →');
    emit(const ProfileLoading());
    try {
      final profile = await _repository.getUserProfile();
      debugPrint('[PROFILE_BLOC] FetchUserProfile ✓ name=${profile.fullName}');
      emit(ProfileLoaded(profile));
    } catch (e) {
      debugPrint('[PROFILE_BLOC] FetchUserProfile ✖ $e');
      if (_isUnauthorized(e)) {
        emit(const ProfileUnauthorized());
      } else {
        emit(ProfileError(_friendlyMessage(e)));
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
    if (error is BadRequestException) {
      return error.message;
    }
    if (error is UnauthorizedException) {
      return error.message;
    }
    if (error is NotFoundException) {
      return error.message;
    }
    if (error is ConflictException) {
      return error.message;
    }
    if (error is ServerException) {
      return error.title;
    }
    if (error is DioException) {
      final status = error.response?.statusCode;
      final body = error.response?.data;
      debugPrint(
        '[PROFILE_BLOC] API error status=$status body=${ProfileRepository.formatLogJson(body)}',
      );

      if (error.error is ConflictException || status == 409) {
        return 'Address change request already sent';
      }
      if (error.error is BadRequestException) {
        return (error.error as BadRequestException).message;
      }
      if (error.error is Exception) {
        return error.error
            .toString()
            .replaceFirst('Exception: ', '');
      }

      final fromBody = _apiErrorMessageFromBody(body);
      if (fromBody != null && fromBody.isNotEmpty) {
        return fromBody;
      }
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}
