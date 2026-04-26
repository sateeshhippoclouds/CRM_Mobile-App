import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import '../../../../app/app.locator.dart';
import '../../../../models/subscription_model.dart';
import '../../../../models/tenant_model.dart';
import '../../../../services/api_services.dart';

class TenantsViewModel extends BaseViewModel {
  final _auth = locator<HippoAuthService>();

  List<TenantModel> _all = [];
  List<TenantModel> filtered = [];
  String? fetchError;
  String activeTab = 'active';
  String _query = '';
  int? togglingId;

  int get activeCount => _all.where((t) => t.isActive).length;
  int get inactiveCount => _all.where((t) => !t.isActive).length;

  Future<void> init() async {
    setBusy(true);
    fetchError = null;
    try {
      _all = await _auth.getTenants();
      _applyFilter();
    } catch (e) {
      fetchError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      setBusy(false);
    }
  }

  void _applyFilter() {
    var list = _all
        .where((t) => activeTab == 'active' ? t.isActive : !t.isActive)
        .toList();
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where((t) =>
              (t.tenantName ?? '').toLowerCase().contains(q) ||
              (t.email ?? '').toLowerCase().contains(q) ||
              (t.contactPerson ?? '').toLowerCase().contains(q) ||
              (t.subscriptionName ?? '').toLowerCase().contains(q))
          .toList();
    }
    filtered = list;
  }

  void setTab(String tab) {
    activeTab = tab;
    _applyFilter();
    notifyListeners();
  }

  void onSearch(String query) {
    _query = query;
    _applyFilter();
    notifyListeners();
  }

  Future<void> addTenant(Map<String, dynamic> data) async {
    await _auth.createTenant(data);
    await init();
  }

  Future<void> editTenant(int id, Map<String, dynamic> data) async {
    await _auth.updateTenant(id, data);
    await init();
  }

  Future<void> toggleStatus(TenantModel t) async {
    if (t.id == null) return;
    togglingId = t.id;
    notifyListeners();
    try {
      final newStatus = t.isActive ? 'inactive' : 'active';
      final idx = _all.indexWhere((x) => x.id == t.id);
      if (idx != -1) {
        _all[idx] = TenantModel(
          id: t.id,
          tenantName: t.tenantName,
          contactPerson: t.contactPerson,
          contactNumber: t.contactNumber,
          email: t.email,
          duration: t.duration,
          maxUsers: t.maxUsers,
          subscriptionId: t.subscriptionId,
          subscriptionName: t.subscriptionName,
          price: t.price,
          tax: t.tax,
          totalAmount: t.totalAmount,
          startDate: t.startDate,
          endDate: t.endDate,
          status: newStatus,
          companyId: t.companyId,
        );
        _applyFilter();
        notifyListeners();
      }
      await _auth.updateTenant(t.id!, {
        'tenant_name': t.tenantName,
        'contact_person': t.contactPerson,
        'contact_number': t.contactNumber,
        'email': t.email,
        'duration': t.duration,
        'max_users': t.maxUsers,
        'subscription_id': t.subscriptionId,
        'price': t.price,
        'tax': t.tax,
        'total_amount': t.totalAmount,
        'start_date': t.startDate,
        'end_date': t.endDate,
        'status': newStatus,
      });
    } catch (_) {
      await init();
    } finally {
      togglingId = null;
      notifyListeners();
    }
  }
}

class TenantDialogViewModel extends BaseViewModel {
  TenantDialogViewModel({this.existing});
  final TenantModel? existing;

  final _auth = locator<HippoAuthService>();

  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameCtrl;
  late final TextEditingController contactPersonCtrl;
  late final TextEditingController contactNumberCtrl;
  late final TextEditingController emailCtrl;
  late final TextEditingController passwordCtrl;
  late final TextEditingController maxUsersCtrl;
  late final TextEditingController priceCtrl;
  late final TextEditingController taxCtrl;
  late final TextEditingController totalCtrl;

  int? selectedSubscriptionId;
  String? selectedDuration;
  String status = 'active';
  DateTime startDate = DateTime.now();
  DateTime? endDate;
  bool _endDateManuallyEdited = false;

  List<SubscriptionModel> subscriptions = [];
  bool subscriptionsLoading = true;

  bool get isEdit => existing != null;

