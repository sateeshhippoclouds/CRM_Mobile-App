import 'package:stacked/stacked.dart';

import '../../../../app/app.locator.dart';
import '../../../../app/app.router.dart';
import '../../../../app/utils.dart';
import '../../../../models/token_response_model.dart';
import '../../../../services/api_services.dart';

class CompanyDashboardViewModel extends BaseViewModel {
  final _auth = locator<HippoAuthService>();

  TokenResponseModel? _user;
  String get userName => _user?.name ?? 'Company';
  String get userInitial =>
      userName.isNotEmpty ? userName[0].toUpperCase() : 'C';
  String get userEmail => _user?.email ?? '';
  String get role => _user?.role ?? 'CEO';

  int totalLeads = 0;
  int totalClients = 0;
  int totalInvoices = 0;
  String revenue = '₹0';
  String collected = '₹0';
  String outstanding = '₹0';
  int totalTasks = 0;
  int followUps = 0;
  String? fetchError;

  Future<void> init() async {
    setBusy(true);
    fetchError = null;
    _user = await _auth.getStoredUser();
    setBusy(false);
  }

  Future<void> logout() async {
    await _auth.logout();
    navigationService.clearStackAndShow(Routes.loginView);
  }
}
