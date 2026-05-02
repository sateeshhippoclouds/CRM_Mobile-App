import 'package:flutter/foundation.dart';
import 'package:stacked/stacked.dart';

import '../../../../../app/app.locator.dart';
import '../../../../../models/permissions_model.dart';
import '../../../../../models/token_response_model.dart';
import '../../../../../services/api_services.dart';

class LeadColumnDef {
  const LeadColumnDef(this.label, this.key, this.width,
      {this.filterable = true, this.alwaysVisible = false});
  final String label;
  final String key;
  final double width;
  final bool filterable;
  final bool alwaysVisible;
}

class FollowupColumnDef {
  const FollowupColumnDef(this.label, this.key, this.width,
      {this.filterable = true, this.alwaysVisible = false});
  final String label;
  final String key;
  final double width;
  final bool filterable;
  final bool alwaysVisible;
}

class CompanyLeadsViewModel extends BaseViewModel {
  final _api = locator<HippoAuthService>();

  TokenResponseModel? _user;
  PermissionsModel? _permissions;

  bool get _isEmployee => _user?.userType == 'employee';
  PermissionsModel get _perms => _isEmployee
      ? (_permissions ?? PermissionsModel.companyDefault)
      : PermissionsModel.companyDefault;

  bool get canRead => _perms.leads.canRead;
  bool get canWrite => _perms.leads.canWrite;
  bool get canUpdate => _perms.leads.canUpdate;
  bool get canDelete => _perms.leads.canDelete;
  bool get canReadFollowup => _perms.followup.canRead;
  bool get canWriteFollowup => _perms.followup.canWrite;
  bool get canUpdateFollowup => _perms.followup.canUpdate;
  bool get canDeleteFollowup => _perms.followup.canDelete;

  // ── Leads state ───────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _items = [];
  String _leadsQuery = '';
  String? fetchError;
  bool _loaded = false;
  String _pipeline = 'pipeline';

  int _currentPage = 0;
  int _rowsPerPage = 25;
  int _total = 0;

  final Map<String, String> _colFilters = {};
  final Set<dynamic> _selectedIds = {};

  final Map<String, bool> _colVisible = {
    'full_name': true,
    'email': true,
    'phone': true,
    'alternate_number': true,
    'source_type_name': true,
    'address': true,
    'city_name': true,
    'country_name': true,
    'interest_level_name': true,
    'lead_stage_name': true,
    'category_name': true,
    'assigned_to_name': true,
    'notes': true,
    'created_at': true,
  };

  // ── Follow-ups state ──────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _followupItems = [];
  String _followupsQuery = '';
  String? fetchFollowupsError;
  bool _followupsLoaded = false;
  bool _followupsBusy = false;

  int _followupsPage = 0;
  int _followupsRowsPerPage = 25;
  int _followupsTotal = 0;

  final Map<String, String> _followupColFilters = {};
  final Set<dynamic> _followupSelectedIds = {};
  final Map<String, bool> _followupColVisible = {
    'employee_name': true,
    'status': true,
    'svc_name': true,
    'svc_duration': false,
    'svc_base_price': true,
    'svc_tax_rate': false,
    'svc_original_duration': false,
    'nextFollowUpDate': true,
    'wantAddServices': true,
    'negotiate': true,
    'quotation_title': true,
    'created_at': true,
    'notes': false,
  };

  // ── Static config ─────────────────────────────────────────────────────────────
  static const List<Map<String, dynamic>> pipelineOptions = [
    {'label': 'Pipeline', 'value': 'pipeline', 'color': 0xff3B82F6},
    {'label': 'Active', 'value': 'active', 'color': 0xff16A34A},
    {'label': 'Inactive', 'value': 'inactive', 'color': 0xffDC2626},
    {'label': 'Bulk Failed', 'value': 'bulkfailed', 'color': 0xffF59E0B},
  ];

  static const List<int> rowsPerPageOptions = [25, 50, 100];

