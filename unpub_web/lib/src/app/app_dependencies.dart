import '../core/auth/auth_session.dart';
import '../core/network/api_client.dart';
import '../core/theme/theme_cubit.dart';
import '../features/admin/data/admin_repository.dart';
import '../features/packages/data/packages_repository.dart';

class AppDependencies {
  AppDependencies({String? apiBaseUrl}) {
    apiClient = ApiClient(baseUrl: apiBaseUrl);
    authSession = AuthSession(apiClient);
    themeCubit = ThemeCubit();
    packagesRepository = PackagesRepository(apiClient);
    adminRepository = AdminRepository(apiClient);
  }

  late final ApiClient apiClient;
  late final AuthSession authSession;
  late final ThemeCubit themeCubit;
  late final PackagesRepository packagesRepository;
  late final AdminRepository adminRepository;
}
