import 'package:stacked/stacked.dart';

import '../../../../../app/app.locator.dart';
import '../../../../../models/permissions_model.dart';
import '../../../../../models/token_response_model.dart';
import '../../../../../services/api_services.dart';

class CompanySalesBillingViewModel extends BaseViewModel {
  final _api = locator<HippoAuthService>();

  TokenResponseModel? _user;
  PermissionsModel? _permissions;

  bool get _isEmployee => _user?.userType == 'employee';
  PermissionsModel get _perms => _isEmployee
      ? (_permissions ?? PermissionsModel.companyDefault)
      : PermissionsModel.companyDefault;

  bool get canWrite => _perms.bills.canWrite;
  bool get canUpdate => _perms.bills.canUpdate;
  bool get canDelete => _perms.bills.canDelete;

  List<Map<String, dynamic>> _drafts = [];
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _history = [];
  String _draftsQuery = '';
  String _salesQuery = '';
  String _historyQuery = '';
  String? fetchError;
  bool _loaded = false;

  List<Map<String, dynamic>> get drafts => _filtered(_drafts, _draftsQuery);
  List<Map<String, dynamic>> get sales => _filtered(_sales, _salesQuery);
  List<Map<String, dynamic>> get history => _filtered(_history, _historyQuery);

  List<Map<String, dynamic>> _filtered(
      List<Map<String, dynamic>> list, String q) {
    if (q.isEmpty) return list;
    return list.where((s) {
      return (s['client'] ?? '').toString().toLowerCase().contains(q) ||
          (s['term'] ?? '').toString().toLowerCase().contains(q) ||
          (s['status'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
  }

  void searchDrafts(String q) {
    _draftsQuery = q.toLowerCase().trim();
    notifyListeners();
  }

  void searchSales(String q) {
    _salesQuery = q.toLowerCase().trim();
    notifyListeners();
  }

  void searchHistory(String q) {
    _historyQuery = q.toLowerCase().trim();
    notifyListeners();
  }

  Future<void> init() async {
    if (!_loaded) setBusy(true);
    fetchError = null;
    _user ??= await _api.getStoredUser();
    if (_isEmployee) _permissions ??= await _api.getStoredPermissions();
    try {
      final data = await _api.getSalesBilling();
      _drafts = _toList(data['drafts']);
      _sales = _toList(data['sales']);
      _history = _toList(data['history']);
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
}
