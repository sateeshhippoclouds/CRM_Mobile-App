import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'ceo_dashboard_viewmodel.dart';

String _fmtAmt(dynamic v) {
  final d =
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
  if (d >= 10000000) return '₹${(d / 10000000).toStringAsFixed(1)}Cr';
  if (d >= 100000) return '₹${(d / 100000).toStringAsFixed(1)}L';
  if (d >= 1000) return '₹${(d / 1000).toStringAsFixed(1)}K';
  return '₹${d.toStringAsFixed(0)}';
}

String _fmtDate(dynamic date) {
  if (date == null) return '—';
  try {
    final d = DateTime.parse(date.toString());
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${d.day.toString().padLeft(2, '0')} ${m[d.month - 1]}';
  } catch (_) {
    return '—';
  }
}

// ─── root view ───────────────────────────────────────────────────────────────

class CeoDashboardView extends StatelessWidget {
  const CeoDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<CeoDashboardViewModel>.reactive(
      viewModelBuilder: () => CeoDashboardViewModel(),
      onViewModelReady: (model) => model.init(),
      builder: (context, model, child) {
        return Scaffold(
          backgroundColor: const Color(0xffEEF1FB),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: Color(0xff1A1F36)),
            title: const Text(
              'Dashboard',
              style: TextStyle(
                  color: Color(0xff1A1F36),
                  fontWeight: FontWeight.w700,
                  fontSize: 20),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xffB0B8C8),
                  child: Text(model.userInitial,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                ),
              ),
            ],
          ),
          drawer: _CeoDrawer(model: model),
          body: model.isBusy
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xff3756DF)))
              : model.fetchError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(model.fetchError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                                onPressed: model.init,
                                child: const Text('Retry')),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: model.init,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _HeaderCard(),
                            const SizedBox(height: 16),

                            // ── 2×2 stats grid ──
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.05,
                              children: [
                                _StatCard(
                                  label: 'Total Tenants',
                                  value: '${model.totalTenants}',
                                  icon: Icons.people_rounded,
                                  iconColor: const Color(0xff4B71F7),
                                  iconBg: const Color(0xffE8EDFF),
                                ),
                                _StatCard(
                                  label: 'Active Tenants',
                                  value: '${model.activeTenants}',
                                  icon: Icons.check_circle_outline_rounded,
                                  iconColor: const Color(0xff22C55E),
                                  iconBg: const Color(0xffDCFCE7),
                                ),
                                _StatCard(
                                  label: 'Inactive Tenants',
                                  value: '${model.inactiveTenants}',
                                  icon: Icons.block_rounded,
                                  iconColor: const Color(0xffEF4444),
                                  iconBg: const Color(0xffFEE2E2),
                                ),
                                _StatCard(
                                  label: 'Total Collected',
                                  value: model.totalCollected,
                                  icon: Icons.attach_money_rounded,
                                  iconColor: const Color(0xff7C3AED),
                                  iconBg: const Color(0xffEDE9FE),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // ── expiring soon (half width) ──
                            Row(
                              children: [
                                Expanded(
                                  child: _StatCard(
                                    label: 'Expiring Soon',
                                    value: '${model.expiringSoon}',
                                    icon: Icons.warning_amber_rounded,
                                    iconColor: const Color(0xffF59E0B),
                                    iconBg: const Color(0xffFEF3C7),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(child: SizedBox()),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // ── revenue trend ──
                            _RevenueTrendSection(data: model.revenueTrend),
                            const SizedBox(height: 16),

                            // ── active subscription plans ──
                            if (model.activeSubscriptions.isNotEmpty) ...[
                              _SubscriptionsSection(
                                  subs: model.activeSubscriptions),
                              const SizedBox(height: 16),
                            ],

                            // ── expiring tenants table ──
                            if (model.expiringTenants.isNotEmpty) ...[
                              _ExpiringTenantsSection(
                                  tenants: model.expiringTenants),
                              const SizedBox(height: 16),
                            ],

                            // ── recent tenants ──
                            if (model.recentTenants.isNotEmpty) ...[
                              _RecentTenantsSection(
                                  tenants: model.recentTenants),
                              const SizedBox(height: 16),
                            ],

                            // ── recent payments ──
                            if (model.recentPayments.isNotEmpty) ...[
                              _RecentPaymentsSection(
                                  payments: model.recentPayments),
                              const SizedBox(height: 16),
                            ],

                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
        );
      },
    );
  }
}

// ─── drawer ──────────────────────────────────────────────────────────────────

class _CeoDrawer extends StatelessWidget {
  const _CeoDrawer({required this.model});
  final CeoDashboardViewModel model;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'hippo',
                          style: TextStyle(
                              color: Color(0xff1565C0),
                              fontSize: 26,
                              fontWeight: FontWeight.w800),
                        ),
                        TextSpan(
                          text: 'cloud',
                          style: TextStyle(
                              color: Color(0xffE65100),
                              fontSize: 26,
                              fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    'Technologies Private Limited',
                    style: TextStyle(
                        fontSize: 11,
                        color: Color(0xff8E9BB5),
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xffEEF0F5)),
            const SizedBox(height: 8),
            _DrawerItem(
              icon: Icons.home_rounded,
              label: 'Dashboard',
              isActive: true,
              onTap: () => Navigator.pop(context),
            ),
            _DrawerItem(
              icon: Icons.list_alt_rounded,
              label: 'Subscriptions',
              onTap: () {
                Navigator.pop(context);
                model.goToSubscriptions();
              },
            ),
            _DrawerItem(
              icon: Icons.grid_view_rounded,
              label: 'Tenants',
              onTap: () {
                Navigator.pop(context);
                model.goToTenants();
              },
            ),
            _DrawerItem(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Tenant Payments',
              onTap: () {
                Navigator.pop(context);
                model.goToPayments();
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  model.logout();
                },
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded,
                          color: Color(0xffEF4444), size: 20),
                      SizedBox(width: 12),
                      Text('Logout',
                          style: TextStyle(
                              color: Color(0xffEF4444),
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xff3756DF) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 20,
                  color: isActive ? Colors.white : const Color(0xff5A6785)),
              const SizedBox(width: 14),
              Text(label,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color:
                          isActive ? Colors.white : const Color(0xff1A1F36))),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── header card ─────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CEO Dashboard',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xff1A1F36))),
                SizedBox(height: 4),
                Text('Platform-wide overview — Tenants & Subscriptions',
                    style: TextStyle(fontSize: 13, color: Color(0xff8E9BB5))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xffEEF2FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('CEO View',
                style: TextStyle(
                    color: Color(0xff3756DF),
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ─── stat card ───────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });
  final String label, value;
  final IconData icon;
  final Color iconColor, iconBg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 14),
          Text(value,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xff1A1F36))),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff1A1F36))),
        ],
      ),
    );
  }
}

