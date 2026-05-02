import 'dart:io';
import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:stacked/stacked.dart';

import '../../../../../app/app.locator.dart';
import '../../../../../services/api_services.dart';
import 'company_employees_viewmodel.dart';
import 'crm_widgets.dart';

class CompanyEmployeesView extends StatefulWidget {
  const CompanyEmployeesView({super.key});

  @override
  State<CompanyEmployeesView> createState() => _CompanyEmployeesViewState();
}

class _CompanyEmployeesViewState extends State<CompanyEmployeesView> {
  final _searchCtrl = TextEditingController();
  final _hScroll = ScrollController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  Future<void> _downloadCsv(CompanyEmployeesViewModel model) async {
    try {
      final csv = model.buildCsvContent();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/employees.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)],
          text: model.hasSelection
              ? 'Employees (${model.selectedCount} selected)'
              : 'All Employees');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  void _showCustomizeColumns(CompanyEmployeesViewModel model) {
    showDialog(
      context: context,
      builder: (_) => _CustomizeColumnsDialog(model: model),
    );
  }

  void _showAddDialog(CompanyEmployeesViewModel model,
      [Map<String, dynamic>? item]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddEmployeeDialog(
        item: item,
        onSave: model.addEmployee,
        onUpdate: (id, data) => model.updateEmployee(id, data),
      ),
    );
  }

  void _showDeleteConfirm(
      Map<String, dynamic> item, CompanyEmployeesViewModel model) {
    final name = item['employee_name']?.toString() ?? 'this employee';
    final id = item['id'] ?? item['employeeid'];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(vertical: 24),
        title: const Text('Delete Employee',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final err = await model.deleteEmployee(id);
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

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<CompanyEmployeesViewModel>.reactive(
      viewModelBuilder: () => CompanyEmployeesViewModel(),
      onViewModelReady: (m) => m.init(),
      builder: (context, model, child) {
        return Scaffold(
          backgroundColor: kCrmBg,
          appBar: crmAppBar('Employees', actions: [
            IconButton(
              icon: const Icon(Icons.download_outlined, color: Colors.white),
              tooltip: model.hasSelection
                  ? 'Download selected (${model.selectedCount})'
                  : 'Download CSV',
              onPressed: () => _downloadCsv(model),
            ),
            IconButton(
              icon: const Icon(Icons.view_column_outlined, color: Colors.white),
              tooltip: 'Customize Columns',
              onPressed: () => _showCustomizeColumns(model),
            ),
            if (model.canWrite)
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                tooltip: 'Add Employee',
                onPressed: () => _showAddDialog(model),
              ),
          ]),
          body: model.isBusy
              ? const Center(child: CircularProgressIndicator(color: kCrmBlue))
              : model.fetchError != null
                  ? CrmErrorBody(error: model.fetchError!, onRetry: model.init)
                  : Column(
                      children: [
                        _Toolbar(
                          searchCtrl: _searchCtrl,
                          model: model,
                          onAdd: model.canWrite ? () => _showAddDialog(model) : null,
                        ),
                        if (model.hasActiveFilters)
                          _ActiveFilterChips(model: model),
                        if (model.hasSelection) _SelectionBar(model: model),
                        Expanded(
                          child: _EmployeeTable(
                            model: model,
                            hScroll: _hScroll,
                            canUpdate: model.canUpdate,
                            canDelete: model.canDelete,
                            onEdit: (item) => _showAddDialog(model, item),
                            onDelete: (item) => _showDeleteConfirm(item, model),
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

// ─── Selection info bar ───────────────────────────────────────────────────────

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.model});
  final CompanyEmployeesViewModel model;

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

// ─── Toolbar ──────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  const _Toolbar(
      {required this.searchCtrl, required this.model, this.onAdd});
  final TextEditingController searchCtrl;
  final CompanyEmployeesViewModel model;
  final VoidCallback? onAdd;

  static const _tabColors = {
    'active': Color(0xff16A34A),
    'inactive': Color(0xffDC2626),
    'bulkfailed': Color(0xffF59E0B),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: CrmSearchBar(
              controller: searchCtrl,
              hint: 'Search Name, Email or ID...',
              onChanged: model.search,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xffD1D5DB)),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: DropdownButton<String>(
              value: model.tab,
              underline: const SizedBox.shrink(),
              isDense: true,
              items: CompanyEmployeesViewModel.tabOptions.map((t) {
                final val = t['value']!;
                final color = _tabColors[val] ?? kCrmBlue;
                return DropdownMenuItem(
                  value: val,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(t['label']!, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) model.setTab(v);
              },
            ),
          ),
          if (onAdd != null) ...[
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Employee', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kCrmBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Active filter chips ──────────────────────────────────────────────────────

class _ActiveFilterChips extends StatelessWidget {
  const _ActiveFilterChips({required this.model});
  final CompanyEmployeesViewModel model;

  String _label(String key) {
    final match =
        CompanyEmployeesViewModel.allColumns.where((c) => c.key == key);
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

class _EmployeeTable extends StatelessWidget {
  const _EmployeeTable({
    required this.model,
    required this.hScroll,
    required this.canUpdate,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });
  final CompanyEmployeesViewModel model;
  final ScrollController hScroll;
  final bool canUpdate;
  final bool canDelete;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onDelete;

  static const double _headerH = 48.0;
  static const double _rowH = 52.0;

  @override
  Widget build(BuildContext context) {
    if (model.items.isEmpty) {
      return const CrmEmptyState(
        icon: Icons.badge_rounded,
        title: 'No Employees Found',
        subtitle: 'Add employees or adjust your filters',
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
                // ── Sticky header
                Container(
                  height: _headerH,
                  decoration: const BoxDecoration(
                    color: Color(0xffF3F4F6),
                    border:
                        Border(bottom: BorderSide(color: Color(0xffE5E7EB))),
                  ),
                  child: Row(
                    children: cols
                        .map((col) => _HeaderCell(
                            col: col, model: model, screenCtx: context))
                        .toList(),
                  ),
                ),
                // ── Vertically scrollable rows
                SizedBox(
                  height: constraints.maxHeight - _headerH,
                  child: ListView.builder(
                    itemCount: model.items.length,
                    itemExtent: _rowH,
                    itemBuilder: (_, i) {
                      final item = model.items[i];
                      final id = item['id'] ?? item['employeeid'];
                      return _DataRow(
                        item: item,
                        rowIndex: model.pageStart + i,
                        cols: cols,
                        isEven: i % 2 == 0,
                        isSelected: model.isSelected(id),
                        canUpdate: canUpdate,
                        canDelete: canDelete,
                        onToggleSelect: () => model.toggleRowSelection(id),
                        onEdit: () => onEdit(item),
                        onDelete: () => onDelete(item),
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
  final ColumnDef col;
  final CompanyEmployeesViewModel model;
  final BuildContext screenCtx;

  void _showFilterDialog() {
    showDialog(
      context: screenCtx,
      builder: (_) => _ColFilterDialog(col: col, model: model),
    );
  }

  static const _divider = BorderSide(color: Color(0xffD1D5DB), width: 0.8);

  @override
  Widget build(BuildContext context) {
    // Checkbox column header = select-all checkbox
    if (col.key == 'checkbox') {
      final allSel = model.allCurrentSelected;
      final someSel = model.someCurrentSelected;
      return Container(
        width: col.width,
        height: 48,
        decoration: const BoxDecoration(
          border: Border(right: _divider),
        ),
        child: Center(
          child: Checkbox(
            value: allSel
                ? true
                : someSel
                    ? null
                    : false,
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
      decoration: const BoxDecoration(
        border: Border(right: _divider),
      ),
      padding: const EdgeInsets.only(left: 8, right: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                col.label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff374151)),
                overflow: TextOverflow.ellipsis,
              ),
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

// ─── Column filter dialog (showDialog — reliable on all columns) ──────────────

class _ColFilterDialog extends StatefulWidget {
  const _ColFilterDialog({required this.col, required this.model});
  final ColumnDef col;
  final CompanyEmployeesViewModel model;

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
    _ctrl.clear();
    widget.model.setColFilter(widget.col.key, '');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(vertical: 24),
      title: Text(
        'Filter by ${widget.col.label}',
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xff1A1F36)),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Filter ${widget.col.label}',
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xff9CA3AF)),
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
        onSubmitted: (_) => _apply(),
      ),
      actions: [
        TextButton(
          onPressed: _clear,
          child:
              const Text('CLEAR', style: TextStyle(color: Color(0xff6B7280))),
        ),
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
    required this.onToggleSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> item;
  final int rowIndex;
  final List<ColumnDef> cols;
  final bool isEven;
  final bool isSelected;
  final bool canUpdate;
  final bool canDelete;
  final VoidCallback onToggleSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Widget _buildCell(ColumnDef col) {
    switch (col.key) {
      case 'checkbox':
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

      case 'sno':
        return _Cell(
          width: col.width,
          child: Text('$rowIndex',
              style: const TextStyle(fontSize: 12, color: Color(0xff6B7280))),
        );

      case 'employee_status':
        final status = item['employee_status']?.toString() ?? '';
        final color = status.toLowerCase() == 'active'
            ? const Color(0xff16A34A)
            : status.toLowerCase() == 'inactive'
                ? const Color(0xffDC2626)
                : const Color(0xffF59E0B);
        return _Cell(
          width: col.width,
          child: Text(status,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        );

      case 'salary':
        final sal = item['salary']?.toString() ?? '';
        return _Cell(
          width: col.width,
          child: Text(
            sal.isNotEmpty ? '₹$sal' : '—',
            style: const TextStyle(
                fontSize: 12,
                color: Color(0xff166534),
                fontWeight: FontWeight.w600),
          ),
        );

      case 'email_alerts':
        final v = item['email_alerts'];
        final yes = v == true || v == 'true' || v == 1;
        return _Cell(
          width: col.width,
          child: Text(yes ? 'Yes' : 'No', style: const TextStyle(fontSize: 12)),
        );

      case 'action':
        return SizedBox(
          width: col.width,
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (canUpdate)
                _ActionBtn(
                    icon: Icons.edit_outlined, color: kCrmBlue, onTap: onEdit),
              if (canUpdate && canDelete) const SizedBox(width: 4),
              if (canDelete)
                _ActionBtn(
                    icon: Icons.delete_outline,
                    color: const Color(0xffDC2626),
                    onTap: onDelete),
            ],
          ),
        );

      default:
        final val = item[col.key]?.toString() ?? '—';
        return _Cell(
          width: col.width,
          child: Text(
            val,
            style: const TextStyle(fontSize: 12, color: Color(0xff374151)),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        );
    }
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
      child: Row(children: cols.map(_buildCell).toList()),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.width, required this.child});
  final double width;
  final Widget child;

  static const _divider = BorderSide(color: Color(0xffEEEEEE), width: 0.8);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 52,
      decoration: const BoxDecoration(
        border: Border(right: _divider),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn(
      {required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

// ─── Pagination bar ───────────────────────────────────────────────────────────

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({required this.model});
  final CompanyEmployeesViewModel model;

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
              items: CompanyEmployeesViewModel.rowsPerPageOptions
                  .map((n) => DropdownMenuItem(
                      value: n,
                      child: Text('$n', style: const TextStyle(fontSize: 13))))
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

// ─── Customize columns dialog (StatefulWidget → updates immediately) ──────────

class _CustomizeColumnsDialog extends StatefulWidget {
  const _CustomizeColumnsDialog({required this.model});
  final CompanyEmployeesViewModel model;

  @override
  State<_CustomizeColumnsDialog> createState() =>
      _CustomizeColumnsDialogState();
}

class _CustomizeColumnsDialogState extends State<_CustomizeColumnsDialog> {
  void _toggle(String key) {
    widget.model.toggleColumn(key); // updates table via notifyListeners
    setState(() {}); // rebuilds dialog checkboxes immediately
  }

  void _setAll(bool visible) {
    widget.model.setAllColumnsVisible(visible); // updates table
    setState(() {}); // rebuilds dialog immediately
  }

  @override
  Widget build(BuildContext context) {
    final toggleable = CompanyEmployeesViewModel.allColumns
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
            child: Text(
              'Customize Columns',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: kCrmBlue),
            ),
          ),
          TextButton(
            onPressed: () => _setAll(!allChecked),
            child: Text(
              allChecked ? 'Unselect All' : 'Select All',
              style: const TextStyle(color: kCrmBlue, fontSize: 13),
            ),
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

// ─── Add / Edit Employee dialog ───────────────────────────────────────────────

class _AddEmployeeDialog extends StatefulWidget {
  const _AddEmployeeDialog({
    this.item,
    required this.onSave,
    required this.onUpdate,
  });
  final Map<String, dynamic>? item;
  final Future<String?> Function(Map<String, dynamic>) onSave;
  final Future<String?> Function(dynamic id, Map<String, dynamic>) onUpdate;

  @override
  State<_AddEmployeeDialog> createState() => _AddEmployeeDialogState();
}

class _AddEmployeeDialogState extends State<_AddEmployeeDialog> {
  final _api = locator<HippoAuthService>();
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _secCtrl = TextEditingController();

  String? _gender;
  dynamic _positionId; // integer ID from masters
  int? _countryId;
  int? _stateId;
  int? _cityId;
  dynamic _leadSourceId;
  bool _followupDuty = false;
  bool _emailAlerts = false;
  bool _saving = false;
  String? _error;

  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _states = [];
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _leadSources = [];
  List<Map<String, dynamic>> _jobPositions = [];
  bool _loadingLoc = true;

  bool get _isEdit => widget.item != null;

  static const _genders = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    _prefill();
    _loadData();
  }

  void _prefill() {
    final e = widget.item;
    if (e == null) return;
    _nameCtrl.text = e['employee_name']?.toString() ?? '';
    _emailCtrl.text = e['email']?.toString() ?? '';
    _phoneCtrl.text = e['phone_number']?.toString() ?? '';
    _secCtrl.text = e['secondary_contact']?.toString() ?? '';

    final g = e['gender']?.toString() ?? '';
    _gender = _genders.contains(g) ? g : null;

    // job_position comes back as integer ID from API
    _positionId = _toInt(e['job_position'] ?? e['jobPosition']);

    // GET returns followUpDuty / emailAlerts (camelCase)
    final fu = e['followUpDuty'] ?? e['followup_duty'];
    _followupDuty = fu == true || fu == 'true' || fu == 1;

    final ea = e['emailAlerts'] ?? e['email_alerts'];
    _emailAlerts = ea == true || ea == 'true' || ea == 1;

    // GET returns city/state/country as integer IDs (no _id suffix)
    _countryId = _toInt(e['country'] ?? e['country_id']);
    _stateId = _toInt(e['state'] ?? e['state_id']);
    _cityId = _toInt(e['city'] ?? e['city_id']);
    _leadSourceId =
        _toInt(e['leadSource'] ?? e['lead_source_id'] ?? e['leadsource']);
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _api.getCountries(),
        _api.getStates(),
        _api.getCities(),
        _api.getLeadMasters(),
        _api.getRoles(),
      ]);
      if (!mounted) return;

      final masters = results[3] as Map<String, dynamic>;
      List<Map<String, dynamic>> parseList(dynamic raw) => raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];

      final srcRaw = masters['sourceType'] ?? [];

      setState(() {
        _countries = results[0] as List<Map<String, dynamic>>;
        _states = results[1] as List<Map<String, dynamic>>;
        _cities = results[2] as List<Map<String, dynamic>>;
        _leadSources = parseList(srcRaw);
        _jobPositions = results[4] as List<Map<String, dynamic>>;
        _loadingLoc = false;
      });
      debugPrint('Roles (job positions): $_jobPositions');
    } catch (e) {
      debugPrint('_loadData error: $e');
      if (mounted) setState(() => _loadingLoc = false);
    }
  }

  List<Map<String, dynamic>> get _filteredStates => _countryId == null
      ? _states
      : _states.where((s) => _toInt(s['country_id']) == _countryId).toList();

  List<Map<String, dynamic>> get _filteredCities => _stateId == null
      ? _cities
      : _cities.where((c) => _toInt(c['state_id']) == _stateId).toList();

  // Returns the value only if it exists in items — prevents dropdown assertion
  int? _safeVal(dynamic value, List<Map<String, dynamic>> items) {
    if (value == null || items.isEmpty) return null;
    final v = _toInt(value);
    return items.any((i) => _toInt(i['id']) == v) ? v : null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _secCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final data = {
      'employeeName': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phoneNumber': _phoneCtrl.text.trim(),
      'secondaryContact': _secCtrl.text.trim(),
      'gender': _gender,
      'jobPosition': _positionId,
      'country': _countryId,
      'state': _stateId,
      'city': _cityId,
      'leadSource': _leadSourceId,
      'followUpDuty': _followupDuty,
      'emailAlerts': _emailAlerts,
    };

    String? err;
    if (_isEdit) {
      final id = widget.item!['id'] ?? widget.item!['employeeid'];
      err = await widget.onUpdate(id, data);
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

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xff9CA3AF)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

  Widget _drop<T>({
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    bool enabled = true,
  }) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        border: Border.all(
            color: enabled ? const Color(0xffD1D5DB) : const Color(0xffE5E7EB)),
        borderRadius: BorderRadius.circular(8),
        color: enabled ? Colors.white : const Color(0xffF9FAFB),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<T>(
        value: value,
        hint: Text(hint,
            style: const TextStyle(fontSize: 13, color: Color(0xff9CA3AF))),
        underline: const SizedBox.shrink(),
        isExpanded: true,
        isDense: true,
        items: items,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isEdit ? 'Edit Employee' : 'Add New Employee',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: kCrmBlue),
                  ),
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
          // ── Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _loadingLoc
                  ? const Center(
                      child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: kCrmBlue),
                    ))
                  : Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Employee Details',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _nameCtrl,
                            decoration: _dec('Employee Name *'),
                            style: const TextStyle(fontSize: 13),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                              child: TextFormField(
                                controller: _emailCtrl,
                                decoration: _dec('Email *'),
                                style: const TextStyle(fontSize: 13),
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _phoneCtrl,
                                decoration: _dec('Phone Number *'),
                                style: const TextStyle(fontSize: 13),
                                keyboardType: TextInputType.phone,
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                            ),
                          ]),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                              child: TextFormField(
                                controller: _secCtrl,
                                decoration: _dec('Secondary Contact'),
                                style: const TextStyle(fontSize: 13),
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _drop<String>(
                                hint: 'Gender *',
                                value: _gender,
                                items: _genders
                                    .map((g) => DropdownMenuItem(
                                        value: g,
                                        child: Text(g,
                                            style:
                                                const TextStyle(fontSize: 13))))
                                    .toList(),
                                onChanged: (v) => setState(() => _gender = v),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                              child: _drop<int?>(
                                hint: 'Job Position *',
                                value: _safeVal(_positionId, _jobPositions),
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('Select Position',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xff9CA3AF))),
                                  ),
                                  ..._jobPositions.map((p) {
                                    final id = _toInt(p['id']);
                                    final label =
                                        p['role_name']?.toString() ?? '';
                                    return DropdownMenuItem<int?>(
                                      value: id,
                                      child: Text(label,
                                          style: const TextStyle(fontSize: 13)),
                                    );
                                  }),
                                ],
                                onChanged: (v) =>
                                    setState(() => _positionId = v),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _drop<int>(
                                hint: 'Country *',
                                value: _countryId,
                                items: _countries
                                    .map((c) => DropdownMenuItem(
                                        value: _toInt(c['id']),
                                        child: Text(c['name']?.toString() ?? '',
                                            style:
                                                const TextStyle(fontSize: 13))))
                                    .toList(),
                                onChanged: (v) => setState(() {
                                  _countryId = v;
                                  _stateId = null;
                                  _cityId = null;
                                }),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                              child: _drop<int>(
                                hint: 'State *',
                                value: _stateId,
                                enabled: _countryId != null,
                                items: _filteredStates
                                    .map((s) => DropdownMenuItem(
                                        value: _toInt(s['id']),
                                        child: Text(s['name']?.toString() ?? '',
                                            style:
                                                const TextStyle(fontSize: 13))))
                                    .toList(),
                                onChanged: (v) => setState(() {
                                  _stateId = v;
                                  _cityId = null;
                                }),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _drop<int>(
                                hint: 'City *',
                                value: _cityId,
                                enabled: _stateId != null,
                                items: _filteredCities
                                    .map((c) => DropdownMenuItem(
                                        value: _toInt(c['id']),
                                        child: Text(c['name']?.toString() ?? '',
                                            style:
                                                const TextStyle(fontSize: 13))))
                                    .toList(),
                                onChanged: (v) => setState(() => _cityId = v),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 10),
                          // Lead Source
                          _followupDuty
                              ? _drop<int?>(
                                  hint: 'Lead Source',
                                  value: _safeVal(_leadSourceId, _leadSources),
                                  items: [
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text('Select Lead Source',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Color(0xff9CA3AF))),
                                    ),
                                    ..._leadSources.map((s) {
                                      final id = _toInt(
                                          s['id'] ?? s['lead_source_id']);
                                      final label = s['value']?.toString() ??
                                          s['name']?.toString() ??
                                          s['lead_source']?.toString() ??
                                          '';
                                      return DropdownMenuItem<int?>(
                                        value: id,
                                        child: Text(label,
                                            style:
                                                const TextStyle(fontSize: 13)),
                                      );
                                    }),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _leadSourceId = v),
                                )
                              : const SizedBox.shrink(),
                          const SizedBox(height: 16),
                          // Follow-up duty + Email alerts
                          Row(children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Assign Follow-up Duty?',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500)),
                                  RadioGroup<bool>(
                                    groupValue: _followupDuty,
                                    onChanged: (v) =>
                                        setState(() => _followupDuty = v!),
                                    child: const Row(children: [
                                      Radio<bool>(value: true),
                                      Text('Yes',
                                          style: TextStyle(fontSize: 13)),
                                      Radio<bool>(value: false),
                                      Text('No',
                                          style: TextStyle(fontSize: 13)),
                                    ]),
                                  ),
                                ],
                              ),
                            ),
                            Row(children: [
                              const Text('Email Alerts',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(width: 8),
                              Switch(
                                value: _emailAlerts,
                                activeThumbColor: kCrmBlue,
                                onChanged: (v) =>
                                    setState(() => _emailAlerts = v),
                              ),
                            ]),
                          ]),
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Text(_error!,
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xffDC2626))),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
          const Divider(height: 1),
          // ── Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
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
                        _isEdit ? 'UPDATE EMPLOYEE' : 'ADD EMPLOYEE',
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
