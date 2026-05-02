import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:stacked/stacked.dart';

import '../../../../../app/app.locator.dart';
import '../../../../../models/permissions_model.dart';
import '../../../../../models/token_response_model.dart';
import '../../../../../services/api_services.dart';

class TaskColumnDef {
  const TaskColumnDef(this.label, this.key, this.width,
      {this.filterable = true, this.alwaysVisible = false});
  final String label;
  final String key;
  final double width;
  final bool filterable;
  final bool alwaysVisible;
}

class CompanyTasksViewModel extends BaseViewModel {
  final _api = locator<HippoAuthService>();

  TokenResponseModel? _user;
  PermissionsModel? _permissions;

  bool get _isEmployee => _user?.userType == 'employee';
  PermissionsModel get _perms => _isEmployee
      ? (_permissions ?? PermissionsModel.companyDefault)
      : PermissionsModel.companyDefault;

  bool get canWrite => _perms.task.canWrite;
  bool get canUpdate => _perms.task.canUpdate;
  bool get canDelete => _perms.task.canDelete;

  String? get currentEmployeeId => _user?.employeeId?.toString();

  List<Map<String, dynamic>> _items = [];
  String _query = '';
  String? fetchError;
  bool _loaded = false;

  int _currentPage = 0;
  int _rowsPerPage = 25;
  int _total = 0;

  final Map<String, String> _colFilters = {};
  final Set<dynamic> _selectedIds = {};

  final Map<String, bool> _colVisible = {
    'title': true,
    'related_to': true,
    'assigned_to': true,
    'created_at': true,
    'start_date': true,
    'due_date': true,
    'priority': true,
    'relatedtotype': true,
    'notes': true,
    'status': true,
  };

  static const List<int> rowsPerPageOptions = [25, 50, 100];

  static const List<TaskColumnDef> allColumns = [
    TaskColumnDef('', 'checkbox', 48, filterable: false, alwaysVisible: true),
    TaskColumnDef('S.No', 'sno', 60, filterable: false, alwaysVisible: true),
    TaskColumnDef('Title', 'title', 200),
    TaskColumnDef('Related To', 'related_to', 160),
    TaskColumnDef('Assigned To', 'assigned_to', 150),
    TaskColumnDef('Created On', 'created_at', 110, filterable: false),
    TaskColumnDef('Start Date', 'start_date', 110, filterable: false),
    TaskColumnDef('Due Date', 'due_date', 110, filterable: false),
    TaskColumnDef('Priority', 'priority', 90),
    TaskColumnDef('Task Type', 'relatedtotype', 100),
    TaskColumnDef('Notes', 'notes', 220, filterable: false),
    TaskColumnDef('Status', 'status', 110),
    TaskColumnDef('Action', 'action', 100,
        filterable: false, alwaysVisible: true),
  ];

  static const statusOptions = [
    'Created',
    'In Progress',
    'Completed',
    'On Hold',
    'Cancelled',
  ];

  static const relatedToTypeOptions = [
    {'label': 'Clients', 'value': 'clients'},
    {'label': 'Leads', 'value': 'leads'},
    {'label': 'Others', 'value': 'others'},
  ];

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

  bool isSelected(dynamic id) => _selectedIds.contains(id);

  bool get allCurrentSelected {
    if (items.isEmpty) return false;
    return items.every((e) => _selectedIds.contains(e['id']));
  }

  bool get someCurrentSelected =>
      items.any((e) => _selectedIds.contains(e['id']));

  List<TaskColumnDef> get visibleColumns => allColumns
      .where((c) => c.alwaysVisible || (_colVisible[c.key] ?? true))
      .toList();

  List<Map<String, dynamic>> get items {
    var list = _items;
    if (_query.isNotEmpty) {
      final q = _query;
      list = list.where((e) {
        return (e['title'] ?? '').toString().toLowerCase().contains(q) ||
            (e['related_to'] ?? '').toString().toLowerCase().contains(q) ||
            (e['assigned_to'] ?? '').toString().toLowerCase().contains(q) ||
            (e['priority'] ?? '').toString().toLowerCase().contains(q);
      }).toList();
    }
    return list;
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
      for (final e in items) _selectedIds.remove(e['id']);
    } else {
      for (final e in items) _selectedIds.add(e['id']);
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
      final result = await _api.getTasksPaged(
        page: _currentPage,
        rowsPerPage: _rowsPerPage,
        colFilters: _colFilters,
      );
      _items = List<Map<String, dynamic>>.from(result['data'] as List);
      _total = result['total'] as int;
      if (_items.length < _rowsPerPage) {
        _total = _currentPage * _rowsPerPage + _items.length;
      }
      _loaded = true;
      debugPrint('=== TASKS | total=$_total rows=${_items.length} ===');
    } catch (e) {
      if (!_loaded) fetchError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      setBusy(false);
    }
  }

  Future<String?> addTask(Map<String, dynamic> data) async {
    try {
      await _api.addTask(data);
      _currentPage = 0;
      _loaded = false;
      await init();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> updateTask(dynamic id, Map<String, dynamic> data) async {
    try {
      await _api.updateTask(id, data);
      _loaded = false;
      await init();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> deleteTask(dynamic id) async {
    try {
      await _api.deleteTask(id);
      _selectedIds.remove(id);
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
      rows.add(exportCols.map((c) {
        if (c.key == 'sno') return '${item['id'] ?? i + 1}';
        if (c.key == 'start_date' ||
            c.key == 'due_date' ||
            c.key == 'created_at') {
          return fmtDate(item[c.key]);
        }
        return item[c.key]?.toString() ?? '';
      }).toList());
    }
    return rows
        .map((r) => r.map((c) => '"${c.replaceAll('"', '""')}"').join(','))
        .join('\n');
  }
}