// ─── revenue trend ───────────────────────────────────────────────────────────

class _RevenueTrendSection extends StatelessWidget {
  const _RevenueTrendSection({required this.data});
  final List<Map<String, dynamic>> data;

  static double _niceMax(double v) {
    if (v <= 0) return 1000;
    var step = 1.0;
    while (step * 10 <= v) {
      step *= 10;
    }
    return (v / step).ceilToDouble() * step;
  }

  static String _fmtY(double v) {
    if (v == 0) return '₹0';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final values = data
        .map((d) => double.tryParse(d['revenue']?.toString() ?? '') ?? 0.0)
        .toList();
    final labels = data.map((d) => d['month']?.toString() ?? '').toList();

    final maxVal =
        values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);
    final yMax = _niceMax(maxVal);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MONTHLY REVENUE TREND (LAST 6 MONTHS)',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Color(0xff8E9BB5)),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Y-axis labels
              SizedBox(
                width: 48,
                height: 160,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(5, (i) {
                    final v = yMax * (4 - i) / 4;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(_fmtY(v),
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xff8E9BB5))),
                    );
                  }),
                ),
              ),
              // Chart area
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: 160,
                      width: double.infinity,
                      child: values.isEmpty
                          ? const Center(
                              child: Text('No data',
                                  style: TextStyle(
                                      color: Color(0xff8E9BB5), fontSize: 12)))
                          : CustomPaint(
                              painter:
                                  _ChartPainter(values: values, yMax: yMax),
                            ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: labels.length <= 1
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.spaceBetween,
                      children: labels
                          .map((l) => Text(l,
                              style: const TextStyle(
                                  fontSize: 10, color: Color(0xff8E9BB5))))
                          .toList(),
                    ),
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

class _ChartPainter extends CustomPainter {
  const _ChartPainter({required this.values, required this.yMax});
  final List<double> values;
  final double yMax;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    if (yMax <= 0 || values.isEmpty) return;

