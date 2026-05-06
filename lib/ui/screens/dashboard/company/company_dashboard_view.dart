import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'company_dashboard_viewmodel.dart';
import 'screens/company_clients_view.dart';
import 'screens/company_employees_view.dart';
import 'screens/company_leads_view.dart';
import 'screens/company_products_view.dart';
import 'screens/company_role_management_view.dart';
import 'screens/company_sales_billing_view.dart';
import 'screens/company_settings_view.dart';
import 'screens/company_tasks_view.dart';
import 'screens/masters/company_location_view.dart';
import 'screens/masters/company_masters_clients_view.dart';
import 'screens/masters/company_masters_leads_view.dart';
import 'screens/masters/company_others_view.dart';
import 'screens/masters/company_terms_view.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _blue = Color(0xff3756DF);
const _red = Color(0xffEF4444);
const _green = Color(0xff22C55E);
const _orange = Color(0xffF59E0B);
const _purple = Color(0xff7C3AED);
const _cyan = Color(0xff0EA5E9);
const _text1 = Color(0xff1A1F36);
const _text2 = Color(0xff6B7280);
const _text3 = Color(0xff9CA3AF);
const _bg = Color(0xffF5F5F7);

// Bar chart colors matching web (each client gets own color)
const _barColors = [
  _blue,
  _purple,
  _cyan,
  _green,
  _orange,
  Color(0xffEC4899),
];

