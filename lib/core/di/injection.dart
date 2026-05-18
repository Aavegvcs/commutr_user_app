import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:commutr_main/core/network/api_client.dart';
import 'package:commutr_main/core/network/api_constants.dart';
import 'package:commutr_main/core/storage/auth_local_storage.dart';

import '../../app.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/data/repository/auth_repository.dart';
import '../../features/auth/presentation/screens/mobile_no_verification.dart';
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
}