    final gridPaint = Paint()
      ..color = const Color(0xffE5E9F5)
      ..strokeWidth = 1;

    // Dashed horizontal grid lines (5 lines)
    for (var i = 0; i < 5; i++) {
      final y = h * i / 4;
      _dashed(canvas, Offset(0, y), Offset(w, y), gridPaint);
    }

    // Compute point positions
    final pts = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? w / 2 : w * i / (values.length - 1);
      final y = h - (h * (values[i] / yMax)).clamp(0.0, h);
      pts.add(Offset(x, y));
    }

    if (pts.length < 2) {
      canvas.drawCircle(pts.first, 5, Paint()..color = const Color(0xff4B71F7));
      return;
    }

    // Filled area
    final fillPath = Path()
      ..moveTo(pts.first.dx, h)
      ..lineTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath
      ..lineTo(pts.last.dx, h)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..color = const Color(0xff4B71F7).withValues(alpha: 0.08)
        ..style = PaintingStyle.fill,
    );

    // Line
    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      linePath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = const Color(0xff4B71F7)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Dots
    for (final p in pts) {
      canvas.drawCircle(p, 4.5, Paint()..color = const Color(0xff4B71F7));
      canvas.drawCircle(p, 2.5, Paint()..color = Colors.white);
    }
  }

  void _dashed(Canvas c, Offset a, Offset b, Paint p) {
    const dash = 5.0, gap = 4.0;
    final len = (b - a).distance;
    if (len == 0) return;
    final dir = (b - a) / len;
    var d = 0.0;
    while (d < len) {
      final s = a + dir * d;
      d = (d + dash).clamp(0.0, len);
      c.drawLine(s, a + dir * d, p);
      d += gap;
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.values != values || old.yMax != yMax;
}

// ─── active subscription plans ───────────────────────────────────────────────

class _SubscriptionsSection extends StatelessWidget {
  const _SubscriptionsSection({required this.subs});
  final List<Map<String, dynamic>> subs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ACTIVE SUBSCRIPTION PLANS',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Color(0xff8E9BB5)),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(
              child: Column(
                children: subs.map((s) => _SubCard(sub: s)).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubCard extends StatelessWidget {
  const _SubCard({required this.sub});
  final Map<String, dynamic> sub;

  @override
  Widget build(BuildContext context) {
    final name = sub['name']?.toString() ?? '—';
    final duration = sub['duration']?.toString() ?? '';
    final price = _fmtAmt(sub['total_amount']);
    final count = int.tryParse(sub['tenant_count']?.toString() ?? '') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xffF7F8FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffEEF0F9)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xffEDE9FE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.subscriptions_rounded,
                color: Color(0xff6366F1), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xff1A1F36))),
                const SizedBox(height: 2),
                Text('$duration · $price',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xff8E9BB5))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xffEEF2FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count ${count == 1 ? 'tenant' : 'tenants'}',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff3756DF)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── expiring tenants ────────────────────────────────────────────────────────

class _ExpiringTenantsSection extends StatelessWidget {
  const _ExpiringTenantsSection({required this.tenants});
  final List<Map<String, dynamic>> tenants;

  static const _cols = [130.0, 155.0, 120.0, 90.0, 80.0];
  static const _total = 575.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xffFFFCEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffF5E6A3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Color(0xffD97706), size: 18),
              SizedBox(width: 8),
              Text(
                'TENANTS EXPIRING IN NEXT 30 DAYS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: Color(0xff92640A)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _total,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const Divider(height: 14, color: Color(0xffF0E3A8)),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: SingleChildScrollView(
                      child: Column(
                        children: tenants
                            .map((t) => _ExpRow(t: t, cols: _cols))
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    const labels = ['Tenant', 'Email', 'Subscription', 'Expiry', 'Status'];
    return Row(
      children: List.generate(
        labels.length,
        (i) => SizedBox(
          width: _cols[i],
          child: Text(labels[i],
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff3756DF))),
        ),
      ),
    );
  }
}

class _ExpRow extends StatelessWidget {
  const _ExpRow({required this.t, required this.cols});
  final Map<String, dynamic> t;
  final List<double> cols;

