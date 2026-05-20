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
import '../../features/trip_detail/data/repository/roaster_shift_repo.dart';
import '../../features/trip_detail/data/repository/schedule_home_repo.dart';
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
