import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stacked/stacked.dart';

import '../../../../constants/app_colors.dart';
import '../../../../models/subscription_model.dart';
import 'ceo_subscriptions_viewmodel.dart';

class CeoSubscriptionsView extends StatelessWidget {
  const CeoSubscriptionsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<SubscriptionsViewModel>.reactive(
      viewModelBuilder: () => SubscriptionsViewModel(),
      onViewModelReady: (m) => m.init(),
      builder: (context, model, child) {
        return Scaffold(
          backgroundColor: const Color(0xffF5F5F7),
          appBar: AppBar(
            backgroundColor: Palette.primary,
            elevation: 0,
            title: const Text('Subscriptions',
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
                  : _SubscriptionsBody(model: model),
        );
      },
    );
  }
}

class _SubscriptionsBody extends StatelessWidget {
  const _SubscriptionsBody({required this.model});
  final SubscriptionsViewModel model;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: TextField(
            onChanged: model.onSearch,
            decoration: InputDecoration(
              hintText: 'Search subscriptions...',
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xffE0E0E0)),
                ),
                child: Row(
                  children: [
                    _ToggleBtn(
                      icon: Icons.grid_view_rounded,
                      selected: !model.isListView,
                      onTap: () => model.setListView(false),
                    ),
                    _ToggleBtn(
                      icon: Icons.list_rounded,
                      selected: model.isListView,
                      onTap: () => model.setListView(true),
                    ),
                  ],
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
                label: const Text('ADD SUBSCRIPTION',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.5)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: model.filtered.isEmpty
              ? const Center(
                  child: Text('No subscriptions found.',
                      style: TextStyle(color: Color(0xff716E6E))))
              : model.isListView
                  ? _TableView(model: model)
                  : _GridView(model: model),
        ),
      ],
    );
  }

  void _showDialog(BuildContext context, SubscriptionsViewModel model,
      SubscriptionModel? existing) {
    showDialog(
      context: context,
      builder: (_) => _SubscriptionDialog(model: model, existing: existing),
    );
  }
}

class _TableView extends StatelessWidget {
  const _TableView({required this.model});
  final SubscriptionsViewModel model;

  static const _cols = [36.0, 140.0, 110.0, 90.0, 80.0, 100.0, 90.0, 90.0];

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
                width: _cols.fold<double>(0.0, (a, b) => a + b),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row(
                      bgColor: const Color(0xffEFF4FF),
                      cells: [
                        '#',
                        'Name',
                        'Duration',
                        'Price',
                        'Tax',
                        'Total',
                        'Status',
                        'Actions'
                      ],
                      isHeader: true,
                    ),
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

  Widget _row(
      {required List<String> cells,
      required Color bgColor,
      bool isHeader = false}) {
    return Container(
      color: bgColor,
      child: Row(
        children: cells.asMap().entries.map((e) {
          return SizedBox(
            width: _cols[e.key],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Text(
                e.value,
                style: TextStyle(
                  fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                  color: isHeader ? Palette.primary : const Color(0xff2D2D2D),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _dataRow(
      BuildContext context, SubscriptionModel s, int index, bool even) {
    final active = s.isActive;
    return Container(
      color: even ? Colors.white : const Color(0xffFAFAFA),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _cell('${index + 1}', _cols[0],
              style: const TextStyle(color: Color(0xff716E6E), fontSize: 13)),
          _cell(s.name ?? '—', _cols[1]),
          SizedBox(
            width: _cols[2],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: _DurationBadge(s.duration ?? '—'),
            ),
          ),
          _cell('₹${_fmt(s.price)}', _cols[3]),
          _cell('₹${_fmt(s.tax)}', _cols[4]),
          _cell('₹${_fmt(s.totalAmount)}', _cols[5]),
          SizedBox(
            width: _cols[6],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: _StatusBadge(active),
            ),
          ),
          SizedBox(
            width: _cols[7],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) =>
                          _SubscriptionDialog(model: model, existing: s),
                    ),
                    icon: const Icon(Icons.edit_outlined,
                        color: Palette.primary, size: 20),
                    tooltip: 'Edit',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  model.togglingId == s.id
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Palette.primary))
                      : IconButton(
                          onPressed: () => model.toggleStatus(s),
                          icon: Icon(
                            active ? Icons.close_rounded : Icons.check_rounded,
                            color:
                                active ? Colors.red : const Color(0xff0F9E35),
                            size: 22,
                          ),
                          tooltip: active ? 'Deactivate' : 'Activate',
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
            style: style ??
                const TextStyle(fontSize: 13, color: Color(0xff2D2D2D))),
      ),
    );
  }

  String _fmt(double? v) => v != null ? v.toStringAsFixed(2) : '0.00';
}

class _GridView extends StatelessWidget {
  const _GridView({required this.model});
  final SubscriptionsViewModel model;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.05),
      itemCount: model.filtered.length,
      itemBuilder: (_, i) {
        final s = model.filtered[i];
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
              Row(
                children: [
                  _DurationBadge(s.duration ?? '—'),
                  const Spacer(),
                  _StatusBadge(s.isActive),
                ],
              ),
              const SizedBox(height: 8),
              Text(s.name ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              const Spacer(),
              Text('₹${s.totalAmount?.toStringAsFixed(2) ?? '0.00'}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Palette.primary)),
              Text('Price ₹${s.price?.toStringAsFixed(2) ?? '0.00'} ',
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xff9E9E9E))),
              const Spacer(),
              Text('Tax ₹${s.tax?.toStringAsFixed(2) ?? '0.00'}',
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xff9E9E9E))),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) =>
                          _SubscriptionDialog(model: model, existing: s),
                    ),
                    child: const Icon(Icons.edit_outlined,
                        color: Palette.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => model.toggleStatus(s),
                    child: Icon(
                      s.isActive ? Icons.close_rounded : Icons.check_rounded,
                      color: s.isActive ? Colors.red : const Color(0xff0F9E35),
                      size: 22,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SubscriptionDialog extends StatelessWidget {
  const _SubscriptionDialog({required this.model, this.existing});
  final SubscriptionsViewModel model;
  final SubscriptionModel? existing;

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
    return ViewModelBuilder<SubscriptionDialogViewModel>.reactive(
      viewModelBuilder: () => SubscriptionDialogViewModel(existing: existing),
      onViewModelReady: (dm) => dm.init(),
      builder: (context, dm, _) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(vertical: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: dm.formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                            dm.isEdit
                                ? 'Edit Subscription'
                                : 'Add Subscription',
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
                  TextFormField(
                    controller: dm.nameCtrl,
                    decoration: _dec('Subscription Name *'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: dm.duration,
                    decoration: _dec('Duration *'),
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
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: dm.priceCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                    ],
                    decoration: _dec('Price (₹) *'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: dm.taxCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                    ],
                    decoration: _dec('Tax (%)'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: dm.totalCtrl,
                    readOnly: true,
                    decoration: _dec('Total Amount (₹)').copyWith(
                      filled: true,
                      fillColor: const Color(0xffFFF3E0),
                    ),
                    style: const TextStyle(color: Color(0xff9E6B00)),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: dm.status,
                    decoration: _dec('Status'),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Active')),
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
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
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
        );
      },
    );
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
      case 'yearly':
        return const Color(0xff0F9E35);
      default:
        return const Color(0xff607D8B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: _color, borderRadius: BorderRadius.circular(20)),
      child: Text(duration,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  const _ToggleBtn(
      {required this.icon, required this.selected, required this.onTap});
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? Palette.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child:
            Icon(icon, size: 20, color: selected ? Colors.white : Colors.grey),
      ),
    );
  }
}