  @override
  Widget build(BuildContext context) {
    final status = t['status']?.toString() ?? '—';
    final isActive = status.toLowerCase() == 'active';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: cols[0],
            child: Text(t['tenant_name']?.toString() ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xff1A1F36))),
          ),
          SizedBox(
            width: cols[1],
            child: Text(t['email']?.toString() ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xff6B7280))),
          ),
          SizedBox(
            width: cols[2],
            child: Text(t['subscription_name']?.toString() ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xff6B7280))),
          ),
          SizedBox(
            width: cols[3],
            child: Text(_fmtDate(t['end_date']),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xffD97706))),
          ),
          SizedBox(
            width: cols[4],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xffDCFCE7)
                    : const Color(0xffFEE2E2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? const Color(0xff16A34A)
                        : const Color(0xffDC2626)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── recent tenants ──────────────────────────────────────────────────────────

class _RecentTenantsSection extends StatelessWidget {
  const _RecentTenantsSection({required this.tenants});
  final List<Map<String, dynamic>> tenants;

  static const _cols = [130.0, 155.0, 120.0, 90.0, 80.0];
  static const _total = 575.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RECENT TENANTS',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Color(0xff8E9BB5))),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _total,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const Divider(height: 1, color: Color(0xffF0F2F8)),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 340),
                    child: SingleChildScrollView(
                      child: Column(
                        children: tenants
                            .map((t) => _TenantRow(t: t, cols: _cols))
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    const labels = ['Tenant', 'Email', 'Plan', 'Amount', 'Status'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: List.generate(
          labels.length,
          (i) => SizedBox(
            width: _cols[i],
            child: Text(labels[i],
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff8E9BB5))),
          ),
        ),
      ),
    );
  }
}

class _TenantRow extends StatelessWidget {
  const _TenantRow({required this.t, required this.cols});
  final Map<String, dynamic> t;
  final List<double> cols;

  @override
  Widget build(BuildContext context) {
    final active = (t['status']?.toString() ?? '').toLowerCase() == 'active';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: cols[0],
                child: Text(t['tenant_name']?.toString() ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xff1A1F36))),
              ),
              SizedBox(
                width: cols[1],
                child: Text(t['email']?.toString() ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xff8E9BB5))),
              ),
              SizedBox(
                width: cols[2],
                child: Text(t['subscription_name']?.toString() ?? '—',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xff6B7280))),
              ),
              SizedBox(
                width: cols[3],
                child: Text(_fmtAmt(t['total_amount']),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff22C55E))),
              ),
              SizedBox(
                width: cols[4],
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xffDCFCE7)
                        : const Color(0xffFEE2E2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    active ? 'active' : 'inactive',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? const Color(0xff16A34A)
                            : const Color(0xffDC2626)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xffF0F2F8)),
      ],
    );
  }
}

// ─── recent payments ─────────────────────────────────────────────────────────

class _RecentPaymentsSection extends StatelessWidget {
  const _RecentPaymentsSection({required this.payments});
  final List<Map<String, dynamic>> payments;

  static const _cols = [150.0, 110.0, 100.0, 90.0];
  static const _total = 450.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: const Color(0xffDCFCE7),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.payments_rounded,
                    color: Color(0xff16A34A), size: 16),
              ),
              const SizedBox(width: 10),
              const Text('RECENT TENANT PAYMENTS',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Color(0xff8E9BB5))),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _total,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const Divider(height: 1, color: Color(0xffF0F2F8)),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 340),
                    child: SingleChildScrollView(
                      child: Column(
                        children: payments
                            .map((p) => _PaymentRow(p: p, cols: _cols))
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    const labels = ['Tenant', 'Method', 'Date', 'Amount'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: List.generate(
          labels.length,
          (i) => SizedBox(
            width: _cols[i],
            child: Text(labels[i],
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff8E9BB5))),
          ),
        ),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.p, required this.cols});
  final Map<String, dynamic> p;
  final List<double> cols;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: cols[0],
                child: Text(p['tenant_name']?.toString() ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xff1A1F36))),
              ),
              SizedBox(
                width: cols[1],
                child: Text(p['payment_method']?.toString() ?? 'Cash',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xff6B7280))),
              ),
              SizedBox(
                width: cols[2],
                child: Text(_fmtDate(p['payment_date']),
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xff8E9BB5))),
              ),
              SizedBox(
                width: cols[3],
                child: Text(_fmtAmt(p['amount']),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff16A34A))),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xffF0F2F8)),
      ],
    );
  }
}
