import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import '../../../../app/app.locator.dart';
import '../../../../models/tenant_model.dart';
import '../../../../services/api_services.dart';

class TenantPaymentSummary {
  TenantPaymentSummary({
    required this.tenant,
    required this.paid,
    required this.balance,
    required this.status,
  });

  final TenantModel tenant;
  final double paid;
  final double balance;

  final String status;
}

class TenantPaymentsViewModel extends BaseViewModel {
  final _auth = locator<HippoAuthService>();

  List<TenantPaymentSummary> _all = [];
  List<TenantPaymentSummary> filtered = [];
  String? fetchError;
  String _query = '';

  Future<void> init() async {
    setBusy(true);
    fetchError = null;
    try {
      final results = await Future.wait([
        _auth.getTenants(),
        _auth.getAllTenantPayments(),
      ]);

      final tenants = results[0] as List<TenantModel>;
      final allPayments = results[1] as List<Map<String, dynamic>>;

      final paidByTenant = <int, double>{};
      for (final p in allPayments) {
        final tid = int.tryParse(p['tenant_id']?.toString() ?? '') ?? 0;
        final amount = double.tryParse(p['amount']?.toString() ?? '') ?? 0.0;
        paidByTenant[tid] = (paidByTenant[tid] ?? 0.0) + amount;
      }

      _all = tenants.map((t) {
        final paid = paidByTenant[t.id] ?? 0.0;
        final total = t.totalAmount ?? 0.0;
        final rawBalance = total - paid;
        final balance = rawBalance < 0 ? 0.0 : rawBalance;

        String status;
        if (paid == 0) {
          status = 'Unpaid';
        } else if (balance == 0) {
          status = 'Paid';
        } else {
          status = 'Partial';
        }

        return TenantPaymentSummary(
          tenant: t,
          paid: paid,
          balance: balance,
          status: status,
        );
      }).toList();

      _applyFilter();
    } catch (e) {
      fetchError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      setBusy(false);
    }
  }

  void _applyFilter() {
    if (_query.isEmpty) {
      filtered = List.from(_all);
      return;
    }
    final q = _query.toLowerCase();
    filtered = _all.where((s) {
      final t = s.tenant;
      return (t.tenantName ?? '').toLowerCase().contains(q) ||
          (t.email ?? '').toLowerCase().contains(q) ||
          (t.subscriptionName ?? '').toLowerCase().contains(q) ||
          s.status.toLowerCase().contains(q);
    }).toList();
  }

  void onSearch(String query) {
    _query = query;
    _applyFilter();
    notifyListeners();
  }
}

class RecordPaymentViewModel extends BaseViewModel {
  RecordPaymentViewModel({
    required this.tenantId,
    required this.totalAmount,
    required this.alreadyPaid,
    this.onSuccess,
  }) {
    pendingBalance = (totalAmount - alreadyPaid).clamp(0, double.infinity);
    paymentDate = DateTime.now();
  }

  final int tenantId;
  final double totalAmount;
  final double alreadyPaid;
  final VoidCallback? onSuccess;

  late double pendingBalance;
  late DateTime paymentDate;

  final formKey = GlobalKey<FormState>();
  final amountCtrl = TextEditingController();
  final transactionCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  String paymentMethod = 'Cash';

  final _auth = locator<HippoAuthService>();

  void setPaymentMethod(String? v) {
    paymentMethod = v ?? 'Cash';
    notifyListeners();
  }

  void setPaymentDate(DateTime d) {
    paymentDate = d;
    notifyListeners();
  }

  Future<bool> submit() async {
    if (!formKey.currentState!.validate()) return false;
    setBusy(true);
    try {
      final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
      await _auth.createTenantPayment({
        'tenant_id': tenantId,
        'amount': amount,
        'payment_method': paymentMethod,
        'payment_date': _fmtIso(paymentDate),
        if (transactionCtrl.text.trim().isNotEmpty)
          'transaction_id': transactionCtrl.text.trim(),
        if (notesCtrl.text.trim().isNotEmpty) 'notes': notesCtrl.text.trim(),
      });
      onSuccess?.call();
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
    amountCtrl.dispose();
    transactionCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }
}