  static const List<FollowupColumnDef> allFollowupColumns = [
    FollowupColumnDef('', 'checkbox', 48, filterable: false, alwaysVisible: true),
    FollowupColumnDef('S.No', 'sno', 60, filterable: false, alwaysVisible: true),
    FollowupColumnDef('Lead Name', 'lead_name', 180, alwaysVisible: true),
    FollowupColumnDef('Assigned To', 'employee_name', 150),
    FollowupColumnDef('Status', 'status', 130),
    FollowupColumnDef('Service Name', 'svc_name', 180, filterable: false),
    FollowupColumnDef('Duration', 'svc_duration', 90, filterable: false),
    FollowupColumnDef('Base Price', 'svc_base_price', 110, filterable: false),
    FollowupColumnDef('Tax', 'svc_tax_rate', 90, filterable: false),
    FollowupColumnDef('Req Duration', 'svc_original_duration', 110, filterable: false),
    FollowupColumnDef('Next Follow-Up', 'nextFollowUpDate', 130, filterable: false),
    FollowupColumnDef('Add Services', 'wantAddServices', 110),
    FollowupColumnDef('Negotiate', 'negotiate', 100),
    FollowupColumnDef('Quotation', 'quotation_title', 150),
    FollowupColumnDef('Created On', 'created_at', 130, filterable: false),
    FollowupColumnDef('Notes', 'notes', 180),
    FollowupColumnDef('Action', 'action', 90, filterable: false, alwaysVisible: true),
  ];

  // Fields NOT in backend fieldToColumnMap — filtered client-side
  static const _clientSideFilterFields = {'alternate_number', 'address'};

  static const List<LeadColumnDef> allColumns = [
    LeadColumnDef('', 'checkbox', 48, filterable: false, alwaysVisible: true),
    LeadColumnDef('S.No', 'sno', 60, filterable: false, alwaysVisible: true),
    LeadColumnDef('Lead Name', 'lead_name', 180, alwaysVisible: true),
    LeadColumnDef('Contact Person', 'full_name', 160),
    LeadColumnDef('Email', 'email', 210),
    LeadColumnDef('Phone', 'phone', 140),
    LeadColumnDef('Alternate', 'alternate_number', 140),
    LeadColumnDef('Source', 'source_type_name', 130),
    LeadColumnDef('Address', 'address', 180),
    LeadColumnDef('City', 'city_name', 120),
    LeadColumnDef('Country', 'country_name', 120),
    LeadColumnDef('Interest Level', 'interest_level_name', 130),
    LeadColumnDef('Lead Stage', 'lead_stage_name', 120),
    LeadColumnDef('Category', 'category_name', 140),
    LeadColumnDef('Assigned To', 'assigned_to_name', 150),
    LeadColumnDef('Notes', 'notes', 180),
    LeadColumnDef('Created On', 'created_at', 190, filterable: false),
    LeadColumnDef('Action', 'action', 90, filterable: false, alwaysVisible: true),
  ];

  // ── Leads getters ─────────────────────────────────────────────────────────────
  String get pipeline => _pipeline;
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

  List<LeadColumnDef> get visibleColumns => allColumns
      .where((c) => c.alwaysVisible || (_colVisible[c.key] ?? true))
      .toList();

