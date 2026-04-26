import 'package:stacked/stacked.dart';

import '../../../../../app/app.locator.dart';
import '../../../../../services/api_services.dart';

class CompanyRoleManagementViewModel extends BaseViewModel {
  final _auth = locator<HippoAuthService>();

  List<Map<String, dynamic>> roles = [];
  String? fetchError;

  Future<void> init() async {
    setBusy(true);
    fetchError = null;
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
