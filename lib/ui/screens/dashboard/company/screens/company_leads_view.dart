import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stacked/stacked.dart';

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
                              _LeadsTab(
                                  model: model, searchCtrl: _searchCtrl),
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

  void _showColumnsDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => _CustomizeColumnsDialog(model: model),
    );
  }

  Future<void> _confirmDelete(BuildContext ctx, Map<String, dynamic> item) async {
    final name = item['lead_name']?.toString() ?? 'this lead';
    final id = item['id'];
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Delete Lead', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        content: Text('Delete "$name"? This action cannot be undone.',
            style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCEL', style: TextStyle(color: Color(0xff6B7280)))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffDC2626), foregroundColor: Colors.white),
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
    return Column(
      children: [
        _Toolbar(
          model: model,
          searchCtrl: searchCtrl,
          onAdd: model.canWrite ? () => _showAddDialog(context) : null,
          onColumns: () => _showColumnsDialog(context),
        ),
        if (model.hasSelection)
          _SelectionBar(model: model),
        if (model.hasActiveFilters)
          _FilterChipsBar(model: model),
        Expanded(
          child: model.items.isEmpty && !model.hasActiveFilters && searchCtrl.text.isEmpty
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
                      canDelete: model.canDelete,
                      onRowTap: (item) => _showDetailModal(context, item),
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
  });
  final CompanyLeadsViewModel model;
  final TextEditingController searchCtrl;
  final VoidCallback? onAdd;
  final VoidCallback onColumns;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: searchCtrl,
                onChanged: model.searchLeads,
                decoration: InputDecoration(
                  hintText: 'Search by Lead Name, Email, or City...',
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
                    borderSide:
                        const BorderSide(color: Color(0xffE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Color(0xffE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: kCrmBlue),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _PipelineDropdown(model: model),
          const SizedBox(width: 8),
          if (onAdd != null)
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('ADD LEAD',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: kCrmBlue,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 6),
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
            icon: Icons.upload_outlined,
            tooltip: 'Bulk Import',
            onTap: () {},
          ),
          const SizedBox(width: 4),
          _IconBtn(
            icon: Icons.view_column_outlined,
            tooltip: 'Customize Columns',
            onTap: onColumns,
          ),
        ],
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
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kCrmBlue)),
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
                final col = CompanyLeadsViewModel.allColumns
                    .firstWhere((c) => c.key == e.key,
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
    required this.canDelete,
    required this.onRowTap,
    required this.onDelete,
  });
  final CompanyLeadsViewModel model;
  final bool canDelete;
  final void Function(Map<String, dynamic>) onRowTap;
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
                        canDelete: canDelete,
                        onToggleSelect: () => model.toggleRowSelection(id),
                        onTap: () => onRowTap(item),
                        onEdit: () {},
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

