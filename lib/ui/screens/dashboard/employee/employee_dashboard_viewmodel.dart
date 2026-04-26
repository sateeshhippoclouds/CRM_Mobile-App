import 'package:stacked/stacked.dart';

import '../../../../app/app.locator.dart';
import '../../../../app/app.router.dart';
import '../../../../app/utils.dart';
import '../../../../models/token_response_model.dart';
import '../../../../services/api_services.dart';

class EmployeeDashboardViewModel extends BaseViewModel {
  final _hippoAuthService = locator<HippoAuthService>();

  TokenResponseModel? _user;
  String get userName => _user?.name ?? 'Employee';
  String get userEmail => _user?.email ?? '';
  String get role => _user?.role ?? 'Employee';

  Future<void> init() async {
    setBusy(true);
    _user = await _hippoAuthService.getStoredUser();
    setBusy(false);
  }

  Future<void> logout() async {
    await _hippoAuthService.logout();
    navigationService.clearStackAndShow(Routes.loginView);
  }
}
