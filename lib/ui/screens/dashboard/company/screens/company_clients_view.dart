import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stacked/stacked.dart';

import '../../../../../app/app.locator.dart';
import '../../../../../services/api_services.dart';
import 'company_clients_viewmodel.dart';
import 'crm_widgets.dart';

// ─── Main screen ──────────────────────────────────────────────────────────────

class CompanyClientsView extends StatefulWidget {
  const CompanyClientsView({super.key});

  @override
  State<CompanyClientsView> createState() => _CompanyClientsViewState();
}

class _CompanyClientsViewState extends State<CompanyClientsView> {
  final _searchCtrl = TextEditingController();
  final _hScroll = ScrollController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  void _showCustomizeColumns(CompanyClientsViewModel model) {
    showDialog(
      context: context,
      builder: (_) => _CustomizeColumnsDialog(model: model),
    );
  }

  void _showAddDialog(CompanyClientsViewModel model,
      [Map<String, dynamic>? item, bool reactivate = false]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddClientDialog(
        item: item,
        reactivate: reactivate,
        onSave: model.addClient,
        onUpdate: (id, data, {String tab = '1'}) =>
            model.updateClient(id, data, tab: tab),
      ),
    );
  }

  void _showDeleteConfirm(
      Map<String, dynamic> item, CompanyClientsViewModel model) {
    final name = item['client_name']?.toString() ?? 'this client';
    final id = item['id'];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(vertical: 24),
        title: const Text('Delete Client',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('Delete "$name"? This cannot be undone.',
            style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final err = await model.deleteClient(id);
              if (err != null && mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(err)));
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffDC2626),
                foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _reactivate(Map<String, dynamic> item, CompanyClientsViewModel model) {
    final name = item['client_name']?.toString() ?? 'this client';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(vertical: 24),
        title: const Text('Reactivate Client',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('Move "$name" back to active?',
            style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final err = await model.reactivateClient(item);
              if (err != null && mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(err)));
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff16A34A),
                foregroundColor: Colors.white),
            child: const Text('Reactivate'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<CompanyClientsViewModel>.reactive(
      viewModelBuilder: () => CompanyClientsViewModel(),
      onViewModelReady: (m) => m.init(),
      builder: (context, model, _) {
        return Scaffold(
          backgroundColor: kCrmBg,
          appBar: crmAppBar('Clients'),
          body: model.isBusy
              ? const Center(child: CircularProgressIndicator(color: kCrmBlue))
              : model.fetchError != null
                  ? CrmErrorBody(error: model.fetchError!, onRetry: model.init)
                  : Column(
                      children: [
                        _Toolbar(
                          searchCtrl: _searchCtrl,
                          model: model,
                          onAdd: model.canWrite
                              ? () => _showAddDialog(model)
                              : null,
                          onColumns: () => _showCustomizeColumns(model),
                        ),
                        if (model.hasActiveFilters)
                          _ActiveFilterChips(model: model),
                        if (model.hasSelection) _SelectionBar(model: model),
                        Expanded(
                          child: _ClientTable(
                            model: model,
                            hScroll: _hScroll,
                            canUpdate: model.canUpdate,
                            canDelete: model.canDelete,
                            onEdit: (item) => _showAddDialog(model, item),
                            onDelete: (item) =>
                                _showDeleteConfirm(item, model),
                            onReactivate: (item) => _reactivate(item, model),
                          ),
                        ),
                        _PaginationBar(model: model),
                      ],
                    ),
        );
      },
    );
  }
}

