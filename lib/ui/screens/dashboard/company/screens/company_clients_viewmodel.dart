import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:stacked/stacked.dart';

import '../../../../../app/app.locator.dart';
import '../../../../../models/permissions_model.dart';
import '../../../../../models/token_response_model.dart';
import '../../../../../services/api_services.dart';

class ClientColumnDef {
  const ClientColumnDef(this.label, this.key, this.width,
      {this.filterable = true, this.alwaysVisible = false});
  final String label;
  final String key;
  final double width;
  final bool filterable;
  final bool alwaysVisible;
}

class CompanyClientsViewModel extends BaseViewModel {
  final _api = locator<HippoAuthService>();

  TokenResponseModel? _user;
  PermissionsModel? _permissions;

  bool get _isEmployee => _user?.userType == 'employee';
  PermissionsModel get _perms => _isEmployee
      ? (_permissions ?? PermissionsModel.companyDefault)
      : PermissionsModel.companyDefault;

  bool get canWrite => _perms.clients.canWrite;
  bool get canUpdate => _perms.clients.canUpdate;
  bool get canDelete => _perms.clients.canDelete;

  List<Map<String, dynamic>> _items = [];
  String _query = '';
  String? fetchError;
  bool _loaded = false;
  String _tab = 'active';

  int _currentPage = 0;
  int _rowsPerPage = 25;
  int _total = 0;

  final Map<String, String> _colFilters = {};
  final Set<dynamic> _selectedIds = {};

  final Map<String, bool> _colVisible = {
    'client_name': true,
    'contact_person': true,
    'email': true,
    'phone': true,
    'city': true,
    'state': true,
    'country': true,
    'assigned_to': true,
    'svc_name': true,
    'svc_duration': true,
    'svc_base_price': true,
    'svc_tax': true,
    'svc_start_date': true,
    'svc_end_date': true,
    'svc_req_duration': true,
    'status': true,
    'quotation_title': true,
  };

  static const List<int> rowsPerPageOptions = [25, 50, 100];
  static const List<ClientColumnDef> allColumns = [
    ClientColumnDef('', 'checkbox', 48, filterable: false, alwaysVisible: true),
    ClientColumnDef('S.No', 'sno', 60, filterable: false, alwaysVisible: true),
    ClientColumnDef('Client Name', 'client_name', 160),
    ClientColumnDef('Contact Person', 'contact_person', 150),
    ClientColumnDef('Email', 'email', 200),
    ClientColumnDef('Phone', 'phone', 130),
    ClientColumnDef('City', 'city', 110),
    ClientColumnDef('State', 'state', 130),
    ClientColumnDef('Country', 'country', 110),
    ClientColumnDef('Assigned To', 'assigned_to', 140),
    ClientColumnDef('Service Name', 'svc_name', 170, filterable: false),
    ClientColumnDef('Duration', 'svc_duration', 90, filterable: false),
    ClientColumnDef('Base Price', 'svc_base_price', 110, filterable: false),
    ClientColumnDef('Tax', 'svc_tax', 90, filterable: false),
    ClientColumnDef('Start Date', 'svc_start_date', 110, filterable: false),
    ClientColumnDef('End Date', 'svc_end_date', 110, filterable: false),
    ClientColumnDef('Req Duration', 'svc_req_duration', 110, filterable: false),
    ClientColumnDef('Status', 'status', 100),
    ClientColumnDef('Quotation', 'quotation_title', 140),
    ClientColumnDef('Action', 'action', 120, filterable: false, alwaysVisible: true),
  ];

  static const tabOptions = [
    {'label': 'Active', 'value': 'active'},
    {'label': 'Inactive', 'value': 'inactive'},
    {'label': 'Draft', 'value': 'draft'},
  ];

  String get tab => _tab;
  int get currentPage => _currentPage;
  int get rowsPerPage => _rowsPerPage;
  int get total => _total;
  bool get hasPrev => _currentPage > 0;
  bool get hasNext => (_currentPage + 1) * _rowsPerPage < _total;
  int get pageStart => _total == 0 ? 0 : _currentPage * _rowsPerPage + 1;
  int get pageEnd => _currentPage * _rowsPerPage + items.length;
  bool get hasActiveFilters => _colFilters.isNotEmpty;
  Map<String, String> get colFilters => Map.unmodifiable(_colFilters);
  Map<String, bool> get colVisible => Map.unmodifiable(_colVisible);
  bool get hasSelection => _selectedIds.isNotEmpty;
  int get selectedCount => _selectedIds.length;
  bool get isInactiveTab => _tab == 'inactive';
  bool get isDraftTab => _tab == 'draft';
  bool get isNonActiveTab => _tab == 'inactive' || _tab == 'draft';