// ─── Data Row ─────────────────────────────────────────────────────────────────

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.item,
    required this.rowIndex,
    required this.cols,
    required this.isEven,
    required this.isSelected,
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
  final bool canDelete;
  final VoidCallback onToggleSelect;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const _cellDivider =
      BorderSide(color: Color(0xffEEEEEE), width: 0.8);

  Widget _buildCell(LeadColumnDef col) {
    switch (col.key) {
      case 'checkbox':
        return Container(
          width: col.width,
          height: _rowH,
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
          decoration:
              const BoxDecoration(border: Border(right: _cellDivider)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
          border: Border(
              right: BorderSide(color: Color(0xffEEEEEE), width: 0.8))),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Text('Rows per page:',
              style: TextStyle(fontSize: 12, color: Color(0xff6B7280))),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: model.rowsPerPage,
            isDense: true,
            underline: const SizedBox.shrink(),
            style: const TextStyle(
                fontSize: 12,
                color: Color(0xff374151),
                fontWeight: FontWeight.w600),
            items: CompanyLeadsViewModel.rowsPerPageOptions
                .map((v) => DropdownMenuItem(
                    value: v, child: Text('$v')))
                .toList(),
            onChanged: (v) => model.setRowsPerPage(v!),
          ),
          const SizedBox(width: 16),
          Text(
            model.total == 0
                ? '0'
                : '${model.pageStart}–${model.pageEnd} of ${model.total}',
            style: const TextStyle(fontSize: 12, color: Color(0xff374151)),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 18),
            onPressed: model.hasPrev ? model.prevPage : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            color: model.hasPrev ? const Color(0xff374151) : const Color(0xffD1D5DB),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 18),
            onPressed: model.hasNext ? model.nextPage : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            color: model.hasNext ? const Color(0xff374151) : const Color(0xffD1D5DB),
          ),
        ],
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
                    child: const Text('Show All',
                        style: TextStyle(fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: () {
                      widget.model.setAllColumnsVisible(false);
                      setState(() {});
                    },
                    child: const Text('Hide All',
                        style: TextStyle(fontSize: 12,
                            color: Color(0xff6B7280))),
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
                    title: Text(col.label,
                        style: const TextStyle(fontSize: 13)),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: Color(0xffE5E7EB))),
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
                    icon: const Icon(Icons.close, size: 20,
                        color: Color(0xff6B7280)),
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
                      onToggle: () =>
                          setState(() => _leadDataExpanded = !_leadDataExpanded),
                      child: Column(
                        children: _fields.map((f) {
                          final val =
                              widget.item[f[1]]?.toString() ?? '-';
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
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(8)),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          border:
              Border(bottom: BorderSide(color: Color(0xffF3F4F6)))),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xff6B7280))),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xff1A1F36))),
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

  bool _submitting = false;
  String? _error;

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
    setState(() { _submitting = true; _error = null; });
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
      setState(() { _submitting = false; _error = err; });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: Color(0xffE5E7EB))),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                        'Add New Lead Details to Grow Your Pipeline',
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
                                    items: const [],
                                    onChanged: (v) =>
                                        setState(() => _country = v),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _DropdownField(
                                    label: 'State',
                                    value: _state,
                                    items: const [],
                                    onChanged: (v) =>
                                        setState(() => _state = v),
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
                                    items: const [],
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
                          items: const [],
                          onChanged: (v) =>
                              setState(() => _sourceType = v),
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
                                    items: const [],
                                    onChanged: (v) =>
                                        setState(() => _interestLevel = v),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _DropdownField(
                                    label: 'Lead Stage',
                                    value: _leadStage,
                                    items: const [],
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
                              items: const [],
                              onChanged: (v) =>
                                  setState(() => _category = v),
                            ),
                            const SizedBox(height: 10),
                            _DropdownField(
                              label: 'Assigned To',
                              value: _assignedTo,
                              items: const [],
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                    top: BorderSide(color: Color(0xffE5E7EB))),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
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
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
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
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : null,
      decoration: _inputDeco(label),
      style: const TextStyle(fontSize: 13, color: Color(0xff374151)),
      hint: Text(label,
          style: const TextStyle(fontSize: 13, color: Color(0xff9CA3AF))),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
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
  final _ctrl = TextEditingController();
  final _hScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.model.followups.isEmpty && !widget.model.followupsBusy) {
      widget.model.initFollowups();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  void _confirmDelete(Map<String, dynamic> item) {
    final model = widget.model;
    final name = item['lead_name']?.toString() ?? 'this follow-up';
    final id = item['id'];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
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
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: CrmSearchBar(
            controller: _ctrl,
            hint: 'Search Lead Name, Assigned To, Status, Notes...',
            onChanged: model.searchFollowups,
          ),
        ),
        Expanded(
          child: model.followups.isEmpty
              ? const CrmEmptyState(
                  icon: Icons.follow_the_signs_rounded,
                  title: 'No Follow-ups Found',
                  subtitle: 'Follow-ups will appear here',
                )
              : _FollowupsTable(
                  model: model,
                  hScroll: _hScroll,
                  canDelete: widget.model.canDeleteFollowup,
                  onDelete: _confirmDelete,
                ),
        ),
        _FollowupsPaginationBar(model: model),
      ],
    );
  }
}

