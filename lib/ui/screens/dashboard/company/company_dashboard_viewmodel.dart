import 'package:flutter/foundation.dart';
import 'package:stacked/stacked.dart';

import '../../../../app/app.locator.dart';
import '../../../../app/app.router.dart';
import '../../../../app/utils.dart';
import '../../../../models/permissions_model.dart';
import '../../../../models/token_response_model.dart';
import '../../../../services/api_services.dart';

class CompanyDashboardViewModel extends BaseViewModel {
  final _auth = locator<HippoAuthService>();

  TokenResponseModel? _user;
  PermissionsModel? _permissions;

  String get userName => _user?.name ?? '';
  String get userInitial =>
      userName.isNotEmpty ? userName[0].toUpperCase() : 'U';
  String get userEmail => _user?.email ?? '';
  String get role => _user?.role ?? '';
  bool get isEmployee => _user?.userType == 'employee';
  String? get employeeId => _user?.employeeId?.toString();

  // ── Permission helpers ────────────────────────────────────────────────────
  PermissionsModel get _perms => isEmployee
      ? (_permissions ?? PermissionsModel.companyDefault)
      : PermissionsModel.companyDefault;

  bool get canViewLeads => _perms.leads.canRead;
  bool get canViewClients => _perms.clients.canRead;
  bool get canViewEmployees => _perms.employees.canRead;
  bool get canViewTasks => _perms.task.canRead;
  bool get canViewBilling => _perms.bills.canRead;
  bool get canViewProducts => _perms.services.canRead;
  bool get canViewRoleManagement => _perms.roleManagement.canRead;
  bool get canViewMasters => _perms.masters.canRead;
  bool get canViewFollowup => _perms.followup.canRead;

  // ── Logo ──────────────────────────────────────────────────────────────────
  String? _logoUrl;
  String? get logoUrl => _logoUrl;

  Future<void> _fetchLogoUrl() async {
    try {
      final rows = await _auth.getCompanySettings('header');
      if (rows.isNotEmpty) {
        final url = rows.first['logo']?.toString();
        if (url != null && url.isNotEmpty) {
          _logoUrl = url;
          await _auth.cacheCompanyLogoUrl(url);
          return;
        }
      }
    } catch (_) {}
    _logoUrl = await _auth.getCachedCompanyLogoUrl();
  }

  Future<void> refreshLogo() async {
    await _fetchLogoUrl();
    notifyListeners();
  }

  // ── Filter state ──────────────────────────────────────────────────────────
  String filterType = 'year'; // year | month | day | range
  int selectedYear = DateTime.now().year;
  int selectedMonth = DateTime.now().month;
  List<int> availableYears = [];

  // Date range
  DateTime rangeStart =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime rangeEnd = DateTime.now();

  void setFilter(String type) {
    filterType = type;
    notifyListeners();
    loadDashboard();
  }

  void setYear(int year) {
    selectedYear = year;
    notifyListeners();
    loadDashboard();
  }

  void setMonth(int month) {
    selectedMonth = month;
    notifyListeners();
    loadDashboard();
  }