// ─────────────────────────────────────────────────────────────────────────────
class CompanyDashboardView extends StatelessWidget {
  const CompanyDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<CompanyDashboardViewModel>.reactive(
      viewModelBuilder: () => CompanyDashboardViewModel(),
      onViewModelReady: (m) => m.init(),
      builder: (context, model, child) {
        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: _text1),
            title: RichText(
              text: const TextSpan(children: [
                TextSpan(
                    text: 'hippo',
                    style: TextStyle(
                        color: _blue,
                        fontWeight: FontWeight.w800,
                        fontSize: 18)),
                TextSpan(
                    text: 'cloud',
                    style: TextStyle(
                        color: _red,
                        fontWeight: FontWeight.w800,
                        fontSize: 18)),
              ]),
            ),
            actions: [
              if (!model.isEmployee)
                IconButton(
                  icon: const Icon(Icons.settings_rounded,
                      color: _text1, size: 22),
                  tooltip: 'Settings',
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CompanySettingsView()),
                    );
                    model.refreshLogo();
                  },
                ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: _blue,
                  child: Text(model.userInitial,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ),
              ),
            ],
          ),
          drawer: _CompanyDrawer(model: model),
          body: model.isBusy
              ? const Center(child: CircularProgressIndicator(color: _blue))
              : RefreshIndicator(
                  onRefresh: model.init,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.fromLTRB(12, 12, 12, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header + Filter bar
                        _DashboardHeader(model: model),
                        const SizedBox(height: 12),
                        // Stats 2×4 grid
                        _StatsGrid(model: model),
                        const SizedBox(height: 14),
                        // Revenue vs Collections
                        _RevenueChart(model: model),
                        const SizedBox(height: 14),
                        // Collection Rate donut
                        _CollectionRateCard(model: model),
                        const SizedBox(height: 14),
                        // Lead Conversion Trend
                        if (model.leadTrend.isNotEmpty) ...[
                          _LeadConversionChart(model: model),
                          const SizedBox(height: 14),
                        ],
                        // Task Activity
                        _TaskActivityCard(model: model),
                        const SizedBox(height: 14),
                        // Top Clients bar chart
                        if (model.topClients.isNotEmpty) ...[
                          _TopClientsCard(model: model),
                          const SizedBox(height: 14),
                        ],
                        // Sales by Status
                        if (model.salesByStatus.isNotEmpty) ...[
                          _SalesByStatusCard(model: model),
                          const SizedBox(height: 14),
                        ],
                        // Team Performance (all users)
                        if (model.teamPerformance.isNotEmpty) ...[
                          _TeamPerformanceCard(model: model),
                          const SizedBox(height: 14),
                        ],
                        // Today's Follow-ups
                        _TodayFollowupsCard(model: model),
                        const SizedBox(height: 14),
                        // Recent Invoices
                        if (model.recentSales.isNotEmpty)
                          _RecentInvoicesCard(model: model),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

// ── Drawer ────────────────────────────────────────────────────────────────────

class _CompanyDrawer extends StatefulWidget {
  const _CompanyDrawer({required this.model});
  final CompanyDashboardViewModel model;

  @override
  State<_CompanyDrawer> createState() => _CompanyDrawerState();
}

class _CompanyDrawerState extends State<_CompanyDrawer> {
  bool _mastersExpanded = false;

  void _navigate(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            color: _blue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.model.logoUrl != null)
                  _DrawerLogo(
                      url: widget.model.logoUrl!,
                      fallbackInitial: widget.model.userInitial)
                else
                  _InitialsAvatar(initial: widget.model.userInitial),
                const SizedBox(height: 10),
                Text(widget.model.userName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
                Text(widget.model.role,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _NavItem(
                    icon: Icons.dashboard_rounded,
                    label: 'Dashboard',
                    selected: true,
                    onTap: () => Navigator.pop(context)),
                if (widget.model.canViewMasters)
                  _MastersItem(
                    expanded: _mastersExpanded,
                    onToggle: () =>
                        setState(() => _mastersExpanded = !_mastersExpanded),
                    children: [
                      _SubNavItem(
                          label: 'Leads',
                          onTap: () => _navigate(
                              context, const CompanyMastersLeadsView())),
                      _SubNavItem(
                          label: 'Clients',
                          onTap: () => _navigate(
                              context, const CompanyMastersClientsView())),
                      _SubNavItem(
                          label: 'Location',
                          onTap: () =>
                              _navigate(context, const CompanyLocationView())),
                      _SubNavItem(
                          label: 'Others',
                          onTap: () =>
                              _navigate(context, const CompanyOthersView())),
                      _SubNavItem(
                          label: 'Terms',
                          onTap: () =>
                              _navigate(context, const CompanyTermsView())),
                    ],
                  ),
                if (widget.model.canViewLeads)
                  _NavItem(
                      icon: Icons.bar_chart_rounded,
                      label: 'Leads',
                      onTap: () =>
                          _navigate(context, const CompanyLeadsView())),
                if (widget.model.canViewClients)
                  _NavItem(
                      icon: Icons.people_rounded,
                      label: 'Clients',
                      onTap: () =>
                          _navigate(context, const CompanyClientsView())),
                if (widget.model.canViewTasks)
                  _NavItem(
                      icon: Icons.task_alt_rounded,
                      label: 'Tasks',
                      onTap: () =>
                          _navigate(context, const CompanyTasksView())),
                if (widget.model.canViewBilling)
                  _NavItem(
                      icon: Icons.receipt_long_rounded,
                      label: 'Sales & Billing',
                      onTap: () => _navigate(
                          context, const CompanySalesBillingView())),
                if (widget.model.canViewEmployees)
                  _NavItem(
                      icon: Icons.badge_rounded,
                      label: 'Employees',
                      onTap: () =>
                          _navigate(context, const CompanyEmployeesView())),
                if (widget.model.canViewProducts)
                  _NavItem(
                      icon: Icons.inventory_2_rounded,
                      label: 'Products',
                      onTap: () =>
                          _navigate(context, const CompanyProductsView())),
                if (widget.model.canViewRoleManagement)
                  _NavItem(
                      icon: Icons.manage_accounts_rounded,
                      label: 'Role Management',
                      onTap: () => _navigate(
                          context, const CompanyRoleManagementView())),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: _red),
            title: const Text('Logout',
                style: TextStyle(color: _red, fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              widget.model.logout();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DrawerLogo extends StatefulWidget {
  const _DrawerLogo({required this.url, required this.fallbackInitial});
  final String url;
  final String fallbackInitial;

  @override
  State<_DrawerLogo> createState() => _DrawerLogoState();
}

class _DrawerLogoState extends State<_DrawerLogo> {
  bool _error = false;

  @override
  void didUpdateWidget(_DrawerLogo old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _error = false;
  }

  @override
  Widget build(BuildContext context) {
    if (_error) return _InitialsAvatar(initial: widget.fallbackInitial);
    return Container(
      height: 52,
      constraints: const BoxConstraints(maxWidth: 180),
      child: Image.network(
        widget.url,
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        loadingBuilder: (_, child, p) =>
            p == null ? child : _InitialsAvatar(initial: widget.fallbackInitial),
        errorBuilder: (_, __, ___) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => setState(() => _error = true));
          return _InitialsAvatar(initial: widget.fallbackInitial);
        },
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initial});
  final String initial;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.white.withValues(alpha: 0.2),
      child: Text(initial,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem(
      {required this.icon,
      required this.label,
      this.selected = false,
      required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: selected ? _blue : _text2, size: 22),
      title: Text(label,
          style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? _blue : _text1)),
      tileColor: selected ? const Color(0xffEEF1FB) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: onTap,
    );
  }
}

class _MastersItem extends StatelessWidget {
  const _MastersItem(
      {required this.expanded,
      required this.onToggle,
      required this.children});
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ListTile(
        leading: const Icon(Icons.folder_rounded, color: _text2, size: 22),
        title: const Text('Masters',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _text1)),
        trailing: Icon(
            expanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: _text2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        onTap: onToggle,
      ),
      if (expanded)
        Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(children: children)),
    ]);
  }
}

class _SubNavItem extends StatelessWidget {
  const _SubNavItem({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.circle, size: 6, color: _text3),
      title: Text(label,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xff374151))),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      dense: true,
      onTap: onTap,
    );
  }
}