// ─── Toolbar ──────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.searchCtrl,
    required this.model,
    this.onAdd,
    required this.onColumns,
  });
  final TextEditingController searchCtrl;
  final CompanyClientsViewModel model;
  final VoidCallback? onAdd;
  final VoidCallback onColumns;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 220,
              height: 38,
              child: TextField(
                controller: searchCtrl,
                onChanged: model.search,
                decoration: InputDecoration(
                  hintText: 'Search clients...',
                  hintStyle: const TextStyle(
                      color: Color(0xff9CA3AF), fontSize: 12),
                  prefixIcon: const Icon(Icons.search,
                      color: Color(0xff9CA3AF), size: 18),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: searchCtrl,
                    builder: (_, v, __) => v.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close,
                                size: 16, color: Color(0xff9CA3AF)),
                            onPressed: () {
                              searchCtrl.clear();
                              model.search('');
                            },
                          )
                        : const SizedBox.shrink(),
                  ),
                  filled: true,
                  fillColor: const Color(0xffF9FAFB),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xffE5E7EB))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xffE5E7EB))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kCrmBlue)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _TabDropdown(model: model),
            if (onAdd != null) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 38,
                child: ElevatedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('ADD CLIENT',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kCrmBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            _IconBtn(
              icon: Icons.download_outlined,
              tooltip: 'Export CSV',
              onTap: () {
                final csv = model.buildCsvContent();
                Clipboard.setData(ClipboardData(text: csv));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('CSV copied to clipboard'),
                      duration: Duration(seconds: 2)),
                );
              },
            ),
            const SizedBox(width: 4),
            _IconBtn(
              icon: Icons.view_column_outlined,
              tooltip: 'Customize Columns',
              onTap: onColumns,
            ),
          ],
        ),
      ),
    );
  }
}

class _TabDropdown extends StatelessWidget {
  const _TabDropdown({required this.model});
  final CompanyClientsViewModel model;

  static const _dotColors = {
    'active': Color(0xff16A34A),
    'inactive': Color(0xffDC2626),
    'draft': Color(0xffF59E0B),
  };

  @override
  Widget build(BuildContext context) {
    final dot = _dotColors[model.tab] ?? const Color(0xff6B7280);
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffD1D5DB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: model.tab,
        underline: const SizedBox.shrink(),
        isDense: true,
        icon: const Icon(Icons.arrow_drop_down, size: 18),
        items: CompanyClientsViewModel.tabOptions
            .map((opt) => DropdownMenuItem<String>(
                  value: opt['value'],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(opt['label']!,
                          style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _dotColors[opt['value']] ??
                              const Color(0xff6B7280),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
        onChanged: (v) {
          if (v != null) model.setTab(v);
        },
        selectedItemBuilder: (_) => CompanyClientsViewModel.tabOptions
            .map((opt) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(opt['label']!,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: dot, shape: BoxShape.circle),
                    ),
                  ],
                ))
            .toList(),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn(
      {required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xffE5E7EB)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: const Color(0xff374151)),
        ),
      ),
    );
  }
}

// ─── Selection bar ────────────────────────────────────────────────────────────

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.model});
  final CompanyClientsViewModel model;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kCrmBlue.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_box_outlined, size: 16, color: kCrmBlue),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${model.selectedCount} row(s) selected — CSV exports selected only',
              style: const TextStyle(fontSize: 12, color: kCrmBlue),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: model.clearSelection,
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero, minimumSize: const Size(40, 24)),
            child: const Text('Clear',
                style: TextStyle(fontSize: 11, color: Color(0xffDC2626))),
          ),
        ],
      ),
    );
  }
}

// ─── Active filter chips ──────────────────────────────────────────────────────

class _ActiveFilterChips extends StatelessWidget {
  const _ActiveFilterChips({required this.model});
  final CompanyClientsViewModel model;

  String _label(String key) {
    final match =
        CompanyClientsViewModel.allColumns.where((c) => c.key == key);
    return match.isNotEmpty ? match.first.label : key;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_outlined,
              size: 14, color: Color(0xff6B7280)),
          const SizedBox(width: 6),
          Expanded(
            child: Wrap(
              spacing: 6,
              children: model.colFilters.entries.map((e) {
                return Chip(
                  label: Text('${_label(e.key)}: ${e.value}',
                      style: const TextStyle(fontSize: 11)),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => model.setColFilter(e.key, ''),
                  backgroundColor: kCrmBlue.withValues(alpha: 0.08),
                  labelStyle: const TextStyle(color: kCrmBlue),
                  deleteIconColor: kCrmBlue,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ),
          TextButton(
            onPressed: model.clearAllFilters,
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero, minimumSize: const Size(40, 24)),
            child: const Text('Clear All',
                style: TextStyle(fontSize: 11, color: Color(0xffDC2626))),
          ),
        ],
      ),
    );
  }
}

// ─── Scrollable data table ────────────────────────────────────────────────────

class _ClientTable extends StatelessWidget {
  const _ClientTable({
    required this.model,
    required this.hScroll,
    required this.canUpdate,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
    required this.onReactivate,
  });
  final CompanyClientsViewModel model;
  final ScrollController hScroll;
  final bool canUpdate;
  final bool canDelete;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onDelete;
  final ValueChanged<Map<String, dynamic>> onReactivate;

