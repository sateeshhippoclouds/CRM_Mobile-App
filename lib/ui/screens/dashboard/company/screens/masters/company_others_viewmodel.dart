import 'package:stacked/stacked.dart';

import '../../../../../../app/app.locator.dart';
import '../../../../../../services/api_services.dart';

class CompanyOthersViewModel extends BaseViewModel {
  final _api = locator<HippoAuthService>();

  List<Map<String, dynamic>> priorities = [];
  List<Map<String, dynamic>> serviceCategories = [];
  String? fetchError;
  bool _loaded = false;

  Future<void> _fetch() async {
    final data = await _api.getOthersMasters();
    priorities = _toList(data['priority']);
    serviceCategories = _toList(data['serviceCategory']);
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
    await _api.addOthersMaster(tab, value);
    await init();
  }

  Future<void> editItem(int id, int tab, String value) async {
    await _api.updateOthersMaster(id, tab, value);
    await init();
  }

  Future<void> deleteItem(int id, int tab) async {
    await _api.deleteOthersMaster(id, tab);
    await init();
  }
}
