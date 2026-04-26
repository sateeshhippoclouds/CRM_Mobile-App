import 'package:stacked/stacked.dart';

import '../../../../app/app.locator.dart';
import '../../../../app/app.router.dart';
import '../../../../app/utils.dart';
import '../../../../models/token_response_model.dart';
import '../../../../services/api_services.dart';

class CeoDashboardViewModel extends BaseViewModel {
  final _auth = locator<HippoAuthService>();

  TokenResponseModel? _user;
  String get userName => _user?.name ?? 'CEO';
  String get userInitial =>
      userName.isNotEmpty ? userName[0].toUpperCase() : 'C';

  int totalTenants = 0;
  int activeTenants = 0;
  int inactiveTenants = 0;
  String totalCollected = '₹0';
  int expiringSoon = 0;

  List<Map<String, dynamic>> activeSubscriptions = [];
  List<Map<String, dynamic>> recentTenants = [];
  List<Map<String, dynamic>> recentPayments = [];
  List<Map<String, dynamic>> revenueTrend = [];
  List<Map<String, dynamic>> expiringTenants = [];

  String? fetchError;

  Future<void> init() async {
    setBusy(true);
    fetchError = null;
    _user = await _auth.getStoredUser();
    try {
      final data = await _auth.getCeoDashboard();

      final stats =
          data['tenantStats'] as Map<String, dynamic>? ?? {};
      totalTenants =
          int.tryParse(stats['total_tenants']?.toString() ?? '') ?? 0;
      activeTenants =
          int.tryParse(stats['active_tenants']?.toString() ?? '') ?? 0;
      inactiveTenants =
          int.tryParse(stats['inactive_tenants']?.toString() ?? '') ?? 0;

      final pt = data['paymentTotals'] as Map<String, dynamic>? ?? {};
      final collected =
          double.tryParse(pt['total_collected']?.toString() ?? '') ?? 0.0;
      totalCollected = _fmtAmt(collected);

      final expList = (data['expiringTenants'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      expiringTenants = expList;
      expiringSoon = expList.length;

      activeSubscriptions = (data['activeSubscriptions'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      recentTenants = (data['recentTenants'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      recentPayments = (data['recentPayments'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      revenueTrend = (data['revenueTrend'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      fetchError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      setBusy(false);
    }
  }

  String _fmtAmt(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }

  Future<void> logout() async {
    await _auth.logout();
    navigationService.clearStackAndShow(Routes.loginView);
  }

  void goToSubscriptions() =>
      navigationService.navigateTo(Routes.ceoSubscriptionsView);

  void goToTenants() => navigationService.navigateTo(Routes.ceoTenantsView);

  void goToPayments() =>
      navigationService.navigateTo(Routes.ceoTenantPaymentsView);
}