  static const double _headerH = 48.0;
  static const double _rowH = 52.0;

  @override
  Widget build(BuildContext context) {
    if (model.items.isEmpty) {
      return const CrmEmptyState(
        icon: Icons.people_outline_rounded,
        title: 'No Clients Found',
        subtitle: 'Add your first client or adjust your filters',
      );
    }

    final cols = model.visibleColumns;
    return LayoutBuilder(builder: (ctx, constraints) {
      final totalW = max(
        cols.fold<double>(0, (s, c) => s + c.width),
        constraints.maxWidth,
      );

      return Scrollbar(
        controller: hScroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: hScroll,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalW,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: _headerH,
                  decoration: const BoxDecoration(
                    color: Color(0xffF3F4F6),
                    border: Border(
                        bottom: BorderSide(color: Color(0xffE5E7EB))),
                  ),
                  child: Row(
                    children: cols
                        .map((col) => _HeaderCell(
                            col: col, model: model, screenCtx: context))
                        .toList(),
                  ),
                ),
                SizedBox(
                  height: constraints.maxHeight - _headerH,
                  child: ListView.builder(
                    itemCount: model.items.length,
                    itemExtent: _rowH,
                    itemBuilder: (_, i) {
                      final item = model.items[i];
                      final id = item['id'];
                      return _DataRow(
                        item: item,
                        rowIndex: model.pageStart + i,
                        cols: cols,
                        isEven: i % 2 == 0,
                        isSelected: model.isSelected(id),
                        canUpdate: canUpdate,
                        canDelete: canDelete,
                        isNonActive: model.isNonActiveTab,
                        onToggleSelect: () => model.toggleRowSelection(id),
                        onEdit: () => onEdit(item),
                        onDelete: () => onDelete(item),
                        onReactivate: () => onReactivate(item),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

// ─── Header cell ──────────────────────────────────────────────────────────────

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(
      {required this.col, required this.model, required this.screenCtx});
  final ClientColumnDef col;
  final CompanyClientsViewModel model;
  final BuildContext screenCtx;

  void _showFilterDialog() {
    showDialog(
      context: screenCtx,
      builder: (_) => _ColFilterDialog(col: col, model: model),
    );
  }

  static const _div = BorderSide(color: Color(0xffD1D5DB), width: 0.8);

  @override
  Widget build(BuildContext context) {
    if (col.key == 'checkbox') {
      final allSel = model.allCurrentSelected;
      final someSel = model.someCurrentSelected;
      return Container(
        width: col.width,
        height: 48,
        decoration: const BoxDecoration(border: Border(right: _div)),
        child: Center(
          child: Checkbox(
            value: allSel ? true : someSel ? null : false,
            tristate: true,
            activeColor: kCrmBlue,
            onChanged: (_) => model.toggleSelectAll(),
          ),
        ),
      );
    }

    final isFiltered = model.colFilters.containsKey(col.key);

    return Container(
      width: col.width,
      height: 48,
      decoration: const BoxDecoration(border: Border(right: _div)),
      padding: const EdgeInsets.only(left: 8, right: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(col.label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff374151)),
                  overflow: TextOverflow.ellipsis),
            ),
            if (col.filterable) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: _showFilterDialog,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isFiltered
                        ? kCrmBlue.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    isFiltered
                        ? Icons.filter_alt_rounded
                        : Icons.filter_list_rounded,
                    size: 14,
                    color: isFiltered ? kCrmBlue : const Color(0xff9CA3AF),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Column filter dialog ─────────────────────────────────────────────────────

class _ColFilterDialog extends StatefulWidget {
  const _ColFilterDialog({required this.col, required this.model});
  final ClientColumnDef col;
  final CompanyClientsViewModel model;

  @override
  State<_ColFilterDialog> createState() => _ColFilterDialogState();
}

class _ColFilterDialogState extends State<_ColFilterDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.model.colFilters[widget.col.key] ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _apply() {
    widget.model.setColFilter(widget.col.key, _ctrl.text);
    Navigator.pop(context);
  }

  void _clear() {
    widget.model.setColFilter(widget.col.key, '');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(vertical: 24),
      title: Text('Filter by ${widget.col.label}',
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xff1A1F36))),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        onSubmitted: (_) => _apply(),
        decoration: InputDecoration(
          hintText: 'Filter ${widget.col.label}',
          hintStyle:
              const TextStyle(fontSize: 13, color: Color(0xff9CA3AF)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xffD1D5DB))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: kCrmBlue)),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 13),
      ),
      actions: [
        TextButton(
            onPressed: _clear,
            child: const Text('CLEAR',
                style: TextStyle(color: Color(0xff6B7280)))),
        ElevatedButton(
          onPressed: _apply,
          style: ElevatedButton.styleFrom(
              backgroundColor: kCrmBlue, foregroundColor: Colors.white),
          child: const Text('APPLY'),
        ),
      ],
    );
  }
}

