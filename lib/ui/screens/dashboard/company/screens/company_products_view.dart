import 'dart:io';
import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:stacked/stacked.dart';

import '../../../../../app/app.locator.dart';
import '../../../../../services/api_services.dart';
import 'company_products_viewmodel.dart';
import 'crm_widgets.dart';

class CompanyProductsView extends StatefulWidget {
  const CompanyProductsView({super.key});

  @override
  State<CompanyProductsView> createState() => _CompanyProductsViewState();
}

class _CompanyProductsViewState extends State<CompanyProductsView> {
  final _searchCtrl = TextEditingController();
  final _hScroll = ScrollController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  Future<void> _downloadCsv(CompanyProductsViewModel model) async {
    try {
      final csv = model.buildCsvContent();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/products.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)],
          text: model.hasSelection
              ? 'Products (${model.selectedCount} selected)'
              : 'All Products');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  void _showCustomizeColumns(CompanyProductsViewModel model) {
    showDialog(
      context: context,
      builder: (_) => _CustomizeColumnsDialog(model: model),
    );
  }

  void _showAddEditDialog(CompanyProductsViewModel model,
      [Map<String, dynamic>? item]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddProductDialog(
        item: item,
        onSave: model.addProduct,
        onUpdate: model.updateProduct,
      ),
    );
  }

  void _showDeleteConfirm(
      Map<String, dynamic> item, CompanyProductsViewModel model) {
    final name = item['service_name']?.toString() ?? 'this product';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(vertical: 24),
        title: const Text('Delete Product',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final err = await model.deleteProduct(item['id']);
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
    return ViewModelBuilder<CompanyProductsViewModel>.reactive(
      viewModelBuilder: () => CompanyProductsViewModel(),
      onViewModelReady: (m) => m.init(),
      builder: (context, model, child) {
        return Scaffold(
          backgroundColor: kCrmBg,
          appBar: crmAppBar('Products', actions: [
            IconButton(
              icon: const Icon(Icons.download_outlined, color: Colors.white),
              tooltip: model.hasSelection
                  ? 'Download selected (${model.selectedCount})'
                  : 'Download CSV',
              onPressed: () => _downloadCsv(model),
            ),
            IconButton(
              icon:
                  const Icon(Icons.view_column_outlined, color: Colors.white),
              tooltip: 'Customize Columns',
              onPressed: () => _showCustomizeColumns(model),
            ),
            if (model.canWrite)
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                tooltip: 'Add Product',
                onPressed: () => _showAddEditDialog(model),
              ),
          ]),
          body: model.isBusy
              ? const Center(
                  child: CircularProgressIndicator(color: kCrmBlue))
              : model.fetchError != null
                  ? CrmErrorBody(
                      error: model.fetchError!, onRetry: model.init)
                  : Column(
                      children: [
                        _Toolbar(
                          searchCtrl: _searchCtrl,
                          model: model,
                          onAdd: model.canWrite ? () => _showAddEditDialog(model) : null,
                        ),
                        if (model.hasActiveFilters)
                          _ActiveFilterChips(model: model),
                        if (model.hasSelection) _SelectionBar(model: model),
                        Expanded(
                          child: _ProductTable(
                            model: model,
                            hScroll: _hScroll,
                            canUpdate: model.canUpdate,
                            canDelete: model.canDelete,
                            onEdit: (item) => _showAddEditDialog(model, item),
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

// ─── Selection bar ────────────────────────────────────────────────────────────

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.model});
  final CompanyProductsViewModel model;

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
  final CompanyProductsViewModel model;
  final VoidCallback? onAdd;

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
              hint: 'Search by Service Name, Category...',
              onChanged: model.search,
            ),
          ),
          if (onAdd != null) ...[
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Product',
                    style: TextStyle(fontSize: 12)),
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
  final CompanyProductsViewModel model;

  String _label(String key) {
    final match =
        CompanyProductsViewModel.allColumns.where((c) => c.key == key);
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

class _ProductTable extends StatelessWidget {
  const _ProductTable({
    required this.model,
    required this.hScroll,
    required this.canUpdate,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });
  final CompanyProductsViewModel model;
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
        icon: Icons.inventory_2_outlined,
        title: 'No Products Found',
        subtitle: 'Add your first product to get started',
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
                            col: col,
                            model: model,
                            screenCtx: context))
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
  final ProductColumnDef col;
  final CompanyProductsViewModel model;
  final BuildContext screenCtx;

  static const _divider = BorderSide(color: Color(0xffD1D5DB), width: 0.8);

  void _showFilterDialog() {
    showDialog(
      context: screenCtx,
      builder: (_) => _ColFilterDialog(col: col, model: model),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (col.key == 'checkbox') {
      final allSel = model.allCurrentSelected;
      final someSel = model.someCurrentSelected;
      return Container(
        width: col.width,
        height: 48,
        decoration: const BoxDecoration(border: Border(right: _divider)),
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
      decoration: const BoxDecoration(border: Border(right: _divider)),
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
                    color:
                        isFiltered ? kCrmBlue : const Color(0xff9CA3AF),
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
  final ProductColumnDef col;
  final CompanyProductsViewModel model;

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
      title: Text('Filter by ${widget.col.label}',
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xff1A1F36))),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
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
        onSubmitted: (_) => _apply(),
      ),
      actions: [
        TextButton(
          onPressed: _clear,
          child: const Text('CLEAR',
              style: TextStyle(color: Color(0xff6B7280))),
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
  final List<ProductColumnDef> cols;
  final bool isEven;
  final bool isSelected;
  final bool canUpdate;
  final bool canDelete;
  final VoidCallback onToggleSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const _cellDivider =
      BorderSide(color: Color(0xffEEEEEE), width: 0.8);

  Widget _buildCell(ProductColumnDef col) {
    switch (col.key) {
      case 'checkbox':
        return Container(
          width: col.width,
          height: 52,
          decoration:
              const BoxDecoration(border: Border(right: _cellDivider)),
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
              style: const TextStyle(
                  fontSize: 12, color: Color(0xff6B7280))),
        );

      case 'base_price':
      case 'total_amount':
        final val = item[col.key]?.toString() ?? '';
        return _Cell(
          width: col.width,
          child: Text(
            val.isNotEmpty ? '₹$val' : '—',
            style: const TextStyle(
                fontSize: 12,
                color: Color(0xff166534),
                fontWeight: FontWeight.w600),
          ),
        );

      case 'tax_rate':
        final val = item['tax_rate']?.toString() ?? '';
        return _Cell(
          width: col.width,
          child: Text(
            val.isNotEmpty ? '$val%' : '—',
            style: const TextStyle(
                fontSize: 12, color: Color(0xff374151)),
          ),
        );

      case 'action':
        return Container(
          width: col.width,
          height: 52,
          decoration:
              const BoxDecoration(border: Border(right: _cellDivider)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (canUpdate)
                _ActionBtn(
                    icon: Icons.edit_outlined,
                    color: kCrmBlue,
                    onTap: onEdit),
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
          child: Text(val,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xff374151)),
              overflow: TextOverflow.ellipsis,
              maxLines: 1),
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
      decoration: const BoxDecoration(border: Border(right: _divider)),
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
  final CompanyProductsViewModel model;

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
              items: CompanyProductsViewModel.rowsPerPageOptions
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
  final CompanyProductsViewModel model;

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
    final toggleable = CompanyProductsViewModel.allColumns
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
              title: Text(col.label,
                  style: const TextStyle(fontSize: 14)),
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

// ─── Add / Edit Product dialog ────────────────────────────────────────────────

class _AddProductDialog extends StatefulWidget {
  const _AddProductDialog({
    this.item,
    required this.onSave,
    required this.onUpdate,
  });
  final Map<String, dynamic>? item;
  final Future<String?> Function(Map<String, dynamic>) onSave;
  final Future<String?> Function(Map<String, dynamic>) onUpdate;

  @override
  State<_AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<_AddProductDialog> {
  final _api = locator<HippoAuthService>();
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _taxCtrl = TextEditingController(text: '18');
  final _totalCtrl = TextEditingController(text: '0');

  int? _categoryId;
  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    _prefill();
    _loadCategories();
    _priceCtrl.addListener(_recalcTotal);
    _taxCtrl.addListener(_recalcTotal);
  }

  void _prefill() {
    final e = widget.item;
    if (e == null) return;
    _nameCtrl.text = e['service_name']?.toString() ?? '';
    _priceCtrl.text = e['base_price']?.toString() ?? '';
    _durationCtrl.text = e['duration']?.toString() ?? '';
    _taxCtrl.text = e['tax_rate']?.toString() ?? '18';
    _totalCtrl.text = e['total_amount']?.toString() ?? '0';
    _categoryId = e['service_category_id'] is int
        ? e['service_category_id'] as int
        : int.tryParse(e['service_category_id']?.toString() ?? '');
  }

  Future<void> _loadCategories() async {
    try {
      final masters = await _api.getLeadMasters();
      final raw = masters['categories'] ?? [];
      if (mounted) {
        setState(() {
          _categories = raw is List
              ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
              : [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _recalcTotal() {
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    final tax = double.tryParse(_taxCtrl.text) ?? 0;
    _totalCtrl.text = (price + price * tax / 100).toStringAsFixed(2);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _durationCtrl.dispose();
    _taxCtrl.dispose();
    _totalCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final data = <String, dynamic>{
      'service_name': _nameCtrl.text.trim(),
      'service_category_id': _categoryId,
      'base_price': double.tryParse(_priceCtrl.text) ?? 0,
      'duration': int.tryParse(_durationCtrl.text) ?? 0,
      'tax_rate': double.tryParse(_taxCtrl.text) ?? 18,
      'total_amount': double.tryParse(_totalCtrl.text) ?? 0,
    };

    String? err;
    if (_isEdit) {
      data['id'] = widget.item!['id'];
      err = await widget.onUpdate(data);
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

  InputDecoration _dec(String hint, {bool readOnly = false}) =>
      InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(fontSize: 13, color: Color(0xff9CA3AF)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        filled: readOnly,
        fillColor: readOnly ? const Color(0xffF3F4F6) : null,
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(vertical: 24),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isEdit ? 'Edit Product' : 'Add New Product',
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
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child:
                            CircularProgressIndicator(color: kCrmBlue),
                      ))
                  : Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _nameCtrl,
                            decoration:
                                _dec('Product / Service Name *'),
                            style: const TextStyle(fontSize: 13),
                            validator: (v) =>
                                v == null || v.trim().isEmpty
                                    ? 'Required'
                                    : null,
                          ),
                          const SizedBox(height: 10),
                          Container(
                            height: 44,
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: const Color(0xffD1D5DB)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12),
                            child: DropdownButton<int?>(
                              value: _categories.any((c) =>
                                      (c['id'] is int
                                          ? c['id']
                                          : int.tryParse(
                                              c['id']?.toString() ??
                                                  '')) ==
                                      _categoryId)
                                  ? _categoryId
                                  : null,
                              hint: const Text('Category',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xff9CA3AF))),
                              underline: const SizedBox.shrink(),
                              isExpanded: true,
                              isDense: true,
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('Select Category',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xff9CA3AF))),
                                ),
                                ..._categories.map((c) {
                                  final id = c['id'] is int
                                      ? c['id'] as int
                                      : int.tryParse(
                                          c['id']?.toString() ?? '');
                                  final label =
                                      c['value']?.toString() ??
                                          c['name']?.toString() ??
                                          '';
                                  return DropdownMenuItem<int?>(
                                    value: id,
                                    child: Text(label,
                                        style: const TextStyle(
                                            fontSize: 13)),
                                  );
                                }),
                              ],
                              onChanged: (v) =>
                                  setState(() => _categoryId = v),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                              child: TextFormField(
                                controller: _priceCtrl,
                                decoration: _dec('Base Price *'),
                                style: const TextStyle(fontSize: 13),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                validator: (v) =>
                                    v == null || v.trim().isEmpty
                                        ? 'Required'
                                        : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _durationCtrl,
                                decoration: _dec('Duration (Days)'),
                                style: const TextStyle(fontSize: 13),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ]),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                              child: TextFormField(
                                controller: _taxCtrl,
                                decoration: _dec('Tax Rate (%)'),
                                style: const TextStyle(fontSize: 13),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _totalCtrl,
                                decoration:
                                    _dec('Total Amount', readOnly: true),
                                style: const TextStyle(fontSize: 13),
                                readOnly: true,
                              ),
                            ),
                          ]),
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Text(_error!,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xffDC2626))),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
          const Divider(height: 1),
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
                        _isEdit ? 'UPDATE PRODUCT' : 'CREATE PRODUCT',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