// ── Dashboard Header + Filter ─────────────────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.model});
  final CompanyDashboardViewModel model;

  static const _filterLabels = ['Yearly', 'Monthly', 'Single Day', 'Date Range'];
  static const _filterValues = ['year', 'month', 'day', 'range'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _displayDate(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: const Color(0xffEEF1FB),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.filter_alt_rounded, color: _blue, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Dashboard',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _text1)),
                Text(
                    model.isEmployee ? 'My data' : 'All team data',
                    style: const TextStyle(fontSize: 11, color: _text3)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          // Filter type tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_filterLabels.length, (i) {
                final selected = model.filterType == _filterValues[i];
                return Padding(
                  padding: EdgeInsets.only(
                      right: i < _filterLabels.length - 1 ? 8 : 0),
                  child: GestureDetector(
                    onTap: () => model.setFilter(_filterValues[i]),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected ? _blue : const Color(0xffF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                        border: selected
                            ? null
                            : Border.all(color: const Color(0xffE5E7EB)),
                      ),
                      child: Text(_filterLabels[i],
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : _text2)),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 10),
          // Secondary controls depending on filter type
          if (model.filterType == 'range') ...[
            // Date range pickers
            Row(children: [
              Expanded(
                child: _DatePickerButton(
                  label: 'From',
                  date: model.rangeStart,
                  displayText: _displayDate(model.rangeStart),
                  firstDate: DateTime(2020),
                  lastDate: model.rangeEnd,
                  onPicked: (d) =>
                      model.setDateRange(d, model.rangeEnd),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DatePickerButton(
                  label: 'To',
                  date: model.rangeEnd,
                  displayText: _displayDate(model.rangeEnd),
                  firstDate: model.rangeStart,
                  lastDate: DateTime(2100),
                  onPicked: (d) =>
                      model.setDateRange(model.rangeStart, d),
                ),
              ),
            ]),
          ] else ...[
            // Year + optional month selectors
            Row(children: [
              Expanded(
                child: _DropdownBox<int>(
                  value: model.selectedYear,
                  items: (model.availableYears.isEmpty
                          ? [DateTime.now().year]
                          : model.availableYears)
                      .map((y) =>
                          DropdownMenuItem(value: y, child: Text('$y')))
                      .toList(),
                  onChanged: (y) {
                    if (y != null) model.setYear(y);
                  },
                ),
              ),
              if (model.filterType == 'month') ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _DropdownBox<int>(
                    value: model.selectedMonth,
                    items: List.generate(
                        12,
                        (i) => DropdownMenuItem(
                            value: i + 1, child: Text(_months[i]))),
                    onChanged: (m) {
                      if (m != null) model.setMonth(m);
                    },
                  ),
                ),
              ],
            ]),
          ],
        ],
      ),
    );
  }
}

class _DropdownBox<T> extends StatelessWidget {
  const _DropdownBox(
      {required this.value,
      required this.items,
      required this.onChanged});
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xffF3F4F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: _text1),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: _text2),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── Date Picker Button ────────────────────────────────────────────────────────

class _DatePickerButton extends StatelessWidget {
  const _DatePickerButton({
    required this.label,
    required this.date,
    required this.displayText,
    required this.firstDate,
    required this.lastDate,
    required this.onPicked,
  });
  final String label;
  final DateTime date;
  final String displayText;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onPicked;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: firstDate,
          lastDate: lastDate,
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(primary: _blue),
            ),
            child: child!,
          ),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xffF3F4F6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xffE5E7EB)),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today_rounded, size: 14, color: _blue),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 9, color: _text3)),
                Text(displayText,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _text1)),
              ],
            ),
          ),
          const Icon(Icons.keyboard_arrow_down_rounded,
              size: 16, color: _text2),
        ]),
      ),
    );
  }
}

// ── Stats Grid ────────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.model});
  final CompanyDashboardViewModel model;

  @override
  Widget build(BuildContext context) {
    final stats = [
      _S('Total Leads', '${model.totalLeads}', 'in period',
          Icons.person_search_rounded, _blue, const Color(0xffEEF1FB)),
      _S('Clients', '${model.totalClients}', 'active accounts',
          Icons.people_rounded, _blue, const Color(0xffEEF1FB)),
      _S('Invoices', '${model.totalInvoices}', 'non-draft',
          Icons.receipt_long_rounded, _purple, const Color(0xffEDE9FE)),
      _S('Revenue', model.revenue, 'total billed',
          Icons.attach_money_rounded, _green, const Color(0xffDCFCE7)),
      _S('Collected', model.collected, 'received',
          Icons.account_balance_wallet_rounded, _cyan,
          const Color(0xffE0F2FE)),
      _S('Outstanding', model.outstanding, 'pending',
          Icons.trending_down_rounded, _red, const Color(0xffFEE2E2)),
      _S('Tasks', '${model.totalTasks}', 'in period',
          Icons.task_alt_rounded, _orange, const Color(0xffFEF3C7)),
      _S('Follow-ups', '${model.followUps}', 'in period',
          Icons.phone_callback_rounded, _text2, const Color(0xffF3F4F6)),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.2,
      ),
      itemCount: stats.length,
      itemBuilder: (_, i) => _StatCard(s: stats[i]),
    );
  }
}