  Future<void> init() async {
    nameCtrl = TextEditingController(text: existing?.tenantName ?? '');
    contactPersonCtrl =
        TextEditingController(text: existing?.contactPerson ?? '');
    contactNumberCtrl =
        TextEditingController(text: existing?.contactNumber ?? '');
    emailCtrl = TextEditingController(text: existing?.email ?? '');
    passwordCtrl = TextEditingController();
    maxUsersCtrl =
        TextEditingController(text: existing?.maxUsers?.toString() ?? '');
    priceCtrl =
        TextEditingController(text: existing?.price?.toStringAsFixed(2) ?? '');
    taxCtrl =
        TextEditingController(text: existing?.tax?.toStringAsFixed(2) ?? '');
    totalCtrl = TextEditingController(
        text: existing?.totalAmount?.toStringAsFixed(2) ?? '');

    selectedSubscriptionId = existing?.subscriptionId;
    selectedDuration = existing?.duration;
    status = existing?.status ?? 'active';

    if (existing?.startDate != null) {
      try {
        startDate = DateTime.parse(existing!.startDate!);
      } catch (_) {}
    }
    if (existing?.endDate != null) {
      try {
        endDate = DateTime.parse(existing!.endDate!);
        _endDateManuallyEdited = true;
      } catch (_) {}
    }

    priceCtrl.addListener(_calcTotal);
    taxCtrl.addListener(_calcTotal);

    try {
      subscriptions = await _auth.getSubscriptions();
    } catch (_) {}
    subscriptionsLoading = false;
    notifyListeners();
  }

  void _calcTotal() {
    final price = double.tryParse(priceCtrl.text) ?? 0;
    final tax = double.tryParse(taxCtrl.text) ?? 0;
    final result = (price + (price * tax / 100)).toStringAsFixed(2);
    if (totalCtrl.text != result) totalCtrl.text = result;
  }

  DateTime? _computeEndDate() {
    if (selectedDuration == null || selectedDuration == 'Lifetime') return null;
    final d = startDate;
    switch (selectedDuration) {
      case 'Monthly':
        return DateTime(d.year, d.month + 1, d.day);
      case 'Quarterly':
        return DateTime(d.year, d.month + 3, d.day);
      case 'Half-Yearly':
        return DateTime(d.year, d.month + 6, d.day);
      case 'Annually':
        return DateTime(d.year + 1, d.month, d.day);
      default:
        return null;
    }
  }

  void selectSubscription(int? id) {
    selectedSubscriptionId = id;
    if (id != null) {
      final sub = subscriptions.firstWhere((s) => s.id == id,
          orElse: () => SubscriptionModel());
      priceCtrl.text = sub.price?.toStringAsFixed(2) ?? '';
      taxCtrl.text = sub.tax?.toStringAsFixed(2) ?? '';
      _calcTotal();
    }
    notifyListeners();
  }

  void setDuration(String? v) {
    selectedDuration = v;
    if (!_endDateManuallyEdited) endDate = _computeEndDate();
    notifyListeners();
  }

  void setStartDate(DateTime d) {
    startDate = d;
    if (!_endDateManuallyEdited) endDate = _computeEndDate();
    notifyListeners();
  }

  void setEndDate(DateTime d) {
    endDate = d;
    _endDateManuallyEdited = true;
    notifyListeners();
  }

  void setStatus(String? v) {
    status = v ?? 'active';
    notifyListeners();
  }

  Future<bool> submit(TenantsViewModel parentModel) async {
    if (!formKey.currentState!.validate()) return false;
    setBusy(true);
    try {
      final data = <String, dynamic>{
        'tenant_name': nameCtrl.text.trim(),
        'contact_person': contactPersonCtrl.text.trim(),
        'contact_number': contactNumberCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'max_users': maxUsersCtrl.text.isNotEmpty
            ? int.tryParse(maxUsersCtrl.text)
            : null,
        'subscription_id': selectedSubscriptionId,
        'duration': selectedDuration,
        'price': double.tryParse(priceCtrl.text) ?? 0,
        'tax': double.tryParse(taxCtrl.text) ?? 0,
        'total_amount': double.tryParse(totalCtrl.text) ?? 0,
        'start_date': _fmtIso(startDate),
        'end_date': endDate != null ? _fmtIso(endDate!) : null,
        'status': status,
      };
      if (passwordCtrl.text.isNotEmpty) {
        data['password'] = passwordCtrl.text;
      }
      if (isEdit) {
        await parentModel.editTenant(existing!.id!, data);
      } else {
        await parentModel.addTenant(data);
      }
      return true;
    } catch (e) {
      setError(e);
      return false;
    } finally {
      setBusy(false);
    }
  }

  String _fmtIso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    nameCtrl.dispose();
    contactPersonCtrl.dispose();
    contactNumberCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    maxUsersCtrl.dispose();
    priceCtrl.dispose();
    taxCtrl.dispose();
    totalCtrl.dispose();
    super.dispose();
  }
}

class PaymentHistoryViewModel extends BaseViewModel {
  PaymentHistoryViewModel({required this.tenantId});
  final int tenantId;

  final _auth = locator<HippoAuthService>();
  List<Map<String, dynamic>> payments = [];
  String? fetchError;

  Future<void> init() async {
    setBusy(true);
    fetchError = null;
    try {
      payments = await _auth.getTenantPayments(tenantId);
    } catch (e) {
      fetchError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      setBusy(false);
    }
  }
}
