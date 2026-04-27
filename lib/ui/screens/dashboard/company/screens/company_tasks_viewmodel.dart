import 'package:stacked/stacked.dart';

import '../../../../../app/app.locator.dart';
import '../../../../../services/api_services.dart';

class CompanyTasksViewModel extends BaseViewModel {
  final _api = locator<HippoAuthService>();

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
