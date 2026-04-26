import 'package:eduvy/application.dart';
import 'package:eduvy/services/analyticsservice.dart';
import 'package:eduvy/services/connectivity_service.dart';
import 'package:eduvy/services/deeplink_service.dart';
import 'package:eduvy/services/location_service.dart';
import 'package:eduvy/services/user_service.dart';

import 'package:stacked/stacked_annotations.dart';
import 'package:stacked_services/stacked_services.dart';

import '../services/api_services.dart';
import '../ui/screens/login/login_view.dart';
import '../ui/screens/splash/splash_view.dart';

@StackedApp(
  routes: [
    MaterialRoute(page: Application, initial: true),
    MaterialRoute(page: SplashView),
    MaterialRoute(page: LoginView),
  ],
  dependencies: [
    LazySingleton(classType: HippoAuthService),
    LazySingleton(classType: NavigationService),
    LazySingleton(classType: DialogService),
    LazySingleton(classType: BottomSheetService),
    LazySingleton(classType: UserService),
    LazySingleton(classType: DeepLinkService),
    LazySingleton(classType: AnalyticsObserver),
    LazySingleton(classType: LocationService),
    LazySingleton(classType: ConnectivityService),
  ],
)
class AppSetup {}
