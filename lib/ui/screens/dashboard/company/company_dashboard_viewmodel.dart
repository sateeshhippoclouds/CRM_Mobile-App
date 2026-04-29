import 'package:stacked/stacked.dart';

import '../../../../app/app.locator.dart';
import '../../../../app/app.router.dart';
import '../../../../app/utils.dart';
import '../../../../models/permissions_model.dart';
import '../../../../models/token_response_model.dart';
import '../../../../services/api_services.dart';

class CompanyDashboardViewModel extends BaseViewModel {
  final _auth = locator<HippoAuthService>();

  TokenResponseModel? _user;
  PermissionsModel? _permissions;

  String get userName => _user?.name ?? '';
  String get userInitial =>
      userName.isNotEmpty ? userName[0].toUpperCase() : 'U';
  String get userEmail => _user?.email ?? '';
  String get role => _user?.role ?? '';
  bool get isEmployee => _user?.userType == 'employee';

  int totalLeads = 0;
  int totalClients = 0;
  int totalInvoices = 0;
  String revenue = '₹0';
  String collected = '₹0';
  String outstanding = '₹0';
  int totalTasks = 0;
  int followUps = 0;
  String? fetchError;

  // ── Permission helpers ────────────────────────────────────────────────────
  // Company users always get full access; employee users use stored permissions.
  PermissionsModel get _perms =>
      isEmployee ? (_permissions ?? PermissionsModel.companyDefault) : PermissionsModel.companyDefault;

  bool get canViewLeads => _perms.leads.canRead;
  bool get canViewClients => _perms.clients.canRead;
  bool get canViewEmployees => _perms.employees.canRead;
  bool get canViewTasks => _perms.task.canRead;
  bool get canViewBilling => _perms.bills.canRead;
  bool get canViewProducts => _perms.services.canRead;
  bool get canViewRoleManagement => _perms.roleManagement.canRead;
  bool get canViewMasters => _perms.masters.canRead;
  bool get canViewFollowup => _perms.followup.canRead;

  Future<void> init() async {
    setBusy(true);
    fetchError = null;
    _user = await _auth.getStoredUser();
    if (isEmployee) {
      _permissions = await _auth.getStoredPermissions();
    }
    setBusy(false);
  }

  Future<void> logout() async {
    await _auth.logout();
    navigationService.clearStackAndShow(Routes.loginView);
  }
}
