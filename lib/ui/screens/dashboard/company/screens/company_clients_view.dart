import 'dart:convert';
import 'dart:io';
import 'dart:math' show max;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:stacked/stacked.dart';
import 'package:xml/xml.dart';

import '../../../../../app/app.locator.dart';
import '../../../../../services/api_services.dart';
import '../../../../widgets/call_button.dart';
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

  Future<void> _downloadCsv(CompanyClientsViewModel model) async {
    try {
      final csv = model.buildCsvContent();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/clients.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)],
          text: model.hasSelection
              ? 'Clients (${model.selectedCount} selected)'
              : 'All Clients');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  void _showCustomizeColumns(CompanyClientsViewModel model) {
    showDialog(
      context: context,
      builder: (_) => _CustomizeColumnsDialog(model: model),
    );
  }

  void _showHistoryDialog(
      Map<String, dynamic> item, CompanyClientsViewModel model) {
    showDialog(
      context: context,
      builder: (_) => _ClientHistoryDialog(
        item: item,
        isDraft: model.isDraftTab,
        fetchHistory: model.getClientHistory,
      ),
    );
  }

  void _showBulkImportDialog(CompanyClientsViewModel model) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ClientBulkImportDialog(
        onImport: (clients) => model.bulkImportClients(clients),
      ),
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
                          onExportCsv: () => _downloadCsv(model),
                          onBulkImport: model.canWrite
                              ? () => _showBulkImportDialog(model)
                              : null,
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
                            onViewHistory: (item) =>
                                _showHistoryDialog(item, model),
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
    required this.onExportCsv,
    this.onBulkImport,
  });
  final TextEditingController searchCtrl;
  final CompanyClientsViewModel model;
  final VoidCallback? onAdd;
  final VoidCallback onColumns;
  final VoidCallback onExportCsv;
  final VoidCallback? onBulkImport;

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
              onTap: onExportCsv,
            ),
            if (onBulkImport != null) ...[
              const SizedBox(width: 4),
              _IconBtn(
                icon: Icons.upload_file_outlined,
                tooltip: 'Bulk Import',
                onTap: onBulkImport!,
              ),
            ],
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
    required this.onViewHistory,
  });
  final CompanyClientsViewModel model;
  final ScrollController hScroll;
  final bool canUpdate;
  final bool canDelete;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onDelete;
  final ValueChanged<Map<String, dynamic>> onReactivate;
  final ValueChanged<Map<String, dynamic>> onViewHistory;

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
                        isDraft: model.isDraftTab,
                        onToggleSelect: () => model.toggleRowSelection(id),
                        onEdit: () => onEdit(item),
                        onDelete: () => onDelete(item),
                        onReactivate: () => onReactivate(item),
                        onViewHistory: () => onViewHistory(item),
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
    required this.isDraft,
    required this.onToggleSelect,
    required this.onEdit,
    required this.onDelete,
    required this.onReactivate,
    required this.onViewHistory,
  });

  final Map<String, dynamic> item;
  final int rowIndex;
  final List<ClientColumnDef> cols;
  final bool isEven;
  final bool isSelected;
  final bool canUpdate;
  final bool canDelete;
  final bool isNonActive;
  final bool isDraft;
  final VoidCallback onToggleSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReactivate;
  final VoidCallback onViewHistory;

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
        child: Text('$rowIndex',
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

    if (col.key == 'created_at') {
      return _C(
        width: col.width,
        child: Text(
          CompanyClientsViewModel.fmtDate(item['created_at']),
          style: const TextStyle(fontSize: 12, color: Color(0xff374151)),
        ),
      );
    }

    if (col.key == 'action') {
      final phone = item['phone']?.toString() ?? '';
      final clientName = item['client_name']?.toString() ?? '';
      final clientId = item['id']?.toString() ?? '';
      return SizedBox(
        width: col.width,
        height: 52,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (phone.isNotEmpty && !isDraft) ...[
                CallButton(
                  phoneNumber: phone,
                  contactName: clientName,
                  contactId: clientId,
                  contactType: 'client',
                  size: 30,
                ),
                const SizedBox(width: 2),
              ],
              if (canUpdate && !isDraft)
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
              if (isNonActive && !isDraft) ...[
                const SizedBox(width: 2),
                _Btn(
                  icon: Icons.refresh_rounded,
                  color: const Color(0xff16A34A),
                  onTap: onReactivate,
                  tooltip: 'Reactivate',
                ),
              ],
              if (isDraft && canUpdate) ...[
                const SizedBox(width: 2),
                _Btn(
                  icon: Icons.refresh_rounded,
                  color: const Color(0xff16A34A),
                  onTap: onReactivate,
                  tooltip: 'Convert to Client',
                ),
              ],
              const SizedBox(width: 2),
              Builder(builder: (ctx) => _Btn(
                icon: Icons.more_vert,
                color: const Color(0xff6B7280),
                onTap: () => showDialog(
                  context: ctx,
                  builder: (_) => _ClientActionsDialog(item: item),
                ),
                tooltip: 'More Actions',
              )),
              const SizedBox(width: 2),
              _Btn(
                icon: Icons.remove_red_eye_outlined,
                color: const Color(0xff7C3AED),
                onTap: onViewHistory,
                tooltip: 'View History',
              ),
            ],
          ),
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
          val = svc['original_duration']?.toString() ?? '—';
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
          val = svc['opted_duration']?.toString() ??
              svc['duration']?.toString() ??
              '—';
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

// ─── Client History Dialog ────────────────────────────────────────────────────

class _ClientHistoryDialog extends StatefulWidget {
  const _ClientHistoryDialog({
    required this.item,
    required this.isDraft,
    required this.fetchHistory,
  });
  final Map<String, dynamic> item;
  final bool isDraft;
  final Future<Map<String, dynamic>?> Function(dynamic) fetchHistory;

  @override
  State<_ClientHistoryDialog> createState() => _ClientHistoryDialogState();
}

class _ClientHistoryDialogState extends State<_ClientHistoryDialog> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  final Set<int> _expanded = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.isDraft) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final id = widget.item['id'];
    final result = await widget.fetchHistory(id);
    if (!mounted) return;
    setState(() {
      _data = result;
      _loading = false;
      if (result == null) _error = 'Could not load client history';
    });
  }

  static String _fmt(dynamic v) {
    if (v == null) return '—';
    final s = v.toString().trim();
    if (s.isEmpty || s == 'null') return '—';
    try {
      final dt = DateTime.parse(s);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {}
    return s;
  }

  static String _money(dynamic v) {
    final d = double.tryParse(v?.toString() ?? '') ?? 0;
    return d.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.item['client_name']?.toString() ?? '—';
    final screenH = MediaQuery.of(context).size.height;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 760, maxHeight: screenH * 0.88),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xffE5E7EB)))),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Client History  $name',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: kCrmBlue)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xffEF4444),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.close,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            // ── Body ──────────────────────────────────────────────────
            Flexible(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(color: kCrmBlue),
                    )
                  : _error != null
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: Color(0xffDC2626))),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: widget.isDraft
                              ? _buildDraftBody()
                              : _buildHistoryBody(),
                        ),
            ),
            // ── Footer ────────────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                  border:
                      Border(top: BorderSide(color: Color(0xffE5E7EB)))),
              child: Center(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xff9CA3AF)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 36, vertical: 10),
                  ),
                  child: const Text('CLOSE',
                      style: TextStyle(
                          color: Color(0xff6B7280),
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Draft: failure reasons + submitted data ───────────────────────────────
  Widget _buildDraftBody() {
    final item = widget.item;
    final reason = item['failure_reasons']?.toString() ?? '—';
    final fields = <String, String>{
      'Client Name': item['client_name']?.toString() ?? '—',
      'Contact Person': item['contact_person']?.toString() ?? '—',
      'Email': item['email']?.toString() ?? '—',
      'Phone': item['phone']?.toString() ?? '—',
      'City': item['city']?.toString() ?? '—',
      'State': item['state']?.toString() ?? '—',
      'Country': item['country']?.toString() ?? '—',
      'Failed At': _fmt(item['created_at']),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xffFEF2F2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xffFCA5A5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Failure Reason',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xffDC2626))),
              const SizedBox(height: 4),
              Text(reason,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xff374151))),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Submitted Data',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kCrmBlue)),
        const SizedBox(height: 8),
        ...fields.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(e.key,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xff6B7280),
                            fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    child: Text(e.value,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xff374151))),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  // ── Active/Inactive: subscription history ─────────────────────────────────
  Widget _buildHistoryBody() {
    final client = _data?['client'] as Map<String, dynamic>? ?? {};
    final summary = _data?['summary'] as Map<String, dynamic>? ?? {};
    final subscriptions = (_data?['subscriptions'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];

    final agreed =
        double.tryParse(summary['revised_total']?.toString() ?? '0') ?? 0;
    final carriedOver =
        double.tryParse(summary['carried_over']?.toString() ?? '0') ?? 0;
    final toCollect =
        double.tryParse(summary['to_collect']?.toString() ?? '0') ?? 0;
    final totalPaid =
        double.tryParse(summary['total_paid']?.toString() ?? '0') ?? 0;
    final balance = toCollect - totalPaid;

    // Compute All-Terms totals for the footer row.
    // Balance = current/last term's balance only (not sum of all terms),
    // because paid terms' balances are carried forward, not outstanding.
    double allAgreed = 0, allPaid = 0;
    double lastTermBalance = 0;
    final currentTermNum =
        _data?['client']?['current_term_number']?.toString();
    Map<String, dynamic>? currentSub;
    for (final sub in subscriptions) {
      final a =
          double.tryParse(sub['revised_total_amount']?.toString() ?? '0') ?? 0;
      final p =
          double.tryParse(sub['total_paid']?.toString() ?? '0') ?? 0;
      allAgreed += a;
      allPaid += p;
      if (currentTermNum != null &&
          sub['term_number']?.toString() == currentTermNum) {
        currentSub = sub;
      }
    }
    // Fall back to the last subscription if current term not identified
    currentSub ??= subscriptions.isNotEmpty ? subscriptions.last : null;
    if (currentSub != null) {
      final a =
          double.tryParse(currentSub['revised_total_amount']?.toString() ?? '0') ??
              0;
      final c =
          double.tryParse(currentSub['carried_over_balance']?.toString() ?? '0') ??
              0;
      final tc =
          double.tryParse(currentSub['to_collect']?.toString() ?? '') ?? (a + c);
      final p =
          double.tryParse(currentSub['total_paid']?.toString() ?? '0') ?? 0;
      lastTermBalance = tc - p;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Client Information card ────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xffF0F9FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xffBAE6FD)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Client Information',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kCrmBlue)),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _infoItem(
                      'Name',
                      client['client_name']?.toString() ??
                          widget.item['client_name']?.toString() ??
                          '—'),
                  const SizedBox(width: 16),
                  _infoItem(
                      'Email',
                      client['email']?.toString() ??
                          widget.item['email']?.toString() ??
                          '—'),
                  const SizedBox(width: 16),
                  _infoItem(
                      'Phone',
                      client['phone']?.toString() ??
                          widget.item['phone']?.toString() ??
                          '—'),
                  const SizedBox(width: 16),
                  _infoItem(
                      'Assigned To',
                      // API client object returns numeric ID for assigned_to;
                      // prefer the name fields from the list row or employee_name.
                      client['employee_name']?.toString().trim().isNotEmpty == true
                          ? client['employee_name'].toString().trim()
                          : client['assigned_to_name']?.toString().trim().isNotEmpty == true
                              ? client['assigned_to_name'].toString().trim()
                              : widget.item['assigned_to']?.toString().trim().isNotEmpty == true
                                  ? widget.item['assigned_to'].toString().trim()
                                  : '—'),
                ]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // ── Summary boxes (horizontal scroll to prevent overflow) ──
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _summaryBox('Agreed', _money(agreed), const Color(0xff2563EB)),
            const SizedBox(width: 8),
            _summaryBox(
                'Carried Over', _money(carriedOver), const Color(0xffF97316)),
            const SizedBox(width: 8),
            _summaryBox(
                'To Collect', _money(toCollect), const Color(0xffD97706)),
            const SizedBox(width: 8),
            _summaryBox(
                'Total Paid', _money(totalPaid), const Color(0xff16A34A)),
            const SizedBox(width: 8),
            _summaryBox(
                'Balance',
                _money(balance),
                balance > 0
                    ? const Color(0xffDC2626)
                    : const Color(0xff16A34A)),
          ]),
        ),
        if (subscriptions.isNotEmpty) ...[
          const SizedBox(height: 20),
          // ── Subscription Terms ───────────────────────────────────
          Text('Subscription Terms (${subscriptions.length})',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kCrmBlue)),
          const SizedBox(height: 8),
          _buildTermsTable(
              subscriptions, allAgreed, allPaid, lastTermBalance),
          const SizedBox(height: 20),
          // ── Subscription Details ─────────────────────────────────
          Text('Subscription Details (${subscriptions.length})',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kCrmBlue)),
          const SizedBox(height: 8),
          ...subscriptions.asMap().entries
              .map((e) => _buildSubDetailRow(e.key, e.value)),
        ],
      ],
    );
  }

  // ── Subscription Terms table ───────────────────────────────────────────────
  Widget _buildTermsTable(List<Map<String, dynamic>> subs, double allAgreed,
      double allPaid, double allBalance) {
    const cols = [140.0, 90.0, 105.0, 105.0, 82.0, 90.0, 80.0];

    Widget hdrCell(String t, double w) => SizedBox(
          width: w,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Text(t,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff374151))),
          ),
        );

    Widget cell(double w, Widget child) => SizedBox(
          width: w,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: child,
          ),
        );

    Widget moneyCell(double w, double v,
            {Color? color, bool bold = false}) =>
        cell(
            w,
            Text(v.toStringAsFixed(2),
                style: TextStyle(
                    fontSize: 12,
                    color: color ?? const Color(0xff374151),
                    fontWeight: bold
                        ? FontWeight.w700
                        : (color != null
                            ? FontWeight.w600
                            : FontWeight.normal))));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Container(
            decoration: BoxDecoration(
              color: const Color(0xffF3E8FF),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border.all(color: const Color(0xffE9D5FF)),
            ),
            child: Row(children: [
              hdrCell('Term', cols[0]),
              hdrCell('Agreed', cols[1]),
              hdrCell('Carried Over', cols[2]),
              hdrCell('To Collect', cols[3]),
              hdrCell('Paid', cols[4]),
              hdrCell('Balance', cols[5]),
              hdrCell('Status', cols[6]),
            ]),
          ),
          // Data rows
          ...subs.asMap().entries.map((entry) {
            final idx = entry.key;
            final sub = entry.value;
            final a =
                double.tryParse(sub['revised_total_amount']?.toString() ?? '0') ??
                    0;
            final c = double.tryParse(
                    sub['carried_over_balance']?.toString() ?? '0') ??
                0;
            final tc =
                double.tryParse(sub['to_collect']?.toString() ?? '') ?? (a + c);
            final p =
                double.tryParse(sub['total_paid']?.toString() ?? '0') ?? 0;
            final bal = tc - p;
            final status = sub['status']?.toString() ?? '';
            final isCurrent = sub['term_number']?.toString() ==
                _data?['client']?['current_term_number']?.toString();
            final termLabel =
                'Term ${sub['term_number'] ?? idx + 1}${isCurrent ? ' (Current)' : ''}';
            final termColor = isCurrent
                ? const Color(0xff16A34A)
                : const Color(0xff7C3AED);

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  left: BorderSide(color: Color(0xffE5E7EB)),
                  right: BorderSide(color: Color(0xffE5E7EB)),
                  bottom: BorderSide(color: Color(0xffE5E7EB)),
                ),
              ),
              child: Row(children: [
                cell(
                    cols[0],
                    Row(children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: termColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                          child: Text(termLabel,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: termColor,
                                  fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis)),
                    ])),
                moneyCell(cols[1], a),
                // Carried over: show "–" when zero (no prior term balance)
                cell(
                    cols[2],
                    c == 0
                        ? const Text('–',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xff9CA3AF)))
                        : Text(c.toStringAsFixed(2),
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xffF97316),
                                fontWeight: FontWeight.w600))),
                moneyCell(cols[3], tc,
                    color: const Color(0xffD97706)),
                moneyCell(cols[4], p,
                    color: const Color(0xff16A34A)),
                moneyCell(cols[5], bal,
                    color: bal > 0
                        ? const Color(0xffDC2626)
                        : const Color(0xff16A34A)),
                cell(
                    cols[6],
                    Text(
                        _termStatusLabel(status),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _termStatusColor(status)))),
              ]),
            );
          }),
          // All Terms Total row
          Container(
            decoration: BoxDecoration(
              color: const Color(0xffF9FAFB),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(8)),
              border: Border.all(color: const Color(0xffE5E7EB)),
            ),
            child: Row(children: [
              cell(
                  cols[0],
                  const Text('All Terms Total',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xff374151)))),
              moneyCell(cols[1], allAgreed, bold: true),
              cell(cols[2], const SizedBox()),
              cell(cols[3], const SizedBox()),
              moneyCell(cols[4], allPaid,
                  color: const Color(0xff16A34A), bold: true),
              moneyCell(cols[5], allBalance,
                  color: allBalance > 0
                      ? const Color(0xffDC2626)
                      : const Color(0xff16A34A),
                  bold: true),
              cell(cols[6], const SizedBox()),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Subscription Details expandable row ───────────────────────────────────
  Widget _buildSubDetailRow(int idx, Map<String, dynamic> sub) {
    final isExpanded = _expanded.contains(idx);
    final isCurrent = sub['term_number']?.toString() ==
        _data?['client']?['current_term_number']?.toString();
    final termNum = sub['term_number'] ?? idx + 1;

    List<Map<String, dynamic>> services = [];
    try {
      final raw = sub['services'];
      if (raw is List) {
        services =
            raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else if (raw is String && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        services =
            decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}

    final paid =
        double.tryParse(sub['total_paid']?.toString() ?? '0') ?? 0;
    final carriedOver =
        double.tryParse(sub['carried_over_balance']?.toString() ?? '0') ?? 0;
    final agreed =
        double.tryParse(sub['revised_total_amount']?.toString() ?? '0') ?? 0;
    final toCollect =
        double.tryParse(sub['to_collect']?.toString() ?? '') ??
            (agreed + carriedOver);
    final balance = toCollect - paid;
    final svcCount = services.length;

    final termBgColor =
        isCurrent ? const Color(0xffFFF7ED) : const Color(0xffF5F3FF);
    final termBorderColor =
        isCurrent ? const Color(0xffFED7AA) : const Color(0xffDDD6FE);
    final termTextColor =
        isCurrent ? const Color(0xffEA580C) : const Color(0xff7C3AED);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header bar (tap to expand/collapse)
        GestureDetector(
          onTap: () => setState(() {
            if (isExpanded) {
              _expanded.remove(idx);
            } else {
              _expanded.add(idx);
            }
          }),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            margin: EdgeInsets.only(bottom: isExpanded ? 0 : 6),
            decoration: BoxDecoration(
              color: isExpanded
                  ? (isCurrent
                      ? const Color(0xffFFF7ED)
                      : const Color(0xffFAF5FF))
                  : Colors.white,
              borderRadius: isExpanded
                  ? const BorderRadius.vertical(top: Radius.circular(8))
                  : BorderRadius.circular(8),
              border: Border.all(color: const Color(0xffE5E7EB)),
            ),
            child: Row(children: [
              // Term badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: termBgColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: termBorderColor),
                ),
                child: Text('Term $termNum',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: termTextColor)),
              ),
              const SizedBox(width: 10),
              Text(
                  '$svcCount Service${svcCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xff374151))),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                    'Paid: ₹${_money(paid)}  |  Balance: ₹${_money(balance)}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xff6B7280))),
              ),
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: const Color(0xff6B7280),
              ),
            ]),
          ),
        ),
        // Expanded detail panel
        if (isExpanded)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(8)),
              border: Border.all(color: const Color(0xffE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service table header
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xffF9FAFB),
                    border: Border(
                        bottom: BorderSide(color: Color(0xffE5E7EB))),
                  ),
                  child: const Row(children: [
                    Expanded(
                        flex: 4,
                        child: Text('Service',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff6B7280)))),
                    Expanded(
                        flex: 2,
                        child: Text('Duration',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff6B7280)))),
                    Expanded(
                        flex: 2,
                        child: Text('Amount',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff6B7280)))),
                  ]),
                ),
                // Service rows
                if (services.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('No service details available',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xff9CA3AF))),
                  )
                else ...[
                  ...services.map((svc) {
                    final svcName = svc['service_name']?.toString() ??
                        svc['product_name']?.toString() ??
                        '—';
                    final dur = svc['duration']?.toString() ?? '—';
                    final amt =
                        double.tryParse(svc['total_amount']?.toString() ?? '')
                            ?.toStringAsFixed(2) ??
                            '—';
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: const BoxDecoration(
                          border: Border(
                              bottom: BorderSide(
                                  color: Color(0xffF3F4F6)))),
                      child: Row(children: [
                        Expanded(
                            flex: 4,
                            child: Text(svcName,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xff374151)))),
                        Expanded(
                            flex: 2,
                            child: Text(dur,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xff374151)))),
                        Expanded(
                            flex: 2,
                            child: Text('₹$amt',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xff374151)))),
                      ]),
                    );
                  }),
                  // Total row
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Row(children: [
                      const Expanded(
                          flex: 4,
                          child: Text('Total',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xff374151)))),
                      const Expanded(flex: 2, child: SizedBox()),
                      Expanded(
                          flex: 2,
                          child: Text(
                              '₹${(agreed).toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xff2563EB)))),
                    ]),
                  ),
                  // Balance from previous term row (only when carried over > 0)
                  if (carriedOver > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: const BoxDecoration(
                        color: Color(0xffFFFBEB),
                        border: Border(
                            top: BorderSide(color: Color(0xffFED7AA))),
                      ),
                      child: Row(children: [
                        const Expanded(
                            flex: 4,
                            child: Text('+ Balance from Previous Term',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xffD97706),
                                    fontWeight: FontWeight.w500))),
                        const Expanded(flex: 2, child: SizedBox()),
                        Expanded(
                            flex: 2,
                            child: Text(
                                '₹${carriedOver.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xffD97706),
                                    fontWeight: FontWeight.w600))),
                      ]),
                    ),
                ],
                // Action buttons
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: const BoxDecoration(
                      border:
                          Border(top: BorderSide(color: Color(0xffE5E7EB)))),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _actionBtn(
                        Icons.remove_red_eye_outlined,
                        'VIEW PDF',
                        const Color(0xff7C3AED),
                        const Color(0xffF5F3FF),
                        onTap: () => _previewPdf(sub, services),
                      ),
                      _actionBtn(
                        Icons.download_outlined,
                        'DOWNLOAD PDF',
                        const Color(0xff2563EB),
                        const Color(0xffEFF6FF),
                        onTap: () => _downloadPdf(sub, services),
                      ),
                      _actionBtn(
                        Icons.email_outlined,
                        'SEND MAIL',
                        const Color(0xff0D9488),
                        const Color(0xffF0FDFA),
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => _ClientComposeEmailDialog(
                            item: widget.item,
                            clientData: _data?['client'] as Map<String, dynamic>? ?? widget.item,
                            sub: sub,
                            services: services,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static Widget _actionBtn(
          IconData icon, String label, Color color, Color bg,
          {VoidCallback? onTap}) =>
      OutlinedButton.icon(
        onPressed: onTap ?? () {},
        icon: Icon(icon, size: 14, color: color),
        label: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color)),
        style: OutlinedButton.styleFrom(
          backgroundColor: bg,
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );

  bool _pdfBusy = false;

  void _previewPdf(Map<String, dynamic> sub,
      List<Map<String, dynamic>> services) async {
    if (_pdfBusy) return;
    _pdfBusy = true;
    SmartDialog.showLoading(msg: 'Generating PDF…');
    try {
      final bytes = await _ClientInvoicePdfGenerator.generate(
          widget.item,
          _data?['client'] as Map<String, dynamic>? ?? widget.item,
          sub,
          services);
      await SmartDialog.dismiss();
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'Subscription - ${widget.item['client_name'] ?? 'PDF'}',
      );
    } catch (e) {
      SmartDialog.dismiss();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('PDF preview error: $e'),
            backgroundColor: const Color(0xffDC2626)));
      }
    } finally {
      _pdfBusy = false;
    }
  }

  void _downloadPdf(Map<String, dynamic> sub,
      List<Map<String, dynamic>> services) async {
    if (_pdfBusy) return;
    _pdfBusy = true;
    SmartDialog.showLoading(msg: 'Preparing PDF…');
    try {
      final bytes = await _ClientInvoicePdfGenerator.generate(
          widget.item,
          _data?['client'] as Map<String, dynamic>? ?? widget.item,
          sub,
          services);
      final dir = await getTemporaryDirectory();
      final name = (widget.item['client_name']?.toString() ?? 'invoice')
          .replaceAll(' ', '_');
      final file = File('${dir.path}/subscription_$name.pdf');
      await file.writeAsBytes(bytes);
      await SmartDialog.dismiss();
      await Share.shareXFiles([XFile(file.path)], text: 'Invoice PDF');
    } catch (e) {
      await SmartDialog.dismiss();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Download error: $e'),
            backgroundColor: const Color(0xffDC2626)));
      }
    } finally {
      _pdfBusy = false;
    }
  }

  Widget _summaryBox(String label, String value, Color color) => Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w700)),
        ]),
      );

  // "completed" from backend maps to the user-facing label "Paid"
  static String _termStatusLabel(String status) {
    if (status.isEmpty) return '—';
    final s = status.toLowerCase();
    if (s == 'completed' || s == 'paid') return 'Paid';
    if (s == 'active') return 'Active';
    return status[0].toUpperCase() + status.substring(1);
  }

  static Color _termStatusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'completed' || s == 'paid') return const Color(0xff16A34A);
    if (s == 'active') return const Color(0xffEA580C);
    return const Color(0xff6B7280);
  }

  static Widget _infoItem(String label, String value) => SizedBox(
        width: 160,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xff6B7280))),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xff111827))),
            ]),
      );
}

