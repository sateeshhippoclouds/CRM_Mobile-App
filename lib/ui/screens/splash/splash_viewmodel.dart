import 'package:stacked/stacked.dart';

import '../../../app/app.locator.dart';
import '../../../app/app.router.dart';
import '../../../app/utils.dart';
import '../../../services/api_services.dart';

class SplashViewModel extends BaseViewModel {
  final _hippoAuthService = locator<HippoAuthService>();

  void init() async {
    await Future.delayed(const Duration(seconds: 2));
    try {
      final user = await _hippoAuthService.getStoredUser();
      if (user != null) {
        // Refresh permissions in background so the app always has latest role data.
        if (!user.platformOwner) {
          await _hippoAuthService.fetchAndStorePermissions();
        }
        final route = user.platformOwner
            ? Routes.ceoDashboardView
            : Routes.companyDashboardView;
        navigationService.clearStackAndShow(route);
      } else {
        navigationService.clearStackAndShow(Routes.loginView);
      }
    } catch (_) {
      navigationService.clearStackAndShow(Routes.loginView);
    }
  }
}
