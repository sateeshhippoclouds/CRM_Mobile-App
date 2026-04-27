import 'package:stacked/stacked.dart';

import '../../../../../../app/app.locator.dart';
import '../../../../../../services/api_services.dart';

class CompanyMastersLeadsViewModel extends BaseViewModel {
  final _api = locator<HippoAuthService>();

  List<Map<String, dynamic>> sourceTypes = [];
  List<Map<String, dynamic>> interestLevels = [];
  List<Map<String, dynamic>> leadStages = [];
  List<Map<String, dynamic>> categories = [];
  String? fetchError;
  bool _loaded = false;

  Future<void> _fetch() async {
    final data = await _api.getLeadMasters();
    sourceTypes = _toList(data['sourceType']);
    interestLevels = _toList(data['interestLevels']);
    leadStages = _toList(data['leadStages']);
    categories = _toList(data['categories']);
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

  Future<void> addItem(int tab, String value) async {
    await _api.addLeadMaster(tab, value);
    await init();
  }

  Future<void> editItem(int id, int tab, String value) async {
    await _api.updateLeadMaster(id, tab, value);
    await init();
  }

  Future<void> deleteItem(int id, int tab) async {
    await _api.deleteLeadMaster(id, tab);
    await init();
  }
}
