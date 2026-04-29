import 'package:flutter/foundation.dart';
import 'package:stacked/stacked.dart';

import '../../../../../app/app.locator.dart';
import '../../../../../models/permissions_model.dart';
import '../../../../../models/token_response_model.dart';
import '../../../../../services/api_services.dart';

class ColumnDef {
  const ColumnDef(
    this.label,
    this.key,
    this.width, {
    this.filterable = true,
    this.alwaysVisible = false,
  });
  final String label;
  final String key;
  final double width;
  final bool filterable;
  final bool alwaysVisible;
}

class CompanyEmployeesViewModel extends BaseViewModel {
  final _api = locator<HippoAuthService>();

  TokenResponseModel? _user;
  PermissionsModel? _permissions;

  bool get _isEmployee => _user?.userType == 'employee';
  PermissionsModel get _perms => _isEmployee
      ? (_permissions ?? PermissionsModel.companyDefault)
      : PermissionsModel.companyDefault;

  bool get canWrite => _perms.employees.canWrite;
  bool get canUpdate => _perms.employees.canUpdate;
  bool get canDelete => _perms.employees.canDelete;

  List<Map<String, dynamic>> _items = [];
  String _query = '';
  String _tab = 'active';
  String? fetchError;
  bool _loaded = false;

  int _currentPage = 0;
  int _rowsPerPage = 25;
  int _total = 0;

  final Map<String, String> _colFilters = {};
  final Set<dynamic> _selectedIds = {};

  final Map<String, bool> _colVisible = {
    'employeeid': true,
    'employee_name': true,
    'email': true,
    'phone_number': true,
    'dob': true,
    'gender': true,
    'salary': true,
    'employee_status': true,
    'email_alerts': true,
  };

  static const List<Map<String, String>> tabOptions = [
    {'label': 'Active', 'value': 'active'},
    {'label': 'Inactive', 'value': 'inactive'},
    {'label': 'Bulk Failed', 'value': 'bulkfailed'},
  ];

  static const List<int> rowsPerPageOptions = [25, 50, 100];

  static const List<ColumnDef> allColumns = [
    ColumnDef('', 'checkbox', 48, filterable: false, alwaysVisible: true),
    ColumnDef('S.No', 'sno', 60, filterable: false, alwaysVisible: true),
    ColumnDef('Employee ID', 'employeeid', 140),
    ColumnDef('Employee Name', 'employee_name', 170),
    ColumnDef('Email', 'email', 210),
    ColumnDef('Phone Number', 'phone_number', 150),
    ColumnDef('DOB', 'dob', 110),
    ColumnDef('Gender', 'gender', 100),
    ColumnDef('Salary', 'salary', 110),
    ColumnDef('Status', 'employee_status', 110, filterable: false),
    ColumnDef('Email Alerts', 'email_alerts', 110, filterable: false),
    ColumnDef('Action', 'action', 90, filterable: false, alwaysVisible: true),
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
  int get activeFilterCount => _colFilters.length;
  Map<String, String> get colFilters => Map.unmodifiable(_colFilters);
  Map<String, bool> get colVisible => Map.unmodifiable(_colVisible);
  bool get hasSelection => _selectedIds.isNotEmpty;
  int get selectedCount => _selectedIds.length;

  void clearSelection() {
    _selectedIds.clear();
    notifyListeners();
  }

  bool isSelected(dynamic id) => _selectedIds.contains(id);

  bool get allCurrentSelected {
    if (items.isEmpty) return false;
    return items.every((e) => _selectedIds.contains(e['id'] ?? e['employeeid']));
  }

  bool get someCurrentSelected {
    return items.any((e) => _selectedIds.contains(e['id'] ?? e['employeeid']));
  }

  List<ColumnDef> get visibleColumns => allColumns
      .where((c) => c.alwaysVisible || (_colVisible[c.key] ?? true))
      .toList();

  // Fields the backend cannot text-filter (numeric / date) — handled client-side
  static const _clientSideFilterFields = {'salary', 'dob'};

  List<Map<String, dynamic>> get items {
    var list = _items;
    if (_query.isNotEmpty) {
      list = list.where((e) {
        return (e['employee_name'] ?? '').toString().toLowerCase().contains(_query) ||
            (e['employeeid'] ?? '').toString().toLowerCase().contains(_query) ||
            (e['email'] ?? '').toString().toLowerCase().contains(_query) ||
            (e['phone_number'] ?? '').toString().toLowerCase().contains(_query);
      }).toList();
    }
    for (final entry in _colFilters.entries) {
      if (_clientSideFilterFields.contains(entry.key)) {
        final q = entry.value.toLowerCase();
        list = list
            .where((e) => (e[entry.key] ?? '').toString().toLowerCase().contains(q))
            .toList();
      }
    }
    return list;
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
    debugPrint('=== FILTER: $field="${value.trim()}" | active filters: $_colFilters ===');
    debugPrint('=== FILTERED RESULTS (${items.length}) ===');
    for (final e in items) {
      debugPrint('  ${e['employee_name']} | $field: ${e[field]}');
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
        _selectedIds.remove(e['id'] ?? e['employeeid']);
      }
    } else {
      for (final e in items) {
        _selectedIds.add(e['id'] ?? e['employeeid']);
      }
    }
    notifyListeners();
  }