  void setDateRange(DateTime start, DateTime end) {
    rangeStart = start;
    rangeEnd = end;
    notifyListeners();
    loadDashboard();
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, String> get _filterParams {
    final p = <String, String>{'filterType': filterType};
    if (filterType == 'range') {
      p['startDate'] = _fmtDate(rangeStart);
      p['endDate'] = _fmtDate(rangeEnd);
    } else {
      p['year'] = selectedYear.toString();
      if (filterType == 'month') p['month'] = selectedMonth.toString();
    }
    if (isEmployee && employeeId != null) {
      p['selfOnly'] = 'true';
      p['employeeid'] = employeeId!;
    }
    return p;
  }

  // ── Stats ─────────────────────────────────────────────────────────────────
  int totalLeads = 0;
  int totalClients = 0;
  int totalInvoices = 0;
  // Raw doubles used for collection rate calculation
  double revenueRaw = 0;
  double collectedRaw = 0;
  double outstandingRaw = 0;
  // Formatted strings for display
  String revenue = '₹0';
  String collected = '₹0';
  String outstanding = '₹0';
  int totalTasks = 0;
  int followUps = 0;

  // collection rate = collectedRaw / revenueRaw
  double get collectionRate =>
      revenueRaw > 0 ? (collectedRaw / revenueRaw).clamp(0.0, 1.0) : 0.0;

  // ── Sales chart data ──────────────────────────────────────────────────────
  List<Map<String, dynamic>> salesTrend = [];
  List<Map<String, dynamic>> topClients = [];
  List<Map<String, dynamic>> salesByStatus = [];
  List<Map<String, dynamic>> recentSales = [];

  // ── Lead data ─────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> leadTrend = [];

  // ── Task chart data ───────────────────────────────────────────────────────
  List<Map<String, dynamic>> taskTrend = [];
  int taskTotalCreated = 0;
  int taskTotalCompleted = 0;

  // ── Employee / Team data ──────────────────────────────────────────────────
  List<Map<String, dynamic>> teamPerformance = [];

  // ── Follow-up data ────────────────────────────────────────────────────────
  List<Map<String, dynamic>> todayFollowups = [];

  String? fetchError;

  static String _fmt(dynamic val) {
    final d = val is num
        ? val.toDouble()
        : double.tryParse(val?.toString() ?? '') ?? 0.0;
    if (d >= 10000000) return '₹${(d / 10000000).toStringAsFixed(1)}Cr';
    if (d >= 100000) return '₹${(d / 100000).toStringAsFixed(1)}L';
    if (d >= 1000) return '₹${(d / 1000).toStringAsFixed(1)}K';
    return '₹${d.toStringAsFixed(0)}';
  }

  // ── Init & load ───────────────────────────────────────────────────────────
  Future<void> init() async {
    setBusy(true);
    fetchError = null;
    _user = await _auth.getStoredUser();
    if (isEmployee) {
      _permissions = await _auth.getStoredPermissions();
    }
    await _fetchLogoUrl();
    await loadDashboard();
    setBusy(false);
  }

  Future<void> loadDashboard() async {
    fetchError = null;
    notifyListeners();
    try {
      final params = _filterParams;
      // Always call all 6 APIs — fixed indices regardless of user type
      final results = await Future.wait([
        _auth.getCompanyDashboardStats(params).catchError((e) {
          debugPrint('stats error: $e');
          return <String, dynamic>{};
        }),
        _auth.getCompanyDashboardSales(params).catchError((e) {
          debugPrint('sales error: $e');
          return <String, dynamic>{};
        }),
        _auth.getCompanyDashboardTasks(params).catchError((e) {
          debugPrint('tasks error: $e');
          return <String, dynamic>{};
        }),
        _auth.getCompanyDashboardEmployees(params).catchError((e) {
          debugPrint('employees error: $e');
          return <String, dynamic>{};
        }),
        _auth.getCompanyDashboardFollowups(params).catchError((e) {
          debugPrint('followups error: $e');
          return <String, dynamic>{};
        }),
        _auth.getCompanyDashboardLeads(params).catchError((e) {
          debugPrint('leads error: $e');
          return <String, dynamic>{};
        }),
      ]);

      _applyStats(results[0]);
      _applySales(results[1]);
      _applyTasks(results[2]);
      _applyEmployees(results[3]);
      _applyFollowups(results[4]);
      _applyLeads(results[5]);
    } catch (e) {
      fetchError = e.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }

  void _applyStats(Map<String, dynamic> d) {
    if (d.isEmpty) return;
    final s = d['stats'] as Map<String, dynamic>? ?? {};
    totalLeads = _toInt(s['leads']);
    totalClients = _toInt(s['clients']);
    totalInvoices = _toInt(s['sales']);
    // Store raw doubles for correct collectionRate calculation
    revenueRaw = _toDouble(s['revenue']);
    collectedRaw = _toDouble(s['collected']);
    outstandingRaw = _toDouble(s['pending']);
    // Format for display
    revenue = _fmt(revenueRaw);
    collected = _fmt(collectedRaw);
    outstanding = _fmt(outstandingRaw);
    totalTasks = _toInt(s['tasks']);
    followUps = _toInt(s['followups']);
    // salesTrend and recentSales live in the stats endpoint
    salesTrend = _toList(d['salesTrend']);
    recentSales = _toList(d['recentSales']);
    // Available years
    final years = d['availableYears'];
    if (years is List && years.isNotEmpty) {
      availableYears = years.map((y) => _toInt(y)).toList();
      if (!availableYears.contains(selectedYear)) {
        selectedYear = availableYears.last;
      }
    }
    if (availableYears.isEmpty) availableYears = [DateTime.now().year];
  }

  void _applySales(Map<String, dynamic> d) {
    if (d.isEmpty) return;
    salesByStatus = _toList(d['byStatus']);
    topClients = _toList(d['topClients']);
  }

  void _applyTasks(Map<String, dynamic> d) {
    if (d.isEmpty) return;
    taskTrend = _toList(d['taskTrend']);
    taskTotalCreated = 0;
    taskTotalCompleted = 0;
    for (final s in _toList(d['byStatus'])) {
      final st = s['status']?.toString().toLowerCase() ?? '';
      final v = _toInt(s['value'] ?? s['count']);
      if (st == 'created' || st == 'total') taskTotalCreated += v;
      if (st == 'completed' || st == 'done') taskTotalCompleted += v;
    }
    if (taskTotalCreated == 0) {
      taskTotalCreated = taskTrend.fold(0, (s, e) => s + _toInt(e['total']));
    }
    if (taskTotalCompleted == 0) {
      taskTotalCompleted =
          taskTrend.fold(0, (s, e) => s + _toInt(e['completed']));
    }
  }

  void _applyEmployees(Map<String, dynamic> d) {
    if (d.isEmpty) return;
    teamPerformance = _toList(d['performance']);
  }

  void _applyFollowups(Map<String, dynamic> d) {
    if (d.isEmpty) return;
    todayFollowups = _toList(d['todayFollowups']);
  }

  void _applyLeads(Map<String, dynamic> d) {
    if (d.isEmpty) return;
    final raw = _toList(
        d['leadTrend'] ?? d['trend'] ?? d['conversionTrend'] ?? d['leads']);
    // Normalise alternate field names so the chart always finds 'newLeads' and 'converted'
    leadTrend = raw.map((item) {
      final m = Map<String, dynamic>.from(item);
      if (!m.containsKey('newLeads')) {
        m['newLeads'] = m['new'] ?? m['new_leads'] ?? m['total'] ?? 0;
      }
      if (!m.containsKey('converted')) {
        m['converted'] = m['convertedLeads'] ?? m['converted_leads'] ?? 0;
      }
      return m;
    }).toList();
  }

  static int _toInt(dynamic v) =>
      v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

  static double _toDouble(dynamic v) =>
      v is double ? v : double.tryParse(v?.toString() ?? '') ?? 0.0;

  static List<Map<String, dynamic>> _toList(dynamic v) {
    if (v is List) {
      return v
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  Future<void> logout() async {
    await _auth.logout();
    navigationService.clearStackAndShow(Routes.loginView);
  }
}
