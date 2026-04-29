import 'package:stacked/stacked.dart';

import '../../../../../app/app.locator.dart';
import '../../../../../models/permissions_model.dart';
import '../../../../../models/token_response_model.dart';
import '../../../../../services/api_services.dart';

class CompanyRoleManagementViewModel extends BaseViewModel {
  final _auth = locator<HippoAuthService>();

  List<Map<String, dynamic>> roles = [];
  String? fetchError;

  TokenResponseModel? _user;
  PermissionsModel? _permissions;

  bool get _isEmployee => _user?.userType == 'employee';

  PermissionsModel get _perms =>
      _isEmployee ? (_permissions ?? PermissionsModel.companyDefault) : PermissionsModel.companyDefault;

  bool get canWrite => _perms.roleManagement.canWrite;
  bool get canUpdate => _perms.roleManagement.canUpdate;
  bool get canDelete => _perms.roleManagement.canDelete;

  Future<void> init() async {
    setBusy(true);
    fetchError = null;
    _user = await _auth.getStoredUser();
    if (_isEmployee) _permissions = await _auth.getStoredPermissions();
    try {
      roles = await _auth.getRoles();
    } catch (e) {
      fetchError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      setBusy(false);
    }
  }

  Future<void> addRole(Map<String, dynamic> data) async {
    await _auth.createRole(data);
    await init();
  }

  Future<void> editRole(Map<String, dynamic> data) async {
    await _auth.updateRole(data);
    await init();
  }

  Future<void> removeRole(int roleId) async {
    await _auth.deleteRole(roleId);
    await init();
  }
}