// ─── Data row ─────────────────────────────────────────────────────────────────

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.item,
    required this.rowIndex,
    required this.cols,
    required this.isEven,
    required this.isSelected,
    required this.canUpdate,
    required this.canDelete,
    required this.isNonActive,
    required this.onToggleSelect,
    required this.onEdit,
    required this.onDelete,
    required this.onReactivate,
  });

  final Map<String, dynamic> item;
  final int rowIndex;
  final List<ClientColumnDef> cols;
  final bool isEven;
  final bool isSelected;
  final bool canUpdate;
  final bool canDelete;
  final bool isNonActive;
  final VoidCallback onToggleSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReactivate;

  static const _statusColors = {
    'active': Color(0xff16A34A),
    'inactive': Color(0xffDC2626),
  };

  Widget _cell(ClientColumnDef col) {
    if (col.key == 'checkbox') {
      return SizedBox(
        width: col.width,
        height: 52,
        child: Center(
          child: Checkbox(
            value: isSelected,
            activeColor: kCrmBlue,
            onChanged: (_) => onToggleSelect(),
          ),
        ),
      );
    }

    if (col.key == 'sno') {
      return _C(
        width: col.width,
        child: Text('${item['id'] ?? rowIndex}',
            style:
                const TextStyle(fontSize: 12, color: Color(0xff6B7280))),
      );
    }

    if (col.key == 'status') {
      final status = item['status']?.toString() ?? '';
      final color =
          _statusColors[status.toLowerCase()] ?? const Color(0xff6B7280);
      return _C(
        width: col.width,
        child: Text(status,
            style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600)),
      );
    }

    if (col.key == 'action') {
      return SizedBox(
        width: col.width,
        height: 52,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (canUpdate)
              _Btn(
                  icon: Icons.edit_outlined,
                  color: kCrmBlue,
                  onTap: onEdit),
            if (canDelete) ...[
              const SizedBox(width: 2),
              _Btn(
                  icon: Icons.delete_outline,
                  color: const Color(0xffDC2626),
                  onTap: onDelete),
            ],
            if (isNonActive) ...[
              const SizedBox(width: 2),
              _Btn(
                icon: Icons.refresh_rounded,
                color: const Color(0xff16A34A),
                onTap: onReactivate,
                tooltip: 'Reactivate',
              ),
            ],
          ],
        ),
      );
    }

    // Service-derived columns
    if (col.key.startsWith('svc_')) {
      final svc = CompanyClientsViewModel.firstService(item);
      String val = '—';
      if (svc != null) {
        if (col.key == 'svc_name') {
          val = svc['service_name']?.toString() ??
              svc['product_name']?.toString() ??
              svc['svc_name']?.toString() ??
              '—';
        } else if (col.key == 'svc_duration') {
          val = svc['opted_duration']?.toString() ??
              svc['duration']?.toString() ??
              '—';
        } else if (col.key == 'svc_base_price') {
          val = svc['base_price']?.toString() ?? '—';
        } else if (col.key == 'svc_tax') {
          final t = svc['tax_rate']?.toString() ?? '';
          val = t.isNotEmpty
              ? (t.contains('%') ? t : '$t%')
              : '—';
        } else if (col.key == 'svc_start_date') {
          val = CompanyClientsViewModel.fmtDate(svc['start_date']);
        } else if (col.key == 'svc_end_date') {
          val = CompanyClientsViewModel.fmtDate(svc['end_date']);
        } else if (col.key == 'svc_req_duration') {
          val = svc['original_duration']?.toString() ?? '—';
        }
      }
      return _C(
        width: col.width,
        child: Text(val,
            style:
                const TextStyle(fontSize: 12, color: Color(0xff374151)),
            overflow: TextOverflow.ellipsis),
      );
    }

    final val = item[col.key]?.toString() ?? '—';
    return _C(
      width: col.width,
      child: Text(val,
          style: const TextStyle(fontSize: 12, color: Color(0xff374151)),
          overflow: TextOverflow.ellipsis,
          maxLines: 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: isSelected
            ? kCrmBlue.withValues(alpha: 0.06)
            : isEven
                ? Colors.white
                : const Color(0xffFAFAFF),
        border: const Border(
            bottom: BorderSide(color: Color(0xffE5E7EB), width: 0.5)),
      ),
      child: Row(children: cols.map(_cell).toList()),
    );
  }
}

