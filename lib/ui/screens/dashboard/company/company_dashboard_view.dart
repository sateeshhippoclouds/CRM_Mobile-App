import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'company_dashboard_viewmodel.dart';
import 'screens/company_clients_view.dart';
import 'screens/company_employees_view.dart';
import 'screens/company_leads_view.dart';
import 'screens/company_products_view.dart';
import 'screens/company_role_management_view.dart';
import 'screens/company_sales_billing_view.dart';
import 'screens/company_tasks_view.dart';
import 'screens/masters/company_location_view.dart';
import 'screens/masters/company_masters_clients_view.dart';
import 'screens/masters/company_masters_leads_view.dart';
import 'screens/masters/company_others_view.dart';
import 'screens/masters/company_terms_view.dart';

class CompanyDashboardView extends StatelessWidget {
  const CompanyDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<CompanyDashboardViewModel>.reactive(
      viewModelBuilder: () => CompanyDashboardViewModel(),
      onViewModelReady: (m) => m.init(),
      builder: (context, model, child) {
        return Scaffold(
          backgroundColor: const Color(0xffF5F5F7),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: Color(0xff1A1F36)),
            title: Row(
              children: [
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'hippo',
                        style: TextStyle(
                            color: Color(0xff3756DF),
                            fontWeight: FontWeight.w800,
                            fontSize: 18),
                      ),
                      TextSpan(
                        text: 'cloud',
                        style: TextStyle(
                            color: Color(0xffEF4444),
                            fontWeight: FontWeight.w800,
                            fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xff3756DF),
                  child: Text(
                    model.userInitial,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
          drawer: _CompanyDrawer(model: model),
          body: model.isBusy
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xff3756DF)))
              : RefreshIndicator(
                  onRefresh: model.init,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DashboardHeader(model: model),
                        const SizedBox(height: 16),
                        _StatsGrid(model: model),
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
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            color: const Color(0xff3756DF),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    widget.model.userInitial,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 20),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.model.userName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16),
                ),
                Text(
                  widget.model.role,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12),
                ),
              ],
            ),
          ),

          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _NavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  selected: true,
                  onTap: () => Navigator.pop(context),
                ),

                if (widget.model.canViewMasters)
                  _MastersItem(
                    expanded: _mastersExpanded,
                    onToggle: () =>
                        setState(() => _mastersExpanded = !_mastersExpanded),
                    children: [
                      _SubNavItem(
                        label: 'Leads',
                        onTap: () => _navigate(
                            context, const CompanyMastersLeadsView()),
                      ),
                      _SubNavItem(
                        label: 'Clients',
                        onTap: () => _navigate(
                            context, const CompanyMastersClientsView()),
                      ),
                      _SubNavItem(
                        label: 'Location',
                        onTap: () =>
                            _navigate(context, const CompanyLocationView()),
                      ),
                      _SubNavItem(
                        label: 'Others',
                        onTap: () =>
                            _navigate(context, const CompanyOthersView()),
                      ),
                      _SubNavItem(
                        label: 'Terms',
                        onTap: () =>
                            _navigate(context, const CompanyTermsView()),
                      ),
                    ],
                  ),

                if (widget.model.canViewLeads)
                  _NavItem(
                    icon: Icons.bar_chart_rounded,
                    label: 'Leads',
                    onTap: () =>
                        _navigate(context, const CompanyLeadsView()),
                  ),
                if (widget.model.canViewClients)
                  _NavItem(
                    icon: Icons.people_rounded,
                    label: 'Clients',
                    onTap: () =>
                        _navigate(context, const CompanyClientsView()),
                  ),
                if (widget.model.canViewTasks)
                  _NavItem(
                    icon: Icons.task_alt_rounded,
                    label: 'Tasks',
                    onTap: () =>
                        _navigate(context, const CompanyTasksView()),
                  ),
                if (widget.model.canViewBilling)
                  _NavItem(
                    icon: Icons.receipt_long_rounded,
                    label: 'Sales & Billing',
                    onTap: () =>
                        _navigate(context, const CompanySalesBillingView()),
                  ),
                if (widget.model.canViewEmployees)
                  _NavItem(
                    icon: Icons.badge_rounded,
                    label: 'Employees',
                    onTap: () =>
                        _navigate(context, const CompanyEmployeesView()),
                  ),
                if (widget.model.canViewProducts)
                  _NavItem(
                    icon: Icons.inventory_2_rounded,
                    label: 'Products',
                    onTap: () =>
                        _navigate(context, const CompanyProductsView()),
                  ),
                if (widget.model.canViewRoleManagement)
                  _NavItem(
                    icon: Icons.manage_accounts_rounded,
                    label: 'Role Management',
                    onTap: () =>
                        _navigate(context, const CompanyRoleManagementView()),
                  ),
              ],
            ),
          ),

          // Logout
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Color(0xffEF4444)),
            title: const Text('Logout',
                style: TextStyle(
                    color: Color(0xffEF4444), fontWeight: FontWeight.w600)),
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.selected = false,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon,
          color: selected ? const Color(0xff3756DF) : const Color(0xff6B7280),
          size: 22),
      title: Text(label,
          style: TextStyle(
              fontSize: 14,
              fontWeight:
                  selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? const Color(0xff3756DF)
                  : const Color(0xff1A1F36))),
      tileColor: selected
          ? const Color(0xffEEF1FB)
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: onTap,
    );
  }
}

