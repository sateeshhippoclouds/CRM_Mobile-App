import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:stacked/stacked.dart';

import '../../../../../app/app.locator.dart';
import '../../../../../services/api_services.dart';
import 'company_leads_viewmodel.dart';
import 'crm_widgets.dart';

const double _headerH = 48;
const double _rowH = 52;

class CompanyLeadsView extends StatefulWidget {
  const CompanyLeadsView({super.key});

  @override
  State<CompanyLeadsView> createState() => _CompanyLeadsViewState();
}

class _CompanyLeadsViewState extends State<CompanyLeadsView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<CompanyLeadsViewModel>.reactive(
      viewModelBuilder: () => CompanyLeadsViewModel(),
      onViewModelReady: (m) => m.init(),
      builder: (context, model, child) {
        return Scaffold(
          backgroundColor: kCrmBg,
          appBar: crmAppBar('Leads'),
          body: model.isBusy
              ? const Center(child: CircularProgressIndicator(color: kCrmBlue))
              : model.fetchError != null
                  ? CrmErrorBody(error: model.fetchError!, onRetry: model.init)
                  : Column(
                      children: [
                        Container(
                          color: Colors.white,
                          child: TabBar(
                            controller: _tabController,
                            labelColor: kCrmBlue,
                            unselectedLabelColor: const Color(0xff6B7280),
                            indicatorColor: kCrmBlue,
                            labelStyle: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                            tabs: const [
                              Tab(text: 'LEADS'),
                              Tab(text: 'FOLLOW-UPS'),
                            ],
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _LeadsTab(model: model, searchCtrl: _searchCtrl),
                              _FollowupsTab(model: model),
                            ],
                          ),
                        ),
                      ],
                    ),
        );
      },
    );
  }
}

// ─── Leads Tab ────────────────────────────────────────────────────────────────

class _LeadsTab extends StatelessWidget {
  const _LeadsTab({required this.model, required this.searchCtrl});
  final CompanyLeadsViewModel model;
  final TextEditingController searchCtrl;

  Future<void> _downloadCsv(BuildContext ctx) async {
    try {
      final csv = model.buildCsvContent();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/leads.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)],
          text: model.hasSelection
              ? 'Leads (${model.selectedCount} selected)'
              : 'All Leads');
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  void _showAddDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => _AddLeadDialog(
        onSave: (data) => model.addLead(data),
      ),
    );
  }

  void _showDetailModal(BuildContext ctx, Map<String, dynamic> item) {
    showDialog(
      context: ctx,
      builder: (_) => _LeadDetailModal(item: item),
    );
  }

  void _showEditDialog(BuildContext ctx, Map<String, dynamic> item) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => _EditLeadDialog(
        item: item,
        onSave: (data) => model.updateLead(item['id'], data),
      ),
    );
  }

  void _showColumnsDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => _CustomizeColumnsDialog(model: model),
    );
  }

  Future<void> _confirmDelete(
      BuildContext ctx, Map<String, dynamic> item) async {
    final name = item['lead_name']?.toString() ?? 'this lead';
    final id = item['id'];
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(vertical: 24),
        title: const Text('Delete Lead',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        content: Text('Delete "$name"? This action cannot be undone.',
            style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCEL',
                  style: TextStyle(color: Color(0xff6B7280)))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffDC2626),
                foregroundColor: Colors.white),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final err = await model.deleteLead(id);
      if (err != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(err)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!model.canRead) {
      return const CrmEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Access Restricted',
        subtitle: 'You do not have permission to view leads',
      );
    }
    return Column(
      children: [
        _Toolbar(
          model: model,
          searchCtrl: searchCtrl,
          onAdd: model.canWrite ? () => _showAddDialog(context) : null,
          onColumns: () => _showColumnsDialog(context),
          onExportCsv: () => _downloadCsv(context),
        ),
        if (model.hasSelection) _SelectionBar(model: model),
        if (model.hasActiveFilters) _FilterChipsBar(model: model),
        Expanded(
          child: model.items.isEmpty &&
                  !model.hasActiveFilters &&
                  searchCtrl.text.isEmpty
              ? const CrmEmptyState(
                  icon: Icons.bar_chart_rounded,
                  title: 'No Leads Found',
                  subtitle: 'Add your first lead to get started',
                )
              : model.items.isEmpty
                  ? const CrmEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No Matching Leads',
                      subtitle: 'Try adjusting your search or filters',
                    )
                  : _LeadsTable(
                      model: model,
                      canUpdate: model.canUpdate,
                      canDelete: model.canDelete,
                      onRowTap: (item) => _showDetailModal(context, item),
                      onEdit: (item) => _showEditDialog(context, item),
                      onDelete: (item) => _confirmDelete(context, item),
                    ),
        ),
        _PaginationBar(model: model),
      ],
    );
  }
}

// ─── Toolbar ──────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.model,
    required this.searchCtrl,
    this.onAdd,
    required this.onColumns,
    required this.onExportCsv,
  });
  final CompanyLeadsViewModel model;
  final TextEditingController searchCtrl;
  final VoidCallback? onAdd;
  final VoidCallback onColumns;
  final VoidCallback onExportCsv;

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
                onChanged: model.searchLeads,
                decoration: InputDecoration(
                  hintText: 'Search leads...',
                  hintStyle:
                      const TextStyle(color: Color(0xff9CA3AF), fontSize: 12),
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
                              model.searchLeads('');
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
                    borderSide: const BorderSide(color: Color(0xffE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xffE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: kCrmBlue),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            _PipelineDropdown(model: model),
            if (onAdd != null) ...[
              const SizedBox(width: 6),
              ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('ADD LEADS',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kCrmBlue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
            const SizedBox(width: 6),
            _IconBtn(
              icon: Icons.download_outlined,
              tooltip: 'Export CSV',
              onTap: onExportCsv,
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
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xffE5E7EB)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 18, color: const Color(0xff374151)),
        ),
      ),
    );
  }
}

// ─── Pipeline Dropdown ────────────────────────────────────────────────────────

class _PipelineDropdown extends StatelessWidget {
  const _PipelineDropdown({required this.model});
  final CompanyLeadsViewModel model;

  @override
  Widget build(BuildContext context) {
    final current = CompanyLeadsViewModel.pipelineOptions
        .firstWhere((o) => o['value'] == model.pipeline);

    return PopupMenuButton<String>(
      onSelected: model.setPipeline,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (_) => CompanyLeadsViewModel.pipelineOptions.map((opt) {
        return PopupMenuItem<String>(
          value: opt['value'] as String,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Color(opt['color'] as int),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(opt['label'] as String,
                  style: const TextStyle(fontSize: 13)),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: kCrmBlue),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Color(current['color'] as int),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(current['label'] as String,
                style: const TextStyle(
                    fontSize: 13,
                    color: kCrmBlue,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: kCrmBlue, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── Selection Bar ────────────────────────────────────────────────────────────

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.model});
  final CompanyLeadsViewModel model;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kCrmBlue.withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('${model.selectedCount} selected',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: kCrmBlue)),
          const SizedBox(width: 8),
          const Flexible(
            child: Text('CSV will export selected only',
                style: TextStyle(fontSize: 12, color: Color(0xff6B7280)),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: model.clearSelection,
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
            child: const Text('Clear',
                style: TextStyle(fontSize: 12, color: kCrmBlue)),
          ),
        ],
      ),
    );
  }
}

// ─── Filter Chips Bar ─────────────────────────────────────────────────────────

class _FilterChipsBar extends StatelessWidget {
  const _FilterChipsBar({required this.model});
  final CompanyLeadsViewModel model;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Row(
        children: [
          const Text('Filters:',
              style: TextStyle(fontSize: 12, color: Color(0xff6B7280))),
          const SizedBox(width: 6),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: model.colFilters.entries.map((e) {
                final col = CompanyLeadsViewModel.allColumns.firstWhere(
                    (c) => c.key == e.key,
                    orElse: () => LeadColumnDef(e.key, e.key, 0));
                return Chip(
                  label: Text('${col.label}: ${e.value}',
                      style: const TextStyle(fontSize: 11)),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => model.setColFilter(e.key, ''),
                  backgroundColor: kCrmBlue.withValues(alpha: 0.08),
                  side: BorderSide(color: kCrmBlue.withValues(alpha: 0.3)),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ),
          TextButton(
            onPressed: model.clearAllFilters,
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
            child: const Text('Clear all',
                style: TextStyle(fontSize: 12, color: Color(0xffDC2626))),
          ),
        ],
      ),
    );
  }
}

// ─── Leads Table ─────────────────────────────────────────────────────────────

class _LeadsTable extends StatelessWidget {
  const _LeadsTable({
    required this.model,
    required this.canUpdate,
    required this.canDelete,
    required this.onRowTap,
    required this.onEdit,
    required this.onDelete,
  });
  final CompanyLeadsViewModel model;
  final bool canUpdate;
  final bool canDelete;
  final void Function(Map<String, dynamic>) onRowTap;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onDelete;

