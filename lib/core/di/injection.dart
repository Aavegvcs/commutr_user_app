import 'package:commutr_main/features/adhoc/bloc/adhoc_bloc.dart';
import 'package:commutr_main/features/notification/bloc/notification_bloc.dart';
import 'package:commutr_main/features/share_cab/data/repository/share_cab_repo.dart';
import 'package:commutr_main/features/share_cab/data/repository/call_driver_ivr_repo.dart';
import 'package:commutr_main/features/notification/data/repository/notification_repository.dart';
import 'package:commutr_main/features/trip_chat/bloc/chat_bloc.dart';
import 'package:commutr_main/features/trip_chat/data/repository/chat_repository.dart';
import 'package:commutr_main/features/trip_chat/service/chat_signalr_service.dart';
import 'package:commutr_main/features/adhoc/data/repository/adhoc_repo.dart';
import 'package:commutr_main/profile/bloc/profile_bloc.dart';
import 'package:commutr_main/profile/data/repository/profile_repository.dart';
import 'package:commutr_main/features/version_check/data/repository/version_check_repository.dart';
import 'package:commutr_main/features/sos/bloc/sos_bloc.dart';
import 'package:commutr_main/features/sos/data/repository/sos_repo.dart';
import 'package:commutr_main/features/trip_detail/data/repository/user_feedback_repo.dart';
import 'package:commutr_main/features/complaint/bloc/complaint_bloc.dart';
import 'package:commutr_main/features/complaint/data/repository/complaint_repo.dart';
import 'package:commutr_main/features/trip_detail/bloc/board_trip/board_trip_bloc.dart';
import 'package:commutr_main/features/trip_detail/bloc/cancel_trip/cancel_trip_bloc.dart';
import 'package:commutr_main/features/trip_detail/bloc/trip_history_bloc.dart';
import 'package:commutr_main/features/trip_detail/data/repository/cab_tracking/user_cab_tracking_repo.dart';
import 'package:commutr_main/features/trip_detail/data/repository/trip_history_repo.dart';
import 'package:commutr_main/features/trip_detail/data/repository/trip_start/board_trip_repo.dart';
import 'package:commutr_main/features/trip_detail/data/repository/trip_start/cancel_trip_home_repo.dart';
import 'package:commutr_main/ride_tracking/bloc/cab_tracking_bloc.dart';
import 'package:commutr_main/ride_tracking/service/ivr_call_repo.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:commutr_main/core/network/api_client.dart';
import 'package:commutr_main/core/network/api_constants.dart';
import 'package:commutr_main/core/storage/auth_local_storage.dart';

import '../../app.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/data/repository/auth_repository.dart';
import '../../features/auth/presentation/screens/mobile_no_verification.dart';
import '../../features/trip_detail/bloc/roaster_bloc.dart';
import '../../features/trip_detail/bloc/schedule_home_bloc.dart';
import '../../features/trip_detail/bloc/shift_bloc.dart';
import '../../features/trip_detail/bloc/trip_home_bloc.dart';
import '../../features/trip_detail/data/repository/roaster_shift_repo.dart';
import '../../features/trip_detail/data/repository/schedule_home_repo.dart';
import '../../features/trip_detail/data/repository/trip_home_repo.dart';
import '../../features/trip_detail/data/repository/user_detail_detail_repo.dart';
import '../../weekly_off/bloc/weekly_off_bloc.dart';
import '../../weekly_off/data/repository/weekly_off_repository.dart';

final sl = GetIt.instance;

/// [ApiClient] for `/Auth/*` (port 5000).
const String authApiClientKey = 'authApiClient';

/// [ApiClient] for app APIs — weekly off, etc. (port 5001); refresh still uses 5000.
const String appApiClientKey = 'appApiClient';

