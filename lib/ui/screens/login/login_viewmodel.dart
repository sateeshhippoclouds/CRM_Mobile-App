import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import '../../../app/app.locator.dart';
import '../../../app/app.router.dart';
import '../../../app/utils.dart';
import '../../../services/api_services.dart';

class LoginViewModel extends BaseViewModel {
  final _hippoAuthService = locator<HippoAuthService>();

  final formKey = GlobalKey<FormState>();

  bool _isPasswordVisible = false;
  bool get isPasswordVisible => _isPasswordVisible;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  void togglePasswordVisibility() {
    _isPasswordVisible = !_isPasswordVisible;
    notifyListeners();
  }

  void resetForm() {
    _isPasswordVisible = false;
    _errorMessage = '';
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    setBusy(true);
    _errorMessage = '';
    notifyListeners();

    try {
      final user = await _hippoAuthService.login(email.trim(), password.trim());
      final route = user.platformOwner
          ? Routes.ceoDashboardView
          : Routes.companyDashboardView;
      navigationService.clearStackAndShow(route);
    } catch (_) {
      _errorMessage = 'Invalid email or password. Please try again.';
      notifyListeners();
    } finally {
      setBusy(false);
    }
  }

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }
}