class _C extends StatelessWidget {
  const _C({required this.width, required this.child});
  final double width;
  final Widget child;

  static const _div = BorderSide(color: Color(0xffEEEEEE), width: 0.8);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 52,
      decoration: const BoxDecoration(border: Border(right: _div)),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn(
      {required this.icon,
      required this.color,
      required this.onTap,
      this.tooltip});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 18, color: color),
      ),
    );
    if (tooltip != null) return Tooltip(message: tooltip!, child: btn);
    return btn;
  }
}

// ─── Pagination bar ───────────────────────────────────────────────────────────

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({required this.model});
  final CompanyClientsViewModel model;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Text('Rows per page:',
              style: TextStyle(fontSize: 12, color: Color(0xff6B7280))),
          const SizedBox(width: 6),
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xffD1D5DB)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: DropdownButton<int>(
              value: model.rowsPerPage,
              underline: const SizedBox.shrink(),
              isDense: true,
              items: CompanyClientsViewModel.rowsPerPageOptions
                  .map((n) => DropdownMenuItem(
                      value: n,
                      child: Text('$n',
                          style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) {
                if (v != null) model.setRowsPerPage(v);
              },
            ),
          ),
          const SizedBox(width: 16),
          Text(
            model.total == 0
                ? '0'
                : '${model.pageStart}–${model.pageEnd} of ${model.total}',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xff1A1F36)),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            iconSize: 20,
            color: model.hasPrev ? kCrmBlue : const Color(0xffD1D5DB),
            onPressed: model.hasPrev ? model.prevPage : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            iconSize: 20,
            color: model.hasNext ? kCrmBlue : const Color(0xffD1D5DB),
            onPressed: model.hasNext ? model.nextPage : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

// ─── Customize columns dialog ─────────────────────────────────────────────────

class _CustomizeColumnsDialog extends StatefulWidget {
  const _CustomizeColumnsDialog({required this.model});
  final CompanyClientsViewModel model;

  @override
  State<_CustomizeColumnsDialog> createState() =>
      _CustomizeColumnsDialogState();
}

class _CustomizeColumnsDialogState extends State<_CustomizeColumnsDialog> {
  void _toggle(String key) {
    widget.model.toggleColumn(key);
    setState(() {});
  }

