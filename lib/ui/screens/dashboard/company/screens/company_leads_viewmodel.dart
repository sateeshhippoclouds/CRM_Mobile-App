import 'package:stacked/stacked.dart';

import '../../../../../app/app.locator.dart';
import '../../../../../services/api_services.dart';

class CompanyLeadsViewModel extends BaseViewModel {
  final _api = locator<HippoAuthService>();

  List<Map<String, dynamic>> _allLeads = [];
  List<Map<String, dynamic>> _allFollowups = [];
  String _leadsQuery = '';
  String _followupsQuery = '';
  String? fetchError;
  bool _loaded = false;

  List<Map<String, dynamic>> get leads => _leadsQuery.isEmpty
      ? _allLeads
      : _allLeads.where((l) {
          final q = _leadsQuery;
          return (l['lead_name'] ?? '').toString().toLowerCase().contains(q) ||
              (l['contact_person'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(q) ||
              (l['email'] ?? '').toString().toLowerCase().contains(q) ||
              (l['city'] ?? '').toString().toLowerCase().contains(q);
        }).toList();

  List<Map<String, dynamic>> get followups => _followupsQuery.isEmpty
      ? _allFollowups
      : _allFollowups.where((f) {
          final q = _followupsQuery;
          return (f['lead_name'] ?? '').toString().toLowerCase().contains(q) ||
              (f['assigned_to'] ?? '').toString().toLowerCase().contains(q) ||
              (f['status'] ?? '').toString().toLowerCase().contains(q);
        }).toList();

  void searchLeads(String q) {
    _leadsQuery = q.toLowerCase().trim();
    notifyListeners();
  }

  void searchFollowups(String q) {
    _followupsQuery = q.toLowerCase().trim();
    notifyListeners();
  }

  Future<void> init() async {
    if (!_loaded) setBusy(true);
    fetchError = null;
    try {
      final results = await Future.wait([
        _api.getLeads(),
        _api.getFollowups(),
      ]);
      _allLeads = results[0];
      _allFollowups = results[1];
      _loaded = true;
    } catch (e) {
      if (!_loaded) fetchError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      setBusy(false);
    }
  }
}
