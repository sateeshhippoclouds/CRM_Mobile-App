import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import '../../../../constants/app_colors.dart';
import '../../../../models/tenant_model.dart';
import 'ceo_tenant_payments_viewmodel.dart';
import 'ceo_tenants_viewmodel.dart';

class CeoTenantPaymentsView extends StatelessWidget {
  const CeoTenantPaymentsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<TenantPaymentsViewModel>.reactive(
      viewModelBuilder: () => TenantPaymentsViewModel(),
      onViewModelReady: (m) => m.init(),
      builder: (context, model, child) {
        return Scaffold(
          backgroundColor: const Color(0xffF5F5F7),
          appBar: AppBar(
            backgroundColor: Palette.primary,
            elevation: 0,
            title: const Text(
              'Tenant Payments',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18),
            ),
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
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 12),
                          ElevatedButton(
                              onPressed: model.init,
                              child: const Text('Retry')),
                        ],
                      ),
                    )
                  : _TenantPaymentsBody(model: model),
        );
      },
    );
  }
}

class _TenantPaymentsBody extends StatelessWidget {
  const _TenantPaymentsBody({required this.model});
  final TenantPaymentsViewModel model;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: TextField(
            onChanged: model.onSearch,
            decoration: InputDecoration(
              hintText: 'Search by tenant, email, subscription or status...',
              hintStyle:
                  const TextStyle(color: Color(0xff9E9E9E), fontSize: 14),
              suffixIcon: const Icon(Icons.search, color: Color(0xff9E9E9E)),
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
        _SummaryStrip(model: model),
        const SizedBox(height: 8),
        Expanded(
          child: model.filtered.isEmpty
              ? const Center(
                  child: Text('No records found.',
                      style: TextStyle(color: Color(0xff716E6E))))
              : _PaymentsTable(model: model),
        ),
      ],
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.model});
  final TenantPaymentsViewModel model;

  @override
  Widget build(BuildContext context) {
    final paid = model.filtered.where((s) => s.status == 'Paid').length;
    final partial = model.filtered.where((s) => s.status == 'Partial').length;
    final unpaid = model.filtered.where((s) => s.status == 'Unpaid').length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _SummaryChip(
              label: 'Paid', count: paid, color: const Color(0xff0F9E35)),
          const SizedBox(width: 8),
          _SummaryChip(
              label: 'Partial', count: partial, color: const Color(0xffE65100)),
          const SizedBox(width: 8),
          _SummaryChip(label: 'Unpaid', count: unpaid, color: Colors.red),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip(
      {required this.label, required this.count, required this.color});
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label: $count',
        style:
            TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _PaymentsTable extends StatelessWidget {
  const _PaymentsTable({required this.model});
  final TenantPaymentsViewModel model;

  static const _headers = [
    '#',
    'Tenant',
    'Email',
    'Subscription',
    'Duration',
    'Total (₹)',
    'Paid (₹)',
    'Balance (₹)',
    'Status',
    'Actions',
  ];
  static const _cols = [
    36.0,
    130.0,
    160.0,
    110.0,
    90.0,
    95.0,
    95.0,
    100.0,
    82.0,
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
                      itemBuilder: (ctx, i) =>
                          _dataRow(ctx, model.filtered[i], i, i % 2 == 0),
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

  Widget _dataRow(BuildContext ctx, TenantPaymentSummary s, int i, bool even) {
    final t = s.tenant;
    return Container(
      color: even ? Colors.white : const Color(0xffFAFAFA),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _cell('${i + 1}', _cols[0],
              style: const TextStyle(color: Color(0xff716E6E), fontSize: 13)),
          _cell(t.tenantName ?? '—', _cols[1]),
          _cell(t.email ?? '—', _cols[2]),
          _cell(t.subscriptionName ?? '—', _cols[3]),
          SizedBox(
            width: _cols[4],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: _DurationBadge(t.duration ?? '—'),
            ),
          ),
          _cell('₹${_fmt(t.totalAmount)}', _cols[5]),
          _cell('₹${_fmt(s.paid)}', _cols[6],
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xff0F9E35),
                  fontWeight: FontWeight.w600)),
          _cell('₹${_fmt(s.balance)}', _cols[7],
              style: TextStyle(
                  fontSize: 13,
                  color: s.balance > 0 ? Colors.red : const Color(0xff2D2D2D),
                  fontWeight:
                      s.balance > 0 ? FontWeight.w600 : FontWeight.normal)),
          SizedBox(
            width: _cols[8],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: _PayStatusBadge(s.status),
            ),
          ),
          SizedBox(
            width: _cols[9],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => showDialog(
                      context: ctx,
                      builder: (_) => _RecordPaymentDialog(
                        summary: s,
                        onRefresh: model.init,
                      ),
                    ),
                    icon: const Icon(Icons.credit_card_rounded,
                        color: Colors.green, size: 20),
                    tooltip: 'Record Payment',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                  IconButton(
                    onPressed: () => showDialog(
                      context: ctx,
                      builder: (_) => _PaymentHistoryDialog(tenant: t),
                    ),
                    icon: const Icon(Icons.history_rounded,
                        color: Color(0xffE65100), size: 20),
                    tooltip: 'Payment History',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
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
}

// ─── Record Payment Dialog ────────────────────────────────────────────────────

class _RecordPaymentDialog extends StatelessWidget {
  const _RecordPaymentDialog({required this.summary, required this.onRefresh});
  final TenantPaymentSummary summary;
  final VoidCallback onRefresh;

  static const _methods = [
    'Cash',
    'Online Transfer',
    'Bank Transfer',
    'UPI',
    'Cheque',
  ];

  static InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xff9E9E9E), fontSize: 14),
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
    return ViewModelBuilder<RecordPaymentViewModel>.reactive(
      viewModelBuilder: () => RecordPaymentViewModel(
        tenantId: summary.tenant.id!,
        totalAmount: summary.tenant.totalAmount ?? 0,
        alreadyPaid: summary.paid,
        onSuccess: () {
          onRefresh();
          Navigator.pop(context);
        },
      ),
      builder: (context, dm, _) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(vertical: 24),
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
                    // ── Title bar ──
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Record Payment — ${summary.tenant.tenantName ?? ''}',
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
                    const SizedBox(height: 20),

                    // ── Summary box ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xffEBF4FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Subscription Total: ₹${_fmt(dm.totalAmount)}',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff2D2D2D)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Already Paid: ₹${_fmt(dm.alreadyPaid)}',
                            style: const TextStyle(
                                fontSize: 14, color: Color(0xff0F9E35)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Pending Balance: ₹${_fmt(dm.pendingBalance)}',
                            style: const TextStyle(
                                fontSize: 14, color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Amount ──
                    TextFormField(
                      controller: dm.amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: _dec('Amount Paying *'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final d = double.tryParse(v.trim());
                        if (d == null || d <= 0) return 'Enter a valid amount';
                        return null;
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Text(
                        'Balance: ₹${_fmt(dm.pendingBalance)}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xff9E9E9E)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Payment Method ──
                    DropdownButtonFormField<String>(
                      initialValue: dm.paymentMethod,
                      decoration:
                          _dec('').copyWith(labelText: 'Payment Method'),
                      items: _methods
                          .map(
                              (m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: dm.setPaymentMethod,
                    ),
                    const SizedBox(height: 14),

                    // ── Payment Date ──
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: dm.paymentDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2040),
                        );
                        if (picked != null) dm.setPaymentDate(picked);
                      },
                      child: InputDecorator(
                        decoration: _dec('').copyWith(
                          labelText: 'Payment Date',
                          suffixIcon: const Icon(Icons.calendar_today_outlined,
                              size: 18, color: Color(0xff9E9E9E)),
                        ),
                        child: Text(
                          '${dm.paymentDate.day.toString().padLeft(2, '0')}/'
                          '${dm.paymentDate.month.toString().padLeft(2, '0')}/'
                          '${dm.paymentDate.year}',
                          style: const TextStyle(
                              fontSize: 14, color: Color(0xff2D2D2D)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Transaction ID ──
                    TextFormField(
                      controller: dm.transactionCtrl,
                      decoration: _dec('Transaction ID / Reference'),
                    ),
                    const SizedBox(height: 14),

                    // ── Notes ──
                    TextFormField(
                      controller: dm.notesCtrl,
                      minLines: 3,
                      maxLines: 5,
                      decoration: _dec('Notes'),
                    ),
                    const SizedBox(height: 24),

                    if (dm.hasError)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          dm.modelError
                              .toString()
                              .replaceFirst('Exception: ', ''),
                          style:
                              const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),

                    // ── Buttons ──
                    Row(
                      children: [
                        GestureDetector(
                          onTap: dm.isBusy ? null : dm.submit,
                          child: Container(
                            padding: const EdgeInsetsDirectional.symmetric(
                                horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xff3A7D44),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: dm.isBusy
                                ? const SizedBox(
                                    width: 100,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Text('RECORD PAYMENT',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    )),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsetsDirectional.symmetric(
                                horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: Palette.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('CANCEL',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                )),
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

  String _fmt(double v) => v.toStringAsFixed(2);
}

// ─── Payment History Dialog ───────────────────────────────────────────────────

class _PaymentHistoryDialog extends StatelessWidget {
  const _PaymentHistoryDialog({required this.tenant});
  final TenantModel tenant;

  static const _headers = [
    '#',
    'Amount',
    'Method',
    'Date',
    'Transaction ID',
    'Notes'
  ];
  static const _cols = [36.0, 90.0, 110.0, 100.0, 130.0, 140.0];

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<PaymentHistoryViewModel>.reactive(
      viewModelBuilder: () => PaymentHistoryViewModel(tenantId: tenant.id!),
      onViewModelReady: (vm) => vm.init(),
      builder: (context, vm, _) {
        final totalOwed = tenant.totalAmount ?? 0.0;
        final totalPaid = _sumPaid(vm.payments);
        final balance = (totalOwed - totalPaid).clamp(0, double.infinity);

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(vertical: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580, maxHeight: 580),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Title bar ──
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
                    // ── Summary cards ──
                    Row(
                      children: [
                        Expanded(
                          child: _InfoCard(
                            label: 'Total Owed',
                            value: '₹${_fmt(totalOwed)}',
                            bg: const Color(0xffEBF4FF),
                            valueColor: Palette.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _InfoCard(
                            label: 'Total Paid',
                            value: '₹${_fmt(totalPaid)}',
                            bg: const Color(0xffF1FBF4),
                            valueColor: const Color(0xff0F9E35),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _InfoCard(
                            label: 'Balance',
                            value: '₹${_fmt(balance.toDouble())}',
                            bg: const Color(0xffFFF0F0),
                            valueColor: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _InfoCard(
                            label: 'Payments',
                            value: '${vm.payments.length}',
                            bg: const Color(0xffFCF0FF),
                            valueColor: const Color(0xff7B2FBE),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Payments table ──
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
                                                  'No payments recorded yet.',
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
                                                        '₹${_fmt(_toDouble(p['amount']))}',
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

  double _sumPaid(List<Map<String, dynamic>> payments) =>
      payments.fold(0.0, (s, p) => s + _toDouble(p['amount']));

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  String _fmt(double v) => v.toStringAsFixed(2);

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

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.label,
    required this.value,
    required this.bg,
    required this.valueColor,
  });
  final String label;
  final String value;
  final Color bg;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xff6B6B6B))),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: valueColor)),
        ],
      ),
    );
  }
}

class _PayStatusBadge extends StatelessWidget {
  const _PayStatusBadge(this.status);
  final String status;

  Color get _color {
    switch (status) {
      case 'Paid':
        return const Color(0xff0F9E35);
      case 'Partial':
        return const Color(0xffE65100);
      default:
        return Colors.brown;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status,
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _color),
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