// ─── Follow-ups data table ────────────────────────────────────────────────────

class _FCol {
  const _FCol(this.label, this.key, this.width);
  final String label;
  final String key;
  final double width;
}

class _FollowupsTable extends StatelessWidget {
  const _FollowupsTable({
    required this.model,
    required this.hScroll,
    required this.canDelete,
    required this.onDelete,
  });
  final CompanyLeadsViewModel model;
  final ScrollController hScroll;
  final bool canDelete;
  final ValueChanged<Map<String, dynamic>> onDelete;

  static const double _headerH = 48.0;
  static const double _rowH = 52.0;

  // Columns exactly matching the web app
  static const _cols = [
    _FCol('S.No', 'sno', 55),
    _FCol('Lead Name', 'lead_name', 180),
    _FCol('Assigned To', 'employee_name', 150),
    _FCol('Status', 'status', 130),
    _FCol('Service Name', 'svc_name', 180),
    _FCol('Duration', 'svc_duration', 90),
    _FCol('Base Price', 'svc_base_price', 110),
    _FCol('Tax', 'svc_tax_rate', 90),
    _FCol('Req Duration', 'svc_original_duration', 110),
    _FCol('Next Follow-Up', 'nextFollowUpDate', 130),
    _FCol('Add Services', 'wantAddServices', 110),
    _FCol('Negotiate', 'negotiate', 100),
    _FCol('Quotation', 'quotation_title', 150),
    _FCol('Created On', 'created_at', 130),
    _FCol('Notes', 'notes', 180),
    _FCol('Action', 'action', 90),
  ];

  static double get _totalW => _cols.fold<double>(0, (s, c) => s + c.width);