void setupDependencies() {
  sl.registerLazySingleton<AuthLocalStorage>(() => AuthLocalStorage());

  void onLogout() {
    clearBearerTokenFromApiClients();
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const MobileNoVerification(),
      ),
      (route) => false,
    );
  }

  sl.registerLazySingleton<ApiClient>(
    () => ApiClient(
      baseUrl: ApiConstants.authBaseUrl,
      authStorage: sl(),
      onLogout: onLogout,
    ),
    instanceName: authApiClientKey,
  );

  sl.registerLazySingleton<ApiClient>(
    () => ApiClient(
      baseUrl: ApiConstants.appBaseUrl,
      authApiBaseUrl: ApiConstants.authBaseUrl,
      authStorage: sl(),
      onLogout: onLogout,
    ),
    instanceName: appApiClientKey,
  );

  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepository(apiClient: sl(instanceName: authApiClientKey)),
  );

  sl.registerFactory<AuthBloc>(
    () => AuthBloc(authRepository: sl(), authStorage: sl()),
  );

  sl.registerLazySingleton<WeeklyOffRepository>(
    () => WeeklyOffRepository(
      apiClient: sl(instanceName: appApiClientKey),
    ),
  );

  sl.registerFactory<WeeklyOffBloc>(
    () => WeeklyOffBloc(repository: sl()),
  );

  sl.registerLazySingleton<RosterRepository>(
    () => RosterRepository(sl(instanceName: appApiClientKey)),
  );

  sl.registerFactory<RosterBloc>(
    () => RosterBloc(sl()),
  );

  sl.registerLazySingleton<RoasterShiftRepo>(
    () => RoasterShiftRepo(sl(instanceName: appApiClientKey)),
  );

  sl.registerFactory<ShiftBloc>(
    () => ShiftBloc(sl()),
  );

  sl.registerLazySingleton<ScheduleHomeRepo>(
    () => ScheduleHomeRepo(sl(instanceName: appApiClientKey)),
  );

  sl.registerFactory<ScheduleHomeBloc>(
    () => ScheduleHomeBloc(sl()),
  );

  sl.registerLazySingleton<TripHomeRepo>(
    () => TripHomeRepo(sl(instanceName: appApiClientKey)),
  );

  sl.registerFactory<TripHomeBloc>(
    () => TripHomeBloc(sl()),
  );

  sl.registerLazySingleton<TripCancelRepository>(()=> TripCancelRepository(sl(instanceName: appApiClientKey)));

  sl.registerFactory<TripCancelBloc>(() => TripCancelBloc(sl()));

  sl.registerLazySingleton<BoardTripRepository>(
    () => BoardTripRepository(sl(instanceName: appApiClientKey)),
  );

  sl.registerFactory<BoardTripBloc>(() => BoardTripBloc(sl()));

  sl.registerLazySingleton<UserCabTrackingRepo>(
    () => UserCabTrackingRepo(sl(instanceName: appApiClientKey)),
  );

  sl.registerFactory<CabTrackingBloc>(() => CabTrackingBloc(sl()));

  sl.registerLazySingleton<TripHistoryRepo>(
    () => TripHistoryRepo(sl(instanceName: appApiClientKey)),
  );

  sl.registerFactory<TripHistoryBloc>(() => TripHistoryBloc(sl()));

  sl.registerLazySingleton<ComplaintRepository>(
    () => ComplaintRepository(sl(instanceName: appApiClientKey)),
  );

  sl.registerFactory<ComplaintBloc>(() => ComplaintBloc(sl()));

  sl.registerLazySingleton<AdhocRepository>(
    () => AdhocRepository(sl(instanceName: appApiClientKey)),
  );

  sl.registerFactory<AdhocBloc>(() => AdhocBloc(sl()));

  sl.registerLazySingleton<SosRepository>(
    () => SosRepository(sl(instanceName: appApiClientKey)),
  );

  sl.registerFactory<SosBloc>(() => SosBloc(sl()));

  sl.registerLazySingleton<UserFeedbackRepo>(
    () => UserFeedbackRepo(sl(instanceName: appApiClientKey)),
  );

  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepository(
      apiClient: sl(instanceName: appApiClientKey),
      authStorage: sl(),
    ),
  );

  sl.registerFactory<ProfileBloc>(
    () => ProfileBloc(sl()),
  );

  sl.registerLazySingleton<ChatRepository>(
    () => ChatRepository(sl(instanceName: appApiClientKey)),
  );

  sl.registerFactory<ChatSignalRService>(() => ChatSignalRService());

  sl.registerFactory<ChatBloc>(
    () => ChatBloc(
      repository: sl(),
      signalRService: sl(),
    ),
  );

  sl.registerLazySingleton<NotificationRepository>(
    () => NotificationRepository(sl(instanceName: appApiClientKey)),
  );

  sl.registerFactory<NotificationBloc>(() => NotificationBloc(sl()));

  sl.registerLazySingleton<ShareCabRepository>(
    () => ShareCabRepository(sl(instanceName: appApiClientKey)),
  );

  sl.registerLazySingleton<CallDriverIvrRepository>(
    () => CallDriverIvrRepository(sl(instanceName: appApiClientKey)),
  );

  sl.registerLazySingleton<IvrCallRepo>(
    () => IvrCallRepo(sl(instanceName: authApiClientKey)),
  );

  sl.registerLazySingleton<VersionCheckRepository>(
    () => VersionCheckRepository(apiClient: sl(instanceName: authApiClientKey)),
  );

  syncBearerTokenToApiClients();
}

/// Sets `Authorization: Bearer <token>` on all registered [ApiClient] instances.
void syncBearerTokenToApiClients() {
  final token = sl<AuthLocalStorage>().getAccessToken();
  final authClient = sl<ApiClient>(instanceName: authApiClientKey);
  final appClient = sl<ApiClient>(instanceName: appApiClientKey);

  if (token != null && token.isNotEmpty) {
    authClient.setAuthToken(token);
    appClient.setAuthToken(token);
  } else {
    authClient.clearAuthToken();
    appClient.clearAuthToken();
  }
}

void clearBearerTokenFromApiClients() {
  sl<ApiClient>(instanceName: authApiClientKey).clearAuthToken();
  sl<ApiClient>(instanceName: appApiClientKey).clearAuthToken();
}