  bool isSelected(dynamic id) => _selectedIds.contains(id);

  bool get allCurrentSelected {
    if (items.isEmpty) return false;
    return items.every((e) => _selectedIds.contains(e['id']));
  }

  bool get someCurrentSelected =>
      items.any((e) => _selectedIds.contains(e['id']));

  List<ClientColumnDef> get visibleColumns => allColumns
      .where((c) => c.alwaysVisible || (_colVisible[c.key] ?? true))
      .toList();

  List<Map<String, dynamic>> get items {
    var list = _items;
    if (_query.isNotEmpty) {
      final q = _query;
      list = list.where((e) {
        return (e['client_name'] ?? '').toString().toLowerCase().contains(q) ||
            (e['contact_person'] ?? '').toString().toLowerCase().contains(q) ||
            (e['email'] ?? '').toString().toLowerCase().contains(q) ||
            (e['phone'] ?? '').toString().toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  static Map<String, dynamic>? firstService(Map<String, dynamic> item) {
    try {
      final raw = item['services'];
      if (raw == null) return null;
      final List list =
          raw is List ? raw : jsonDecode(raw.toString()) as List;
      if (list.isEmpty) return null;
      return Map<String, dynamic>.from(list[0] as Map);
    } catch (_) {
      return null;
    }
  }

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

  // ── Actions ───────────────────────────────────────────────────────────────────

  void setTab(String value) {
    if (_tab == value) return;
    _tab = value;
    _currentPage = 0;
    _loaded = false;
    _selectedIds.clear();
    init();
  }

  void search(String q) {
    _query = q.toLowerCase().trim();
    notifyListeners();
  }

  void setColFilter(String field, String value) {
    if (value.trim().isEmpty) {
      _colFilters.remove(field);
    } else {
      _colFilters[field] = value.trim();
    }
    _currentPage = 0;
    _loaded = false;
    init();
  }

  void clearAllFilters() {
    _colFilters.clear();
    _currentPage = 0;
    _loaded = false;
    init();
  }

  void toggleColumn(String key) {
    _colVisible[key] = !(_colVisible[key] ?? true);
    notifyListeners();
  }

  void setAllColumnsVisible(bool visible) {
    for (final key in _colVisible.keys.toList()) {
      _colVisible[key] = visible;
    }
    notifyListeners();
  }

  void setRowsPerPage(int value) {
    if (_rowsPerPage == value) return;
    _rowsPerPage = value;
    _currentPage = 0;
    _loaded = false;
    init();
  }

  void toggleRowSelection(dynamic id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  void toggleSelectAll() {
    if (allCurrentSelected) {
      for (final e in items) {
        _selectedIds.remove(e['id']);
      }
    } else {
      for (final e in items) {
        _selectedIds.add(e['id']);
      }
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedIds.clear();
    notifyListeners();
  }

  void nextPage() {
    if (hasNext) {
      _currentPage++;
      init();
    }
  }

  void prevPage() {
    if (hasPrev) {
      _currentPage--;
      init();
    }
  }

  Future<void> init() async {
    if (!_loaded) setBusy(true);
    fetchError = null;
    _user ??= await _api.getStoredUser();
    if (_isEmployee) _permissions ??= await _api.getStoredPermissions();
    try {
      final result = await _api.getClientsPaged(
        tab: _tab,
        page: _currentPage,
        rowsPerPage: _rowsPerPage,
        colFilters: _colFilters,
        selfOnly: _isEmployee && _perms.selfOnly,
        employeeId: _user?.employeeId?.toString(),
      );
      _items = List<Map<String, dynamic>>.from(result['data'] as List);
      _total = result['total'] as int;
      if (_items.length < _rowsPerPage) {
        _total = _currentPage * _rowsPerPage + _items.length;
      }
      _loaded = true;
      debugPrint('=== CLIENTS $_tab | total=$_total rows=${_items.length} ===');
    } catch (e) {
      if (!_loaded) fetchError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      setBusy(false);
    }
  }

  Future<String?> addClient(Map<String, dynamic> data) async {
    try {
      await _api.addClient(data);
      _currentPage = 0;
      _loaded = false;
      await init();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> updateClient(dynamic id, Map<String, dynamic> data,
      {String tab = '1'}) async {
    try {
      await _api.updateClient(id, data, tab: tab);
      _loaded = false;
      await init();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> deleteClient(dynamic id) async {
    try {
      final tabNum = _tab == 'inactive' ? '2' : _tab == 'draft' ? '3' : '1';
      await _api.deleteClient(id, tab: tabNum);
      _selectedIds.remove(id);
      _loaded = false;
      await init();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> reactivateClient(Map<String, dynamic> item) async {
    try {
      final id = item['id'];
      final svc = firstService(item);
      final data = {
        'clientName': item['client_name'] ?? '',
        'contactPerson': item['contact_person'] ?? '',
        'email': item['email'] ?? '',
        'phone': item['phone'] ?? '',
        'alternateContact': item['alternate_contact'] ?? '',
        'taxId': item['tax_id'] ?? '',
        'streetAddress': item['street_address'] ?? '',
        'city': item['city_id'] ?? item['city'] ?? '',
        'state': item['state_id'] ?? item['state'] ?? '',
        'country': item['country_id'] ?? item['country'] ?? '',
        'postalCode': item['postal_code'] ?? '',
        'completeAddress': item['complete_address'] ?? '',
        'assignedTo': item['assigned_to_id'] ?? item['assigned_to'] ?? '',
        'paymentTerms': item['payment_terms'] ?? '',
        'preferredPayment': item['preferred_payment'] ?? '',
        'notes': item['notes'] ?? '',
        'selectedServices': svc != null ? [svc] : [],
        'negotiate': item['negotiate'] ?? 'No',
        'taxOption': item['tax_option'] ?? 'including',
        'roundOff': item['round_off'] ?? 0,
        'original_taxableAmount': item['original_taxable_amount'] ?? 0,
        'original_taxAmount': item['original_tax_amount'] ?? 0,
        'original_totalAmount': item['original_total_amount'] ?? 0,
        'revised_taxableAmount': item['revised_taxable_amount'] ?? 0,
        'revised_taxAmount': item['revised_tax_amount'] ?? 0,
        'revised_totalAmount': item['revised_total_amount'] ?? 0,
        'revisedAmounts': item['revisedamounts'] ?? [],
        'quotationId': item['quotation_id'] ?? '',
        'quotationTitle': item['quotation_title'] ?? '',
      };
      final srcTab = _tab == 'draft' ? '3' : '2';
      await _api.updateClient(id, data, tab: srcTab);
      _loaded = false;
      await init();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  String buildCsvContent() {
    final exportCols = visibleColumns
        .where((c) => c.key != 'checkbox' && c.key != 'action')
        .toList();
    final exportItems = hasSelection
        ? _items.where((e) => _selectedIds.contains(e['id'])).toList()
        : _items;
    final headers = exportCols.map((c) => c.label).toList();
    final rows = <List<String>>[headers];
    for (int i = 0; i < exportItems.length; i++) {
      final item = exportItems[i];
      final svc = firstService(item);
      rows.add(exportCols.map((c) {
        if (c.key == 'sno') return '${i + 1}';
        if (c.key == 'svc_name') {
          return svc?['service_name']?.toString() ??
              svc?['product_name']?.toString() ??
              svc?['svc_name']?.toString() ??
              '—';
        }
        if (c.key == 'svc_duration') {
          return svc?['opted_duration']?.toString() ??
              svc?['duration']?.toString() ??
              '—';
        }
        if (c.key == 'svc_base_price') {
          return svc?['base_price']?.toString() ?? '—';
        }
        if (c.key == 'svc_tax') {
          return svc?['tax_rate']?.toString() ?? '—';
        }
        if (c.key == 'svc_start_date') {
          return fmtDate(svc?['start_date']);
        }
        if (c.key == 'svc_end_date') {
          return fmtDate(svc?['end_date']);
        }
        if (c.key == 'svc_req_duration') {
          return svc?['original_duration']?.toString() ?? '—';
        }
        return item[c.key]?.toString() ?? '';
      }).toList());
    }
    return rows
        .map((r) => r.map((c) => '"${c.replaceAll('"', '""')}"').join(','))
        .join('\n');
  }
}