  @override
  Widget build(BuildContext context) {
    final rows = model.followups;
    return LayoutBuilder(builder: (ctx, constraints) {
      final totalW = _totalW < constraints.maxWidth ? constraints.maxWidth : _totalW;
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
                // ── Header row
                Container(
                  height: _headerH,
                  decoration: const BoxDecoration(
                    color: Color(0xffF3F4F6),
                    border: Border(bottom: BorderSide(color: Color(0xffE5E7EB))),
                  ),
                  child: Row(
                    children: _cols.map((c) => _FHeaderCell(col: c)).toList(),
                  ),
                ),
                // ── Data rows
                SizedBox(
                  height: constraints.maxHeight - _headerH,
                  child: ListView.builder(
                    itemCount: rows.length,
                    itemExtent: _rowH,
                    itemBuilder: (_, i) => _FollowupRow(
                      item: rows[i],
                      rowIndex: model.followupsPageStart + i,
                      isEven: i % 2 == 0,
                      canDelete: canDelete,
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

// ─── Header cell ──────────────────────────────────────────────────────────────

class _FHeaderCell extends StatelessWidget {
  const _FHeaderCell({required this.col});
  final _FCol col;

  static const _div = BorderSide(color: Color(0xffD1D5DB), width: 0.8);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: col.width,
      height: 48,
      decoration: const BoxDecoration(border: Border(right: _div)),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          col.label,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xff374151)),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ─── Data row ─────────────────────────────────────────────────────────────────

class _FollowupRow extends StatelessWidget {
  const _FollowupRow({
    required this.item,
    required this.rowIndex,
    required this.isEven,
    required this.canDelete,
    required this.onDelete,
  });
  final Map<String, dynamic> item;
  final int rowIndex;
  final bool isEven;
  final bool canDelete;
  final VoidCallback onDelete;

  static const _div = BorderSide(color: Color(0xffEEEEEE), width: 0.8);

  // Parse services JSON string/list → first service map
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
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}';
    } catch (_) {
      return s.length > 10 ? s.substring(0, 10) : s;
    }
  }

  Widget _buildCell(String key, double width) {
    String val;
    Color? color;
    FontWeight fw = FontWeight.normal;

    switch (key) {
      case 'sno':
        val = '$rowIndex';
        color = const Color(0xff6B7280);
        break;
      case 'lead_name':
        val = item['lead_name']?.toString() ?? '—';
        fw = FontWeight.w600;
        color = kCrmBlue;
        break;
      case 'employee_name':
        val = item['employee_name']?.toString() ?? '—';
        break;
      case 'status':
        val = item['status']?.toString() ?? '—';
        if (val != '—') { color = const Color(0xff3B82F6); fw = FontWeight.w600; }
        break;
      // ── service fields from services[0]
      case 'svc_name':
        val = _firstSvc?['service_name']?.toString() ?? '—';
        break;
      case 'svc_duration':
        val = _firstSvc?['duration']?.toString() ?? '—';
        break;
      case 'svc_base_price':
        final bp = _firstSvc?['base_price'];
        val = bp != null ? '₹$bp' : '—';
        color = bp != null ? const Color(0xff166534) : null;
        fw = bp != null ? FontWeight.w600 : FontWeight.normal;
        break;
      case 'svc_tax_rate':
        final tr = _firstSvc?['tax_rate'];
        val = tr != null ? '$tr%' : '—';
        break;
      case 'svc_original_duration':
        val = _firstSvc?['original_duration']?.toString() ?? '—';
        break;
      case 'nextFollowUpDate':
        val = _fmt(item['nextFollowUpDate']);
        break;
      case 'created_at':
        val = _fmt(item['created_at']);
        break;
      case 'wantAddServices':
        val = item['wantAddServices']?.toString() ?? '—';
        if (val.toLowerCase() == 'yes') { color = const Color(0xff16A34A); fw = FontWeight.w600; }
        break;
      case 'negotiate':
        val = item['negotiate']?.toString() ?? '—';
        if (val.toLowerCase() == 'yes') { color = const Color(0xff16A34A); fw = FontWeight.w600; }
        break;
      case 'quotation_title':
        val = item['quotation_title']?.toString() ?? '—';
        break;
      case 'notes':
        final n = item['notes']?.toString() ?? '';
        val = n.trim().isEmpty ? 'Not mentioned' : n;
        if (n.trim().isEmpty) color = const Color(0xff9CA3AF);
        break;
      case 'action':
        return SizedBox(
          width: width,
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
      default:
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
        color: isEven ? Colors.white : const Color(0xffFAFAFF),
        border: const Border(bottom: BorderSide(color: Color(0xffE5E7EB), width: 0.5)),
      ),
      child: Row(
        children: _FollowupsTable._cols.map((c) => _buildCell(c.key, c.width)).toList(),
      ),
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
              value: model.followupsRowsPerPage,
              underline: const SizedBox.shrink(),
              isDense: true,
              items: CompanyLeadsViewModel.rowsPerPageOptions
                  .map((n) => DropdownMenuItem(
                      value: n, child: Text('$n', style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) { if (v != null) model.setFollowupsRowsPerPage(v); },
            ),
          ),
          const SizedBox(width: 16),
          Text(
            model.followupsTotal == 0
                ? '0'
                : '${model.followupsPageStart}–${model.followupsPageEnd} of ${model.followupsTotal}',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xff1A1F36)),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            iconSize: 20,
            color: model.followupsHasPrev ? kCrmBlue : const Color(0xffD1D5DB),
            onPressed: model.followupsHasPrev ? model.prevFollowupsPage : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            iconSize: 20,
            color: model.followupsHasNext ? kCrmBlue : const Color(0xffD1D5DB),
            onPressed: model.followupsHasNext ? model.nextFollowupsPage : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}
