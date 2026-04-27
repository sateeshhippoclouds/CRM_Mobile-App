import 'package:stacked/stacked.dart';

import '../../../../../../app/app.locator.dart';
import '../../../../../../services/api_services.dart';

class CompanyTermsViewModel extends BaseViewModel {
  final _api = locator<HippoAuthService>();

  List<Map<String, dynamic>> followupQuotations = [];
  List<Map<String, dynamic>> clientQuotations = [];
  String? fetchError;
  bool _loaded = false;

  Future<void> _fetch() async {
    final data = await _api.getQuoteMasters();
    followupQuotations = _toList(data['followupQuotations']);
    clientQuotations = _toList(data['clientQuotations']);
  }

  Future<void> init() async {
    if (!_loaded) setBusy(true);
    fetchError = null;
    try {
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

  Future<void> addItem(int tab, String title, List<String> notes) async {
    await _api.addQuoteMaster(tab, title, notes);
    await init();
  }

  Future<void> editItem(
      int id, int tab, String title, List<String> notes) async {
    await _api.updateQuoteMaster(id, tab, title, notes);
    await init();
  }

  Future<void> deleteItem(int id, int tab) async {
    await _api.deleteQuoteMaster(id, tab);
    await init();
  }
}