class _S {
  const _S(this.label, this.value, this.sub, this.icon, this.iconColor,
      this.iconBg);
  final String label, value, sub;
  final IconData icon;
  final Color iconColor, iconBg;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.s});
  final _S s;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: s.iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(s.icon, color: s.iconColor, size: 20),
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(s.value,
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _text1)),
          ),
          const SizedBox(height: 1),
          Text(s.label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff374151))),
          Text(s.sub,
              style: const TextStyle(fontSize: 10, color: _text3)),
        ],
      ),
    );
  }
}

// ── Revenue vs Collections Line Chart ────────────────────────────────────────

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.model});
  final CompanyDashboardViewModel model;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('REVENUE VS COLLECTIONS',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: _text3)),
          const SizedBox(height: 10),
          model.salesTrend.isEmpty
              ? const SizedBox(
                  height: 180,
                  child: _EmptyChart(message: 'No revenue data'))
              : SizedBox(
                  height: 200,
                  child: CustomPaint(
                    painter: _LineChartPainter(
                      data: model.salesTrend,
                      series: const [
                        _LS(key: 'revenue', color: _blue),
                        _LS(key: 'collected', color: _green),
                      ],
                      labelKey: 'name',
                    ),
                    size: const Size(double.infinity, 200),
                  ),
                ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Dot(color: _green, label: 'Collected'),
              SizedBox(width: 20),
              _Dot(color: _blue, label: 'Revenue'),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Collection Rate Donut ─────────────────────────────────────────────────────

class _CollectionRateCard extends StatelessWidget {
  const _CollectionRateCard({required this.model});
  final CompanyDashboardViewModel model;

  @override
  Widget build(BuildContext context) {
    final rate = model.collectionRate;
    final pct = (rate * 100).round();
    // Red arc = pending (uncollected), gray = collected
    final pendingFrac = 1.0 - rate;

    return _Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('COLLECTION RATE',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: _text3)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Donut chart
              SizedBox(
                width: 130,
                height: 130,
                child: CustomPaint(
                  painter: _DonutPainter(
                    collectedFrac: rate,
                    pendingFrac: pendingFrac,
                    centerText: '$pct%',
                    subText: 'collected',
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Legend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LegendRow(
                        color: _blue,
                        label: 'Billed',
                        value: model.revenue),
                    const SizedBox(height: 10),
                    _LegendRow(
                        color: _green,
                        label: 'Received',
                        value: model.collected),
                    const SizedBox(height: 10),
                    _LegendRow(
                        color: _red,
                        label: 'Pending',
                        value: model.outstanding),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow(
      {required this.color, required this.label, required this.value});
  final Color color;
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w500, color: _text2)),
      const Spacer(),
      Text(value,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: _text1)),
    ]);
  }
}

// ── Task Activity Chart ───────────────────────────────────────────────────────