class _MastersItem extends StatelessWidget {
  const _MastersItem({
    required this.expanded,
    required this.onToggle,
    required this.children,
  });
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.folder_rounded,
              color: Color(0xff6B7280), size: 22),
          title: const Text('Masters',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xff1A1F36))),
          trailing: Icon(
            expanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: const Color(0xff6B7280),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          onTap: onToggle,
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(children: children),
          ),
      ],
    );
  }
}

class _SubNavItem extends StatelessWidget {
  const _SubNavItem({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.circle,
          size: 6, color: Color(0xff9CA3AF)),
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

// ── Dashboard Header ──────────────────────────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.model});
  final CompanyDashboardViewModel model;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xffEEF1FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.filter_list_rounded,
                color: Color(0xff3756DF), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dashboard',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff1A1F36))),
                Text('Welcome back, ${model.userName}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xff8E9BB5))),
              ],
            ),
          ),
        ],
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
      _StatData(
        label: 'Total Leads',
        sub: 'in period',
        value: '${model.totalLeads}',
        icon: Icons.person_search_rounded,
        iconColor: const Color(0xff3756DF),
        iconBg: const Color(0xffEEF1FB),
      ),
      _StatData(
        label: 'Clients',
        sub: 'active accounts',
        value: '${model.totalClients}',
        icon: Icons.people_rounded,
        iconColor: const Color(0xff3756DF),
        iconBg: const Color(0xffEEF1FB),
      ),
      _StatData(
        label: 'Invoices',
        sub: 'non-draft',
        value: '${model.totalInvoices}',
        icon: Icons.receipt_long_rounded,
        iconColor: const Color(0xff7C3AED),
        iconBg: const Color(0xffEDE9FE),
      ),
      _StatData(
        label: 'Revenue',
        sub: 'total billed',
        value: model.revenue,
        icon: Icons.attach_money_rounded,
        iconColor: const Color(0xff16A34A),
        iconBg: const Color(0xffDCFCE7),
      ),
      _StatData(
        label: 'Collected',
        sub: 'received',
        value: model.collected,
        icon: Icons.account_balance_wallet_rounded,
        iconColor: const Color(0xff0EA5E9),
        iconBg: const Color(0xffE0F2FE),
      ),
      _StatData(
        label: 'Outstanding',
        sub: 'pending',
        value: model.outstanding,
        icon: Icons.trending_down_rounded,
        iconColor: const Color(0xffEF4444),
        iconBg: const Color(0xffFEE2E2),
      ),
      _StatData(
        label: 'Tasks',
        sub: 'in period',
        value: '${model.totalTasks}',
        icon: Icons.task_alt_rounded,
        iconColor: const Color(0xffF59E0B),
        iconBg: const Color(0xffFEF3C7),
      ),
      _StatData(
        label: 'Follow-ups',
        sub: 'in period',
        value: '${model.followUps}',
        icon: Icons.phone_callback_rounded,
        iconColor: const Color(0xff6B7280),
        iconBg: const Color(0xffF3F4F6),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: stats.length,
      itemBuilder: (_, i) => _StatCard(data: stats[i]),
    );
  }
}

class _StatData {
  const _StatData({
    required this.label,
    required this.sub,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });
  final String label, sub, value;
  final IconData icon;
  final Color iconColor, iconBg;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});
  final _StatData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: data.iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, color: data.iconColor, size: 22),
          ),
          const Spacer(),
          Text(data.value,
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xff1A1F36))),
          const SizedBox(height: 2),
          Text(data.label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff374151))),
          Text(data.sub,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xff9CA3AF))),
        ],
      ),
    );
  }
}
