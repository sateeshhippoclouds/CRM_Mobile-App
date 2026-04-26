import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stacked/stacked.dart';

import '../../../../constants/app_colors.dart';
import '../../../../models/tenant_model.dart';
import 'ceo_tenants_viewmodel.dart';

class CeoTenantsView extends StatelessWidget {
  const CeoTenantsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<TenantsViewModel>.reactive(
      viewModelBuilder: () => TenantsViewModel(),
      onViewModelReady: (m) => m.init(),
      builder: (context, model, child) {
        return Scaffold(
          backgroundColor: const Color(0xffF5F5F7),
          appBar: AppBar(
            backgroundColor: Palette.primary,
            elevation: 0,
            title: const Text('Tenants',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18)),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: model.isBusy
              ? const Center(
                  child: CircularProgressIndicator(color: Palette.primary))
              : model.fetchError != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(model.fetchError!,
                              style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 12),
                          ElevatedButton(
                              onPressed: model.init,
                              child: const Text('Retry')),
                        ],
                      ),
                    )
                  : _TenantsBody(model: model),
        );
      },
    );
  }
}

class _TenantsBody extends StatelessWidget {
  const _TenantsBody({required this.model});
  final TenantsViewModel model;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: model.onSearch,
                decoration: InputDecoration(
                  hintText: 'Search tenants...',
                  hintStyle:
                      const TextStyle(color: Color(0xff9E9E9E), fontSize: 14),
                  suffixIcon:
                      const Icon(Icons.search, color: Color(0xff9E9E9E)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => _showDialog(context, model, null),
              style: ElevatedButton.styleFrom(
                backgroundColor: Palette.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('ADD TENANT',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.5)),
            ),
          ],
        ),
        _TabBar(model: model),
        const SizedBox(height: 8),
        Expanded(
          child: model.filtered.isEmpty
              ? const Center(
                  child: Text('No tenants found.',
                      style: TextStyle(color: Color(0xff716E6E))))
              : _TableView(
                  model: model, onEdit: (t) => _showDialog(context, model, t)),
        ),
      ],
    );
  }

  void _showDialog(
      BuildContext context, TenantsViewModel model, TenantModel? existing) {
    showDialog(
      context: context,
      builder: (_) => _TenantDialog(model: model, existing: existing),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.model});
  final TenantsViewModel model;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _Tab(
            label: 'ACTIVE',
            count: model.activeCount,
            selected: model.activeTab == 'active',
            onTap: () => model.setTab('active'),
          ),
          const SizedBox(width: 4),
          _Tab(
            label: 'INACTIVE',
            count: model.inactiveCount,
            selected: model.activeTab == 'inactive',
            onTap: () => model.setTab('inactive'),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab(
      {required this.label,
      required this.count,
      required this.selected,
      required this.onTap});
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? Palette.primary : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Palette.primary : const Color(0xff9E9E9E),
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _TableView extends StatelessWidget {
  const _TableView({required this.model, required this.onEdit});
  final TenantsViewModel model;
  final void Function(TenantModel) onEdit;

  static const _headers = [
    '#',
    'Tenant',
    'Contact Person',
    'Email',
    'Contact',
    'Subscription',
    'Duration',
    'Start',
    'End',
    'Total (₹)',
    'Status',
    'Actions',
  ];
  static const _cols = [
    36.0,
    130.0,
    130.0,
    155.0,
    110.0,
    110.0,
    90.0,
    95.0,
    95.0,
    90.0,
    80.0,
    80.0,
  ];

  static double get _totalWidth => _cols.fold<double>(0.0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: _totalWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _headerRow(),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: model.filtered.length,
                      itemBuilder: (_, i) =>
                          _dataRow(context, model.filtered[i], i, i % 2 == 0),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerRow() {
    return Container(
      color: const Color(0xffEFF4FF),
      child: Row(
        children: _headers.asMap().entries.map((e) {
          return SizedBox(
            width: _cols[e.key],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Text(e.value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Palette.primary)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _dataRow(BuildContext ctx, TenantModel t, int i, bool even) {
    return Container(
      color: even ? Colors.white : const Color(0xffFAFAFA),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _cell('${i + 1}', _cols[0],
              style: const TextStyle(color: Color(0xff716E6E), fontSize: 13)),
          _cell(t.tenantName ?? '—', _cols[1]),
          _cell(t.contactPerson ?? '—', _cols[2]),
          _cell(t.email ?? '—', _cols[3]),
          _cell(t.contactNumber ?? '—', _cols[4]),
          _cell(t.subscriptionName ?? '—', _cols[5]),
          SizedBox(
            width: _cols[6],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: _DurationBadge(t.duration ?? '—'),
            ),
          ),
          _cell(_fmtDate(t.startDate), _cols[7]),
          _cell(_fmtDate(t.endDate), _cols[8]),
          _cell('₹${_fmt(t.totalAmount)}', _cols[9]),
          SizedBox(
            width: _cols[10],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: _StatusBadge(t.isActive),
            ),
          ),
          SizedBox(
            width: _cols[11],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => onEdit(t),
                    icon: const Icon(Icons.edit_outlined,
                        color: Palette.primary, size: 20),
                    tooltip: 'Edit',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  IconButton(
                    onPressed: () => showDialog(
                      context: ctx,
                      builder: (_) => _PaymentHistoryDialog(tenant: t),
                    ),
                    icon: const Icon(Icons.history_rounded,
                        color: Color(0xffE65100), size: 22),
                    tooltip: 'Payment History',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(String text, double width, {TextStyle? style}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style ??
                const TextStyle(fontSize: 13, color: Color(0xff2D2D2D))),
      ),
    );
  }

  String _fmt(double? v) => v != null ? v.toStringAsFixed(2) : '0.00';

  String _fmtDate(String? date) {
    if (date == null || date.isEmpty) return '—';
    try {
      final d = DateTime.parse(date);
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}';
    } catch (_) {
      return date;
    }
  }
}

class _PaymentHistoryDialog extends StatelessWidget {
  const _PaymentHistoryDialog({required this.tenant});
  final TenantModel tenant;

  static const _headers = ['#', 'Amount', 'Method', 'Date', 'Ref', 'Notes'];
  static const _cols = [36.0, 90.0, 100.0, 100.0, 120.0, 140.0];

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<PaymentHistoryViewModel>.reactive(
      viewModelBuilder: () => PaymentHistoryViewModel(tenantId: tenant.id!),
      onViewModelReady: (vm) => vm.init(),
      builder: (context, vm, _) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Payment History — ${tenant.tenantName ?? ''}',
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Palette.primary),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                              color: Palette.primary,
                              borderRadius: BorderRadius.circular(6)),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (vm.isBusy)
                    const Center(
                        child:
                            CircularProgressIndicator(color: Palette.primary))
                  else if (vm.fetchError != null)
                    Center(
                        child: Text(vm.fetchError!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 13)))
                  else ...[
                    Flexible(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xffE0E0E0)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: _cols.fold<double>(0.0, (a, b) => a + b),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      color: const Color(0xffEFF4FF),
                                      child: Row(
                                        children: _headers
                                            .asMap()
                                            .entries
                                            .map((e) => SizedBox(
                                                  width: _cols[e.key],
                                                  child: Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 10,
                                                        horizontal: 8),
                                                    child: Text(e.value,
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 13,
                                                            color: Palette
                                                                .primary)),
                                                  ),
                                                ))
                                            .toList(),
                                      ),
                                    ),
                                    vm.payments.isEmpty
                                        ? const Padding(
                                            padding: EdgeInsets.all(24),
                                            child: Center(
                                              child: Text(
                                                  'No payments recorded.',
                                                  style: TextStyle(
                                                      color: Color(0xff9E9E9E),
                                                      fontSize: 13)),
                                            ),
                                          )
                                        : ListView.builder(
                                            shrinkWrap: true,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            itemCount: vm.payments.length,
                                            itemBuilder: (_, i) {
                                              final p = vm.payments[i];
                                              final even = i % 2 == 0;
                                              return Container(
                                                color: even
                                                    ? Colors.white
                                                    : const Color(0xffFAFAFA),
                                                child: Row(
                                                  children: [
                                                    _pcell(
                                                        '${i + 1}', _cols[0]),
                                                    _pcell(
                                                        '₹${_fmt(p['amount'])}',
                                                        _cols[1]),
                                                    _pcell(
                                                        p['payment_method']
                                                                ?.toString() ??
                                                            '—',
                                                        _cols[2]),
                                                    _pcell(
                                                        _fmtDate(
                                                            p['payment_date']),
                                                        _cols[3]),
                                                    _pcell(
                                                        p['transaction_id']
                                                                ?.toString() ??
                                                            '—',
                                                        _cols[4]),
                                                    _pcell(
                                                        p['notes']
                                                                ?.toString() ??
                                                            '—',
                                                        _cols[5]),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (vm.payments.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xffF1FBF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xff0F9E35)
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'Total Paid: ₹${_fmt(_totalPaid(vm.payments))}',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xff0F9E35)),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _pcell(String text, double width) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Color(0xff2D2D2D))),
      ),
    );
  }

  double _totalPaid(List<Map<String, dynamic>> payments) {
    return payments.fold(0.0, (sum, p) {
      final v = p['amount'];
      if (v == null) return sum;
      return sum +
          (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);
    });
  }

  String _fmt(dynamic v) {
    if (v == null) return '0.00';
    final d = v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
    return d.toStringAsFixed(2);
  }

  String _fmtDate(dynamic date) {
    if (date == null) return '—';
    try {
      final d = DateTime.parse(date.toString());
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}';
    } catch (_) {
      return date.toString();
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.active);
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xff0F9E35).withValues(alpha: 0.12)
            : Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'active' : 'inactive',
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active ? const Color(0xff0F9E35) : Colors.red),
      ),
    );
  }
}