class _TaskActivityCard extends StatelessWidget {
  const _TaskActivityCard({required this.model});
  final CompanyDashboardViewModel model;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TASK ACTIVITY — CREATED VS COMPLETED',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: _text3)),
          const SizedBox(height: 10),
          model.taskTrend.isEmpty
              ? const SizedBox(
                  height: 150,
                  child: _EmptyChart(message: 'No task data'))
              : SizedBox(
                  height: 160,
                  child: CustomPaint(
                    painter: _LineChartPainter(
                      data: model.taskTrend,
                      series: const [
                        _LS(key: 'completed', color: _green),
                        _LS(key: 'total', color: _orange),
                      ],
                      labelKey: 'name',
                    ),
                    size: const Size(double.infinity, 160),
                  ),
                ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _Dot(color: _green, label: 'Completed'),
              const SizedBox(width: 20),
              const _Dot(color: _orange, label: 'Created'),
              const Spacer(),
              // Created count badge
              if (model.taskTotalCreated > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xffEEF1FB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                      '● Created ${model.taskTotalCreated}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _blue)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Lead Conversion Trend ─────────────────────────────────────────────────────

class _LeadConversionChart extends StatelessWidget {
  const _LeadConversionChart({required this.model});
  final CompanyDashboardViewModel model;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('LEAD CONVERSION TREND — NEW VS CONVERTED',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: _text3)),
          const SizedBox(height: 14),
          SizedBox(
            height: 190,
            child: CustomPaint(
              painter: _LineChartPainter(
                data: model.leadTrend,
                series: const [
                  _LS(key: 'newLeads', color: _blue),
                  _LS(key: 'converted', color: _green),
                ],
                labelKey: 'name',
              ),
              size: const Size(double.infinity, 190),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Dot(color: _green, label: 'Converted'),
              SizedBox(width: 20),
              _Dot(color: _blue, label: 'New Leads'),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Top Clients Bar Chart ─────────────────────────────────────────────────────

class _TopClientsCard extends StatelessWidget {
  const _TopClientsCard({required this.model});
  final CompanyDashboardViewModel model;

  @override
  Widget build(BuildContext context) {
    final items = model.topClients.take(6).toList().asMap().entries.map((e) {
      final c = e.value;
      return _BI(
        label: _short(c['client_name']?.toString() ??
            c['clientname']?.toString() ??
            c['name']?.toString() ??
            '?'),
        value: _toD(c['revenue'] ?? 0),
        color: _barColors[e.key % _barColors.length],
      );
    }).toList();

    return _Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TOP CLIENTS BY REVENUE',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: _text3)),
          const SizedBox(height: 14),
          SizedBox(
            height: 200,
            child: CustomPaint(
              painter: _BarChartPainter(items: items),
              size: const Size(double.infinity, 200),
            ),
          ),
        ],
      ),
    );
  }

  static String _short(String s) =>
      s.length > 10 ? '${s.substring(0, 9)}…' : s;

  static double _toD(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
}

// ── Sales by Status ───────────────────────────────────────────────────────────

class _SalesByStatusCard extends StatelessWidget {
  const _SalesByStatusCard({required this.model});
  final CompanyDashboardViewModel model;

  @override
  Widget build(BuildContext context) {
    final items = model.salesByStatus;
    final maxCount = items.fold<double>(
        0, (p, e) => math.max(p, _toD(e['count'] ?? e['value'] ?? 0)));

    return _Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SALES BY STATUS',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: _text3)),
          const SizedBox(height: 14),
          ...items.map((item) {
            final status =
                (item['status'] ?? '').toString();
            final count = _toD(item['count'] ?? item['value'] ?? 0);
            final amount = _toD(item['amount'] ?? 0);
            final frac = maxCount > 0 ? count / maxCount : 0.0;
            final label =
                status.isNotEmpty ? _cap(status) : 'Unknown';

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                              color: _blue, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(label,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _text1)),
                      ),
                      Text(count.toInt().toString(),
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _text1)),
                    ],
                  ),
                  if (amount > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 18, top: 2),
                      child: Text(_fmt(amount),
                          style: const TextStyle(
                              fontSize: 11, color: _text3)),
                    ),
                  const SizedBox(height: 6),
                  LayoutBuilder(builder: (_, c) {
                    return Stack(children: [
                      Container(
                          height: 8,
                          width: c.maxWidth,
                          decoration: BoxDecoration(
                              color: const Color(0xffE5E7EB),
                              borderRadius: BorderRadius.circular(4))),
                      Container(
                          height: 8,
                          width: c.maxWidth * frac,
                          decoration: BoxDecoration(
                              color: _blue,
                              borderRadius: BorderRadius.circular(4))),
                    ]);
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static double _toD(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

  static String _cap(String s) =>
      s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : s;

  static String _fmt(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }
}

// ── Team Performance ──────────────────────────────────────────────────────────

class _TeamPerformanceCard extends StatelessWidget {
  const _TeamPerformanceCard({required this.model});
  final CompanyDashboardViewModel model;

  static int _total(Map<String, dynamic> d) =>
      _i(d['leads']) + _i(d['followups']) + _i(d['sales']);

  static int _i(dynamic v) =>
      v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) {
    final perf = model.teamPerformance.take(10).toList();
    final maxTotal = perf.fold(0, (p, e) => math.max(p, _total(e)));

    return _Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TEAM PERFORMANCE',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: _text3)),
          const SizedBox(height: 14),
          ...perf.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final d = entry.value;
            final name = d['name']?.toString() ?? 'Employee';
            final leads = _i(d['leads']);
            final followups = _i(d['followups']);
            final sales = _i(d['sales']);
            final tot = _total(d);
            final frac =
                maxTotal > 0 ? tot / maxTotal : 0.0;
            final initial =
                name.isNotEmpty ? name[0].toUpperCase() : 'E';
            final rankColor = rank == 1
                ? _orange
                : rank == 2
                    ? _text2
                    : rank == 3
                        ? const Color(0xffB45309)
                        : _text3;
            final avatarColors = [
              _green, _blue, _text2, _purple, _orange, _cyan,
            ];
            final avatarColor =
                avatarColors[(rank - 1) % avatarColors.length];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xffF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xffF3F4F6)),
              ),
              child: Row(children: [
                // Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: avatarColor.withValues(alpha: 0.15),
                  child: Text(initial,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: avatarColor)),
                ),
                const SizedBox(width: 10),
                // Name + stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _text1),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(
                          '$leads leads  $followups followups  $sales sales',
                          style: const TextStyle(
                              fontSize: 11, color: _text3)),
                      const SizedBox(height: 6),
                      // Progress bar
                      LayoutBuilder(builder: (_, c) {
                        return Stack(children: [
                          Container(
                              height: 5,
                              width: c.maxWidth,
                              decoration: BoxDecoration(
                                  color: const Color(0xffE5E7EB),
                                  borderRadius:
                                      BorderRadius.circular(3))),
                          Container(
                              height: 5,
                              width: c.maxWidth * frac,
                              decoration: BoxDecoration(
                                  color: _blue,
                                  borderRadius:
                                      BorderRadius.circular(3))),
                        ]);
                      }),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Rank badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: rankColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('#$rank',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: rankColor)),
                ),
              ]),
            );
          }),
        ],
      ),
    );
  }
}