  void _setAll(bool visible) {
    widget.model.setAllColumnsVisible(visible);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final toggleable = CompanyClientsViewModel.allColumns
        .where((c) => !c.alwaysVisible)
        .toList();
    final allChecked =
        toggleable.every((c) => widget.model.colVisible[c.key] ?? true);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(vertical: 24),
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          const Expanded(
            child: Text('Customize Columns',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kCrmBlue)),
          ),
          TextButton(
            onPressed: () => _setAll(!allChecked),
            child: Text(allChecked ? 'Unselect All' : 'Select All',
                style: const TextStyle(color: kCrmBlue, fontSize: 13)),
          ),
        ],
      ),
      content: SizedBox(
        width: 280,
        child: ListView(
          shrinkWrap: true,
          children: toggleable.map((col) {
            final visible = widget.model.colVisible[col.key] ?? true;
            return CheckboxListTile(
              value: visible,
              title: Text(col.label, style: const TextStyle(fontSize: 14)),
              activeColor: kCrmBlue,
              dense: true,
              onChanged: (_) => _toggle(col.key),
            );
          }).toList(),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
              backgroundColor: kCrmBlue, foregroundColor: Colors.white),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

// ─── Add / Edit Client dialog ─────────────────────────────────────────────────

class _AddClientDialog extends StatefulWidget {
  const _AddClientDialog({
    this.item,
    this.reactivate = false,
    required this.onSave,
    required this.onUpdate,
  });
  final Map<String, dynamic>? item;
  final bool reactivate;
  final Future<String?> Function(Map<String, dynamic>) onSave;
  final Future<String?> Function(dynamic id, Map<String, dynamic> data,
      {String tab}) onUpdate;

  @override
  State<_AddClientDialog> createState() => _AddClientDialogState();
}

class _AddClientDialogState extends State<_AddClientDialog> {
  final _api = locator<HippoAuthService>();

  // controllers
  final _clientNameCtrl = TextEditingController();
  final _contactPersonCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _altContactCtrl = TextEditingController();
  final _taxIdCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  final _completeAddrCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // master data
  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _allStates = [];
  List<Map<String, dynamic>> _allCities = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _quotations = [];
  List<Map<String, dynamic>> _paymentTerms = [];
  List<Map<String, dynamic>> _preferredPayments = [];

  // selections
  String? _countryId;
  String? _stateId;
  String? _cityId;
  String? _assignedToId;
  String? _quotationId;
  String? _paymentTermId;
  String? _preferredPaymentId;

  List<Map<String, dynamic>> get _filteredStates => _allStates
      .where((s) => s['country_id']?.toString() == _countryId)
      .toList();
  List<Map<String, dynamic>> get _filteredCities => _allCities
      .where((c) => c['state_id']?.toString() == _stateId)
      .toList();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    _loadMasters();
  }

  @override
  void dispose() {
    _clientNameCtrl.dispose();
    _contactPersonCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _altContactCtrl.dispose();
    _taxIdCtrl.dispose();
    _streetCtrl.dispose();
    _postalCtrl.dispose();
    _completeAddrCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMasters() async {
    try {
      final results = await Future.wait<dynamic>([
        _api.getCountries(),
        _api.getStates(),
        _api.getCities(),
        _api.getEmployeesPaged(tab: 'active', rowsPerPage: 500),
        _api.getQuoteMasters(),
        _api.getClientMasters(),
      ]);
      if (!mounted) return;

      final empData = results[3] as Map<String, dynamic>;
      final qm = results[4] as Map<String, dynamic>;
      final cm = results[5] as Map<String, dynamic>;

      setState(() {
        _countries =
            List<Map<String, dynamic>>.from(results[0] as List);
        _allStates =
            List<Map<String, dynamic>>.from(results[1] as List);
        _allCities =
            List<Map<String, dynamic>>.from(results[2] as List);
        _employees = List<Map<String, dynamic>>.from(
            (empData['data'] as List? ?? []));
        _quotations = _toIdLabel(
            qm['followupQuotations'] ?? qm['clientQuotations'], 'id', 'title');
        _paymentTerms = _toIdLabel(cm['paymentTerms'], 'id', 'value');
        _preferredPayments =
            _toIdLabel(cm['preferredPayments'] ?? cm['preferredPayment'], 'id', 'value');

        _loading = false;
        _prefill();
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _prefill() {
    final d = widget.item;
    if (d == null) return;
    _clientNameCtrl.text = d['client_name']?.toString() ?? '';
    _contactPersonCtrl.text = d['contact_person']?.toString() ?? '';
    _emailCtrl.text = d['email']?.toString() ?? '';
    _phoneCtrl.text = d['phone']?.toString() ?? '';
    _altContactCtrl.text = d['alternate_contact']?.toString() ?? '';
    _taxIdCtrl.text = d['tax_id']?.toString() ?? '';
    _streetCtrl.text = d['street_address']?.toString() ?? '';
    _postalCtrl.text = d['postal_code']?.toString() ?? '';
    _completeAddrCtrl.text = d['complete_address']?.toString() ?? '';
    _notesCtrl.text = d['notes']?.toString() ?? '';

    // Cascade dropdowns
    final cid = d['country_id']?.toString() ?? d['country']?.toString();
    final sid = d['state_id']?.toString() ?? d['state']?.toString();
    final cityId = d['city_id']?.toString() ?? d['city']?.toString();

    if (_countries.any((c) => c['id']?.toString() == cid)) {
      _countryId = cid;
    }
    if (_allStates.any((s) => s['id']?.toString() == sid)) _stateId = sid;
    if (_allCities.any((c) => c['id']?.toString() == cityId)) _cityId = cityId;

    final eid = d['assigned_to_id']?.toString();
    if (eid != null && _employees.any((e) => e['id']?.toString() == eid)) {
      _assignedToId = eid;
    }

    final qid = d['quotation_id']?.toString();
    if (qid != null && _quotations.any((q) => q['id'] == qid)) {
      _quotationId = qid;
    }

    final pt = d['payment_terms']?.toString();
    if (pt != null && _paymentTerms.any((t) => t['id'] == pt)) {
      _paymentTermId = pt;
    }

    final pp = d['preferred_payment']?.toString();
    if (pp != null && _preferredPayments.any((p) => p['id'] == pp)) {
      _preferredPaymentId = pp;
    }
  }

  List<Map<String, dynamic>> _toIdLabel(
      dynamic list, String idKey, String labelKey) {
    if (list is! List) return [];
    return list
        .map((e) {
          final m = e as Map;
          return {
            'id': m[idKey]?.toString() ?? '',
            'label': m[labelKey]?.toString() ?? '',
          };
        })
        .where((e) => (e['id'] as String).isNotEmpty)
        .toList();
  }

  Future<void> _submit() async {
    if (_clientNameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Client Name, Email and Phone are required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    // Build first service from selected product (optional)
    final data = <String, dynamic>{
      'clientName': _clientNameCtrl.text.trim(),
      'contactPerson': _contactPersonCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'alternateContact': _altContactCtrl.text.trim(),
      'taxId': _taxIdCtrl.text.trim(),
      'streetAddress': _streetCtrl.text.trim(),
      'postalCode': _postalCtrl.text.trim(),
      'completeAddress': _completeAddrCtrl.text.trim(),
      'notes': _notesCtrl.text.trim(),
      'country': _countryId ?? '',
      'state': _stateId ?? '',
      'city': _cityId ?? '',
      'assignedTo': _assignedToId ?? '',
      'quotationId': _quotationId ?? '',
      'quotationTitle': _quotationId != null
          ? (_quotations.firstWhere(
              (q) => q['id'] == _quotationId,
              orElse: () => {'label': ''},
            )['label'] ?? '')
          : '',
      'paymentTerms': _paymentTermId ?? '',
      'preferredPayment': _preferredPaymentId ?? '',
      'selectedServices': const [],
      'negotiate': 'No',
      'taxOption': 'including',
      'roundOff': 0,
      'original_taxableAmount': 0,
      'original_taxAmount': 0,
      'original_totalAmount': 0,
      'revised_taxableAmount': 0,
      'revised_taxAmount': 0,
      'revised_totalAmount': 0,
      'revisedAmounts': const [],
    };

    String? err;
    if (_isEdit) {
      final id = widget.item!['id'];
      final tab = widget.reactivate ? '2' : '1';
      err = await widget.onUpdate(id, data, tab: tab);
    } else {
      err = await widget.onSave(data);
    }

    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = false;
        _error = err;
      });
    }
  }

  InputDecoration _dec(String hint, {bool required = false}) => InputDecoration(
        hintText: required ? '$hint *' : hint,
        hintStyle:
            const TextStyle(fontSize: 13, color: Color(0xff9CA3AF)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xffD1D5DB))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xffD1D5DB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: kCrmBlue)),
        isDense: true,
      );

  Widget _section(String title, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xffE5E7EB)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xff374151))),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  Widget _dropdown({
    required String hint,
    required String? value,
    required List<Map<String, dynamic>> items,
    required ValueChanged<String?> onChanged,
  }) {
    final valid = items.any((e) => e['id'] == value);
    return DropdownButtonFormField<String>(
      value: valid ? value : null,
      decoration: _dec(hint),
      hint: Text(hint,
          style: const TextStyle(fontSize: 13, color: Color(0xff9CA3AF))),
      style: const TextStyle(fontSize: 13, color: Color(0xff374151)),
      isExpanded: true,
      items: items
          .map((e) => DropdownMenuItem<String>(
                value: e['id'] as String,
                child: Text(e['label'] as String,
                    overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    String title = 'Add New Client to CRM';
    if (_isEdit) title = widget.reactivate ? 'Reactivate Client' : 'Edit Client';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: kCrmBlue)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body
          Flexible(
            child: _loading
                ? const SizedBox(
                    height: 200,
                    child: Center(
                        child: CircularProgressIndicator(color: kCrmBlue)))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Client Details
                        _section(
                          'Client Details',
                          TextFormField(
                            controller: _clientNameCtrl,
                            decoration: _dec('Client Name', required: true),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),

                        // Personal Details
                        _section(
                          'Personal Details',
                          Column(
                            children: [
                              Row(children: [
                                Expanded(
                                    child: TextFormField(
                                        controller: _contactPersonCtrl,
                                        decoration: _dec('Contact Person'),
                                        style: const TextStyle(fontSize: 13))),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: TextFormField(
                                        controller: _emailCtrl,
                                        decoration:
                                            _dec('Email', required: true),
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        style: const TextStyle(fontSize: 13))),
                              ]),
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                    child: TextFormField(
                                        controller: _phoneCtrl,
                                        decoration:
                                            _dec('Phone', required: true),
                                        keyboardType: TextInputType.phone,
                                        style: const TextStyle(fontSize: 13))),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: TextFormField(
                                        controller: _altContactCtrl,
                                        decoration: _dec('Alternate Contact'),
                                        keyboardType: TextInputType.phone,
                                        style: const TextStyle(fontSize: 13))),
                              ]),
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                    child: TextFormField(
                                        controller: _taxIdCtrl,
                                        decoration: _dec('Tax ID'),
                                        style: const TextStyle(fontSize: 13))),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: TextFormField(
                                        controller: _streetCtrl,
                                        decoration: _dec('Street Address'),
                                        style: const TextStyle(fontSize: 13))),
                              ]),
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                  child: _dropdown(
                                    hint: 'Country',
                                    value: _countryId,
                                    items: _countries
                                        .map((c) => {
                                              'id': c['id']?.toString() ?? '',
                                              'label':
                                                  c['name']?.toString() ?? ''
                                            })
                                        .toList(),
                                    onChanged: (v) => setState(() {
                                      _countryId = v;
                                      _stateId = null;
                                      _cityId = null;
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _dropdown(
                                    hint: 'State',
                                    value: _stateId,
                                    items: _filteredStates
                                        .map((s) => {
                                              'id': s['id']?.toString() ?? '',
                                              'label':
                                                  s['name']?.toString() ?? ''
                                            })
                                        .toList(),
                                    onChanged: (v) => setState(() {
                                      _stateId = v;
                                      _cityId = null;
                                    }),
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                  child: _dropdown(
                                    hint: 'City',
                                    value: _cityId,
                                    items: _filteredCities
                                        .map((c) => {
                                              'id': c['id']?.toString() ?? '',
                                              'label':
                                                  c['name']?.toString() ?? ''
                                            })
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _cityId = v),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: TextFormField(
                                        controller: _postalCtrl,
                                        decoration: _dec('Postal Code'),
                                        style: const TextStyle(fontSize: 13))),
                              ]),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _completeAddrCtrl,
                                decoration: _dec('Complete Address'),
                                style: const TextStyle(fontSize: 13),
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),

                        // Terms & Conditions
                        _section(
                          'Terms & Conditions',
                          _dropdown(
                            hint: 'Select Template',
                            value: _quotationId,
                            items: _quotations,
                            onChanged: (v) =>
                                setState(() => _quotationId = v),
                          ),
                        ),

                        // Billing Details
                        _section(
                          'Billing Details',
                          Column(children: [
                            _dropdown(
                              hint: 'Assigned To',
                              value: _assignedToId,
                              items: _employees
                                  .map((e) => {
                                        'id': e['id']?.toString() ?? '',
                                        'label': e['employee_name']
                                                ?.toString() ??
                                            ''
                                      })
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _assignedToId = v),
                            ),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(
                                child: _dropdown(
                                  hint: 'Payment Terms',
                                  value: _paymentTermId,
                                  items: _paymentTerms,
                                  onChanged: (v) =>
                                      setState(() => _paymentTermId = v),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _dropdown(
                                  hint: 'Preferred Payment',
                                  value: _preferredPaymentId,
                                  items: _preferredPayments,
                                  onChanged: (v) =>
                                      setState(() => _preferredPaymentId = v),
                                ),
                              ),
                            ]),
                          ]),
                        ),

                        // Notes
                        _section(
                          'Notes',
                          TextFormField(
                            controller: _notesCtrl,
                            decoration: _dec('Notes'),
                            style: const TextStyle(fontSize: 13),
                            maxLines: 3,
                          ),
                        ),

                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(_error!,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xffDC2626))),
                          ),
                      ],
                    ),
                  ),
          ),

          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: (_saving || _loading) ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kCrmBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(
                        _isEdit
                            ? (widget.reactivate
                                ? 'REACTIVATE CLIENT'
                                : 'UPDATE CLIENT')
                            : 'SUBMIT CLIENT',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