// ─── Bulk Import Dialog ───────────────────────────────────────────────────────

class _ClientBulkImportDialog extends StatefulWidget {
  const _ClientBulkImportDialog({required this.onImport});
  final Future<String?> Function(List<Map<String, dynamic>>) onImport;

  @override
  State<_ClientBulkImportDialog> createState() =>
      _ClientBulkImportDialogState();
}

class _ClientBulkImportDialogState extends State<_ClientBulkImportDialog> {
  List<Map<String, dynamic>>? _parsed;
  String? _parseError;
  bool _submitting = false;
  String? _submitError;

  // Required columns (CSV/xlsx headers after normalisation)
  static const _requiredCols = ['client_name', 'phone'];

  // All recognised columns mapped to the backend payload
  static const _allCols = [
    'client_name', 'contact_person', 'email', 'phone',
    'alternate_contact', 'tax_id', 'street_address',
    'city', 'state', 'postal_code', 'country',
    'notes', 'negotiate', 'tax_option', 'round_off',
    'payment_terms', 'preferred_payment',
    'services', 'start_dates', 'required_durations',
  ];

  // camelCase / spaces → snake_case
  static String _normalizeHeader(String h) {
    h = h.trim().replaceAll('"', '');
    h = h.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (m) => '_${m.group(0)!.toLowerCase()}',
    );
    h = h.replaceAll(' ', '_').toLowerCase();
    if (h.startsWith('_')) h = h.substring(1);
    return h;
  }

  // Proper CSV field splitter (handles quoted fields with commas inside)
  static List<String> _splitCsvLine(String line) {
    final fields = <String>[];
    final buf = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        fields.add(buf.toString().trim());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    fields.add(buf.toString().trim());
    return fields;
  }

  void _parseCsv(String raw) {
    try {
      raw = raw.replaceFirst('﻿', ''); // strip BOM
      raw = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      final lines = raw
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.length < 2) {
        setState(() =>
            _parseError = 'CSV must have a header row and data rows');
        return;
      }
      final headers =
          _splitCsvLine(lines.first).map(_normalizeHeader).toList();
      for (final req in _requiredCols) {
        if (!headers.contains(req)) {
          setState(() => _parseError = 'Missing required column: $req');
          return;
        }
      }
      final rows = <Map<String, dynamic>>[];
      for (final line in lines.skip(1)) {
        final vals = _splitCsvLine(line);
        final row = <String, dynamic>{};
        for (int i = 0; i < headers.length; i++) {
          if (_allCols.contains(headers[i])) {
            row[headers[i]] = i < vals.length ? vals[i] : '';
          }
        }
        if ((row['client_name'] ?? '').toString().trim().isNotEmpty &&
            (row['phone'] ?? '').toString().trim().isNotEmpty) {
          rows.add(row);
        }
      }
      if (rows.isEmpty) {
        setState(() => _parseError =
            'No valid rows found — ensure client_name and phone have data');
        return;
      }
      setState(() {
        _parsed = rows;
        _parseError = null;
      });
    } catch (e) {
      setState(() => _parseError = 'Parse error: $e');
    }
  }

  void _parseXlsx(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      // 1. Shared strings table
      final sharedStrings = <String>[];
      final ssFile = archive.findFile('xl/sharedStrings.xml');
      if (ssFile != null) {
        final ssBytes = ssFile.content;
        if (ssBytes.isNotEmpty) {
          final doc = XmlDocument.parse(utf8.decode(ssBytes));
          for (final si in doc.findAllElements('si')) {
            sharedStrings
                .add(si.findAllElements('t').map((t) => t.innerText).join());
          }
        }
      }

      // 2. First worksheet (try common paths)
      ArchiveFile? sheetFile;
      for (final path in [
        'xl/worksheets/sheet1.xml',
        'xl/worksheets/Sheet1.xml',
        'xl/worksheets/sheet.xml',
      ]) {
        sheetFile = archive.findFile(path);
        if (sheetFile != null) break;
      }
      if (sheetFile == null) {
        for (final f in archive.files) {
          if (f.name.startsWith('xl/worksheets/') && f.name.endsWith('.xml')) {
            sheetFile = f;
            break;
          }
        }
      }

      if (sheetFile == null) {
        if (mounted) setState(() => _parseError = 'No worksheet found in Excel file');
        return;
      }

      final sheetBytes = sheetFile.content;
      final sheetDoc = XmlDocument.parse(utf8.decode(sheetBytes));

      // 3. Build rows
      int xlColIndex(String ref) {
        final letters = ref.replaceAll(RegExp(r'[0-9]'), '').toUpperCase();
        int idx = 0;
        for (final ch in letters.codeUnits) {
          idx = idx * 26 + (ch - 64);
        }
        return idx - 1;
      }

      final rows = <List<String>>[];
      for (final rowEl in sheetDoc.findAllElements('row')) {
        final cells = <String>[];
        for (final cell in rowEl.findAllElements('c')) {
          final ref = cell.getAttribute('r') ?? '';
          final colIdx = xlColIndex(ref);
          while (cells.length < colIdx) { cells.add(''); }
          final type = cell.getAttribute('t') ?? '';
          final vEls = cell.findElements('v');
          final vEl = vEls.isEmpty ? null : vEls.first;
          String value = '';
          if (type == 's') {
            final idx = int.tryParse(vEl?.innerText.trim() ?? '') ?? -1;
            value = (idx >= 0 && idx < sharedStrings.length)
                ? sharedStrings[idx]
                : '';
          } else if (type == 'inlineStr') {
            value = cell.findAllElements('t').map((t) => t.innerText).join();
          } else {
            value = vEl?.innerText ?? '';
          }
          cells.add(value.trim());
        }
        if (cells.isNotEmpty) rows.add(cells);
      }

      if (rows.length < 2) {
        if (mounted) {
          setState(() => _parseError =
              'Excel sheet must have a header row and data rows (found ${rows.length})');
        }
        return;
      }

      // 4. Headers → validate → map rows
      final headers = rows.first.map(_normalizeHeader).toList();
      for (final req in _requiredCols) {
        if (!headers.contains(req)) {
          if (mounted) {
            setState(() => _parseError =
                'Missing required column: $req (found: ${headers.join(', ')})');
          }
          return;
        }
      }

      final result = <Map<String, dynamic>>[];
      for (final row in rows.skip(1)) {
        final map = <String, dynamic>{};
        for (int i = 0; i < headers.length; i++) {
          if (_allCols.contains(headers[i])) {
            map[headers[i]] = (i < row.length ? row[i] : '').trim();
          }
        }
        final name = (map['client_name'] ?? '').toString().trim();
        final phone = (map['phone'] ?? '').toString().trim();
        if (name.isNotEmpty && phone.isNotEmpty) result.add(map);
      }

      if (result.isEmpty) {
        final sample =
            rows.length > 1 ? rows[1].take(4).join(' | ') : '(no rows)';
        if (mounted) {
          setState(() => _parseError =
              'No valid rows found — client_name and phone must have values. '
              'First data row: $sample');
        }
        return;
      }

      if (mounted) {
        setState(() {
          _parsed = result;
          _parseError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _parseError = 'Excel parse error: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        if (mounted) setState(() => _parseError = 'Could not read file bytes');
        return;
      }
      final ext = (file.extension ?? '').toLowerCase();
      if (ext == 'csv') {
        _parseCsv(utf8.decode(bytes));
      } else if (ext == 'xlsx' || ext == 'xls') {
        _parseXlsx(bytes);
      } else {
        if (mounted) {
          setState(() => _parseError = 'Unsupported file type. Use .csv or .xlsx');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _parseError = 'Error picking file: $e');
    }
  }

  Future<void> _submit() async {
    if (_parsed == null) return;
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    final msg = await widget.onImport(_parsed!);
    if (!mounted) return;
    final isPartial = msg != null &&
        msg.contains('Imported') &&
        msg.contains('failed');
    if (msg == null || isPartial) {
      Navigator.pop(context);
      if (isPartial && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xffD97706),
          duration: const Duration(seconds: 5),
        ));
      }
    } else {
      setState(() {
        _submitting = false;
        _submitError = msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: const BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: Color(0xffE5E7EB)))),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Bulk Import Clients',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: kCrmBlue)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 20, color: Color(0xff6B7280)),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Instructions
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xffEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xffBFDBFE)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Format Instructions',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: kCrmBlue)),
                          SizedBox(height: 6),
                          Text(
                            'Required: client_name, phone\n'
                            'Optional: contact_person, email, alternate_contact,\n'
                            '  tax_id, street_address, city, state, postal_code,\n'
                            '  country, notes, services, start_dates,\n'
                            '  required_durations\n'
                            'Tip: services = comma-separated service names\n'
                            'Valid data → Active tab  |  Failed → Draft tab',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xff374151)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Pick file button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.upload_file_outlined, size: 18),
                        label: Text(_parsed != null
                            ? '${_parsed!.length} rows loaded — tap to change'
                            : 'Choose File (.csv / .xlsx)'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kCrmBlue,
                          side: const BorderSide(color: kCrmBlue),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    if (_parseError != null) ...[
                      const SizedBox(height: 8),
                      Text(_parseError!,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xffDC2626))),
                    ],
                    if (_parsed != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xffF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: const Color(0xff86EFAC)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline,
                                size: 16, color: Color(0xff16A34A)),
                            const SizedBox(width: 8),
                            Text('${_parsed!.length} client(s) ready to import',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xff16A34A),
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                    if (_submitError != null) ...[
                      const SizedBox(height: 8),
                      Text(_submitError!,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xffDC2626))),
                    ],
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                  border:
                      Border(top: BorderSide(color: Color(0xffE5E7EB)))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _submitting ? null : () => Navigator.pop(context),
                    child: const Text('CANCEL',
                        style: TextStyle(color: Color(0xff6B7280))),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed:
                        (_parsed == null || _submitting) ? null : _submit,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: kCrmBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8))),
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('IMPORT'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable circular action button ─────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    this.bgColor,
    this.circular = false,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final Color? bgColor;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    if (circular) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: bgColor ?? color.withValues(alpha: 0.10),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
      );
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ─── Client Actions Dialog (3-dot menu) ──────────────────────────────────────