// ── Today's Follow-ups ────────────────────────────────────────────────────────

class _TodayFollowupsCard extends StatelessWidget {
  const _TodayFollowupsCard({required this.model});
  final CompanyDashboardViewModel model;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 8,
              height: 8,
              decoration:
                  const BoxDecoration(color: _red, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            const Text("TODAY'S FOLLOW-UPS",
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: _text3)),
          ]),
          const SizedBox(height: 12),
          model.todayFollowups.isEmpty
              ? _emptyFollowups()
              : Column(
                  children: model.todayFollowups.take(8).map((f) {
                    final name = f['client_name']?.toString() ??
                        f['clientname']?.toString() ??
                        f['name']?.toString() ??
                        f['lead_name']?.toString() ??
                        'Client';
                    final time = f['followup_time']?.toString() ??
                        f['time']?.toString() ??
                        '';
                    final type = f['followup_type']?.toString() ??
                        f['type']?.toString() ??
                        'Call';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: _blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(type,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _blue)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(name,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _text1),
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (time.isNotEmpty)
                          Text(time,
                              style: const TextStyle(
                                  fontSize: 11, color: _text3)),
                      ]),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  Widget _emptyFollowups() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.phone_forwarded_rounded,
                size: 40, color: _text3.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            const Text('No follow-ups today',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _text3)),
          ],
        ),
      ),
    );
  }
}

// ── Recent Invoices Table ─────────────────────────────────────────────────────

class _RecentInvoicesCard extends StatelessWidget {
  const _RecentInvoicesCard({required this.model});
  final CompanyDashboardViewModel model;

  static const _statusColor = {
    'paid': _green,
    'partial': _orange,
    'pending': _red,
    'draft': _text3,
    'overdue': Color(0xffDC2626),
  };

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _fmtDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day} ${_months[dt.month]} ${dt.year.toString().substring(2)}';
    } catch (_) {
      return raw.length > 10 ? raw.substring(0, 10) : raw;
    }
  }

  static String _fmtAmt(dynamic v) {
    final d =
        v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
    if (d >= 100000) return '₹${(d / 100000).toStringAsFixed(1)}L';
    if (d >= 1000) return '₹${(d / 1000).toStringAsFixed(1)}K';
    return '₹${d.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RECENT INVOICES',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: _text3)),
          const SizedBox(height: 12),
          // Horizontally scrollable table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width - 56),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xffF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const _InvoiceRow(
                      col1: 'INVOICE #',
                      col2: 'CLIENT',
                      col3: 'AMOUNT',
                      col4: 'PAID',
                      col5: 'STATUS',
                      col6: 'DATE',
                      isHeader: true,
                    ),
                  ),
                  // Data rows
                  ...model.recentSales
                      .take(8)
                      .toList()
                      .asMap()
                      .entries
                      .map((entry) {
                    final i = entry.key;
                    final inv = entry.value;
                    final invoiceNo = inv['invoice_number']?.toString() ??
                        inv['invoiceno']?.toString() ??
                        inv['id']?.toString() ??
                        '#';
                    final client = inv['client_name']?.toString() ??
                        inv['clientname']?.toString() ??
                        'Client';
                    final amount =
                        _fmtAmt(inv['amount'] ?? inv['totalamount'] ?? 0);
                    final paid =
                        _fmtAmt(inv['paid_amount'] ?? inv['paidamount'] ?? 0);
                    final status =
                        (inv['status'] ?? 'pending').toString().toLowerCase();
                    final date = _fmtDate(inv['invoice_date']?.toString() ??
                        inv['invoicedate']?.toString() ??
                        '');
                    final sc = _statusColor[status] ?? _text3;
                    return Container(
                      color: i % 2 == 0
                          ? Colors.white
                          : const Color(0xffFAFAFB),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      child: _InvoiceRow(
                        col1: invoiceNo,
                        col2: client,
                        col3: amount,
                        col4: paid,
                        col5: status.isNotEmpty
                            ? '${status[0].toUpperCase()}${status.substring(1)}'
                            : status,
                        col6: date,
                        statusColor: sc,
                      ),
                    );
                  }),
                  const Divider(height: 1, color: Color(0xffF3F4F6)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Invoice Row (header + data) ───────────────────────────────────────────────

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({
    required this.col1,
    required this.col2,
    required this.col3,
    required this.col4,
    required this.col5,
    required this.col6,
    this.isHeader = false,
    this.statusColor,
  });
  final String col1, col2, col3, col4, col5, col6;
  final bool isHeader;
  final Color? statusColor;

  static const _w1 = 110.0;
  static const _w2 = 100.0;
  static const _w3 = 80.0;
  static const _w4 = 70.0;
  static const _w5 = 85.0;
  static const _w6 = 75.0;

  @override
  Widget build(BuildContext context) {
    if (isHeader) {
      return Row(children: [
        _hCell(col1, _w1),
        _hCell(col2, _w2),
        _hCell(col3, _w3),
        _hCell(col4, _w4),
        _hCell(col5, _w5),
        _hCell(col6, _w6),
      ]);
    }
    return Row(children: [
      _cell(col1, _w1,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: _blue)),
      _cell(col2, _w2,
          style: const TextStyle(fontSize: 12, color: _text1),
          overflow: TextOverflow.ellipsis),
      _cell(col3, _w3,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: _text1)),
      _cell(col4, _w4,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: _green)),
      // Status badge cell
      SizedBox(
        width: _w5,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: (statusColor ?? _text3).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(col5,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: statusColor ?? _text3),
              overflow: TextOverflow.ellipsis),
        ),
      ),
      _cell(col6, _w6,
          style: const TextStyle(fontSize: 11, color: _text3)),
    ]);
  }

  static Widget _hCell(String text, double width) => SizedBox(
        width: width,
        child: Text(text,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _text3,
                letterSpacing: 0.3)),
      );

  static Widget _cell(String text, double width,
          {required TextStyle style,
          TextOverflow overflow = TextOverflow.clip}) =>
      SizedBox(
        width: width,
        child: Text(text, style: style, overflow: overflow),
      );
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: child,
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label,
          style: const TextStyle(fontSize: 11, color: _text2)),
    ]);
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message,
          style: const TextStyle(fontSize: 12, color: _text3)),
    );
  }
}