class _DurationBadge extends StatelessWidget {
  const _DurationBadge(this.duration);
  final String duration;

  Color get _color {
    switch (duration.toLowerCase()) {
      case 'monthly':
        return const Color(0xff1A4FBA);
      case 'quarterly':
        return const Color(0xff7B2FBE);
      case 'half-yearly':
        return const Color(0xffE65100);
      case 'annually':
        return const Color(0xff0F9E35);
      case 'lifetime':
        return const Color(0xff00796B);
      default:
        return const Color(0xff607D8B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: _color, borderRadius: BorderRadius.circular(20)),
      child: Text(duration,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _TenantDialog extends StatelessWidget {
  const _TenantDialog({required this.model, this.existing});
  final TenantsViewModel model;
  final TenantModel? existing;

  static InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xff9E9E9E), fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xffE0E0E0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xffE0E0E0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Palette.primary)),
      );

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<TenantDialogViewModel>.reactive(
      viewModelBuilder: () => TenantDialogViewModel(existing: existing),
      onViewModelReady: (dm) => dm.init(),
      builder: (context, dm, _) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: dm.formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(dm.isEdit ? 'Edit Tenant' : 'Add Tenant',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Palette.primary)),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                                color: Palette.primary,
                                borderRadius: BorderRadius.circular(6)),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _sectionLabel('Tenant Information'),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: dm.nameCtrl,
                      decoration: _dec('Tenant Name *'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: dm.contactPersonCtrl,
                      decoration: _dec('Contact Person'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: dm.contactNumberCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _dec('Contact Number'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: dm.emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _dec('Email *'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (!v.contains('@')) return 'Invalid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: dm.passwordCtrl,
                      obscureText: true,
                      decoration: _dec(dm.isEdit
                          ? 'Password (leave blank to keep)'
                          : 'Password'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: dm.maxUsersCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _dec('Max Users'),
                    ),
                    const SizedBox(height: 20),
                    _sectionLabel('Subscription & Pricing'),
                    const SizedBox(height: 10),
                    dm.subscriptionsLoading
                        ? const Center(
                            child: Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(
                                color: Palette.primary, strokeWidth: 2),
                          ))
                        : DropdownButtonFormField<int>(
                            initialValue: dm.selectedSubscriptionId,
                            decoration: _dec('Service (Subscription)'),
                            items: dm.subscriptions
                                .map((s) => DropdownMenuItem(
                                    value: s.id,
                                    child: Text('${s.name} - ${s.duration} ')))
                                .toList(),
                            onChanged: dm.selectSubscription,
                          ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: dm.selectedDuration,
                      decoration: _dec('Duration'),
                      items: const [
                        DropdownMenuItem(
                            value: 'Monthly', child: Text('Monthly')),
                        DropdownMenuItem(
                            value: 'Quarterly', child: Text('Quarterly')),
                        DropdownMenuItem(
                            value: 'Half-Yearly', child: Text('Half-Yearly')),
                        DropdownMenuItem(
                            value: 'Annually', child: Text('Annually')),
                        DropdownMenuItem(
                            value: 'Lifetime', child: Text('Lifetime')),
                      ],
                      onChanged: dm.setDuration,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: dm.priceCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]'))
                            ],
                            decoration: _dec('Price (₹)'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: dm.taxCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]'))
                            ],
                            decoration: _dec('Tax (%)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: dm.totalCtrl,
                      readOnly: true,
                      decoration: _dec('Total Amount (₹)').copyWith(
                        fillColor: const Color(0xffFFF3E0),
                      ),
                      style: const TextStyle(color: Color(0xff9E6B00)),
                    ),
                    const SizedBox(height: 20),
                    _sectionLabel('Dates'),
                    const SizedBox(height: 10),
                    _DateField(
                      label: 'Start Date',
                      date: dm.startDate,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: dm.startDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2040),
                        );
                        if (picked != null) dm.setStartDate(picked);
                      },
                    ),
                    const SizedBox(height: 10),
                    _DateField(
                      label: 'End Date (editable)',
                      date: dm.endDate,
                      hint: 'Auto-calculated, but editable',
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: dm.endDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2040),
                        );
                        if (picked != null) dm.setEndDate(picked);
                      },
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: dm.status,
                      decoration: _dec('Status'),
                      items: const [
                        DropdownMenuItem(
                            value: 'active', child: Text('Active')),
                        DropdownMenuItem(
                            value: 'inactive', child: Text('Inactive')),
                      ],
                      onChanged: dm.setStatus,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: dm.isBusy
                                ? null
                                : () async {
                                    final ok = await dm.submit(model);
                                    if (!context.mounted) return;
                                    if (ok) {
                                      Navigator.pop(context);
                                    } else if (dm.hasError) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(dm.modelError
                                                  .toString()
                                                  .replaceFirst(
                                                      'Exception: ', '')),
                                              backgroundColor: Colors.red));
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Palette.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            child: dm.isBusy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : Text(dm.isEdit ? 'UPDATE' : 'CREATE',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Palette.primary,
                              side: const BorderSide(color: Palette.primary),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('CANCEL',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sectionLabel(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700, color: Palette.primary));
  }
}

class _DateField extends StatelessWidget {
  const _DateField(
      {required this.label,
      required this.date,
      required this.onTap,
      this.hint});
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final String? hint;

  String get _display {
    if (date == null) return hint ?? 'dd/mm/yyyy';
    return '${date!.day.toString().padLeft(2, '0')}/'
        '${date!.month.toString().padLeft(2, '0')}/'
        '${date!.year}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xff9E9E9E), fontSize: 12),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xffE0E0E0))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xffE0E0E0))),
          suffixIcon: const Icon(Icons.calendar_today_outlined,
              size: 18, color: Color(0xff9E9E9E)),
        ),
        child: Text(_display,
            style: TextStyle(
                fontSize: 14,
                color: date != null
                    ? const Color(0xff2D2D2D)
                    : const Color(0xff9E9E9E))),
      ),
    );
  }
}
