import 'package:flutter/foundation.dart';
import 'package:stacked/stacked.dart';

import '../../../../../app/app.locator.dart';
import '../../../../../models/permissions_model.dart';
import '../../../../../models/token_response_model.dart';
import '../../../../../services/api_services.dart';

class CompanySalesBillingViewModel extends BaseViewModel {
  final _api = locator<HippoAuthService>();

  TokenResponseModel? _user;
  PermissionsModel? _permissions;

  bool get _isEmployee => _user?.userType == 'employee';
  PermissionsModel get _perms => _isEmployee
      ? (_permissions ?? PermissionsModel.companyDefault)
      : PermissionsModel.companyDefault;

  bool get canWrite => _perms.bills.canWrite;
  bool get canUpdate => _perms.bills.canUpdate;
  bool get canDelete => _perms.bills.canDelete;

  String? get currentEmployeeId => _user?.employeeId?.toString();
  String? get currentEmployeeName => _user?.name;

  // ── Drafts ───────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _drafts = [];
  String _draftsQuery = '';
  int _draftsPage = 0;
  final int _draftsPerPage = 25;
  int _draftsTotal = 0;
  bool _draftsLoaded = false;
  String? draftsError;

  List<Map<String, dynamic>> get drafts {
    if (_draftsQuery.isEmpty) return _drafts;
    final q = _draftsQuery;
    return _drafts.where((e) =>
        (e['client_name'] ?? '').toString().toLowerCase().contains(q) ||
        (e['invoice_number'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

  int get draftsPage => _draftsPage;
  int get draftsPerPage => _draftsPerPage;
  int get draftsTotal => _draftsTotal;
  bool get draftsPrev => _draftsPage > 0;
  bool get draftsNext => (_draftsPage + 1) * _draftsPerPage < _draftsTotal;
  int get draftsStart => _draftsTotal == 0 ? 0 : _draftsPage * _draftsPerPage + 1;
  int get draftsEnd => _draftsPage * _draftsPerPage + drafts.length;

  // ── Sales (per-client summary) ────────────────────────────────────────────────
  List<Map<String, dynamic>> _sales = [];
  String _salesQuery = '';
  bool _salesLoaded = false;
  String? salesError;
  final Map<String, String> _salesColFilters = {};

  List<Map<String, dynamic>> get sales {
    var list = _sales;
    if (_salesColFilters.isNotEmpty) {
      list = list.where((e) {
        return _salesColFilters.entries.every((f) =>
            (e[f.key] ?? '').toString().toLowerCase().contains(f.value.toLowerCase()));
      }).toList();
    }
    if (_salesQuery.isEmpty) return list;
    final q = _salesQuery;
    return list.where((e) =>
        (e['client_name'] ?? '').toString().toLowerCase().contains(q) ||
        (e['pay_status'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

  Map<String, String> get salesColFilters => Map.unmodifiable(_salesColFilters);
  bool get hasSalesFilters => _salesColFilters.isNotEmpty;

  // Sales column visibility
  final Map<String, bool> _salesColVis = {
    'client_name': true, 'current_term': true, 'revised_total': true,
    'carried_over': true, 'total_paid': true, 'balance': true,
    'pay_status': true, 'payment_count': true,
  };
  Map<String, bool> get salesColVis => Map.unmodifiable(_salesColVis);
  void toggleSalesColVis(String key) {
    _salesColVis[key] = !(_salesColVis[key] ?? true);
    notifyListeners();
  }
  void setAllSalesColVis(bool v) {
    for (final k in _salesColVis.keys) { _salesColVis[k] = v; }
    notifyListeners();
  }

  // Sales row selection
  final Set<dynamic> _salesSel = {};
  bool get hasSalesSel => _salesSel.isNotEmpty;
  int get salesSelCount => _salesSel.length;
  bool isSalesSel(dynamic id) => _salesSel.contains(id);
  bool get allSalesSel =>
      sales.isNotEmpty && sales.every((e) => _salesSel.contains(e['client_id']));
  bool get someSalesSel => sales.any((e) => _salesSel.contains(e['client_id']));
  void toggleSalesSel(dynamic id) {
    if (_salesSel.contains(id)) {
      _salesSel.remove(id);
    } else {
      _salesSel.add(id);
    }
    notifyListeners();
  }
  void toggleSelectAllSales() {
    if (allSalesSel) {
      for (final e in sales) { _salesSel.remove(e['client_id']); }
    } else {
      for (final e in sales) { _salesSel.add(e['client_id']); }
    }
    notifyListeners();
  }
  void clearSalesSel() { _salesSel.clear(); notifyListeners(); }

  // ── History (invoice records) ─────────────────────────────────────────────────
  List<Map<String, dynamic>> _history = [];
  String _historyQuery = '';
  int _historyPage = 0;
  int _historyPerPage = 25;
  int _historyTotal = 0;
  bool _historyLoaded = false;
  String? historyError;
  final Map<String, String> _historyColFilters = {};

  List<Map<String, dynamic>> get history {
    if (_historyQuery.isEmpty) return _history;
    final q = _historyQuery;
    return _history.where((e) =>
        (e['client_name'] ?? '').toString().toLowerCase().contains(q) ||
        (e['invoice_number'] ?? '').toString().toLowerCase().contains(q) ||
        (e['status'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

  int get historyPage => _historyPage;
  int get historyPerPage => _historyPerPage;
  int get historyTotal => _historyTotal;
  bool get historyPrev => _historyPage > 0;
  bool get historyNext => (_historyPage + 1) * _historyPerPage < _historyTotal;
  int get historyStart => _historyTotal == 0 ? 0 : _historyPage * _historyPerPage + 1;
  int get historyEnd => _historyPage * _historyPerPage + history.length;
  Map<String, String> get historyColFilters => Map.unmodifiable(_historyColFilters);
  bool get hasHistoryFilters => _historyColFilters.isNotEmpty;

  // History column visibility
  final Map<String, bool> _histColVis = {
    'invoice_number': true, 'client_name': true, 'invoice_date': true,
    'total_amount': true, 'paid_amount': true, 'remaining_balance': true,
    'status': true,
  };
  Map<String, bool> get histColVis => Map.unmodifiable(_histColVis);
  void toggleHistColVis(String key) {
    _histColVis[key] = !(_histColVis[key] ?? true);
    notifyListeners();
  }
  void setAllHistColVis(bool v) {
    for (final k in _histColVis.keys) { _histColVis[k] = v; }
    notifyListeners();
  }

  // History row selection
  final Set<dynamic> _histSel = {};
  bool get hasHistSel => _histSel.isNotEmpty;
  int get histSelCount => _histSel.length;
  bool isHistSel(dynamic id) => _histSel.contains(id);
  bool get allHistSel =>
      _history.isNotEmpty && _history.every((e) => _histSel.contains(e['id']));
  bool get someHistSel => _history.any((e) => _histSel.contains(e['id']));
  void toggleHistSel(dynamic id) {
    if (_histSel.contains(id)) {
      _histSel.remove(id);
    } else {
      _histSel.add(id);
    }
    notifyListeners();
  }
  void toggleSelectAllHist() {
    if (allHistSel) {
      for (final e in _history) { _histSel.remove(e['id']); }
    } else {
      for (final e in _history) { _histSel.add(e['id']); }
    }
    notifyListeners();
  }
  void clearHistSel() { _histSel.clear(); notifyListeners(); }

  static const List<int> rowsPerPageOptions = [25, 50, 100];

  // ── Formatters ───────────────────────────────────────────────────────────────

  static String fmtDate(dynamic val) {
    if (val == null) return '—';
    final s = val.toString();
    if (s.isEmpty || s == 'null') return '—';
    try {
      final dt = DateTime.parse(s);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}';
    } catch (_) {
      return s.length > 10 ? s.substring(0, 10) : s;
    }
  }

  static String fmtAmt(dynamic val) {
    if (val == null) return '0.00';
    final n = double.tryParse(val.toString()) ?? 0.0;
    return n.toStringAsFixed(2);
  }

  // ── Search ───────────────────────────────────────────────────────────────────

  void searchDrafts(String q) {
    _draftsQuery = q.toLowerCase().trim();
    notifyListeners();
  }

  void searchSales(String q) {
    _salesQuery = q.toLowerCase().trim();
    notifyListeners();
  }

  void searchHistory(String q) {
    _historyQuery = q.toLowerCase().trim();
    notifyListeners();
  }

  // ── Filters ──────────────────────────────────────────────────────────────────

  void setSalesFilter(String field, String value) {
    if (value.trim().isEmpty) {
      _salesColFilters.remove(field);
    } else {
      _salesColFilters[field] = value.trim();
    }
    notifyListeners();
  }

  void clearSalesFilters() {
    _salesColFilters.clear();
    notifyListeners();
  }

  void setHistoryFilter(String field, String value) {
    if (value.trim().isEmpty) {
      _historyColFilters.remove(field);
    } else {
      _historyColFilters[field] = value.trim();
    }
    _historyPage = 0;
    _historyLoaded = false;
    initHistory();
  }

  void clearHistoryFilters() {
    _historyColFilters.clear();
    _historyPage = 0;
    _historyLoaded = false;
    initHistory();
  }

  // ── Pagination ────────────────────────────────────────────────────────────────

  void draftsNextPage() {
    if (draftsNext) {
      _draftsPage++;
      initDrafts();
    }
  }

  void draftsPrevPage() {
    if (draftsPrev) {
      _draftsPage--;
      initDrafts();
    }
  }

  void historyNextPage() {
    if (historyNext) {
      _historyPage++;
      initHistory();
    }
  }

  void historyPrevPage() {
    if (historyPrev) {
      _historyPage--;
      initHistory();
    }
  }

  void setHistoryPerPage(int v) {
    if (_historyPerPage == v) return;
    _historyPerPage = v;
    _historyPage = 0;
    _historyLoaded = false;
    initHistory();
  }

  // ── Init ─────────────────────────────────────────────────────────────────────

  Future<void> _loadUser() async {
    _user ??= await _api.getStoredUser();
    if (_isEmployee) _permissions ??= await _api.getStoredPermissions();
  }

  Future<void> init() async {
    setBusy(true);
    await _loadUser();
    await Future.wait([initDrafts(), initSales(), initHistory()]);
    setBusy(false);
  }

  Future<void> initDrafts() async {
    draftsError = null;
    try {
      final result = await _api.getSalesPaged(
        page: _draftsPage,
        rowsPerPage: _draftsPerPage,
        colFilters: {'status': 'Draft'},
      );
      _drafts = List<Map<String, dynamic>>.from(result['data'] as List);
      _draftsTotal = result['total'] as int;
      if (_drafts.length < _draftsPerPage) {
        _draftsTotal = _draftsPage * _draftsPerPage + _drafts.length;
      }
      _draftsLoaded = true;
      debugPrint('=== DRAFTS | total=$_draftsTotal rows=${_drafts.length} ===');
    } catch (e) {
      if (!_draftsLoaded) draftsError = e.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }

  Future<void> initSales() async {
    salesError = null;
    try {
      _sales = await _api.getSalesHistory();
      _salesLoaded = true;
      debugPrint('=== SALES HISTORY | rows=${_sales.length} ===');
    } catch (e) {
      if (!_salesLoaded) salesError = e.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }

  Future<void> initHistory() async {
    historyError = null;
    try {
      final result = await _api.getSalesPaged(
        page: _historyPage,
        rowsPerPage: _historyPerPage,
        colFilters: _historyColFilters,
      );
      _history = List<Map<String, dynamic>>.from(result['data'] as List);
      _historyTotal = result['total'] as int;
      if (_history.length < _historyPerPage) {
        _historyTotal = _historyPage * _historyPerPage + _history.length;
      }
      _historyLoaded = true;
      debugPrint('=== HISTORY | total=$_historyTotal rows=${_history.length} ===');
    } catch (e) {
      if (!_historyLoaded) historyError = e.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }

  // ── CRUD ─────────────────────────────────────────────────────────────────────

  Future<String?> addSale(Map<String, dynamic> data) async {
    try {
      final payAmt = double.tryParse(data.remove('currentlyPaying')?.toString() ?? '0') ?? 0;
      final payMethod = data.remove('paymentMethod')?.toString() ?? 'Cash';
      final payDate = data.remove('paymentDate')?.toString();
      final transactionId = data.remove('transactionId');
      final paymentNotes = data.remove('paymentNotes');
      final saleId = await _api.addSale(data);
      if (payAmt > 0 && saleId > 0) {
        await _api.recordSalePayment({
          'saleId': saleId,
          'amount_paid': payAmt,
          'payment_method': payMethod,
          'payment_date': payDate ?? data['invoiceDate'],
          'createdBy': data['createdBy'],
          if (transactionId != null) 'transaction_id': transactionId,
          if (paymentNotes != null) 'notes': paymentNotes,
        });
      }
      _draftsLoaded = false;
      _salesLoaded = false;
      _historyLoaded = false;
      await Future.wait([initDrafts(), initSales(), initHistory()]);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> updateSale(dynamic id, Map<String, dynamic> data) async {
    try {
      await _api.updateSale(id, data);
      _draftsLoaded = false;
      _salesLoaded = false;
      _historyLoaded = false;
      await Future.wait([initDrafts(), initSales(), initHistory()]);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> submitDraft(Map<String, dynamic> draft) async {
    try {
      List<dynamic> services = [];
      try {
        final raw = draft['services'];
        if (raw is List) services = raw;
      } catch (_) {}

      await _api.updateSale(draft['id'], {
        'invoiceNumber': draft['invoice_number'],
        'invoiceDate': draft['invoice_date'],
        'clientId': draft['client_id'],
        'clientName': draft['client_name'],
        'revised_total_amount': draft['total_amount'] ?? 0,
        'original_total_amount': draft['total_amount'] ?? 0,
        'revised_taxable_amount': 0,
        'revised_tax_amount': 0,
        'original_taxable_amount': 0,
        'original_tax_amount': 0,
        'discount': draft['discount'] ?? 0,
        'tax_option': draft['tax_option'] ?? 'including',
        'round_off': 0,
        'services': services,
        'notes': draft['notes'],
        'status': 'Pending',
      });
      _draftsLoaded = false;
      _salesLoaded = false;
      _historyLoaded = false;
      await Future.wait([initDrafts(), initSales(), initHistory()]);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> deleteSale(dynamic id) async {
    try {
      await _api.deleteSale(id);
      _draftsLoaded = false;
      _salesLoaded = false;
      _historyLoaded = false;
      await Future.wait([initDrafts(), initSales(), initHistory()]);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }
}