// ── CustomPainter: Line Chart ─────────────────────────────────────────────────

class _LS {
  const _LS({required this.key, required this.color});
  final String key;
  final Color color;
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({
    required this.data,
    required this.series,
    required this.labelKey,
  });
  final List<Map<String, dynamic>> data;
  final List<_LS> series;
  final String labelKey;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const pTop = 12.0;
    const pBottom = 28.0;
    const pLeft = 38.0;
    const pRight = 8.0;
    final chartH = size.height - pTop - pBottom;
    final chartW = size.width - pLeft - pRight;
    final n = data.length;

    // Find max
    double maxV = 0;
    for (final s in series) {
      for (final d in data) {
        final v = _v(d, s.key);
        if (v > maxV) maxV = v;
      }
    }
    if (maxV == 0) maxV = 1;

    // Grid + y labels
    const gridLines = 4;
    final lp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i <= gridLines; i++) {
      final y = pTop + chartH - chartH * i / gridLines;
      canvas.drawLine(
          Offset(pLeft, y),
          Offset(size.width - pRight, y),
          Paint()
            ..color = const Color(0xffF3F4F6)
            ..strokeWidth = 1);
      final lv = maxV * i / gridLines;
      lp.text = TextSpan(
          text: _fmt(lv),
          style: const TextStyle(
              fontSize: 8, color: _text3, fontWeight: FontWeight.w500));
      lp.layout();
      lp.paint(canvas,
          Offset(pLeft - lp.width - 3, y - lp.height / 2));
    }

    // X axis
    canvas.drawLine(
        Offset(pLeft, pTop + chartH),
        Offset(size.width - pRight, pTop + chartH),
        Paint()
          ..color = const Color(0xffE5E7EB)
          ..strokeWidth = 1);

    // X labels
    for (int i = 0; i < n; i++) {
      final x = pLeft + (n <= 1 ? chartW / 2 : chartW * i / (n - 1));
      final label = data[i][labelKey]?.toString() ?? '';
      lp.text = TextSpan(
          text: label,
          style: const TextStyle(fontSize: 8, color: _text3));
      lp.layout();
      lp.paint(canvas, Offset(x - lp.width / 2, size.height - pBottom + 5));
    }

    // Draw each series
    for (final s in series) {
      final pts = <Offset>[];
      for (int i = 0; i < n; i++) {
        final v = _v(data[i], s.key);
        final x = pLeft + (n <= 1 ? chartW / 2 : chartW * i / (n - 1));
        final y = pTop + chartH - chartH * v / maxV;
        pts.add(Offset(x, y));
      }
      if (pts.isEmpty) continue;

      // Area fill
      final fillPath = Path()
        ..moveTo(pts.first.dx, pTop + chartH);
      for (final p in pts) {
        fillPath.lineTo(p.dx, p.dy);
      }
      fillPath
        ..lineTo(pts.last.dx, pTop + chartH)
        ..close();
      canvas.drawPath(
          fillPath,
          Paint()
            ..color = s.color.withValues(alpha: 0.08)
            ..style = PaintingStyle.fill);

      // Smooth line
      final linePath = Path();
      for (int i = 0; i < pts.length; i++) {
        if (i == 0) {
          linePath.moveTo(pts[i].dx, pts[i].dy);
        } else {
          final cp1x = (pts[i - 1].dx + pts[i].dx) / 2;
          linePath.cubicTo(
              cp1x, pts[i - 1].dy, cp1x, pts[i].dy, pts[i].dx, pts[i].dy);
        }
      }
      canvas.drawPath(
          linePath,
          Paint()
            ..color = s.color
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round);

      // Dots
      for (final p in pts) {
        canvas.drawCircle(p, 3, Paint()..color = s.color);
        canvas.drawCircle(
            p,
            3,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5);
      }
    }
  }

  static double _v(Map<String, dynamic> d, String key) {
    final v = d[key];
    return v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static String _fmt(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(0)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    if (v == 0) return '₹0';
    return '₹${v.toInt()}';
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.data != data || old.series != series;
}

// ── CustomPainter: Donut ──────────────────────────────────────────────────────

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.collectedFrac,
    required this.pendingFrac,
    required this.centerText,
    required this.subText,
  });
  final double collectedFrac, pendingFrac;
  final String centerText, subText;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outerR = math.min(cx, cy) - 4;
    final strokeW = outerR * 0.32;
    final r = outerR - strokeW / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Gray background ring (collected / safe part)
    canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..color = const Color(0xffE5E7EB)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW);

    // Red arc = pending (uncollected) — starts at top (-π/2), sweeps pendingFrac
    if (pendingFrac > 0) {
      canvas.drawArc(
          rect,
          -math.pi / 2,
          pendingFrac * 2 * math.pi,
          false,
          Paint()
            ..color = _red
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW
            ..strokeCap = StrokeCap.butt);
    }

    // Center text: percentage
    final tp1 = TextPainter(
      text: TextSpan(
          text: centerText,
          style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _text1)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp1.paint(canvas, Offset(cx - tp1.width / 2, cy - tp1.height / 2 - 6));

    // Sub text: "collected"
    final tp2 = TextPainter(
      text: TextSpan(
          text: subText,
          style: const TextStyle(fontSize: 10, color: _text3)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp2.paint(canvas,
        Offset(cx - tp2.width / 2, cy + tp1.height / 2 - 4));
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.collectedFrac != collectedFrac || old.pendingFrac != pendingFrac;
}

// ── CustomPainter: Bar Chart (multi-color) ────────────────────────────────────

class _BI {
  const _BI({required this.label, required this.value, required this.color});
  final String label;
  final double value;
  final Color color;
}

class _BarChartPainter extends CustomPainter {
  const _BarChartPainter({required this.items});
  final List<_BI> items;

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) return;

    const pTop = 20.0;
    const pBottom = 32.0;
    const pLeft = 36.0;
    const pRight = 8.0;
    final chartH = size.height - pTop - pBottom;
    final chartW = size.width - pLeft - pRight;
    final n = items.length;
    final maxV = items.fold(0.0, (p, e) => math.max(p, e.value));
    if (maxV == 0) return;

    final barW = chartW / n * 0.55;
    final gap = chartW / n;

    // Y grid lines + labels
    const gridLines = 4;
    final lp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i <= gridLines; i++) {
      final y = pTop + chartH - chartH * i / gridLines;
      canvas.drawLine(
          Offset(pLeft, y),
          Offset(size.width - pRight, y),
          Paint()
            ..color = const Color(0xffF3F4F6)
            ..strokeWidth = 1);
      lp.text = TextSpan(
          text: _fmt(maxV * i / gridLines),
          style: const TextStyle(fontSize: 8, color: _text3));
      lp.layout();
      lp.paint(canvas,
          Offset(pLeft - lp.width - 3, y - lp.height / 2));
    }

    // X axis
    canvas.drawLine(
        Offset(pLeft, pTop + chartH),
        Offset(size.width - pRight, pTop + chartH),
        Paint()
          ..color = const Color(0xffE5E7EB)
          ..strokeWidth = 1);

    for (int i = 0; i < n; i++) {
      final barH = chartH * items[i].value / maxV;
      final x = pLeft + gap * i + (gap - barW) / 2;
      final y = pTop + chartH - barH;

      canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x, y, barW, barH),
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(4),
          ),
          Paint()..color = items[i].color);

      // Value on top
      lp.text = TextSpan(
          text: _fmt(items[i].value),
          style: TextStyle(
              fontSize: 8,
              color: items[i].color,
              fontWeight: FontWeight.w600));
      lp.layout();
      lp.paint(canvas,
          Offset(x + barW / 2 - lp.width / 2, y - lp.height - 2));

      // X label (angled slightly for longer names)
      lp.text = TextSpan(
          text: items[i].label,
          style: const TextStyle(fontSize: 8, color: _text3));
      lp.layout();
      lp.paint(canvas,
          Offset(x + barW / 2 - lp.width / 2, size.height - pBottom + 5));
    }
  }

  static String _fmt(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    if (v == 0) return '₹0';
    return '₹${v.toInt()}';
  }

  @override
  bool shouldRepaint(_BarChartPainter old) => old.items != items;
}

