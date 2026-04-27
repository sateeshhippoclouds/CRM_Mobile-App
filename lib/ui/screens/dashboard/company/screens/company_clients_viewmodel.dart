import 'package:stacked/stacked.dart';

import '../../../../../app/app.locator.dart';
import '../../../../../services/api_services.dart';

class CompanyClientsViewModel extends BaseViewModel {
  final _api = locator<HippoAuthService>();

  List<Map<String, dynamic>> _all = [];
  String _query = '';
  String? fetchError;
  bool _loaded = false;

  List<Map<String, dynamic>> get items => _query.isEmpty
      ? _all
      : _all.where((c) {
          final q = _query;
          return (c['company_name'] ?? '').toString().toLowerCase().contains(q) ||
              (c['client_name'] ?? '').toString().toLowerCase().contains(q) ||
              (c['contact_person'] ?? '').toString().toLowerCase().contains(q) ||
              (c['email'] ?? '').toString().toLowerCase().contains(q) ||
              (c['city'] ?? '').toString().toLowerCase().contains(q);
        }).toList();

  void search(String q) {
    _query = q.toLowerCase().trim();
    notifyListeners();
  }

  Future<void> init() async {
    if (!_loaded) setBusy(true);
    fetchError = null;
    try {
      _all = await _api.getClients();
      _loaded = true;
    } catch (e) {
      if (!_loaded) fetchError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      setBusy(false);
    }
  }
}
