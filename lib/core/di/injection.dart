import 'package:get_it/get_it.dart';
import 'package:commutr_main/core/network/api_client.dart';
import 'package:commutr_main/auth/data/repository/auth_repository.dart';
import 'package:commutr_main/auth/bloc/auth_bloc.dart';

final sl = GetIt.instance;

void setupDependencies() {
  sl.registerLazySingleton<ApiClient>(
    () => ApiClient(baseUrl: 'http://13.235.144.192:5000/api/v1'),
  );

  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepository(apiClient: sl()),
  );

  sl.registerFactory<AuthBloc>(() => AuthBloc(authRepository: sl()));
}