  List<Map<String, dynamic>> get items {
    var list = _items;
    if (_leadsQuery.isNotEmpty) {
      list = list.where((e) {
        return (e['lead_name'] ?? '').toString().toLowerCase().contains(_leadsQuery) ||
            (e['full_name'] ?? '').toString().toLowerCase().contains(_leadsQuery) ||
            (e['email'] ?? '').toString().toLowerCase().contains(_leadsQuery) ||
            (e['city_name'] ?? '').toString().toLowerCase().contains(_leadsQuery);
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

  // ── Follow-ups getters ────────────────────────────────────────────────────────
  bool get followupsBusy => _followupsBusy;
  int get followupsPage => _followupsPage;
  int get followupsRowsPerPage => _followupsRowsPerPage;
  int get followupsTotal => _followupsTotal;
  bool get followupsHasPrev => _followupsPage > 0;
  bool get followupsHasNext =>
      (_followupsPage + 1) * _followupsRowsPerPage < _followupsTotal;
  int get followupsPageStart =>
      _followupsTotal == 0 ? 0 : _followupsPage * _followupsRowsPerPage + 1;
  int get followupsPageEnd =>
      _followupsPage * _followupsRowsPerPage + followups.length;

  bool get followupHasActiveFilters => _followupColFilters.isNotEmpty;
  Map<String, String> get followupColFilters => Map.unmodifiable(_followupColFilters);
  Map<String, bool> get followupColVisible => Map.unmodifiable(_followupColVisible);
  bool get followupHasSelection => _followupSelectedIds.isNotEmpty;
  int get followupSelectedCount => _followupSelectedIds.length;

  bool followupIsSelected(dynamic id) => _followupSelectedIds.contains(id);

  bool get allFollowupCurrentSelected {
    if (followups.isEmpty) return false;
    return followups.every((e) => _followupSelectedIds.contains(e['id']));
  }

  bool get someFollowupCurrentSelected =>
      followups.any((e) => _followupSelectedIds.contains(e['id']));

  List<FollowupColumnDef> get visibleFollowupColumns => allFollowupColumns
      .where((c) => c.alwaysVisible || (_followupColVisible[c.key] ?? true))
      .toList();

  // Fields from backend: id, lead_name, employee_name, followUpDate, services,
  // status, notes, nextFollowUpDate, negotiate, wantAddServices,
  // quotation_title, created_at
  List<Map<String, dynamic>> get followups {
    if (_followupsQuery.isEmpty) return _followupItems;
    final q = _followupsQuery;
    return _followupItems.where((f) {
      return (f['lead_name'] ?? '').toString().toLowerCase().contains(q) ||
          (f['employee_name'] ?? '').toString().toLowerCase().contains(q) ||
          (f['status'] ?? '').toString().toLowerCase().contains(q) ||
          (f['notes'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
  }

  // ── Leads methods ─────────────────────────────────────────────────────────────
  void searchLeads(String q) {
    _leadsQuery = q.toLowerCase().trim();
    notifyListeners();
  }

  void setPipeline(String value) {
    if (_pipeline == value) return;
    _pipeline = value;
    _currentPage = 0;
    _loaded = false;
    _selectedIds.clear();
    init();
  }

  void setColFilter(String field, String value) {
    if (value.trim().isEmpty) {
      _colFilters.remove(field);
    } else {
      _colFilters[field] = value.trim();
    }
    debugPrint('=== LEAD FILTER: $field="${value.trim()}" | active: $_colFilters ===');
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
      for (final e in items) { _selectedIds.remove(e['id']); }
    } else {
      for (final e in items) { _selectedIds.add(e['id']); }
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedIds.clear();
    notifyListeners();
  }

  void nextPage() {
    if (hasNext) { _currentPage++; init(); }
  }

  void prevPage() {
    if (hasPrev) { _currentPage--; init(); }
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
      final result = await _api.getLeadsPaged(
        pipeline: _pipeline,
        page: _currentPage,
        rowsPerPage: _rowsPerPage,
        colFilters: backendFilters,
        selfOnly: _isEmployee && _perms.selfOnly,
        employeeId: _user?.employeeId?.toString(),
      );
      _items = List<Map<String, dynamic>>.from(result['data'] as List);
      _total = result['total'] as int;
      // Backend COUNT ignores pipeline filter; clamp total to actual data size
      // when fewer rows returned than page size (last/only page).
      if (_items.length < _rowsPerPage) {
        _total = _currentPage * _rowsPerPage + _items.length;
      }
      _loaded = true;
      debugPrint('=== LEADS DATA ===');
      debugPrint('Backend total: $_total | After filters: ${items.length}');
      for (final e in items) { debugPrint(e.toString()); }
      debugPrint('=== END LEADS ===');
    } catch (e) {
      if (!_loaded) fetchError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      setBusy(false);
    }
  }

  // ── Follow-ups methods ────────────────────────────────────────────────────────
  void searchFollowups(String q) {
    _followupsQuery = q.toLowerCase().trim();
    notifyListeners();
  }

  void setFollowupsRowsPerPage(int value) {
    if (_followupsRowsPerPage == value) return;
    _followupsRowsPerPage = value;
    _followupsPage = 0;
    _followupsLoaded = false;
    initFollowups();
  }

  void nextFollowupsPage() {
    if (followupsHasNext) { _followupsPage++; initFollowups(); }
  }

  void prevFollowupsPage() {
    if (followupsHasPrev) { _followupsPage--; initFollowups(); }
  }

  void setFollowupColFilter(String field, String value) {
    if (value.trim().isEmpty) {
      _followupColFilters.remove(field);
    } else {
      _followupColFilters[field] = value.trim();
    }
    _followupsPage = 0;
    _followupsLoaded = false;
    initFollowups();
  }

  void clearAllFollowupFilters() {
    _followupColFilters.clear();
    _followupsPage = 0;
    _followupsLoaded = false;
    initFollowups();
  }

  void toggleFollowupColumn(String key) {
    _followupColVisible[key] = !(_followupColVisible[key] ?? true);
    notifyListeners();
  }

  void setAllFollowupColumnsVisible(bool visible) {
    for (final key in _followupColVisible.keys.toList()) {
      _followupColVisible[key] = visible;
    }
    notifyListeners();
  }

  void toggleFollowupRowSelection(dynamic id) {
    if (_followupSelectedIds.contains(id)) {
      _followupSelectedIds.remove(id);
    } else {
      _followupSelectedIds.add(id);
    }
    notifyListeners();
  }

  void toggleFollowupSelectAll() {
    if (allFollowupCurrentSelected) {
      for (final e in followups) { _followupSelectedIds.remove(e['id']); }
    } else {
      for (final e in followups) { _followupSelectedIds.add(e['id']); }
    }
    notifyListeners();
  }

  void clearFollowupSelection() {
    _followupSelectedIds.clear();
    notifyListeners();
  }

  String buildFollowupCsvContent() {
    final exportCols = visibleFollowupColumns
        .where((c) => c.key != 'checkbox' && c.key != 'action')
        .toList();
    final exportItems = followupHasSelection
        ? _followupItems.where((e) => _followupSelectedIds.contains(e['id'])).toList()
        : _followupItems;
    final headers = exportCols.map((c) => c.label).toList();
    final rows = <List<String>>[headers];
    for (int i = 0; i < exportItems.length; i++) {
      final item = exportItems[i];
      rows.add(exportCols.map((c) {
        if (c.key == 'sno') return '${i + 1}';
        return item[c.key]?.toString() ?? '';
      }).toList());
    }
    return rows
        .map((r) => r.map((c) => '"${c.replaceAll('"', '""')}"').join(','))
        .join('\n');
  }

  Future<void> initFollowups() async {
    _followupsBusy = true;
    fetchFollowupsError = null;
    notifyListeners();
    _user ??= await _api.getStoredUser();
    if (_isEmployee) _permissions ??= await _api.getStoredPermissions();
    try {
      final result = await _api.getFollowupsPaged(
        page: _followupsPage,
        rowsPerPage: _followupsRowsPerPage,
        colFilters: _followupColFilters,
        selfOnly: _isEmployee && _perms.selfOnly,
        employeeId: _user?.employeeId?.toString(),
      );
      _followupItems = List<Map<String, dynamic>>.from(result['data'] as List);
      _followupsTotal = result['total'] as int;
      _followupsLoaded = true;
      debugPrint('=== FOLLOWUPS DATA ===');
      debugPrint('Total: $_followupsTotal | Loaded: ${_followupItems.length}');
      for (final e in _followupItems) { debugPrint(e.toString()); }
      debugPrint('=== END FOLLOWUPS ===');
    } catch (e) {
      if (!_followupsLoaded) {
        fetchFollowupsError = e.toString().replaceFirst('Exception: ', '');
      }
    } finally {
      _followupsBusy = false;
      notifyListeners();
    }
  }

  Future<String?> addFollowup(Map<String, dynamic> data) async {
    try {
      await _api.addFollowup(data);
      _followupsLoaded = false;
      await initFollowups();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> updateFollowup(dynamic id, Map<String, dynamic> data) async {
    try {
      await _api.updateFollowup(id, data);
      _followupsLoaded = false;
      await initFollowups();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> deleteFollowup(dynamic id) async {
    try {
      await _api.deleteFollowup(id);
      _followupsLoaded = false;
      await initFollowups();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  // ── Lead CRUD ─────────────────────────────────────────────────────────────────
  Future<String?> addLead(Map<String, dynamic> data) async {
    try {
      await _api.addLead(data);
      _currentPage = 0;
      _loaded = false;
      await init();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> updateLead(dynamic id, Map<String, dynamic> data) async {
    try {
      await _api.updateLead(id, _pipeline, data);
      _loaded = false;
      await init();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> deleteLead(dynamic id) async {
    try {
      await _api.deleteLead(id, _pipeline);
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
        if (c.key == 'sno') return '${i + 1}';
        return item[c.key]?.toString() ?? '';
      }).toList());
    }
    return rows
        .map((r) => r.map((c) => '"${c.replaceAll('"', '""')}"').join(','))
        .join('\n');
  }
}
