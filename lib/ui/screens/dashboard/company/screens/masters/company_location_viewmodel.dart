import 'package:stacked/stacked.dart';

import '../../../../../../app/app.locator.dart';
import '../../../../../../models/permissions_model.dart';
import '../../../../../../models/token_response_model.dart';
import '../../../../../../services/api_services.dart';

class CompanyLocationViewModel extends BaseViewModel {
  final _api = locator<HippoAuthService>();

  List<Map<String, dynamic>> countries = [];
  List<Map<String, dynamic>> states = [];
  List<Map<String, dynamic>> cities = [];
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
    final results = await Future.wait([
      _api.getCountries(),
      _api.getStates(),
      _api.getCities(),
    ]);
    countries = results[0];
    states = results[1];
    cities = results[2];
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

  Future<void> addCountry(String name) async {
    await _api.addCountry(name);
    await init();
  }

  Future<void> updateCountry(int id, String name) async {
    await _api.updateCountry(id, name);
    await init();
  }

  Future<void> deleteCountry(int id) async {
    await _api.deleteCountry(id);
    await init();
  }

  Future<void> addState(String name, int countryId) async {
    await _api.addState(name, countryId);
    await init();
  }

  Future<void> updateState(int id, String name, int countryId) async {
    await _api.updateState(id, name, countryId);
    await init();
  }

  Future<void> deleteState(int id) async {
    await _api.deleteState(id);
    await init();
  }

  Future<void> addCity(String name, int stateId, int countryId) async {
    await _api.addCity(name, stateId, countryId);
    await init();
  }

  Future<void> updateCity(
      int id, String name, int stateId, int countryId) async {
    await _api.updateCity(id, name, stateId, countryId);
    await init();
  }

  Future<void> deleteCity(int id) async {
    await _api.deleteCity(id);
    await init();
  }
}
