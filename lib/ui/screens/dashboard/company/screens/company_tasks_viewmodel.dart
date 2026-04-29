import 'package:stacked/stacked.dart';

import '../../../../../app/app.locator.dart';
import '../../../../../models/permissions_model.dart';
import '../../../../../models/token_response_model.dart';
import '../../../../../services/api_services.dart';

class CompanyTasksViewModel extends BaseViewModel {
  final _api = locator<HippoAuthService>();

  TokenResponseModel? _user;
  PermissionsModel? _permissions;

  bool get _isEmployee => _user?.userType == 'employee';
  PermissionsModel get _perms => _isEmployee
      ? (_permissions ?? PermissionsModel.companyDefault)
      : PermissionsModel.companyDefault;

  bool get canWrite => _perms.task.canWrite;
  bool get canUpdate => _perms.task.canUpdate;
  bool get canDelete => _perms.task.canDelete;

  List<Map<String, dynamic>> _all = [];
  String _query = '';
  String? fetchError;
  bool _loaded = false;

  List<Map<String, dynamic>> get items => _query.isEmpty
      ? _all
      : _all.where((t) {
          final q = _query;
          return (t['title'] ?? '').toString().toLowerCase().contains(q) ||
              (t['related_to'] ?? '').toString().toLowerCase().contains(q) ||
              (t['assigned_to'] ?? '').toString().toLowerCase().contains(q) ||
              (t['task_type'] ?? '').toString().toLowerCase().contains(q);
        }).toList();

  void search(String q) {
    _query = q.toLowerCase().trim();
    notifyListeners();
  }

  Future<void> init() async {
    if (!_loaded) setBusy(true);
    fetchError = null;
    _user ??= await _api.getStoredUser();
    if (_isEmployee) _permissions ??= await _api.getStoredPermissions();
    try {
      _all = await _api.getTasks();
      _loaded = true;
    } catch (e) {
      if (!_loaded) fetchError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      setBusy(false);
    }
  }
}
