import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:stacked/stacked.dart';

import '../../../../../app/app.locator.dart';
import '../../../../../models/token_response_model.dart';
import '../../../../../services/api_services.dart';

class CompanySettingsViewModel extends BaseViewModel {
  final _api = locator<HippoAuthService>();

  TokenResponseModel? _user;

  Map<String, dynamic> _bank = {};
  Map<String, dynamic> get bank => _bank;

  Map<String, dynamic> _header = {};
  String? get logoUrl => _header['logo']?.toString();
  String? get digisignUrl => _header['digisign']?.toString();
  String? get letterheadUrl => _header['letterhead']?.toString();

  String? fetchError;
  bool _bankSaving = false;
  bool get bankSaving => _bankSaving;

  String? _uploadingField;
  bool isUploading(String field) => _uploadingField == field;

  Future<void> init() async {
    setBusy(true);
    fetchError = null;
    _user = await _api.getStoredUser();
    await Future.wait([_loadBank(), _loadHeader()]);
    setBusy(false);
  }

  Future<void> _loadBank() async {
    try {
      final rows = await _api.getCompanySettings('bank');
      _bank = rows.isNotEmpty ? rows.first : {};
    } catch (e) {
      debugPrint('loadBank error: $e');
    }
  }

  Future<void> _loadHeader() async {
    try {
      final rows = await _api.getCompanySettings('header');
      _header = rows.isNotEmpty ? rows.first : {};
      // Always keep the cached logo URL in sync with the latest from API
      await _api.cacheCompanyLogoUrl(logoUrl);
    } catch (e) {
      debugPrint('loadHeader error: $e');
    }
  }

  Future<String?> saveBankDetails(Map<String, dynamic> data) async {
    _bankSaving = true;
    notifyListeners();
    try {
      await _api.saveCompanyBank({
        ...data,
        'companyid': _user?.companyId?.toString() ?? '',
      });
      await _loadBank();
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    } finally {
      _bankSaving = false;
      notifyListeners();
    }
  }

  Future<String?> uploadFile(String field, File file) async {
    _uploadingField = field;
    notifyListeners();
    try {
      final companyId = _user?.companyId?.toString() ?? '';
      await _api.uploadCompanySettingsFile(field, file, companyId);
      await _loadHeader();
      if (field == 'logo') {
        await _api.cacheCompanyLogoUrl(logoUrl);
      }
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    } finally {
      _uploadingField = null;
      notifyListeners();
    }
  }
}