  void setTab(String t) {
    if (_tab == t) return;
    _tab = t;
    _currentPage = 0;
    _items = [];
    _total = 0;
    _loaded = false;
    _selectedIds.clear();
    init();
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
      final backendFilters = Map.fromEntries(
        _colFilters.entries.where((e) => !_clientSideFilterFields.contains(e.key)),
      );
      final result = await _api.getEmployeesPaged(
        tab: _tab,
        page: _currentPage,
        rowsPerPage: _rowsPerPage,
        colFilters: backendFilters,
      );
      _items = List<Map<String, dynamic>>.from(result['data'] as List);
      _total = result['total'] as int;
      _loaded = true;
      debugPrint('=== EMPLOYEES DATA ===');
      debugPrint('Backend total: $_total | After filters: ${items.length}');
      for (final e in items) {
        debugPrint(e.toString());
      }
      debugPrint('=== END EMPLOYEES ===');
    } catch (e) {
      if (!_loaded) fetchError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      setBusy(false);
    }
  }

  Future<String?> addEmployee(Map<String, dynamic> data) async {
    try {
      await _api.addEmployee(data);
      _currentPage = 0;
      _loaded = false;
      await init();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> updateEmployee(dynamic id, Map<String, dynamic> data) async {
    try {
      await _api.updateEmployee(id, data);
      _loaded = false;
      await init();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> deleteEmployee(dynamic id) async {
    try {
      await _api.deleteEmployee(id);
      _selectedIds.remove(id);
      _loaded = false;
      await init();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  String buildCsvContent() {
    // Columns to export (exclude checkbox, action; include sno)
    final exportCols = visibleColumns
        .where((c) => c.key != 'checkbox' && c.key != 'action')
        .toList();

    // Export selected rows if any, otherwise all loaded rows
    final exportItems = hasSelection
        ? _items
            .where((e) => _selectedIds.contains(e['id'] ?? e['employeeid']))
            .toList()
        : _items;

    final headers = exportCols.map((c) => c.label).toList();
    final rows = <List<String>>[headers];

    for (int i = 0; i < exportItems.length; i++) {
      final item = exportItems[i];
      rows.add(exportCols.map((c) {
        if (c.key == 'sno') return '${i + 1}';
        if (c.key == 'email_alerts') {
          final v = item['email_alerts'];
          return (v == true || v == 'true' || v == 1) ? 'Yes' : 'No';
        }
        return item[c.key]?.toString() ?? '';
      }).toList());
    }

    return rows
        .map((r) => r.map((c) => '"${c.replaceAll('"', '""')}"').join(','))
        .join('\n');
  }
}