class _ClientActionsDialog extends StatelessWidget {
  const _ClientActionsDialog({required this.item});
  final Map<String, dynamic> item;

  List<Map<String, dynamic>> _services() {
    try {
      final raw = item['services'];
      if (raw == null) return [];
      final list = raw is List ? raw : jsonDecode(raw.toString()) as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static bool _busy = false;

  void _preview(BuildContext context) async {
    if (_busy) return;
    _busy = true;
    final sm = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    SmartDialog.showLoading(msg: 'Generating PDF…');
    try {
      final bytes = await _ClientSimpleInvoicePdfGenerator.generate(
          item, item, item, _services());
      await SmartDialog.dismiss();
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'Invoice - ${item['client_name'] ?? 'PDF'}',
      );
    } catch (e) {
      await SmartDialog.dismiss();
      sm.showSnackBar(SnackBar(
          content: Text('PDF error: $e'),
          backgroundColor: const Color(0xffDC2626)));
    } finally {
      _busy = false;
    }
  }

  void _download(BuildContext context) async {
    if (_busy) return;
    _busy = true;
    final sm = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    SmartDialog.showLoading(msg: 'Preparing PDF…');
    try {
      final bytes = await _ClientSimpleInvoicePdfGenerator.generate(
          item, item, item, _services());
      final dir = await getTemporaryDirectory();
      final name = (item['client_name']?.toString() ?? 'invoice')
          .replaceAll(' ', '_');
      final file = File('${dir.path}/invoice_$name.pdf');
      await file.writeAsBytes(bytes);
      await SmartDialog.dismiss();
      await Share.shareXFiles([XFile(file.path)], text: 'Invoice PDF');
    } catch (e) {
      await SmartDialog.dismiss();
      sm.showSnackBar(SnackBar(
          content: Text('Download error: $e'),
          backgroundColor: const Color(0xffDC2626)));
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('What would you like to do?',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff111827))),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _ActionBtn(
                  icon: Icons.email_outlined,
                  color: const Color(0xff2563EB),
                  circular: true,
                  onTap: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (_) => _ClientComposeEmailDialog(
                        item: item,
                        clientData: item,
                        sub: item,
                        services: _services(),
                      ),
                    );
                  },
                ),
                _ActionBtn(
                  icon: Icons.remove_red_eye_outlined,
                  color: const Color(0xff0891B2),
                  circular: true,
                  onTap: () => _preview(context),
                ),
                _ActionBtn(
                  icon: Icons.download_outlined,
                  color: const Color(0xff0891B2),
                  circular: true,
                  onTap: () => _download(context),
                ),
                _ActionBtn(
                  icon: Icons.close,
                  color: const Color(0xffEF4444),
                  bgColor: const Color(0xffFEF2F2),
                  circular: true,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Client Invoice PDF Generator ─────────────────────────────────────────────

class _ClientInvoicePdfGenerator {
  static Future<Uint8List> generate(
    Map<String, dynamic> listItem,
    Map<String, dynamic> clientData,
    Map<String, dynamic> sub,
    List<Map<String, dynamic>> services,
  ) async {
    final api = locator<HippoAuthService>();
    Map<String, dynamic> header = {};
    String userName = '';
    try {
      final settings = await api.getCompanySettingsForPdf();
      header = settings['header'] as Map<String, dynamic>? ?? {};
      userName = settings['userName']?.toString() ?? '';
    } catch (_) {}

    pw.ImageProvider? letterheadImage;
    try {
      final lhUrl = header['letterhead']?.toString() ?? '';
      if (lhUrl.isNotEmpty) letterheadImage = await networkImage(lhUrl);
    } catch (_) {}

    pw.ImageProvider? logoImage;
    try {
      final logoUrl = header['logo']?.toString() ?? '';
      if (logoUrl.isNotEmpty) logoImage = await networkImage(logoUrl);
    } catch (_) {}

    pw.ImageProvider? digisignImage;
    try {
      final dsUrl = header['digisign']?.toString() ?? '';
      if (dsUrl.isNotEmpty) digisignImage = await networkImage(dsUrl);
    } catch (_) {}

    final ttf = await PdfGoogleFonts.notoSansRegular();
    final ttfBold = await PdfGoogleFonts.notoSansBold();

    // ── Client info ───────────────────────────────────────────────────────────
    final clientName = clientData['client_name']?.toString() ??
        listItem['client_name']?.toString() ?? '—';
    final contact = clientData['contact_person']?.toString() ??
        listItem['contact_person']?.toString() ?? '—';
    final email = clientData['email']?.toString() ??
        listItem['email']?.toString() ?? '—';
    final phone = clientData['phone']?.toString() ??
        listItem['phone']?.toString() ?? '—';
    final assignedTo = clientData['employee_name']?.toString().trim().isNotEmpty == true
        ? clientData['employee_name'].toString().trim()
        : clientData['assigned_to_name']?.toString().trim().isNotEmpty == true
            ? clientData['assigned_to_name'].toString().trim()
            : listItem['assigned_to']?.toString().trim().isNotEmpty == true
                ? listItem['assigned_to'].toString().trim()
                : '—';
    final clientStatus = (listItem['status']?.toString() ?? '').toUpperCase();

    // ── Term info ─────────────────────────────────────────────────────────────
    final termNum = sub['term_number']?.toString() ?? '1';
    final subId = sub['subscription_id']?.toString() ??
        sub['current_subscription_id']?.toString() ??
        sub['id']?.toString() ?? '—';
    final subStatus = (sub['status']?.toString() ?? '').toUpperCase();
    final discount = sub['discount']?.toString() ?? '0.00';
    final taxOption = sub['tax_option']?.toString() ?? '—';
    final negotiate = sub['negotiate']?.toString() ?? '—';
    final roundOff = double.tryParse(sub['round_off']?.toString() ?? '0') ?? 0;
    final periodStart = _fmtDate(sub['start_date'] ??
        (services.isNotEmpty ? services.first['start_date'] : null));
    final periodEnd = _fmtDate(sub['end_date'] ??
        (services.isNotEmpty ? services.first['end_date'] : null));

    // ── Financials ────────────────────────────────────────────────────────────
    final origTotal = double.tryParse(sub['original_total_amount']?.toString() ?? '') ?? 0;
    final origTax = double.tryParse(sub['original_tax_amount']?.toString() ?? '') ?? 0;
    final revisedTotal = double.tryParse(sub['revised_total_amount']?.toString() ?? '') ?? 0;
    final totalPaid = double.tryParse(sub['total_paid']?.toString() ?? '0') ?? 0;
    final carriedOver = double.tryParse(sub['carried_over_balance']?.toString() ?? '0') ?? 0;
    final toCollect = double.tryParse(sub['to_collect']?.toString() ?? '') ?? (revisedTotal + carriedOver);
    final balanceDue = toCollect - totalPaid;

    // ── Generated date/time ───────────────────────────────────────────────────
    final now = DateTime.now();
    final genStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}'
        ' ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // ── Page theme ────────────────────────────────────────────────────────────
    // bottom=75 reserves space for signatory(~55px) + footer bar(~20px)
    final pageTheme = letterheadImage != null
        ? pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.fromLTRB(28, 130, 28, 75),
            buildBackground: (pw.Context context) => pw.FullPage(
              ignoreMargins: true,
              child: pw.Image(letterheadImage!,
                  fit: pw.BoxFit.fill,
                  width: PdfPageFormat.a4.width,
                  height: PdfPageFormat.a4.height),
            ),
          )
        : pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.fromLTRB(28, 20, 28, 75),
          );

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageTheme: pageTheme,
      build: (pw.Context ctx) {
        final widgets = <pw.Widget>[];

        // ── Programmatic header (no letterhead) ──────────────────────────────
        if (letterheadImage == null) {
          widgets.add(pw.Column(children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                logoImage != null
                    ? pw.Image(logoImage, width: 130, height: 50, fit: pw.BoxFit.contain)
                    : pw.Text(userName,
                        style: pw.TextStyle(font: ttfBold, fontSize: 18,
                            color: const PdfColor.fromInt(0xFF1E3A8A))),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  if ((header['phone']?.toString() ?? '').isNotEmpty)
                    pw.Text('☎ ${header['phone']}',
                        style: pw.TextStyle(font: ttf, fontSize: 9)),
                  if ((header['email']?.toString() ?? '').isNotEmpty)
                    pw.Text('✉ ${header['email']}',
                        style: pw.TextStyle(font: ttf, fontSize: 9)),
                  if ((header['website']?.toString() ?? '').isNotEmpty)
                    pw.Text('⊕ ${header['website']}',
                        style: pw.TextStyle(font: ttf, fontSize: 9)),
                ]),
              ],
            ),
            pw.Divider(thickness: 0.8, color: PdfColors.grey400),
            pw.SizedBox(height: 6),
          ]));
        }

        // ── Title ─────────────────────────────────────────────────────────────
        widgets.add(pw.Center(
          child: pw.Text('Subscription Statement — Term $termNum',
              style: pw.TextStyle(font: ttfBold, fontSize: 13,
                  color: const PdfColor.fromInt(0xFF1E3A8A))),
        ));
        widgets.add(pw.SizedBox(height: 6));

        // ── Client Information ─────────────────────────────────────────────────
        widgets.add(_sectionHeader('Client Information', ttfBold));
        widgets.add(pw.SizedBox(height: 4));
        widgets.add(_infoGrid([
          ['Client Name', clientName],
          ['Contact Person', contact],
          ['Email', email],
          ['Phone', phone],
          ['Assigned To', assignedTo],
          ['Status', clientStatus],
        ], ttf, ttfBold));
        widgets.add(pw.SizedBox(height: 2));
        widgets.add(pw.Text('Generated: $genStr',
            style: pw.TextStyle(font: ttf, fontSize: 7, color: PdfColors.grey600)));
        widgets.add(pw.SizedBox(height: 6));

        // ── Term Overview ──────────────────────────────────────────────────────
        widgets.add(_sectionHeader('Term $termNum Overview', ttfBold));
        widgets.add(pw.SizedBox(height: 4));
        widgets.add(_infoGrid([
          ['Subscription ID', '#$subId'],
          ['Term Number', 'Term $termNum'],
          ['Status', subStatus],
          ['Period', '$periodStart - $periodEnd'],
          ['Discount', '$discount%'],
          ['Tax Option', taxOption],
          ['Negotiate', negotiate],
          ['Round Off', roundOff.toStringAsFixed(2)],
        ], ttf, ttfBold));
        widgets.add(pw.SizedBox(height: 6));

        // ── Services Breakdown ─────────────────────────────────────────────────
        widgets.add(_sectionHeader('Services Breakdown', ttfBold));
        widgets.add(pw.SizedBox(height: 4));

        const svcCols = <int, pw.TableColumnWidth>{
          0: pw.FixedColumnWidth(22),
          1: pw.FlexColumnWidth(3),
          2: pw.FlexColumnWidth(2),
          3: pw.FlexColumnWidth(2),
          4: pw.FlexColumnWidth(1.5),
          5: pw.FlexColumnWidth(2),
        };

        // Header row
        final svcRows = <pw.TableRow>[
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF3F4F6)),
            children: [
              _tc('#', ttfBold, isHeader: true, align: pw.TextAlign.center),
              _tc('Service', ttfBold, isHeader: true),
              _tc('Duration', ttfBold, isHeader: true, align: pw.TextAlign.center),
              _tc('Base', ttfBold, isHeader: true, align: pw.TextAlign.right),
              _tc('Tax %', ttfBold, isHeader: true, align: pw.TextAlign.center),
              _tc('Total', ttfBold, isHeader: true, align: pw.TextAlign.right),
            ],
          ),
        ];

        double svcOrigSubtotal = 0;
        for (var i = 0; i < services.length; i++) {
          final svc = services[i];
          final svcName = svc['service_name']?.toString() ??
              svc['product_name']?.toString() ?? '—';
          final dur = svc['original_duration']?.toString() ??
              svc['opted_duration']?.toString() ?? svc['duration']?.toString() ?? '—';
          final base = double.tryParse(svc['base_price']?.toString() ?? '') ?? 0;
          final taxRate = svc['tax_rate']?.toString() ?? '0';
          final svcTotal = double.tryParse(svc['total_amount']?.toString() ?? '') ?? 0;
          svcOrigSubtotal += svcTotal;
          svcRows.add(pw.TableRow(children: [
            _tc('${i + 1}', ttf, align: pw.TextAlign.center),
            _tc(svcName, ttf),
            _tc('$dur mo', ttf, align: pw.TextAlign.center),
            _tc(base.toStringAsFixed(2), ttf, align: pw.TextAlign.right),
            _tc('$taxRate%', ttf, align: pw.TextAlign.center),
            _tc(svcTotal.toStringAsFixed(2), ttf, align: pw.TextAlign.right),
          ]));
        }

        widgets.add(pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: svcCols,
          children: svcRows,
        ));

        // Subtotals
        final subtotalActual = origTotal > 0 ? origTotal : svcOrigSubtotal;
        final taxLabel = taxOption.toLowerCase() == 'excluding'
            ? 'Tax (Tax Exclusive)'
            : 'Tax (Tax Inclusive)';
        widgets.add(_subtotalRow('Subtotal (Original):', subtotalActual.toStringAsFixed(2), ttf));
        widgets.add(_subtotalRow('$taxLabel:', origTax.toStringAsFixed(2), ttf));
        if (roundOff != 0) {
          widgets.add(_subtotalRow('Round Off:', roundOff.toStringAsFixed(2), ttf));
        }
        widgets.add(_subtotalRow('Revised Total:', revisedTotal.toStringAsFixed(2), ttfBold, bold: true));
        if (carriedOver > 0) {
          widgets.add(_subtotalRow('Previous Balance:', carriedOver.toStringAsFixed(2), ttf));
          widgets.add(_subtotalRow('Amount to Collect:', toCollect.toStringAsFixed(2), ttfBold, bold: true));
        }
        widgets.add(pw.SizedBox(height: 6));

        // ── Payment History ────────────────────────────────────────────────────
        widgets.add(_sectionHeader('Payment History', ttfBold));
        widgets.add(pw.SizedBox(height: 4));
        final payments = <Map<String, dynamic>>[];
        try {
          final raw = sub['payments'];
          if (raw is List && raw.isNotEmpty) {
            payments.addAll(raw.map((e) => Map<String, dynamic>.from(e as Map)));
          }
        } catch (_) {}
        if (payments.isEmpty) {
          widgets.add(pw.Text('No payments recorded for this term.',
              style: pw.TextStyle(font: ttf, fontSize: 8,
                  fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)));
        } else {
          final payRows = <pw.TableRow>[
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF3F4F6)),
              children: [
                _tc('Date', ttfBold, isHeader: true),
                _tc('Amount', ttfBold, isHeader: true, align: pw.TextAlign.right),
                _tc('Mode', ttfBold, isHeader: true),
                _tc('Reference', ttfBold, isHeader: true),
              ],
            ),
            ...payments.map((p) => pw.TableRow(children: [
              _tc(_fmtDate(p['payment_date'] ?? p['date'] ?? p['created_at']), ttf),
              _tc((double.tryParse(p['amount']?.toString() ?? '0') ?? 0).toStringAsFixed(2),
                  ttf, align: pw.TextAlign.right),
              _tc(p['payment_mode']?.toString() ?? p['mode']?.toString() ?? '—', ttf),
              _tc(p['reference']?.toString() ?? p['transaction_id']?.toString() ?? '—', ttf),
            ])),
          ];
          widgets.add(pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(1.5),
              2: pw.FlexColumnWidth(1.5),
              3: pw.FlexColumnWidth(2),
            },
            children: payRows,
          ));
        }
        widgets.add(pw.SizedBox(height: 6));

        // ── Financial Summary ─────────────────────────────────────────────────
        widgets.add(_sectionHeader('Financial Summary', ttfBold));
        widgets.add(pw.SizedBox(height: 4));
        widgets.add(_financialRow('Agreed Amount (Revised Total):', revisedTotal.toStringAsFixed(2), ttf, ttfBold));
        if (carriedOver > 0) {
          widgets.add(_financialRow('Balance Carried from Previous Term:', carriedOver.toStringAsFixed(2), ttf, ttfBold));
          widgets.add(_financialRow('Total to Collect:', toCollect.toStringAsFixed(2), ttf, ttfBold));
        }
        widgets.add(_financialRow('Total Paid:', totalPaid.toStringAsFixed(2), ttf, ttfBold));
        widgets.add(_financialRow('Balance Due:', balanceDue.toStringAsFixed(2), ttf, ttfBold, highlight: true));

        return widgets;
      },
      footer: (pw.Context ctx) {
        final footerAddr = header['address']?.toString().isNotEmpty == true
            ? header['address'].toString()
            : 'HippoCloud Technologies Pvt. Ltd.';
        final isLast = ctx.pageNumber == ctx.pagesCount;
        return pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            if (isLast) ...[
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (digisignImage != null)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 4),
                          child: pw.Image(digisignImage,
                              width: 80, height: 40, fit: pw.BoxFit.contain),
                        )
                      else
                        pw.SizedBox(height: 28),
                      pw.Text('Authorized Signatory',
                          style: pw.TextStyle(
                              font: ttf,
                              fontSize: 8,
                              fontStyle: pw.FontStyle.italic,
                              color: PdfColors.grey700)),
                      pw.Text(userName,
                          style: pw.TextStyle(font: ttfBold, fontSize: 9)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
            ],
            pw.Container(
              decoration: const pw.BoxDecoration(
                  border: pw.Border(
                      top: pw.BorderSide(color: PdfColors.grey300))),
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 0, vertical: 4),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(userName,
                      style: pw.TextStyle(
                          font: ttf, fontSize: 7, color: PdfColors.grey600)),
                  pw.Expanded(
                    child: pw.Text(footerAddr,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            font: ttf,
                            fontSize: 7,
                            color: PdfColors.grey600)),
                  ),
                  pw.Text(
                      'Page ${ctx.pageNumber} of ${ctx.pagesCount}  $genStr',
                      style: pw.TextStyle(
                          font: ttf,
                          fontSize: 7,
                          color: PdfColors.grey600)),
                ],
              ),
            ),
          ],
        );
      },
    ));

    return doc.save();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static String _fmtDate(dynamic raw) {
    if (raw == null) return '—';
    final s = raw.toString().trim();
    if (s.isEmpty || s == 'null') return '—';
    try {
      final dt = DateTime.parse(s);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {}
    return s;
  }

  static pw.Widget _sectionHeader(String title, pw.Font ttfBold) =>
      pw.Text(title,
          style: pw.TextStyle(
              font: ttfBold, fontSize: 9, color: PdfColors.black));

  static pw.Widget _infoGrid(
      List<List<String>> rows, pw.Font ttf, pw.Font ttfBold) {
    final left = <List<String>>[];
    final right = <List<String>>[];
    for (var i = 0; i < rows.length; i++) {
      if (i.isEven) { left.add(rows[i]); } else { right.add(rows[i]); }
    }
    final maxLen = left.length > right.length ? left.length : right.length;
    final tableRows = <pw.TableRow>[];
    for (var i = 0; i < maxLen; i++) {
      tableRows.add(pw.TableRow(children: [
        _infoCell(i < left.length ? left[i][0] : '', i < left.length ? left[i][1] : '', ttf, ttfBold),
        _infoCell(i < right.length ? right[i][0] : '', i < right.length ? right[i][1] : '', ttf, ttfBold),
      ]));
    }
    return pw.Table(
      columnWidths: const {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(1)},
      children: tableRows,
    );
  }

  static pw.Widget _infoCell(
      String label, String value, pw.Font ttf, pw.Font ttfBold) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: pw.RichText(
          text: pw.TextSpan(children: [
            pw.TextSpan(
                text: label.isNotEmpty ? '$label: ' : '',
                style: pw.TextStyle(font: ttfBold, fontSize: 8,
                    color: PdfColors.grey800)),
            pw.TextSpan(
                text: value,
                style: pw.TextStyle(font: ttf, fontSize: 8,
                    color: PdfColors.grey900)),
          ]),
        ),
      );

  static pw.Widget _tc(String text, pw.Font font,
      {bool isHeader = false, pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: pw.Text(text,
            textAlign: align,
            style: pw.TextStyle(
                font: font,
                fontSize: isHeader ? 9 : 8,
                color: isHeader ? PdfColors.grey800 : PdfColors.grey700)),
      );

  static pw.Widget _subtotalRow(
      String label, String value, pw.Font font, {bool bold = false}) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    font: font, fontSize: bold ? 8 : 7,
                    color: bold ? PdfColors.grey900 : PdfColors.grey700)),
            pw.SizedBox(width: 40),
            pw.SizedBox(
              width: 80,
              child: pw.Text(value,
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                      font: font, fontSize: bold ? 8 : 7,
                      color: bold ? PdfColors.grey900 : PdfColors.grey700)),
            ),
          ],
        ),
      );

  static pw.Widget _financialRow(
      String label, String value, pw.Font ttf, pw.Font ttfBold,
      {bool highlight = false}) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        color: highlight ? const PdfColor.fromInt(0xFFFFF7ED) : PdfColors.white,
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    font: highlight ? ttfBold : ttf,
                    fontSize: highlight ? 9 : 8,
                    color: highlight
                        ? const PdfColor.fromInt(0xFFDC2626)
                        : PdfColors.grey800)),
            pw.Text(value,
                style: pw.TextStyle(
                    font: ttfBold,
                    fontSize: highlight ? 9 : 8,
                    color: highlight
                        ? const PdfColor.fromInt(0xFFDC2626)
                        : PdfColors.grey900)),
          ],
        ),
      );
}

