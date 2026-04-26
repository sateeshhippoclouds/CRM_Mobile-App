import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import '../../../../app/app.locator.dart';
import '../../../../models/subscription_model.dart';
import '../../../../services/api_services.dart';

class SubscriptionsViewModel extends BaseViewModel {
  final _auth = locator<HippoAuthService>();

  List<SubscriptionModel> _all = [];
  List<SubscriptionModel> filtered = [];
  String? fetchError;
  bool isListView = true;
  int? togglingId;

  Future<void> init() async {
    setBusy(true);
    fetchError = null;
    try {
      _all = await _auth.getSubscriptions();
      filtered = List.from(_all);
    } catch (e) {
      fetchError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      setBusy(false);
    }
  }

  void onSearch(String query) {
    final q = query.toLowerCase();
    filtered = q.isEmpty
        ? List.from(_all)
        : _all
            .where((s) =>
                (s.name ?? '').toLowerCase().contains(q) ||
                (s.duration ?? '').toLowerCase().contains(q))
            .toList();
    notifyListeners();
  }

  void setListView(bool value) {
    isListView = value;
    notifyListeners();
  }

  Future<void> addSubscription(Map<String, dynamic> data) async {
    await _auth.createSubscription(data);
    await init();
  }

  Future<void> editSubscription(int id, Map<String, dynamic> data) async {
    await _auth.updateSubscription(id, data);
    await init();
  }

  Future<void> toggleStatus(SubscriptionModel s) async {
    if (s.id == null) return;
    togglingId = s.id;
    notifyListeners();
    try {
      final newStatus = s.isActive ? 'inactive' : 'active';
      final idx = _all.indexWhere((x) => x.id == s.id);
      if (idx != -1) {
        _all[idx] = SubscriptionModel(
          id: s.id,
          name: s.name,
          duration: s.duration,
          price: s.price,
          tax: s.tax,
          totalAmount: s.totalAmount,
          status: newStatus,
          createdAt: s.createdAt,
          updatedAt: s.updatedAt,
        );
        filtered = List.from(_all);
        notifyListeners();
      }
      await _auth.updateSubscription(s.id!, {
        'name': s.name,
        'duration': s.duration,
        'price': s.price,
        'tax': s.tax,
        'total_amount': s.totalAmount,
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

class SubscriptionDialogViewModel extends BaseViewModel {
  SubscriptionDialogViewModel({this.existing});
  final SubscriptionModel? existing;

  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameCtrl;
  late final TextEditingController priceCtrl;
  late final TextEditingController taxCtrl;
  late final TextEditingController totalCtrl;
  String? duration;
  String status = 'active';

  bool get isEdit => existing != null;

  void init() {
    nameCtrl = TextEditingController(text: existing?.name ?? '');
    priceCtrl =
        TextEditingController(text: existing?.price?.toStringAsFixed(2) ?? '');
    taxCtrl =
        TextEditingController(text: existing?.tax?.toStringAsFixed(2) ?? '');
    totalCtrl = TextEditingController(
        text: existing?.totalAmount?.toStringAsFixed(2) ?? '');
    duration = existing?.duration;
    status = existing?.status ?? 'active';
    priceCtrl.addListener(_calcTotal);
    taxCtrl.addListener(_calcTotal);
  }

  void _calcTotal() {
    final price = double.tryParse(priceCtrl.text) ?? 0;
    final tax = double.tryParse(taxCtrl.text) ?? 0;
    totalCtrl.text = (price + (price * tax / 100)).toStringAsFixed(2);
  }

  void setDuration(String? v) {
    duration = v;
    notifyListeners();
  }

  void setStatus(String? v) {
    status = v ?? 'active';
    notifyListeners();
  }

  Future<bool> submit(SubscriptionsViewModel parentModel) async {
    if (!formKey.currentState!.validate()) return false;
    setBusy(true);
    try {
      final data = {
        'name': nameCtrl.text.trim(),
        'duration': duration,
        'price': double.parse(priceCtrl.text),
        'tax': double.tryParse(taxCtrl.text) ?? 0,
        'total_amount':
            double.tryParse(totalCtrl.text) ?? double.parse(priceCtrl.text),
        'status': status,
      };
      if (isEdit) {
        await parentModel.editSubscription(existing!.id!, data);
      } else {
        await parentModel.addSubscription(data);
      }
      return true;
    } catch (e) {
      setError(e);
      return false;
    } finally {
      setBusy(false);
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
    taxCtrl.dispose();
    totalCtrl.dispose();
    super.dispose();
  }
}
