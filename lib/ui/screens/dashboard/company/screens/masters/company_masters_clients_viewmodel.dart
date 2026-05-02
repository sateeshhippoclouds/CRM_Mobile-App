import 'package:stacked/stacked.dart';

import '../../../../../../app/app.locator.dart';
import '../../../../../../models/permissions_model.dart';
import '../../../../../../models/token_response_model.dart';
import '../../../../../../services/api_services.dart';

class CompanyMastersClientsViewModel extends BaseViewModel {
  final _api = locator<HippoAuthService>();

  List<Map<String, dynamic>> preferredPayments = [];
  List<Map<String, dynamic>> paymentTerms = [];
  String? fetchError;
  bool _loaded = false;

  TokenResponseModel? _user;
  PermissionsModel? _permissions;
  bool get _isEmployee => _user?.userType == 'employee';
  PermissionsModel get _perms => _isEmployee
      ? (_permissions ?? PermissionsModel.companyDefault)
      : PermissionsModel.companyDefault;
  bool get canWrite => _perms.masters.canWrite;
  bool get canUpdate => _perms.masters.canUpdate;
  bool get canDelete => _perms.masters.canDelete;

  Future<void> _fetch() async {
    final data = await _api.getClientMasters();
    preferredPayments = _toList(data['preferredPayment']);
    paymentTerms = _toList(data['paymentTerms']);
  }

  Future<void> init() async {
    if (!_loaded) setBusy(true);
    fetchError = null;
    try {
      _user ??= await _api.getStoredUser();
      if (_isEmployee) _permissions ??= await _api.getStoredPermissions();
      await _fetch();
      _loaded = true;
    } catch (e) {
      if (!_loaded) fetchError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      setBusy(false);
    }
  }

  List<Map<String, dynamic>> _toList(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> addItem(int tab, String value) async {
    await _api.addClientMaster(tab, value);
    await init();
  }

  Future<void> editItem(int id, int tab, String value) async {
    await _api.updateClientMaster(id, tab, value);
    await init();
  }

  Future<void> deleteItem(int id, int tab) async {
    await _api.deleteClientMaster(id, tab);
    await init();
  }
}