// ─── Client Simple Invoice PDF Generator ──────────────────────────────────────

class _ClientSimpleInvoicePdfGenerator {
  static Future<Uint8List> generate(
    Map<String, dynamic> listItem,
    Map<String, dynamic> clientData,
    Map<String, dynamic> sub,
    List<Map<String, dynamic>> services, {
    String title = 'Invoice',
    bool showSubscriptionDetails = false,
  }) async {
    final api = locator<HippoAuthService>();
    Map<String, dynamic> header = {};
    Map<String, dynamic> bank = {};
    String userName = '';
    try {
      final settings = await api.getCompanySettingsForPdf();
      header = settings['header'] as Map<String, dynamic>? ?? {};
      bank = settings['bank'] as Map<String, dynamic>? ?? {};
      userName = settings['userName']?.toString() ?? '';
    } catch (_) {}

    pw.ImageProvider? letterheadImage;
    try {
      final lhUrl = header['letterhead']?.toString() ?? '';
      if (lhUrl.isNotEmpty) letterheadImage = await networkImage(lhUrl);
    } catch (_) {}

    pw.ImageProvider? logoImage;
    try {
      final logoUrl = header['logo']?.toString() ?? '';
      if (logoUrl.isNotEmpty) logoImage = await networkImage(logoUrl);
    } catch (_) {}

    pw.ImageProvider? digisignImage;
    try {
      final dsUrl = header['digisign']?.toString() ?? '';
      if (dsUrl.isNotEmpty) digisignImage = await networkImage(dsUrl);
    } catch (_) {}

    final ttf = await PdfGoogleFonts.notoSansRegular();
    final ttfBold = await PdfGoogleFonts.notoSansBold();

    final clientName = clientData['client_name']?.toString() ??
        listItem['client_name']?.toString() ?? '—';
    final contact = clientData['contact_person']?.toString() ??
        listItem['contact_person']?.toString() ?? '—';
    final email = clientData['email']?.toString() ??
        listItem['email']?.toString() ?? '—';
    final phone = clientData['phone']?.toString() ??
        listItem['phone']?.toString() ?? '—';
    final rawAddr = clientData['complete_address']?.toString().trim() ??
        listItem['complete_address']?.toString().trim() ?? '';
    final address = rawAddr.isNotEmpty
        ? rawAddr
        : [
            clientData['street_address'] ?? listItem['street_address'],
            clientData['postal_code'] ?? listItem['postal_code'],
          ].where((v) => v != null && v.toString().isNotEmpty).join(', ');

    final revisedTaxable =
        double.tryParse(sub['revised_taxable_amount']?.toString() ?? '') ?? 0;
    final revisedTax =
        double.tryParse(sub['revised_tax_amount']?.toString() ?? '') ?? 0;
    final revisedTotal =
        double.tryParse(sub['revised_total_amount']?.toString() ??
            sub['round_off']?.toString() ?? '') ?? 0;

    // Subscription term fields
    final termNum = sub['term_number']?.toString() ?? '1';
    final subId = sub['subscription_id']?.toString() ??
        sub['current_subscription_id']?.toString() ??
        sub['id']?.toString() ?? '—';
    final subStatus = (sub['status']?.toString() ?? '').toUpperCase();
    final discount = sub['discount']?.toString() ?? '0.00';
    final taxOption = sub['tax_option']?.toString() ?? '—';
    final negotiate = sub['negotiate']?.toString() ?? '—';
    final roundOff =
        double.tryParse(sub['round_off']?.toString() ?? '0') ?? 0;
    final periodStart = _fmt(sub['start_date'] ??
        (services.isNotEmpty ? services.first['start_date'] : null));
    final periodEnd = _fmt(sub['end_date'] ??
        (services.isNotEmpty ? services.first['end_date'] : null));
    final origTotal =
        double.tryParse(sub['original_total_amount']?.toString() ?? '') ?? 0;
    final origTax =
        double.tryParse(sub['original_tax_amount']?.toString() ?? '') ?? 0;
    final totalPaid =
        double.tryParse(sub['total_paid']?.toString() ?? '0') ?? 0;
    final balanceDue = revisedTotal - totalPaid;

    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final pageTheme = letterheadImage != null
        ? pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.fromLTRB(28, 130, 28, 55),
            buildBackground: (pw.Context context) => pw.FullPage(
              ignoreMargins: true,
              child: pw.Image(letterheadImage!,
                  fit: pw.BoxFit.fill,
                  width: PdfPageFormat.a4.width,
                  height: PdfPageFormat.a4.height),
            ),
          )
        : pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.fromLTRB(28, 20, 28, 20),
          );

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageTheme: pageTheme,
      build: (pw.Context ctx) {
        final widgets = <pw.Widget>[];

        if (letterheadImage == null) {
          widgets.add(pw.Column(children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                logoImage != null
                    ? pw.Image(logoImage, width: 130, height: 50,
                        fit: pw.BoxFit.contain)
                    : pw.Text(userName,
                        style: pw.TextStyle(font: ttfBold, fontSize: 18,
                            color: const PdfColor.fromInt(0xFF1E3A8A))),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                  if ((header['phone']?.toString() ?? '').isNotEmpty)
                    pw.Text('☎ ${header['phone']}',
                        style: pw.TextStyle(font: ttf, fontSize: 9)),
                  if ((header['email']?.toString() ?? '').isNotEmpty)
                    pw.Text('✉ ${header['email']}',
                        style: pw.TextStyle(font: ttf, fontSize: 9)),
                  if ((header['website']?.toString() ?? '').isNotEmpty)
                    pw.Text('⊕ ${header['website']}',
                        style: pw.TextStyle(font: ttf, fontSize: 9)),
                ]),
              ],
            ),
            pw.Divider(thickness: 0.8, color: PdfColors.grey400),
            pw.SizedBox(height: 6),
          ]));
        }

        widgets.add(pw.Center(
          child: pw.Text(title,
              style: pw.TextStyle(font: ttfBold, fontSize: 18,
                  color: const PdfColor.fromInt(0xFF111827))),
        ));
        widgets.add(pw.SizedBox(height: 10));

        widgets.add(pw.Text('Invoice for $clientName',
            style: pw.TextStyle(font: ttfBold, fontSize: 13)));
        widgets.add(pw.SizedBox(height: 8));

        widgets.add(pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('To: $clientName',
                      style: pw.TextStyle(font: ttf, fontSize: 9)),
                  pw.Text('Contact: $contact',
                      style: pw.TextStyle(font: ttf, fontSize: 9)),
                  pw.Text('Email: $email',
                      style: pw.TextStyle(font: ttf, fontSize: 9)),
                  pw.Text('Phone: $phone',
                      style: pw.TextStyle(font: ttf, fontSize: 9)),
                  if (address.isNotEmpty)
                    pw.Text('Address: $address',
                        style: pw.TextStyle(font: ttf, fontSize: 9)),
                ],
              ),
            ),
            pw.Text('Date: $dateStr',
                style: pw.TextStyle(font: ttf, fontSize: 9)),
          ],
        ));
        widgets.add(pw.SizedBox(height: 14));

        // Subscription Details (only for eye button / subscription view)
        if (showSubscriptionDetails) {
          widgets.add(pw.Text('Subscription Details',
              style: pw.TextStyle(font: ttfBold, fontSize: 11)));
          widgets.add(pw.Divider(thickness: 0.8, color: PdfColors.grey500));
          widgets.add(pw.SizedBox(height: 4));
          widgets.add(pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(children: [
                _infoLine('Subscription ID', '#$subId', ttf, ttfBold),
                _infoLine('Term Number', 'Term $termNum', ttf, ttfBold),
              ]),
              pw.TableRow(children: [
                _infoLine('Status', subStatus, ttf, ttfBold),
                _infoLine('Period', '$periodStart – $periodEnd', ttf, ttfBold),
              ]),
              pw.TableRow(children: [
                _infoLine('Discount', '$discount%', ttf, ttfBold),
                _infoLine('Tax Option', taxOption, ttf, ttfBold),
              ]),
              pw.TableRow(children: [
                _infoLine('Negotiate', negotiate, ttf, ttfBold),
                _infoLine('Round Off', roundOff.toStringAsFixed(2), ttf,
                    ttfBold),
              ]),
            ],
          ));
          widgets.add(pw.SizedBox(height: 14));
        }

        // Services Details
        widgets.add(pw.Text('Services Details',
            style: pw.TextStyle(font: ttfBold, fontSize: 11)));
        widgets.add(pw.Divider(thickness: 0.8, color: PdfColors.grey500));
        widgets.add(pw.SizedBox(height: 4));

        final svcRows = <pw.TableRow>[
          pw.TableRow(
            decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF3F4F6)),
            children: [
              _cell('Service', ttfBold, isHeader: true),
              _cell('Start Date', ttfBold,
                  isHeader: true, align: pw.TextAlign.center),
              _cell('End Date', ttfBold,
                  isHeader: true, align: pw.TextAlign.center),
              _cell('Days', ttfBold,
                  isHeader: true, align: pw.TextAlign.center),
            ],
          ),
        ];
        for (final svc in services) {
          final svcName = svc['service_name']?.toString() ??
              svc['product_name']?.toString() ?? '—';
          final startDate = _fmt(svc['start_date']);
          final endDate = _fmt(svc['end_date']);
          final days = svc['duration']?.toString() ?? '—';
          svcRows.add(pw.TableRow(children: [
            _cell(svcName, ttf),
            _cell(startDate, ttf, align: pw.TextAlign.center),
            _cell(endDate, ttf, align: pw.TextAlign.center),
            _cell(days, ttf, align: pw.TextAlign.center),
          ]));
        }
        widgets.add(pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FlexColumnWidth(2),
            2: pw.FlexColumnWidth(2),
            3: pw.FlexColumnWidth(1.5),
          },
          children: svcRows,
        ));
        widgets.add(pw.SizedBox(height: 14));

        // Financial Summary
        widgets.add(pw.Text('Financial Summary',
            style: pw.TextStyle(font: ttfBold, fontSize: 11)));
        widgets.add(pw.Divider(thickness: 0.8, color: PdfColors.grey500));
        widgets.add(pw.SizedBox(height: 4));

        widgets.add(pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF3F4F6)),
              children: [
                _cell('Description', ttfBold, isHeader: true),
                _cell('Amount', ttfBold,
                    isHeader: true, align: pw.TextAlign.right),
              ],
            ),
            if (showSubscriptionDetails) ...[
              pw.TableRow(children: [
                _cell('Subtotal (Original)', ttf),
                _cell(origTotal.toStringAsFixed(2), ttf,
                    align: pw.TextAlign.right),
              ]),
              pw.TableRow(children: [
                _cell('Tax Amount (Original)', ttf),
                _cell(origTax.toStringAsFixed(2), ttf,
                    align: pw.TextAlign.right),
              ]),
            ],
            pw.TableRow(children: [
              _cell('Taxable Amount', ttf),
              _cell(revisedTaxable.toStringAsFixed(2), ttf,
                  align: pw.TextAlign.right),
            ]),
            pw.TableRow(children: [
              _cell('Tax Amount', ttf),
              _cell(revisedTax.toStringAsFixed(2), ttf,
                  align: pw.TextAlign.right),
            ]),
            pw.TableRow(children: [
              _cell('Total Amount', ttfBold),
              _cell(revisedTotal.toStringAsFixed(2), ttfBold,
                  align: pw.TextAlign.right),
            ]),
            if (showSubscriptionDetails) ...[
              pw.TableRow(children: [
                _cell('Total Paid', ttf),
                _cell(totalPaid.toStringAsFixed(2), ttf,
                    align: pw.TextAlign.right),
              ]),
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFFFF7ED)),
                children: [
                  _cell('Balance Due', ttfBold),
                  _cell(balanceDue.toStringAsFixed(2), ttfBold,
                      align: pw.TextAlign.right),
                ],
              ),
            ],
          ],
        ));
        widgets.add(pw.SizedBox(height: 14));

        // Bank Details
        if (bank.isNotEmpty) {
          widgets.add(pw.Text('Bank Details:',
              style: pw.TextStyle(font: ttfBold, fontSize: 10)));
          widgets.add(pw.SizedBox(height: 6));
          widgets.add(pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _bankLine('Bank Name', bank['bankname'], ttf, ttfBold),
                    _bankLine('A/C Number', bank['accountnumber'], ttf,
                        ttfBold),
                    _bankLine('Branch Name', bank['branchname'], ttf,
                        ttfBold),
                    _bankLine('Branch Address', bank['branchaddress'], ttf,
                        ttfBold),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _bankLine('A/C Holder', bank['accountholdername'], ttf,
                        ttfBold),
                    _bankLine('IFSC Code', bank['ifsccode'], ttf, ttfBold),
                    _bankLine('MICR Code', bank['micrcode'], ttf, ttfBold),
                  ],
                ),
              ),
            ],
          ));
          widgets.add(pw.SizedBox(height: 16));
        }

        // Authorized Signatory
        widgets.add(pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (digisignImage != null)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Image(digisignImage,
                        width: 80, height: 40, fit: pw.BoxFit.contain),
                  )
                else
                  pw.SizedBox(height: 28),
                pw.Text('For $userName',
                    style: pw.TextStyle(
                        font: ttf, fontSize: 9,
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColors.grey700)),
                pw.Text('Authorized Signature',
                    style: pw.TextStyle(font: ttfBold, fontSize: 9)),
              ],
            ),
          ],
        ));

        return widgets;
      },
      footer: (pw.Context ctx) {
        final footerAddr =
            header['address']?.toString().isNotEmpty == true
                ? header['address'].toString()
                : 'HippoCloud Technologies Pvt. Ltd.';
        return pw.Container(
          decoration: const pw.BoxDecoration(
              border:
                  pw.Border(top: pw.BorderSide(color: PdfColors.grey300))),
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 0, vertical: 4),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(userName,
                  style: pw.TextStyle(
                      font: ttf, fontSize: 7, color: PdfColors.grey600)),
              pw.Expanded(
                child: pw.Text(footerAddr,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                        font: ttf,
                        fontSize: 7,
                        color: PdfColors.grey600)),
              ),
              pw.Text(
                  'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: pw.TextStyle(
                      font: ttf, fontSize: 7, color: PdfColors.grey600)),
            ],
          ),
        );
      },
    ));

    return doc.save();
  }

  static String _fmt(dynamic raw) {
    if (raw == null) return '—';
    final s = raw.toString().trim();
    if (s.isEmpty || s == 'null') return '—';
    try {
      final dt = DateTime.parse(s);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {}
    return s;
  }

  static pw.Widget _infoLine(
          String label, String value, pw.Font ttf, pw.Font ttfBold) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
        child: pw.RichText(
          text: pw.TextSpan(children: [
            pw.TextSpan(
                text: '$label: ',
                style: pw.TextStyle(
                    font: ttfBold, fontSize: 9, color: PdfColors.grey800)),
            pw.TextSpan(
                text: value,
                style: pw.TextStyle(
                    font: ttf, fontSize: 9, color: PdfColors.grey900)),
          ]),
        ),
      );

  static pw.Widget _cell(String text, pw.Font font,
          {bool isHeader = false,
          pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: pw.Text(text,
            textAlign: align,
            style: pw.TextStyle(
                font: font,
                fontSize: isHeader ? 9 : 8,
                color: isHeader ? PdfColors.grey800 : PdfColors.grey700)),
      );

  static pw.Widget _bankLine(
          String label, dynamic value, pw.Font ttf, pw.Font ttfBold) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.RichText(
          text: pw.TextSpan(children: [
            pw.TextSpan(
                text: '$label: ',
                style: pw.TextStyle(
                    font: ttfBold, fontSize: 9,
                    color: PdfColors.grey800)),
            pw.TextSpan(
                text: value?.toString() ?? '—',
                style: pw.TextStyle(
                    font: ttf, fontSize: 9, color: PdfColors.grey900)),
          ]),
        ),
      );
}