  @override
  Widget build(BuildContext context) {
    final cols = model.visibleColumns;
    final totalW = cols.fold(0.0, (s, c) => s + c.width);
    final hScroll = ScrollController();

    return LayoutBuilder(builder: (_, constraints) {
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
                        onTap: () => onRowTap(item),
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

// ─── Header Cell ─────────────────────────────────────────────────────────────

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(
      {required this.col, required this.model, required this.screenCtx});
  final LeadColumnDef col;
  final CompanyLeadsViewModel model;
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
        height: _headerH,
        decoration: const BoxDecoration(border: Border(right: _divider)),
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
      height: _headerH,
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

// ─── Column Filter Dialog ─────────────────────────────────────────────────────

class _ColFilterDialog extends StatefulWidget {
  const _ColFilterDialog({required this.col, required this.model});
  final LeadColumnDef col;
  final CompanyLeadsViewModel model;

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

// ─── Data Row ─────────────────────────────────────────────────────────────────

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
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> item;
  final int rowIndex;
  final List<LeadColumnDef> cols;
  final bool isEven;
  final bool isSelected;
  final bool canUpdate;
  final bool canDelete;
  final VoidCallback onToggleSelect;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const _cellDivider = BorderSide(color: Color(0xffEEEEEE), width: 0.8);

  Widget _buildCell(LeadColumnDef col) {
    switch (col.key) {
      case 'checkbox':
        return Container(
          width: col.width,
          height: _rowH,
          decoration: const BoxDecoration(border: Border(right: _cellDivider)),
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
          child: Text('${item['id'] ?? rowIndex}',
              style: const TextStyle(fontSize: 12, color: Color(0xff6B7280))),
        );

      case 'lead_name':
        final name = item['lead_name']?.toString() ?? '—';
        return _Cell(
          width: col.width,
          child: GestureDetector(
            onTap: onTap,
            child: Text(name,
                style: const TextStyle(
                    fontSize: 12,
                    color: kCrmBlue,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline),
                overflow: TextOverflow.ellipsis,
                maxLines: 1),
          ),
        );

      case 'action':
        return Container(
          width: col.width,
          height: _rowH,
          decoration: const BoxDecoration(border: Border(right: _cellDivider)),
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
          child: Text(val,
              style: const TextStyle(fontSize: 12, color: Color(0xff374151)),
              overflow: TextOverflow.ellipsis,
              maxLines: 1),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isSelected
          ? kCrmBlue.withValues(alpha: 0.06)
          : isEven
              ? Colors.white
              : const Color(0xffFAFAFA),
      child: Row(
        children: cols.map(_buildCell).toList(),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.width, required this.child});
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: _rowH,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
          border:
              Border(right: BorderSide(color: Color(0xffEEEEEE), width: 0.8))),
      alignment: Alignment.centerLeft,
      child: child,
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
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ─── Pagination Bar ───────────────────────────────────────────────────────────

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({required this.model});
  final CompanyLeadsViewModel model;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text('Rows:',
                style: TextStyle(fontSize: 12, color: Color(0xff6B7280))),
            const SizedBox(width: 6),
            DropdownButton<int>(
              value: model.rowsPerPage,
              isDense: true,
              underline: const SizedBox.shrink(),
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xff374151),
                  fontWeight: FontWeight.w600),
              items: CompanyLeadsViewModel.rowsPerPageOptions
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                  .toList(),
              onChanged: (v) => model.setRowsPerPage(v!),
            ),
            const SizedBox(width: 12),
            Text(
              model.total == 0
                  ? '0'
                  : '${model.pageStart}–${model.pageEnd} of ${model.total}',
              style: const TextStyle(fontSize: 12, color: Color(0xff374151)),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 18),
              onPressed: model.hasPrev ? model.prevPage : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              color: model.hasPrev
                  ? const Color(0xff374151)
                  : const Color(0xffD1D5DB),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 18),
              onPressed: model.hasNext ? model.nextPage : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              color: model.hasNext
                  ? const Color(0xff374151)
                  : const Color(0xffD1D5DB),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Customize Columns Dialog ─────────────────────────────────────────────────

class _CustomizeColumnsDialog extends StatefulWidget {
  const _CustomizeColumnsDialog({required this.model});
  final CompanyLeadsViewModel model;

  @override
  State<_CustomizeColumnsDialog> createState() =>
      _CustomizeColumnsDialogState();
}

class _CustomizeColumnsDialogState extends State<_CustomizeColumnsDialog> {
  @override
  Widget build(BuildContext context) {
    final toggleable = CompanyLeadsViewModel.allColumns
        .where((c) => !c.alwaysVisible && c.key != 'action')
        .toList();
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(vertical: 24),
      title: const Text('Customize Columns',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () {
                      widget.model.setAllColumnsVisible(true);
                      setState(() {});
                    },
                    child:
                        const Text('Show All', style: TextStyle(fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: () {
                      widget.model.setAllColumnsVisible(false);
                      setState(() {});
                    },
                    child: const Text('Hide All',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xff6B7280))),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView(
                shrinkWrap: true,
                children: toggleable.map((col) {
                  final visible = widget.model.colVisible[col.key] ?? true;
                  return CheckboxListTile(
                    value: visible,
                    onChanged: (_) {
                      widget.model.toggleColumn(col.key);
                      setState(() {});
                    },
                    title:
                        Text(col.label, style: const TextStyle(fontSize: 13)),
                    activeColor: kCrmBlue,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('DONE'),
        ),
      ],
    );
  }
}

// ─── Lead Detail Modal ────────────────────────────────────────────────────────

class _LeadDetailModal extends StatefulWidget {
  const _LeadDetailModal({required this.item});
  final Map<String, dynamic> item;

  @override
  State<_LeadDetailModal> createState() => _LeadDetailModalState();
}

class _LeadDetailModalState extends State<_LeadDetailModal> {
  bool _leadDataExpanded = true;

  static const List<List<String>> _fields = [
    ['Lead Name', 'lead_name'],
    ['Full Name', 'full_name'],
    ['Email', 'email'],
    ['Phone', 'phone'],
    ['Source Type', 'source_type_name'],
    ['Interest Level', 'interest_level_name'],
    ['Lead Stage', 'lead_stage_name'],
    ['Category', 'category_name'],
    ['Assigned To', 'assigned_to_name'],
    ['Address', 'address'],
    ['City', 'city_name'],
    ['State', 'state_name'],
    ['Country', 'country_name'],
    ['Zip Code', 'zip_code'],
    ['Created On', 'created_at'],
    ['Notes', 'notes'],
  ];

  @override
  Widget build(BuildContext context) {
    final title = widget.item['lead_name']?.toString() ?? 'Lead Details';
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xffE5E7EB))),
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
                    icon: const Icon(Icons.close,
                        size: 20, color: Color(0xff6B7280)),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _DetailSection(
                      title: 'Lead Data',
                      expanded: _leadDataExpanded,
                      onToggle: () => setState(
                          () => _leadDataExpanded = !_leadDataExpanded),
                      child: Column(
                        children: _fields.map((f) {
                          final val = widget.item[f[1]]?.toString() ?? '-';
                          return _DetailRow(label: f[0], value: val);
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });
  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xffE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff1A1F36))),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xff6B7280),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, color: Color(0xffE5E7EB)),
            child,
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xffF3F4F6)))),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Color(0xff6B7280))),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, color: Color(0xff1A1F36))),
          ),
        ],
      ),
    );
  }
}

// ─── Add Lead Dialog ──────────────────────────────────────────────────────────

class _AddLeadDialog extends StatefulWidget {
  const _AddLeadDialog({required this.onSave});
  final Future<String?> Function(Map<String, dynamic>) onSave;

  @override
  State<_AddLeadDialog> createState() => _AddLeadDialogState();
}

class _AddLeadDialogState extends State<_AddLeadDialog> {
  final _api = locator<HippoAuthService>();
  final _formKey = GlobalKey<FormState>();
  final _leadNameCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _altPhoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _sourceType;
  String? _interestLevel;
  String? _leadStage;
  String? _category;
  String? _assignedTo;
  String? _country;
  String? _state;
  String? _city;

  // masters data
  List<Map<String, String>> _sourceTypes = [];
  List<Map<String, String>> _interestLevels = [];
  List<Map<String, String>> _leadStages = [];
  List<Map<String, String>> _categories = [];
  List<Map<String, String>> _countries = [];
  List<Map<String, dynamic>> _allStates = [];
  List<Map<String, dynamic>> _allCities = [];
  List<Map<String, String>> _employees = [];