// ─── Client Compose Email Dialog ──────────────────────────────────────────────

class _ClientComposeEmailDialog extends StatefulWidget {
  const _ClientComposeEmailDialog({
    required this.item,
    required this.clientData,
    required this.sub,
    required this.services,
  });
  final Map<String, dynamic> item;
  final Map<String, dynamic> clientData;
  final Map<String, dynamic> sub;
  final List<Map<String, dynamic>> services;

  @override
  State<_ClientComposeEmailDialog> createState() =>
      _ClientComposeEmailDialogState();
}

class _ClientComposeEmailDialogState
    extends State<_ClientComposeEmailDialog> {
  final _api = locator<HippoAuthService>();
  late final TextEditingController _subjectCtrl;
  late final TextEditingController _bodyCtrl;
  bool _sending = false;
  String? _error;

  String get _contactName {
    final v = widget.clientData['contact_person']?.toString().trim() ??
        widget.item['contact_person']?.toString().trim() ?? '';
    if (v.isNotEmpty) return v;
    return widget.clientData['client_name']?.toString().trim() ??
        widget.item['client_name']?.toString() ?? 'Sir/Madam';
  }

  @override
  void initState() {
    super.initState();
    final clientName = widget.clientData['client_name']?.toString() ??
        widget.item['client_name']?.toString() ?? '';
    final termNum = widget.sub['term_number']?.toString() ?? '1';
    _subjectCtrl = TextEditingController(
        text: 'Subscription Statement — $clientName Term $termNum');
    _bodyCtrl = TextEditingController(
        text: 'Dear ${_contactName},\n\nWe hope this message finds you well. '
            'Attached are the details for your Payment Details, including services, '
            'dates, and financial summary.\n\nPlease review the attached PDF for '
            'complete details. Feel free to reach out if you have any questions or '
            'require further assistance.\n\nBest regards,\n');
    _api.getCompanySettingsForPdf().then((s) {
      if (!mounted) return;
      final header = s['header'] as Map<String, dynamic>? ?? {};
      final company = header['name']?.toString().trim().isNotEmpty == true
          ? header['name'].toString().trim()
          : header['companyname']?.toString().trim().isNotEmpty == true
              ? header['companyname'].toString().trim()
              : s['userName']?.toString().trim() ?? '';
      if (company.isNotEmpty) {
        _bodyCtrl.text =
            'Dear ${_contactName},\n\nWe hope this message finds you well. '
            'Attached are the details for your Payment Details, including services, '
            'dates, and financial summary.\n\nPlease review the attached PDF for '
            'complete details. Feel free to reach out if you have any questions or '
            'require further assistance.\n\nBest regards,\n$company';
      }
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final toEmail = widget.clientData['email']?.toString() ??
        widget.item['email']?.toString() ?? '';
    if (toEmail.isEmpty) {
      setState(() => _error = 'No email address found for this client.');
      return;
    }
    setState(() { _sending = true; _error = null; });
    try {
      final bytes = await _ClientInvoicePdfGenerator.generate(
          widget.item, widget.clientData, widget.sub, widget.services);
      final pdfBase64 = base64Encode(bytes);
      final clientName = (widget.clientData['client_name']?.toString() ??
              widget.item['client_name']?.toString() ?? 'invoice')
          .replaceAll(' ', '_');
      await _api.sendFollowupEmail(
        toEmail: toEmail,
        subject: _subjectCtrl.text.trim(),
        message: _bodyCtrl.text.trim(),
        pdfBase64: pdfBase64,
        fileName: 'invoice_$clientName.pdf',
        lead: widget.clientData,
        services: widget.services,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Compose Email',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                      color: kCrmBlue)),
              const SizedBox(height: 16),
              TextField(
                controller: _subjectCtrl,
                decoration: const InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bodyCtrl,
                maxLines: 7,
                decoration: const InputDecoration(
                    labelText: 'Email Content',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                style: const TextStyle(fontSize: 13),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xffDC2626))),
              ],
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                ElevatedButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send, size: 16),
                  label: const Text('SEND EMAIL'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kCrmBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 16,
                      color: Color(0xff6B7280)),
                  label: const Text('CANCEL',
                      style: TextStyle(color: Color(0xff6B7280))),
                  style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