  bool _loading = true;
  String? _loadError;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMasters();
  }

  static List<Map<String, String>> _toIdLabel(
      dynamic list, String idKey, String labelKey) {
    if (list is! List) return [];
    return list
        .map<Map<String, String>>((dynamic e) => {
              'id': (e as Map)[idKey]?.toString() ?? '',
              'label': e[labelKey]?.toString() ?? '',
            })
        .where((e) => e['id']!.isNotEmpty)
        .toList();
  }

  Future<void> _loadMasters() async {
    try {
      final results = await Future.wait<dynamic>([
        _api.getLeadMasters(),
        _api.getCountries(),
        _api.getStates(),
        _api.getCities(),
        _api.getEmployeesPaged(tab: 'active', rowsPerPage: 500),
      ]);
      if (!mounted) return;
      final masters = results[0] as Map<String, dynamic>;
      final countries = results[1] as List<Map<String, dynamic>>;
      final states = results[2] as List<Map<String, dynamic>>;
      final cities = results[3] as List<Map<String, dynamic>>;
      final empData = results[4] as Map<String, dynamic>;
      final empList = (empData['data'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      setState(() {
        _sourceTypes = _toIdLabel(masters['sourceType'], 'id', 'value');
        _interestLevels = _toIdLabel(masters['interestLevels'], 'id', 'value');
        _leadStages = _toIdLabel(masters['leadStages'], 'id', 'value');
        _categories = _toIdLabel(masters['categories'], 'id', 'value');
        _countries = countries
            .map<Map<String, String>>((e) => {
                  'id': e['id']?.toString() ?? '',
                  'label': e['name']?.toString() ?? '',
                })
            .where((e) => e['id']!.isNotEmpty)
            .toList();
        _allStates = states;
        _allCities = cities;
        _employees = empList
            .map<Map<String, String>>((e) => {
                  'id': e['id']?.toString() ?? '',
                  'label': e['employee_name']?.toString() ?? '',
                })
            .where((e) => e['id']!.isNotEmpty)
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<Map<String, String>> get _filteredStates {
    if (_country == null) return [];
    return _allStates
        .where((s) => s['country_id']?.toString() == _country)
        .map<Map<String, String>>((s) => {
              'id': s['id']?.toString() ?? '',
              'label': s['name']?.toString() ?? '',
            })
        .where((s) => s['id']!.isNotEmpty)
        .toList();
  }

  List<Map<String, String>> get _filteredCities {
    if (_state == null) return [];
    return _allCities
        .where((c) => c['state_id']?.toString() == _state)
        .map<Map<String, String>>((c) => {
              'id': c['id']?.toString() ?? '',
              'label': c['name']?.toString() ?? '',
            })
        .where((c) => c['id']!.isNotEmpty)
        .toList();
  }

  @override
  void dispose() {
    _leadNameCtrl.dispose();
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _altPhoneCtrl.dispose();
    _addressCtrl.dispose();
    _zipCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final data = {
      'leadName': _leadNameCtrl.text.trim(),
      'fullName': _fullNameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'alternateNumber': _altPhoneCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'zipCode': _zipCtrl.text.trim(),
      'notes': _notesCtrl.text.trim(),
      'sourceType': _sourceType,
      'interestLevel': _interestLevel,
      'leadStage': _leadStage,
      'category': _category,
      'assignedTo': _assignedTo,
      'country': _country,
      'state': _state,
      'city': _city,
    };
    final err = await widget.onSave(data);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _submitting = false;
        _error = err;
      });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xffE5E7EB))),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Add New Lead Details to Grow Your Pipeline',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kCrmBlue),
                    ),
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
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(color: kCrmBlue),
              )
            else if (_loadError != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(_loadError!,
                        style: const TextStyle(
                            color: Color(0xffDC2626), fontSize: 13),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _loading = true;
                          _loadError = null;
                        });
                        _loadMasters();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FormSection(
                          title: 'Lead Details',
                          child: _FormField(
                            controller: _leadNameCtrl,
                            label: 'Lead name',
                            required: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _FormSection(
                          title: 'Personal Details',
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _FormField(
                                      controller: _fullNameCtrl,
                                      label: 'Full Name',
                                      required: true,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _FormField(
                                      controller: _emailCtrl,
                                      label: 'Email',
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _FormField(
                                      controller: _phoneCtrl,
                                      label: 'Phone Number',
                                      required: true,
                                      keyboardType: TextInputType.phone,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _FormField(
                                      controller: _altPhoneCtrl,
                                      label: 'Alternate Number',
                                      keyboardType: TextInputType.phone,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _FormField(
                                controller: _addressCtrl,
                                label: 'Address',
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _DropdownField(
                                      label: 'Country',
                                      value: _country,
                                      items: _countries,
                                      onChanged: (v) => setState(() {
                                        _country = v;
                                        _state = null;
                                        _city = null;
                                      }),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _DropdownField(
                                      label: 'State',
                                      value: _state,
                                      items: _filteredStates,
                                      onChanged: (v) => setState(() {
                                        _state = v;
                                        _city = null;
                                      }),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _DropdownField(
                                      label: 'City',
                                      value: _city,
                                      items: _filteredCities,
                                      onChanged: (v) =>
                                          setState(() => _city = v),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _FormField(
                                      controller: _zipCtrl,
                                      label: 'Zip Code',
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _FormSection(
                          title: 'Lead Source Tracking',
                          child: _DropdownField(
                            label: 'Source Type',
                            value: _sourceType,
                            items: _sourceTypes,
                            onChanged: (v) => setState(() => _sourceType = v),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _FormSection(
                          title: 'Lead Status & Assignment',
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _DropdownField(
                                      label: 'Interest Level',
                                      value: _interestLevel,
                                      items: _interestLevels,
                                      onChanged: (v) =>
                                          setState(() => _interestLevel = v),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _DropdownField(
                                      label: 'Lead Stage',
                                      value: _leadStage,
                                      items: _leadStages,
                                      onChanged: (v) =>
                                          setState(() => _leadStage = v),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _DropdownField(
                                label: 'Category',
                                value: _category,
                                items: _categories,
                                onChanged: (v) => setState(() => _category = v),
                              ),
                              const SizedBox(height: 10),
                              _DropdownField(
                                label: 'Assigned To',
                                value: _assignedTo,
                                items: _employees,
                                onChanged: (v) =>
                                    setState(() => _assignedTo = v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _FormSection(
                          title: 'Notes and Comments',
                          child: TextFormField(
                            controller: _notesCtrl,
                            maxLines: 4,
                            decoration: _inputDeco('Notes'),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(_error!,
                              style: const TextStyle(
                                  color: Color(0xffDC2626), fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            if (!_loading)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xffE5E7EB))),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        (_submitting || _loadError != null) ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kCrmBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('SUBMIT LEAD',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Edit Lead Dialog ─────────────────────────────────────────────────────────

class _EditLeadDialog extends StatefulWidget {
  const _EditLeadDialog({required this.item, required this.onSave});
  final Map<String, dynamic> item;
  final Future<String?> Function(Map<String, dynamic>) onSave;

  @override
  State<_EditLeadDialog> createState() => _EditLeadDialogState();
}

class _EditLeadDialogState extends State<_EditLeadDialog> {
  final _api = locator<HippoAuthService>();
  final _formKey = GlobalKey<FormState>();
  final _leadNameCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _altPhoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _sourceType;
  String? _interestLevel;
  String? _leadStage;
  String? _category;
  String? _assignedTo;
  String? _country;
  String? _state;
  String? _city;

  List<Map<String, String>> _sourceTypes = [];
  List<Map<String, String>> _interestLevels = [];
  List<Map<String, String>> _leadStages = [];
  List<Map<String, String>> _categories = [];
  List<Map<String, String>> _countries = [];
  List<Map<String, dynamic>> _allStates = [];
  List<Map<String, dynamic>> _allCities = [];
  List<Map<String, String>> _employees = [];

  bool _loading = true;
  String? _loadError;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final d = widget.item;
    _leadNameCtrl.text = d['lead_name']?.toString() ?? '';
    _fullNameCtrl.text = d['full_name']?.toString() ?? '';
    _emailCtrl.text = d['email']?.toString() ?? '';
    _phoneCtrl.text = d['phone']?.toString() ?? '';
    _altPhoneCtrl.text = d['alternate_number']?.toString() ?? '';
    _addressCtrl.text = d['address']?.toString() ?? '';
    _zipCtrl.text = d['zip_code']?.toString() ?? '';
    _notesCtrl.text = d['notes']?.toString() ?? '';
    _loadMasters();
  }

  static List<Map<String, String>> _toIdLabel(
      dynamic list, String idKey, String labelKey) {
    if (list is! List) return [];
    return list
        .map<Map<String, String>>((dynamic e) => {
              'id': (e as Map)[idKey]?.toString() ?? '',
              'label': e[labelKey]?.toString() ?? '',
            })
        .where((e) => e['id']!.isNotEmpty)
        .toList();
  }

  Future<void> _loadMasters() async {
    try {
      final results = await Future.wait<dynamic>([
        _api.getLeadMasters(),
        _api.getCountries(),
        _api.getStates(),
        _api.getCities(),
        _api.getEmployeesPaged(tab: 'active', rowsPerPage: 500),
      ]);
      if (!mounted) return;
      final masters = results[0] as Map<String, dynamic>;
      final countries = results[1] as List<Map<String, dynamic>>;
      final states = results[2] as List<Map<String, dynamic>>;
      final cities = results[3] as List<Map<String, dynamic>>;
      final empData = results[4] as Map<String, dynamic>;
      final empList = (empData['data'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      final d = widget.item;
      setState(() {
        _sourceTypes = _toIdLabel(masters['sourceType'], 'id', 'value');
        _interestLevels = _toIdLabel(masters['interestLevels'], 'id', 'value');
        _leadStages = _toIdLabel(masters['leadStages'], 'id', 'value');
        _categories = _toIdLabel(masters['categories'], 'id', 'value');
        _countries = countries
            .map<Map<String, String>>((e) => {
                  'id': e['id']?.toString() ?? '',
                  'label': e['name']?.toString() ?? '',
                })
            .where((e) => e['id']!.isNotEmpty)
            .toList();
        _allStates = states;
        _allCities = cities;
        _employees = empList
            .map<Map<String, String>>((e) => {
                  'id': e['id']?.toString() ?? '',
                  'label': e['employee_name']?.toString() ?? '',
                })
            .where((e) => e['id']!.isNotEmpty)
            .toList();
        // pre-select existing values using IDs from the item
        _country = d['country']?.toString();
        _state = d['state']?.toString();
        _city = d['city']?.toString();
        _sourceType = d['source_type']?.toString();
        _interestLevel = d['interest_level']?.toString();
        _leadStage = d['lead_stage']?.toString();
        _category = d['category']?.toString();
        _assignedTo = d['assigned_to']?.toString();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<Map<String, String>> get _filteredStates {
    if (_country == null) return [];
    return _allStates
        .where((s) => s['country_id']?.toString() == _country)
        .map<Map<String, String>>((s) => {
              'id': s['id']?.toString() ?? '',
              'label': s['name']?.toString() ?? '',
            })
        .where((s) => s['id']!.isNotEmpty)
        .toList();
  }

  List<Map<String, String>> get _filteredCities {
    if (_state == null) return [];
    return _allCities
        .where((c) => c['state_id']?.toString() == _state)
        .map<Map<String, String>>((c) => {
              'id': c['id']?.toString() ?? '',
              'label': c['name']?.toString() ?? '',
            })
        .where((c) => c['id']!.isNotEmpty)
        .toList();
  }

  @override
  void dispose() {
    _leadNameCtrl.dispose();
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _altPhoneCtrl.dispose();
    _addressCtrl.dispose();
    _zipCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final data = {
      'leadName': _leadNameCtrl.text.trim(),
      'fullName': _fullNameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'alternateNumber': _altPhoneCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'zipCode': _zipCtrl.text.trim(),
      'notes': _notesCtrl.text.trim(),
      'sourceType': _sourceType,
      'interestLevel': _interestLevel,
      'leadStage': _leadStage,
      'category': _category,
      'assignedTo': _assignedTo,
      'country': _country,
      'state': _state,
      'city': _city,
    };
    final err = await widget.onSave(data);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _submitting = false;
        _error = err;
      });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xffE5E7EB))),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Edit Lead',
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
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(color: kCrmBlue),
              )
            else if (_loadError != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(_loadError!,
                        style: const TextStyle(
                            color: Color(0xffDC2626), fontSize: 13),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _loading = true;
                          _loadError = null;
                        });
                        _loadMasters();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FormSection(
                          title: 'Lead Details',
                          child: _FormField(
                            controller: _leadNameCtrl,
                            label: 'Lead name',
                            required: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _FormSection(
                          title: 'Personal Details',
                          child: Column(
                            children: [
                              Row(children: [
                                Expanded(
                                    child: _FormField(
                                        controller: _fullNameCtrl,
                                        label: 'Full Name',
                                        required: true)),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: _FormField(
                                        controller: _emailCtrl,
                                        label: 'Email',
                                        keyboardType:
                                            TextInputType.emailAddress)),
                              ]),
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                    child: _FormField(
                                        controller: _phoneCtrl,
                                        label: 'Phone Number',
                                        required: true,
                                        keyboardType: TextInputType.phone)),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: _FormField(
                                        controller: _altPhoneCtrl,
                                        label: 'Alternate Number',
                                        keyboardType: TextInputType.phone)),
                              ]),
                              const SizedBox(height: 10),
                              _FormField(
                                  controller: _addressCtrl, label: 'Address'),
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                  child: _DropdownField(
                                    label: 'Country',
                                    value: _country,
                                    items: _countries,
                                    onChanged: (v) => setState(() {
                                      _country = v;
                                      _state = null;
                                      _city = null;
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _DropdownField(
                                    label: 'State',
                                    value: _state,
                                    items: _filteredStates,
                                    onChanged: (v) => setState(() {
                                      _state = v;
                                      _city = null;
                                    }),
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                  child: _DropdownField(
                                    label: 'City',
                                    value: _city,
                                    items: _filteredCities,
                                    onChanged: (v) => setState(() => _city = v),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: _FormField(
                                        controller: _zipCtrl,
                                        label: 'Zip Code',
                                        keyboardType: TextInputType.number)),
                              ]),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _FormSection(
                          title: 'Lead Source Tracking',
                          child: _DropdownField(
                            label: 'Source Type',
                            value: _sourceType,
                            items: _sourceTypes,
                            onChanged: (v) => setState(() => _sourceType = v),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _FormSection(
                          title: 'Lead Status & Assignment',
                          child: Column(children: [
                            Row(children: [
                              Expanded(
                                child: _DropdownField(
                                  label: 'Interest Level',
                                  value: _interestLevel,
                                  items: _interestLevels,
                                  onChanged: (v) =>
                                      setState(() => _interestLevel = v),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _DropdownField(
                                  label: 'Lead Stage',
                                  value: _leadStage,
                                  items: _leadStages,
                                  onChanged: (v) =>
                                      setState(() => _leadStage = v),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 10),
                            _DropdownField(
                              label: 'Category',
                              value: _category,
                              items: _categories,
                              onChanged: (v) => setState(() => _category = v),
                            ),
                            const SizedBox(height: 10),
                            _DropdownField(
                              label: 'Assigned To',
                              value: _assignedTo,
                              items: _employees,
                              onChanged: (v) => setState(() => _assignedTo = v),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        _FormSection(
                          title: 'Notes and Comments',
                          child: TextFormField(
                            controller: _notesCtrl,
                            maxLines: 4,
                            decoration: _inputDeco('Notes'),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(_error!,
                              style: const TextStyle(
                                  color: Color(0xffDC2626), fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            if (!_loading)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xffE5E7EB))),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        (_submitting || _loadError != null) ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kCrmBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('UPDATE LEAD',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _inputDeco(String label, {bool required = false}) {
  return InputDecoration(
    hintText: required ? '$label *' : label,
    hintStyle: const TextStyle(fontSize: 13, color: Color(0xff9CA3AF)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xffD1D5DB))),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xffD1D5DB))),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kCrmBlue)),
    errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xffDC2626))),
    focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xffDC2626))),
    isDense: true,
  );
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xffE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff1A1F36))),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.label,
    this.required = false,
    this.keyboardType,
  });
  final TextEditingController controller;
  final String label;
  final bool required;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: _inputDeco(label, required: required),
      style: const TextStyle(fontSize: 13),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final String? value;
  final List<Map<String, String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final ids = items.map((e) => e['id']!).toList();
    return DropdownButtonFormField<String>(
      initialValue: ids.contains(value) ? value : null,
      decoration: _inputDeco(label),
      style: const TextStyle(fontSize: 13, color: Color(0xff374151)),
      hint: Text(label,
          style: const TextStyle(fontSize: 13, color: Color(0xff9CA3AF))),
      items: items
          .map((e) => DropdownMenuItem(
                value: e['id'],
                child: Text(e['label'] ?? '', overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: onChanged,
      isExpanded: true,
    );
  }
}

// ─── Follow-ups Tab ───────────────────────────────────────────────────────────

class _FollowupsTab extends StatefulWidget {
  const _FollowupsTab({required this.model});
  final CompanyLeadsViewModel model;

  @override
  State<_FollowupsTab> createState() => _FollowupsTabState();
}

class _FollowupsTabState extends State<_FollowupsTab> {
  final _searchCtrl = TextEditingController();
  final _hScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.model.followups.isEmpty && !widget.model.followupsBusy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.model.initFollowups();
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  Future<void> _downloadFollowupsCsv() async {
    try {
      final csv = widget.model.buildFollowupCsvContent();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/followups.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)],
          text: widget.model.followupHasSelection
              ? 'Follow-ups (${widget.model.followupSelectedCount} selected)'
              : 'All Follow-ups');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  void _showFollowupForm({Map<String, dynamic>? existing}) {
    final model = widget.model;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FollowupFormDialog(
        existing: existing,
        onSave: existing == null
            ? (data) => model.addFollowup(data)
            : (data) => model.updateFollowup(existing['id'], data),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> item) {
    final model = widget.model;
    final name = item['lead_name']?.toString() ?? 'this follow-up';
    final id = item['id'];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(vertical: 24),
        title: const Text('Delete Follow-up',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('Delete follow-up for "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final err = await model.deleteFollowup(id);
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

  void _showColumnsDialog() {
    showDialog(
      context: context,
      builder: (_) => _CustomizeFollowupColumnsDialog(model: widget.model),
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    if (model.followupsBusy) {
      return const Center(child: CircularProgressIndicator(color: kCrmBlue));
    }
    if (model.fetchFollowupsError != null) {
      return CrmErrorBody(
          error: model.fetchFollowupsError!, onRetry: model.initFollowups);
    }
    if (!model.canReadFollowup) {
      return const CrmEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Access Restricted',
        subtitle: 'You do not have permission to view follow-ups',
      );
    }
    return Column(
      children: [
        // ── Toolbar
        Container(
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
                    controller: _searchCtrl,
                    onChanged: model.searchFollowups,
                    decoration: InputDecoration(
                      hintText: 'Search follow-ups...',
                      hintStyle: const TextStyle(
                          color: Color(0xff9CA3AF), fontSize: 12),
                      prefixIcon: const Icon(Icons.search,
                          color: Color(0xff9CA3AF), size: 18),
                      suffixIcon: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _searchCtrl,
                        builder: (_, v, __) => v.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close,
                                    size: 16, color: Color(0xff9CA3AF)),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  model.searchFollowups('');
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
                        borderSide: const BorderSide(color: Color(0xffE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xffE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: kCrmBlue),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (model.canWriteFollowup) ...[
                  ElevatedButton.icon(
                    onPressed: () => _showFollowupForm(),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('ADD FOLLOW UPS',
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
                  const SizedBox(width: 6),
                ],
                _IconBtn(
                  icon: Icons.download_outlined,
                  tooltip: 'Export CSV',
                  onTap: _downloadFollowupsCsv,
                ),
                const SizedBox(width: 4),
                _IconBtn(
                  icon: Icons.view_column_outlined,
                  tooltip: 'Customize Columns',
                  onTap: _showColumnsDialog,
                ),
              ],
            ),
          ),
        ),
        // ── Selection bar
        if (model.followupHasSelection) _FollowupsSelectionBar(model: model),
        // ── Filter chips
        if (model.followupHasActiveFilters)
          _FollowupsFilterChipsBar(model: model),
        // ── Table
        Expanded(
          child: model.followups.isEmpty
              ? const CrmEmptyState(
                  icon: Icons.follow_the_signs_rounded,
                  title: 'No Follow-ups Found',
                  subtitle: 'Follow-ups will appear here',
                )
              : _FollowupsDataTable(
                  model: model,
                  hScroll: _hScroll,
                  canUpdate: model.canUpdateFollowup,
                  canDelete: model.canDeleteFollowup,
                  onEdit: (item) => _showFollowupForm(existing: item),
                  onDelete: _confirmDelete,
                  screenCtx: context,
                ),
        ),
        _FollowupsPaginationBar(model: model),
      ],
    );
  }
}

// ─── Followups selection bar ──────────────────────────────────────────────────

class _FollowupsSelectionBar extends StatelessWidget {
  const _FollowupsSelectionBar({required this.model});
  final CompanyLeadsViewModel model;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kCrmBlue.withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('${model.followupSelectedCount} selected',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: kCrmBlue)),
          const SizedBox(width: 8),
          const Flexible(
            child: Text('CSV will export selected only',
                style: TextStyle(fontSize: 12, color: Color(0xff6B7280)),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: model.clearFollowupSelection,
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
            child: const Text('Clear',
                style: TextStyle(fontSize: 12, color: kCrmBlue)),
          ),
        ],
      ),
    );
  }
}

// ─── Followups filter chips bar ───────────────────────────────────────────────

class _FollowupsFilterChipsBar extends StatelessWidget {
  const _FollowupsFilterChipsBar({required this.model});
  final CompanyLeadsViewModel model;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Row(
        children: [
          const Text('Filters:',
              style: TextStyle(fontSize: 12, color: Color(0xff6B7280))),
          const SizedBox(width: 6),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: model.followupColFilters.entries.map((e) {
                final col = CompanyLeadsViewModel.allFollowupColumns.firstWhere(
                    (c) => c.key == e.key,
                    orElse: () => FollowupColumnDef(e.key, e.key, 0));
                return Chip(
                  label: Text('${col.label}: ${e.value}',
                      style: const TextStyle(fontSize: 11)),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => model.setFollowupColFilter(e.key, ''),
                  backgroundColor: kCrmBlue.withValues(alpha: 0.08),
                  side: BorderSide(color: kCrmBlue.withValues(alpha: 0.3)),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ),
          TextButton(
            onPressed: model.clearAllFollowupFilters,
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
            child: const Text('Clear all',
                style: TextStyle(fontSize: 12, color: Color(0xffDC2626))),
          ),
        ],
      ),
    );
  }
}

// ─── Follow-ups data table ────────────────────────────────────────────────────

class _FollowupsDataTable extends StatelessWidget {
  const _FollowupsDataTable({
    required this.model,
    required this.hScroll,
    required this.canUpdate,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
    required this.screenCtx,
  });
  final CompanyLeadsViewModel model;
  final ScrollController hScroll;
  final bool canUpdate;
  final bool canDelete;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onDelete;
  final BuildContext screenCtx;

  static const double _headerH = 48.0;
  static const double _rowH = 52.0;

  @override
  Widget build(BuildContext context) {
    final cols = model.visibleFollowupColumns;
    final totalW = cols.fold(0.0, (s, c) => s + c.width);
    final rows = model.followups;

    return LayoutBuilder(builder: (_, constraints) {
      final w = totalW < constraints.maxWidth ? constraints.maxWidth : totalW;
      return Scrollbar(
        controller: hScroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: hScroll,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: w,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header
                Container(
                  height: _headerH,
                  decoration: const BoxDecoration(
                    color: Color(0xffF3F4F6),
                    border:
                        Border(bottom: BorderSide(color: Color(0xffE5E7EB))),
                  ),
                  child: Row(
                    children: cols
                        .map((col) => _FuHeaderCell(
                            col: col, model: model, screenCtx: screenCtx))
                        .toList(),
                  ),
                ),
                // ── Rows
                SizedBox(
                  height: constraints.maxHeight - _headerH,
                  child: ListView.builder(
                    itemCount: rows.length,
                    itemExtent: _rowH,
                    itemBuilder: (_, i) => _FollowupDataRow(
                      item: rows[i],
                      rowIndex: model.followupsPageStart + i,
                      cols: cols,
                      isEven: i % 2 == 0,
                      isSelected: model.followupIsSelected(rows[i]['id']),
                      canUpdate: canUpdate,
                      canDelete: canDelete,
                      onToggleSelect: () =>
                          model.toggleFollowupRowSelection(rows[i]['id']),
                      onEdit: () => onEdit(rows[i]),
                      onDelete: () => onDelete(rows[i]),
                    ),
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

// ─── Followup header cell ─────────────────────────────────────────────────────

class _FuHeaderCell extends StatelessWidget {
  const _FuHeaderCell(
      {required this.col, required this.model, required this.screenCtx});
  final FollowupColumnDef col;
  final CompanyLeadsViewModel model;
  final BuildContext screenCtx;

  static const _div = BorderSide(color: Color(0xffD1D5DB), width: 0.8);

  void _showFilterDialog() {
    showDialog(
      context: screenCtx,
      builder: (_) => _FuColFilterDialog(col: col, model: model),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (col.key == 'checkbox') {
      final allSel = model.allFollowupCurrentSelected;
      final someSel = model.someFollowupCurrentSelected;
      return Container(
        width: col.width,
        height: 48,
        decoration: const BoxDecoration(border: Border(right: _div)),
        child: Center(
          child: Checkbox(
            value: allSel
                ? true
                : someSel
                    ? null
                    : false,
            tristate: true,
            activeColor: kCrmBlue,
            onChanged: (_) => model.toggleFollowupSelectAll(),
          ),
        ),
      );
    }

    final isFiltered = model.followupColFilters.containsKey(col.key);
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

// ─── Followup column filter dialog ───────────────────────────────────────────

class _FuColFilterDialog extends StatefulWidget {
  const _FuColFilterDialog({required this.col, required this.model});
  final FollowupColumnDef col;
  final CompanyLeadsViewModel model;

  @override
  State<_FuColFilterDialog> createState() => _FuColFilterDialogState();
}

class _FuColFilterDialogState extends State<_FuColFilterDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.model.followupColFilters[widget.col.key] ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _apply() {
    widget.model.setFollowupColFilter(widget.col.key, _ctrl.text);
    Navigator.pop(context);
  }

  void _clear() {
    _ctrl.clear();
    widget.model.setFollowupColFilter(widget.col.key, '');
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

// ─── Followup data row ────────────────────────────────────────────────────────

class _FollowupDataRow extends StatelessWidget {
  const _FollowupDataRow({
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
  final List<FollowupColumnDef> cols;
  final bool isEven;
  final bool isSelected;
  final bool canUpdate;
  final bool canDelete;
  final VoidCallback onToggleSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const _div = BorderSide(color: Color(0xffEEEEEE), width: 0.8);

  Map<String, dynamic>? get _firstSvc {
    final raw = item['services'];
    if (raw == null) return null;
    try {
      List<dynamic> list;
      if (raw is List) {
        list = raw;
      } else {
        final s = raw.toString().trim();
        if (s.isEmpty || s == 'null' || s == '[]') return null;
        final decoded = jsonDecode(s);
        if (decoded is! List) return null;
        list = decoded;
      }
      if (list.isEmpty) return null;
      return Map<String, dynamic>.from(list[0] as Map);
    } catch (_) {
      return null;
    }
  }

  String _fmt(dynamic raw) {
    if (raw == null) return '—';
    final s = raw.toString();
    if (s.isEmpty || s == 'null') return '—';
    try {
      final dt = DateTime.parse(s);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return s.length > 10 ? s.substring(0, 10) : s;
    }
  }

  Widget _buildCell(FollowupColumnDef col) {
    final key = col.key;
    final width = col.width;

    if (key == 'checkbox') {
      return Container(
        width: width,
        height: 52,
        decoration: const BoxDecoration(border: Border(right: _div)),
        child: Center(
          child: Checkbox(
            value: isSelected,
            activeColor: kCrmBlue,
            onChanged: (_) => onToggleSelect(),
          ),
        ),
      );
    }

    if (key == 'action') {
      return SizedBox(
        width: width,
        height: 52,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (canUpdate)
              InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.edit_outlined, size: 18, color: kCrmBlue),
                ),
              ),
            if (canUpdate && canDelete) const SizedBox(width: 4),
            if (canDelete)
              InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline,
                      size: 18, color: Color(0xffDC2626)),
                ),
              ),
          ],
        ),
      );
    }

    String val;
    Color? color;
    FontWeight fw = FontWeight.normal;

    if (key == 'sno') {
      val = '${item['id'] ?? rowIndex}';
      color = const Color(0xff6B7280);
    } else if (key == 'lead_name') {
      val = item['lead_name']?.toString() ?? '—';
      fw = FontWeight.w600;
      color = kCrmBlue;
    } else if (key == 'employee_name') {
      val = item['employee_name']?.toString() ?? '—';
    } else if (key == 'status') {
      val = item['status']?.toString() ?? '—';
      if (val != '—') {
        color = const Color(0xff3B82F6);
        fw = FontWeight.w600;
      }
    } else if (key == 'svc_name') {
      val = _firstSvc?['service_name']?.toString() ?? '—';
    } else if (key == 'svc_duration') {
      val = _firstSvc?['duration']?.toString() ?? '—';
    } else if (key == 'svc_base_price') {
      final bp = _firstSvc?['base_price'];
      val = bp != null ? '₹$bp' : '—';
      color = bp != null ? const Color(0xff166534) : null;
      fw = bp != null ? FontWeight.w600 : FontWeight.normal;
    } else if (key == 'svc_tax_rate') {
      final tr = _firstSvc?['tax_rate'];
      val = tr != null ? '$tr%' : '—';
    } else if (key == 'svc_original_duration') {
      val = _firstSvc?['original_duration']?.toString() ?? '—';
    } else if (key == 'nextFollowUpDate') {
      val = _fmt(item['nextFollowUpDate']);
    } else if (key == 'created_at') {
      val = _fmt(item['created_at']);
    } else if (key == 'wantAddServices') {
      val = item['wantAddServices']?.toString() ?? '—';
      if (val.toLowerCase() == 'yes') {
        color = const Color(0xff16A34A);
        fw = FontWeight.w600;
      }
    } else if (key == 'negotiate') {
      val = item['negotiate']?.toString() ?? '—';
      if (val.toLowerCase() == 'yes') {
        color = const Color(0xff16A34A);
        fw = FontWeight.w600;
      }
    } else if (key == 'quotation_title') {
      val = item['quotation_title']?.toString() ?? '—';
    } else if (key == 'notes') {
      final n = item['notes']?.toString() ?? '';
      val = n.trim().isEmpty ? 'Not mentioned' : n;
      if (n.trim().isEmpty) color = const Color(0xff9CA3AF);
    } else {
      val = item[key]?.toString() ?? '—';
    }

    return Container(
      width: width,
      height: 52,
      decoration: const BoxDecoration(border: Border(right: _div)),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          val,
          style: TextStyle(
              fontSize: 12,
              color: color ?? const Color(0xff374151),
              fontWeight: fw),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
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
      child: Row(children: cols.map(_buildCell).toList()),
    );
  }
}

// ─── Customize followup columns dialog ───────────────────────────────────────

class _CustomizeFollowupColumnsDialog extends StatefulWidget {
  const _CustomizeFollowupColumnsDialog({required this.model});
  final CompanyLeadsViewModel model;

  @override
  State<_CustomizeFollowupColumnsDialog> createState() =>
      _CustomizeFollowupColumnsDialogState();
}

class _CustomizeFollowupColumnsDialogState
    extends State<_CustomizeFollowupColumnsDialog> {
  @override
  Widget build(BuildContext context) {
    final toggleable = CompanyLeadsViewModel.allFollowupColumns
        .where((c) => !c.alwaysVisible && c.key != 'action')
        .toList();
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(vertical: 24),
      title: const Text('Customize Columns',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () {
                      widget.model.setAllFollowupColumnsVisible(true);
                      setState(() {});
                    },
                    child:
                        const Text('Show All', style: TextStyle(fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: () {
                      widget.model.setAllFollowupColumnsVisible(false);
                      setState(() {});
                    },
                    child: const Text('Hide All',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xff6B7280))),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView(
                shrinkWrap: true,
                children: toggleable.map((col) {
                  final visible =
                      widget.model.followupColVisible[col.key] ?? true;
                  return CheckboxListTile(
                    value: visible,
                    onChanged: (_) {
                      widget.model.toggleFollowupColumn(col.key);
                      setState(() {});
                    },
                    title:
                        Text(col.label, style: const TextStyle(fontSize: 13)),
                    activeColor: kCrmBlue,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('DONE'),
        ),
      ],
    );
  }
}

// ─── Follow-ups pagination bar ────────────────────────────────────────────────

class _FollowupsPaginationBar extends StatelessWidget {
  const _FollowupsPaginationBar({required this.model});
  final CompanyLeadsViewModel model;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text('Rows:',
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
                value: model.followupsRowsPerPage,
                underline: const SizedBox.shrink(),
                isDense: true,
                items: CompanyLeadsViewModel.rowsPerPageOptions
                    .map((n) => DropdownMenuItem(
                        value: n,
                        child:
                            Text('$n', style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (v) {
                  if (v != null) model.setFollowupsRowsPerPage(v);
                },
              ),
            ),
            const SizedBox(width: 12),
            Text(
              model.followupsTotal == 0
                  ? '0'
                  : '${model.followupsPageStart}–${model.followupsPageEnd} of ${model.followupsTotal}',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff1A1F36)),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              iconSize: 20,
              color:
                  model.followupsHasPrev ? kCrmBlue : const Color(0xffD1D5DB),
              onPressed:
                  model.followupsHasPrev ? model.prevFollowupsPage : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              iconSize: 20,
              color:
                  model.followupsHasNext ? kCrmBlue : const Color(0xffD1D5DB),
              onPressed:
                  model.followupsHasNext ? model.nextFollowupsPage : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Service row model ────────────────────────────────────────────────────────

class _SvcRow {
  final Map<String, dynamic> product;
  String optedDuration;
  DateTime? startDate;
  DateTime? endDate;

  _SvcRow(this.product) : optedDuration = product['duration']?.toString() ?? '';

  double get basePrice =>
      double.tryParse(product['base_price']?.toString() ?? '0') ?? 0;
  double get taxRate =>
      double.tryParse(product['tax_rate']?.toString() ?? '0') ?? 0;
  double get taxableAmount => basePrice;
  double get taxAmount =>
      double.parse((taxableAmount * taxRate / 100).toStringAsFixed(2));
  double get totalAmount => taxableAmount + taxAmount;
}

// ─── Date picker cell ─────────────────────────────────────────────────────────

class _DateCell extends StatelessWidget {
  const _DateCell(
      {required this.date, required this.hint, required this.onPicked});
  final DateTime? date;
  final String hint;
  final ValueChanged<DateTime> onPicked;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
                colorScheme: const ColorScheme.light(primary: kCrmBlue)),
            child: child!,
          ),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xffD1D5DB)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              date == null
                  ? hint
                  : '${date!.day.toString().padLeft(2, '0')}/'
                      '${date!.month.toString().padLeft(2, '0')}/'
                      '${date!.year}',
              style: TextStyle(
                  fontSize: 11,
                  color: date == null
                      ? const Color(0xff9CA3AF)
                      : const Color(0xff374151)),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.calendar_today_outlined,
                size: 12, color: Color(0xff6B7280)),
          ],
        ),
      ),
    );
  }
}

// ─── Followup Form Dialog (Add & Edit) ───────────────────────────────────────

class _FollowupFormDialog extends StatefulWidget {
  const _FollowupFormDialog({required this.onSave, this.existing});
  final Future<String?> Function(Map<String, dynamic>) onSave;
  final Map<String, dynamic>? existing;

  @override
  State<_FollowupFormDialog> createState() => _FollowupFormDialogState();
}

class _FollowupFormDialogState extends State<_FollowupFormDialog> {
  final _api = locator<HippoAuthService>();
  final _roundOffCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();

  bool _loading = true;
  String? _loadError;
  bool _submitting = false;
  String? _error;

  List<Map<String, dynamic>> _allLeads = [];
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, String>> _leadStages = [];
  List<Map<String, String>> _quotations = [];

  Map<String, dynamic>? _selectedLead;
  String? _assignedToName;
  bool _wantAddServices = false;
  final List<_SvcRow> _services = [];
  bool _negotiate = false;
  String _taxOption = 'including';
  String? _statusId;
  DateTime? _nextFollowUpDate;
  String? _quotationId;
  String? _quotationTitle;

  @override
  void initState() {
    super.initState();
    final d = widget.existing;
    if (d != null) {
      _notesCtrl.text = d['notes']?.toString() ?? '';
      _wantAddServices =
          d['wantAddServices']?.toString().toLowerCase() == 'yes';
      _negotiate = d['negotiate']?.toString().toLowerCase() == 'yes';
      _taxOption = d['taxOption']?.toString() ?? 'including';
      _roundOffCtrl.text = d['roundOff']?.toString() ?? '0';
      _statusId = d['status_id']?.toString() ?? d['status']?.toString();
      _quotationId = d['quotationId']?.toString();
      _quotationTitle = d['quotation_title']?.toString();
      final nfd = d['nextFollowUpDate']?.toString();
      if (nfd != null && nfd.isNotEmpty && nfd != 'null') {
        try {
          _nextFollowUpDate = DateTime.parse(nfd);
        } catch (_) {}
      }
    }
    _loadMasters();
  }

  static List<Map<String, String>> _toIdLabel(
      dynamic list, String idKey, String labelKey) {
    if (list is! List) return [];
    return list
        .map<Map<String, String>>((dynamic e) => {
              'id': (e as Map)[idKey]?.toString() ?? '',
              'label': e[labelKey]?.toString() ?? '',
            })
        .where((e) => e['id']!.isNotEmpty)
        .toList();
  }

  Future<void> _loadMasters() async {
    try {
      final results = await Future.wait<dynamic>([
        _api.getLeads(pipeline: 'pipeline'),
        _api.getLeadMasters(),
        _api.getProductsPaged(rowsPerPage: 500),
        _api.getQuoteMasters(),
      ]);
      if (!mounted) return;
      final leads = results[0] as List<Map<String, dynamic>>;
      final masters = results[1] as Map<String, dynamic>;
      final productsData = results[2] as Map<String, dynamic>;
      final quoteMasters = results[3] as Map<String, dynamic>;

      final products = (productsData['data'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];

      setState(() {
        _allLeads = leads;
        _allProducts = products;
        _leadStages = _toIdLabel(masters['leadStages'], 'id', 'value');
        _quotations =
            _toIdLabel(quoteMasters['followupQuotations'], 'id', 'title');

        final d = widget.existing;
        if (d != null) {
          final leadId = d['leadId']?.toString() ?? d['leadid']?.toString();
          if (leadId != null) {
            try {
              _selectedLead =
                  _allLeads.firstWhere((l) => l['id']?.toString() == leadId);
            } catch (_) {
              _selectedLead = {
                'id': leadId,
                'lead_name': d['lead_name'] ?? '',
                'phone': ''
              };
            }
            _assignedToName = d['employee_name']?.toString() ?? '';
          }
          if (_wantAddServices) {
            final raw = d['services'];
            if (raw != null) {
              try {
                final list =
                    raw is List ? raw : jsonDecode(raw.toString()) as List;
                for (final s in list) {
                  final sm = Map<String, dynamic>.from(s as Map);
                  Map<String, dynamic> prod;
                  try {
                    prod = _allProducts.firstWhere(
                        (p) => p['id']?.toString() == sm['id']?.toString());
                  } catch (_) {
                    prod = sm;
                  }
                  final row = _SvcRow(prod);
                  row.optedDuration =
                      sm['duration']?.toString() ?? row.optedDuration;
                  final sd = sm['start_date']?.toString();
                  final ed = sm['end_date']?.toString();
                  if (sd != null && sd.isNotEmpty && sd != 'null') {
                    try {
                      row.startDate = DateTime.parse(sd);
                    } catch (_) {}
                  }
                  if (ed != null && ed.isNotEmpty && ed != 'null') {
                    try {
                      row.endDate = DateTime.parse(ed);
                    } catch (_) {}
                  }
                  _services.add(row);
                }
              } catch (_) {}
            }
          }
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _addService(Map<String, dynamic> product) {
    if (_services
        .any((s) => s.product['id']?.toString() == product['id']?.toString())) {
      return;
    }
    setState(() => _services.add(_SvcRow(product)));
  }

  void _removeService(int index) => setState(() => _services.removeAt(index));

  double get _totalTaxable => _services.fold(0, (s, r) => s + r.taxableAmount);
  double get _totalTax => _services.fold(0, (s, r) => s + r.taxAmount);
  double get _grandTotal => _totalTaxable + _totalTax;
  double get _roundOffValue => double.tryParse(_roundOffCtrl.text) ?? 0;
  double get _amountToPay => _grandTotal - _roundOffValue;

  String _fm(double v) => v.toStringAsFixed(2);
  String _fd(DateTime? d) => d == null
      ? ''
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (_selectedLead == null) {
      setState(() => _error = 'Please select a lead');
      return;
    }
    if (_statusId == null) {
      setState(() => _error = 'Please select a status');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });

    final now = DateTime.now();
    final svcs = _services
        .map((r) => {
              'id': r.product['id'],
              'service_name': r.product['service_name'] ?? r.product['name'],
              'duration': r.optedDuration,
              'original_duration': r.product['duration'],
              'base_price': r.basePrice,
              'taxable_amount': r.taxableAmount,
              'tax_rate': r.taxRate,
              'tax_amount': r.taxAmount,
              'total_amount': r.totalAmount,
              'start_date': _fd(r.startDate),
              'end_date': _fd(r.endDate),
            })
        .toList();

    final revisedAmounts = _negotiate
        ? [
            {'description': 'Original Taxable Amount', 'amount': _totalTaxable},
            {'description': 'Original Tax Amount', 'amount': _totalTax},
            {'description': 'Original Total Amount', 'amount': _grandTotal},
            {'description': 'Revised Taxable Amount', 'amount': _totalTaxable},
            {'description': 'Revised Tax Amount', 'amount': _totalTax},
            {'description': 'Final Total Amount', 'amount': _amountToPay},
          ]
        : <Map<String, dynamic>>[];

    final data = {
      'leadId': _selectedLead!['id'],
      'followUpDate': _fd(now),
      'followUpTime': '',
      'assignedTo': _selectedLead!['assigned_to'],
      'status': _statusId,
      'notes': _notesCtrl.text.trim(),
      'nextFollowUpDate': _fd(_nextFollowUpDate),
      'services': svcs,
      'discount': 0,
      'negotiate': _negotiate ? 'Yes' : 'No',
      'wantAddServices': _wantAddServices ? 'Yes' : 'No',
      'taxOption': _taxOption,
      'roundOff': _roundOffValue,
      'original_taxableAmount': _totalTaxable,
      'original_taxAmount': _totalTax,
      'original_totalAmount': _grandTotal,
      'revised_taxableAmount': _totalTaxable,
      'revised_taxAmount': _totalTax,
      'revised_totalAmount': _amountToPay.toString(),
      'revisedAmounts': revisedAmounts,
      'quotationId': _quotationId,
      'quotationTitle': _quotationTitle,
    };

    final err = await widget.onSave(data);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _submitting = false;
        _error = err;
      });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _roundOffCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(isEdit
                ? 'Edit Follow-up Details'
                : 'Add New Follow-up Details'),
            if (_loading)
              const Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(color: kCrmBlue))
            else if (_loadError != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  Text(_loadError!,
                      style: const TextStyle(
                          color: Color(0xffDC2626), fontSize: 13),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _loading = true;
                        _loadError = null;
                      });
                      _loadMasters();
                    },
                    child: const Text('Retry'),
                  ),
                ]),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _card('Follow-up Details', _buildLeadSection()),
                      const SizedBox(height: 12),
                      _card('Products & Negotiation', _buildProductsSection()),
                      const SizedBox(height: 12),
                      _card('Follow-up Information', _buildInfoSection()),
                      const SizedBox(height: 12),
                      _card('Quotation Selection', _buildQuotationSection()),
                      const SizedBox(height: 12),
                      _card(
                          'Notes and Comments',
                          TextFormField(
                            controller: _notesCtrl,
                            maxLines: 4,
                            decoration: _inputDeco('Notes'),
                            style: const TextStyle(fontSize: 13),
                          )),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(_error!,
                            style: const TextStyle(
                                color: Color(0xffDC2626), fontSize: 12)),
                      ],
                    ],
                  ),
                ),
              ),
            if (!_loading)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xffE5E7EB)))),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        (_submitting || _loadError != null) ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kCrmBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(isEdit ? 'UPDATE FOLLOW-UP' : 'SAVE FOLLOW-UP',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String title) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xffE5E7EB)))),
        child: Row(children: [
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kCrmBlue))),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: Color(0xff6B7280)),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ]),
      );

  Widget _card(String title, Widget child) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xffE5E7EB)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff1A1F36))),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );

  Widget _buildLeadSection() {
    final displayText = _selectedLead == null
        ? ''
        : '${_selectedLead!['lead_name']} (${_selectedLead!['phone'] ?? ''})';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Autocomplete<Map<String, dynamic>>(
        initialValue: TextEditingValue(text: displayText),
        displayStringForOption: (o) =>
            '${o['lead_name']} (${o['phone'] ?? ''})',
        optionsBuilder: (tv) {
          if (tv.text.isEmpty) return _allLeads.take(20);
          final q = tv.text.toLowerCase();
          return _allLeads.where((l) =>
              (l['lead_name'] ?? '').toString().toLowerCase().contains(q) ||
              (l['phone'] ?? '').toString().contains(q));
        },
        onSelected: (opt) => setState(() {
          _selectedLead = opt;
          _assignedToName = opt['assigned_to_name']?.toString() ?? '';
        }),
        fieldViewBuilder: (ctx, ctrl, focus, onSub) => TextFormField(
          controller: ctrl,
          focusNode: focus,
          onFieldSubmitted: (_) => onSub(),
          decoration:
              _inputDeco('Search Lead by Name or Mobile', required: true),
          style: const TextStyle(fontSize: 13),
        ),
        optionsViewBuilder: (ctx, onSel, opts) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 560,
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: opts
                    .map((o) => ListTile(
                          dense: true,
                          title: Text('${o['lead_name']} (${o['phone'] ?? ''})',
                              style: const TextStyle(fontSize: 13)),
                          onTap: () => onSel(o),
                        ))
                    .toList(),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      TextFormField(
        readOnly: true,
        controller: TextEditingController(text: _assignedToName ?? ''),
        decoration: _inputDeco('Assigned To'),
        style: const TextStyle(fontSize: 13),
      ),
    ]);
  }

  Widget _buildProductsSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Do you want to add Products?',
          style: TextStyle(fontSize: 13, color: Color(0xff374151))),
      const SizedBox(height: 6),
      Row(children: [
        Radio<bool>(
            value: true,
            groupValue: _wantAddServices,
            activeColor: kCrmBlue,
            onChanged: (_) => setState(() => _wantAddServices = true)),
        const Text('Yes', style: TextStyle(fontSize: 13)),
        const SizedBox(width: 16),
        Radio<bool>(
            value: false,
            groupValue: _wantAddServices,
            activeColor: kCrmBlue,
            onChanged: (_) => setState(() {
                  _wantAddServices = false;
                  _services.clear();
                })),
        const Text('No', style: TextStyle(fontSize: 13)),
      ]),
      if (_wantAddServices) ...[
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: null,
          decoration: _inputDeco('Select Products'),
          hint: const Text('Select Products',
              style: TextStyle(fontSize: 13, color: Color(0xff9CA3AF))),
          style: const TextStyle(fontSize: 13, color: Color(0xff374151)),
          isExpanded: true,
          items: _allProducts
              .map((p) => DropdownMenuItem(
                    value: p['id']?.toString(),
                    child: Text(
                        p['service_name']?.toString() ??
                            p['name']?.toString() ??
                            '',
                        overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            try {
              final p =
                  _allProducts.firstWhere((e) => e['id']?.toString() == v);
              _addService(p);
            } catch (_) {}
          },
        ),
        if (_services.isNotEmpty) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 36,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 56,
              columnSpacing: 10,
              headingTextStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff374151)),
              dataTextStyle:
                  const TextStyle(fontSize: 12, color: Color(0xff374151)),
              columns: const [
                DataColumn(label: Text('S.No')),
                DataColumn(label: Text('Product')),
                DataColumn(label: Text('Orig.Dur')),
                DataColumn(label: Text('Opted Dur')),
                DataColumn(label: Text('Base Price')),
                DataColumn(label: Text('Tax%')),
                DataColumn(label: Text('Tax Amt')),
                DataColumn(label: Text('Total')),
                DataColumn(label: Text('Start')),
                DataColumn(label: Text('End')),
                DataColumn(label: Text('')),
              ],
              rows: _services.asMap().entries.map((e) {
                final i = e.key;
                final r = e.value;
                return DataRow(cells: [
                  DataCell(Text('${i + 1}')),
                  DataCell(SizedBox(
                    width: 110,
                    child: Text(
                      r.product['service_name']?.toString() ??
                          r.product['name']?.toString() ??
                          '',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  )),
                  DataCell(Text(r.product['duration']?.toString() ?? '—')),
                  DataCell(SizedBox(
                    width: 70,
                    child: TextField(
                      controller: TextEditingController(text: r.optedDuration),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(fontSize: 12),
                      onChanged: (v) => r.optedDuration = v,
                    ),
                  )),
                  DataCell(Text('₹${_fm(r.basePrice)}')),
                  DataCell(Text('${r.taxRate}%')),
                  DataCell(Text('₹${_fm(r.taxAmount)}')),
                  DataCell(Text('₹${_fm(r.totalAmount)}')),
                  DataCell(_DateCell(
                    date: r.startDate,
                    hint: 'Start',
                    onPicked: (d) => setState(() => r.startDate = d),
                  )),
                  DataCell(_DateCell(
                    date: r.endDate,
                    hint: 'End',
                    onPicked: (d) => setState(() => r.endDate = d),
                  )),
                  DataCell(IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Color(0xffDC2626), size: 18),
                    onPressed: () => _removeService(i),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )),
                ]);
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Taxable Amount: ₹${_fm(_totalTaxable)}',
                  style: const TextStyle(fontSize: 12)),
              Text('Tax Amount: ₹${_fm(_totalTax)}',
                  style: const TextStyle(fontSize: 12)),
              Text('Grand Total: ₹${_fm(_grandTotal)}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 12),
          _buildNegotiateSection(),
        ],
      ],
    ]);
  }

  Widget _buildNegotiateSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xffF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffE5E7EB)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Do you want to negotiate?',
              style: TextStyle(
                  fontSize: 13, color: kCrmBlue, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          const Text('Tax Option',
              style: TextStyle(fontSize: 13, color: Color(0xff374151))),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 4, children: [
          Radio<bool>(
              value: true,
              groupValue: _negotiate,
              activeColor: kCrmBlue,
              onChanged: (_) => setState(() => _negotiate = true)),
          const Text('Yes', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          Radio<bool>(
              value: false,
              groupValue: _negotiate,
              activeColor: kCrmBlue,
              onChanged: (_) => setState(() {
                    _negotiate = false;
                    _roundOffCtrl.text = '0';
                  })),
          const Text('No', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 16),
          Radio<String>(
              value: 'including',
              groupValue: _taxOption,
              activeColor: kCrmBlue,
              onChanged: (v) => setState(() => _taxOption = v!)),
          const Text('Including Tax', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          Radio<String>(
              value: 'excluding',
              groupValue: _taxOption,
              activeColor: kCrmBlue,
              onChanged: (v) => setState(() => _taxOption = v!)),
          const Text('Excluding Tax', style: TextStyle(fontSize: 13)),
        ]),
        if (_negotiate) ...[
          const SizedBox(height: 10),
          Row(children: [
            SizedBox(
              width: 140,
              child: TextField(
                controller: _roundOffCtrl,
                keyboardType: TextInputType.number,
                decoration: _inputDeco('Round Off Amount'),
                style: const TextStyle(fontSize: 13),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text('Amount to Pay: ₹${_fm(_amountToPay)}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 10),
          Table(
            border: TableBorder.all(color: const Color(0xffE5E7EB)),
            columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
            children: [
              _tRow('Description', 'Amount', header: true),
              _tRow('Original Taxable Amount', '₹${_fm(_totalTaxable)}'),
              _tRow('Original Tax Amount', '₹${_fm(_totalTax)}'),
              _tRow('Original Total Amount', '₹${_fm(_grandTotal)}'),
              _tRow('Revised Taxable Amount', '₹${_fm(_totalTaxable)}'),
              _tRow('Revised Tax Amount', '₹${_fm(_totalTax)}'),
              _tRow('Final Total Amount', '₹${_fm(_amountToPay)}', bold: true),
            ],
          ),
        ],
      ]),
    );
  }

  TableRow _tRow(String a, String b, {bool header = false, bool bold = false}) {
    final fw = (header || bold) ? FontWeight.w600 : FontWeight.normal;
    return TableRow(
      decoration: header ? const BoxDecoration(color: Color(0xffF3F4F6)) : null,
      children: [
        Padding(
            padding: const EdgeInsets.all(8),
            child: Text(a, style: TextStyle(fontSize: 12, fontWeight: fw))),
        Padding(
            padding: const EdgeInsets.all(8),
            child: Text(b,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, fontWeight: fw))),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Row(children: [
      Expanded(
        child: DropdownButtonFormField<String>(
          value:
              _leadStages.any((s) => s['id'] == _statusId) ? _statusId : null,
          decoration: _inputDeco('Status'),
          hint: const Text('Status *',
              style: TextStyle(fontSize: 13, color: Color(0xff9CA3AF))),
          style: const TextStyle(fontSize: 13, color: Color(0xff374151)),
          isExpanded: true,
          items: _leadStages
              .map((s) => DropdownMenuItem(
                    value: s['id'],
                    child:
                        Text(s['label'] ?? '', overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _statusId = v),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _nextFollowUpDate ??
                  DateTime.now().add(const Duration(days: 1)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.light(primary: kCrmBlue)),
                child: child!,
              ),
            );
            if (picked != null) setState(() => _nextFollowUpDate = picked);
          },
          child: InputDecorator(
            decoration: _inputDeco('Next Follow-up Date'),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _nextFollowUpDate == null
                        ? 'Select date'
                        : '${_nextFollowUpDate!.day.toString().padLeft(2, '0')}/'
                            '${_nextFollowUpDate!.month.toString().padLeft(2, '0')}/'
                            '${_nextFollowUpDate!.year}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: _nextFollowUpDate == null
                          ? const Color(0xff9CA3AF)
                          : const Color(0xff374151),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: Color(0xff6B7280)),
              ],
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildQuotationSection() {
    return DropdownButtonFormField<String>(
      value:
          _quotations.any((q) => q['id'] == _quotationId) ? _quotationId : null,
      decoration: _inputDeco('Select Quotation'),
      hint: const Text('Select Quotation',
          style: TextStyle(fontSize: 13, color: Color(0xff9CA3AF))),
      style: const TextStyle(fontSize: 13, color: Color(0xff374151)),
      isExpanded: true,
      items: _quotations
          .map((q) => DropdownMenuItem(
                value: q['id'],
                child: Text(q['label'] ?? '', overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (v) {
        final q = _quotations.firstWhere((e) => e['id'] == v, orElse: () => {});
        setState(() {
          _quotationId = v;
          _quotationTitle = q['label'];
        });
      },
    );
  }
}
