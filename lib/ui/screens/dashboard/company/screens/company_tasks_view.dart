import 'dart:io';
import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:stacked/stacked.dart';

import '../../../../../app/app.locator.dart';
import '../../../../../services/api_services.dart';
import 'company_tasks_viewmodel.dart';
import 'crm_widgets.dart';

// ─── Main screen ──────────────────────────────────────────────────────────────

class CompanyTasksView extends StatefulWidget {
  const CompanyTasksView({super.key});

  @override
  State<CompanyTasksView> createState() => _CompanyTasksViewState();
}

class _CompanyTasksViewState extends State<CompanyTasksView> {
  final _searchCtrl = TextEditingController();
  final _hScroll = ScrollController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  Future<void> _downloadCsv(CompanyTasksViewModel model) async {
    try {
      final csv = model.buildCsvContent();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/tasks.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)],
          text: model.hasSelection
              ? 'Tasks (${model.selectedCount} selected)'
              : 'All Tasks');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  void _showCustomizeColumns(CompanyTasksViewModel model) {
    showDialog(
      context: context,
      builder: (_) => _CustomizeColumnsDialog(model: model),
    );
  }

  void _showAddDialog(CompanyTasksViewModel model,
      [Map<String, dynamic>? item]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddTaskDialog(
        item: item,
        currentEmployeeId: model.currentEmployeeId,
        onSave: model.addTask,
        onUpdate: model.updateTask,
      ),
    );
  }

  void _showDeleteConfirm(
      Map<String, dynamic> item, CompanyTasksViewModel model) {
    final name = item['title']?.toString() ?? 'this task';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(vertical: 24),
        title: const Text('Delete Task',
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
              final err = await model.deleteTask(item['id']);
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
    return ViewModelBuilder<CompanyTasksViewModel>.reactive(
      viewModelBuilder: () => CompanyTasksViewModel(),
      onViewModelReady: (m) => m.init(),
      builder: (context, model, _) {
        return Scaffold(
          backgroundColor: kCrmBg,
          appBar: crmAppBar('Tasks'),
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
                        ),
                        if (model.hasActiveFilters)
                          _ActiveFilterChips(model: model),
                        if (model.hasSelection) _SelectionBar(model: model),
                        Expanded(
                          child: _TaskTable(
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

// ─── Toolbar ──────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.searchCtrl,
    required this.model,
    this.onAdd,
    required this.onColumns,
    required this.onExportCsv,
  });
  final TextEditingController searchCtrl;
  final CompanyTasksViewModel model;
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
                onChanged: model.search,
                decoration: InputDecoration(
                  hintText: 'Search tasks...',
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
                      borderSide: const BorderSide(color: Color(0xffE5E7EB))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xffE5E7EB))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kCrmBlue)),
                ),
              ),
            ),
            if (onAdd != null) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 38,
                child: ElevatedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('ADD TASK',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
  final CompanyTasksViewModel model;

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
  final CompanyTasksViewModel model;

  String _label(String key) {
    final match = CompanyTasksViewModel.allColumns.where((c) => c.key == key);
    return match.isNotEmpty ? match.first.label : key;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Row(
        children: [
          const Text('Filters:',
              style: TextStyle(fontSize: 11, color: Color(0xff6B7280))),
          const SizedBox(width: 6),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: model.colFilters.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Chip(
                      label: Text('${_label(e.key)}: ${e.value}',
                          style: const TextStyle(fontSize: 11)),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () => model.setColFilter(e.key, ''),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      backgroundColor: kCrmBlue.withValues(alpha: 0.08),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          TextButton(
            onPressed: model.clearAllFilters,
            child: const Text('Clear All',
                style: TextStyle(fontSize: 11, color: Color(0xffDC2626))),
          ),
        ],
      ),
    );
  }
}

// ─── Task table ───────────────────────────────────────────────────────────────

class _TaskTable extends StatelessWidget {
  const _TaskTable({
    required this.model,
    required this.hScroll,
    required this.canUpdate,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });
  final CompanyTasksViewModel model;
  final ScrollController hScroll;
  final bool canUpdate;
  final bool canDelete;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onDelete;

  static const double _headerH = 44;
  static const double _rowH = 52;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = model.visibleColumns;
      final tableW = cols.fold<double>(0, (s, c) => s + c.width);
      final minW = max(tableW, constraints.maxWidth);

      return Scrollbar(
        controller: hScroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: hScroll,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: minW,
            child: Column(
              children: [
                // Header
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
                  child: model.items.isEmpty
                      ? const Center(
                          child: Text('No tasks found',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xff9CA3AF))),
                        )
                      : ListView.builder(
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
                              onToggleSelect: () =>
                                  model.toggleRowSelection(id),
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
  final TaskColumnDef col;
  final CompanyTasksViewModel model;
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
        height: 44,
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
      height: 44,
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
            if (col.filterable && col.key != 'action') ...[
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
  final TaskColumnDef col;
  final CompanyTasksViewModel model;

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
  final List<TaskColumnDef> cols;
  final bool isEven;
  final bool isSelected;
  final bool canUpdate;
  final bool canDelete;
  final VoidCallback onToggleSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const _statusColors = {
    'created': Color(0xff3B82F6),
    'in progress': Color(0xffF59E0B),
    'completed': Color(0xff16A34A),
    'on hold': Color(0xff6B7280),
    'cancelled': Color(0xffDC2626),
  };

  static const _priorityColors = {
    'high': Color(0xffDC2626),
    'medium': Color(0xffF59E0B),
    'low': Color(0xff16A34A),
  };

  Widget _cell(TaskColumnDef col) {
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
            style: const TextStyle(fontSize: 12, color: Color(0xff6B7280))),
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
                fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      );
    }

    if (col.key == 'priority') {
      final priority = item['priority']?.toString() ?? '';
      final color =
          _priorityColors[priority.toLowerCase()] ?? const Color(0xff6B7280);
      return _C(
        width: col.width,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(priority,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ),
      );
    }

    if (col.key == 'relatedtotype') {
      final v = item['relatedtotype']?.toString() ?? '';
      return _C(
        width: col.width,
        child: Text(v,
            style: const TextStyle(fontSize: 12, color: Color(0xff374151)),
            overflow: TextOverflow.ellipsis),
      );
    }

    if (col.key == 'title') {
      final v = item['title']?.toString() ?? '—';
      return _C(
        width: col.width,
        child: Text(v,
            style: const TextStyle(
                fontSize: 12, color: kCrmBlue, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
            maxLines: 1),
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
              _Btn(icon: Icons.edit_outlined, color: kCrmBlue, onTap: onEdit),
            if (canDelete) ...[
              const SizedBox(width: 2),
              _Btn(
                  icon: Icons.delete_outline,
                  color: const Color(0xffDC2626),
                  onTap: onDelete),
            ],
          ],
        ),
      );
    }

    if (col.key == 'start_date' ||
        col.key == 'due_date' ||
        col.key == 'created_at') {
      return _C(
        width: col.width,
        child: Text(CompanyTasksViewModel.fmtDate(item[col.key]),
            style: const TextStyle(fontSize: 12, color: Color(0xff374151))),
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
  final CompanyTasksViewModel model;

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
              items: CompanyTasksViewModel.rowsPerPageOptions
                  .map((v) => DropdownMenuItem(
                        value: v,
                        child: Text('$v', style: const TextStyle(fontSize: 12)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) model.setRowsPerPage(v);
              },
            ),
          ),
          const SizedBox(width: 16),
          Text(
            model.total == 0
                ? '0 of 0'
                : '${model.pageStart}–${model.pageEnd} of ${model.total}',
            style: const TextStyle(fontSize: 12, color: Color(0xff6B7280)),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: model.hasPrev ? model.prevPage : null,
            color: model.hasPrev
                ? const Color(0xff374151)
                : const Color(0xffD1D5DB),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: model.hasNext ? model.nextPage : null,
            color: model.hasNext
                ? const Color(0xff374151)
                : const Color(0xffD1D5DB),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

// ─── Customize columns dialog ─────────────────────────────────────────────────

class _CustomizeColumnsDialog extends StatefulWidget {
  const _CustomizeColumnsDialog({required this.model});
  final CompanyTasksViewModel model;

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
    final toggleable = CompanyTasksViewModel.allColumns
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

// ─── Add / Edit Task dialog ───────────────────────────────────────────────────

class _AddTaskDialog extends StatefulWidget {
  const _AddTaskDialog({
    this.item,
    this.currentEmployeeId,
    required this.onSave,
    required this.onUpdate,
  });
  final Map<String, dynamic>? item;
  final String? currentEmployeeId;
  final Future<String?> Function(Map<String, dynamic>) onSave;
  final Future<String?> Function(dynamic id, Map<String, dynamic> data)
      onUpdate;

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> {
  final _api = locator<HippoAuthService>();
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _otherRelatedCtrl = TextEditingController();

  // masters
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _priorities = [];
  List<Map<String, dynamic>> _leads = [];
  List<Map<String, dynamic>> _clients = [];

  // selections
  String? _assignedToId;
  String? _priorityId;
  String? _relatedToType;
  String? _relatedToId;
  String? _status;
  DateTime? _startDate;
  DateTime? _dueDate;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.item != null;

  List<Map<String, dynamic>> get _relatedToItems {
    if (_relatedToType == 'leads') return _leads;
    if (_relatedToType == 'clients') return _clients;
    return [];
  }

  @override
  void initState() {
    super.initState();
    _loadMasters();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _otherRelatedCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMasters() async {
    try {
      final results = await Future.wait<dynamic>([
        _api.getEmployeesPaged(tab: 'active', rowsPerPage: 500),
        _api.getOthersMasters(),
        _api.getLeads(pipeline: 'pipeline'),
        _api.getClientsPaged(tab: 'active', rowsPerPage: 500),
      ]);
      if (!mounted) return;

      final empData = results[0] as Map<String, dynamic>;
      final othersData = results[1] as Map<String, dynamic>;
      final leadsRaw = results[2] as List<Map<String, dynamic>>;
      final clientData = results[3] as Map<String, dynamic>;

      final priorityRaw = othersData['priority'] as List? ?? [];
      final clientList =
          List<Map<String, dynamic>>.from(clientData['data'] as List? ?? []);

      setState(() {
        _employees =
            List<Map<String, dynamic>>.from(empData['data'] as List? ?? []);
        _priorities = priorityRaw
            .map((p) {
              final map = Map<String, dynamic>.from(p as Map);
              final id = (map['id'] ?? '').toString();
              final label =
                  map['value']?.toString() ?? map['label']?.toString() ?? id;
              return {'id': id, 'label': label};
            })
            .where((p) => (p['label'] as String).isNotEmpty)
            .toList();
        _leads = leadsRaw
            .map((l) => {
                  'id': l['id']?.toString() ?? '',
                  'label': l['lead_name']?.toString() ?? '',
                })
            .toList();
        _clients = clientList
            .map((c) => {
                  'id': c['id']?.toString() ?? '',
                  'label': c['client_name']?.toString() ?? '',
                })
            .toList();
        _loading = false;
        _prefill();
      });
    } catch (e, st) {
      debugPrint('=== TASK DIALOG _loadMasters ERROR: $e\n$st');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _prefill() {
    final d = widget.item;
    if (d == null) return;

    _titleCtrl.text = d['title']?.toString() ?? '';
    _notesCtrl.text = d['notes']?.toString() ?? '';
    _status = d['status']?.toString();

    final rType = d['relatedtotype']?.toString();
    if (rType != null && rType != 'none') _relatedToType = rType;

    final relName = d['related_to']?.toString() ?? '';
    if (_relatedToType == 'leads' && relName.isNotEmpty) {
      final match = _leads.where((l) => l['label'] == relName);
      if (match.isNotEmpty) _relatedToId = match.first['id'] as String?;
    } else if (_relatedToType == 'clients' && relName.isNotEmpty) {
      final match = _clients.where((c) => c['label'] == relName);
      if (match.isNotEmpty) _relatedToId = match.first['id'] as String?;
    } else if (_relatedToType == 'others' && relName.isNotEmpty) {
      _otherRelatedCtrl.text = relName;
    }

    final eid = d['assigned_to_id']?.toString();
    if (eid != null && _employees.any((e) => e['id']?.toString() == eid)) {
      _assignedToId = eid;
    }

    final pid = d['priority_id']?.toString();
    if (pid != null && _priorities.any((p) => p['id'] == pid)) {
      _priorityId = pid;
    }

    final sd = d['start_date']?.toString();
    if (sd != null && sd.isNotEmpty && sd != 'null') {
      try {
        _startDate = DateTime.parse(sd);
      } catch (_) {}
    }
    final dd = d['due_date']?.toString();
    if (dd != null && dd.isNotEmpty && dd != 'null') {
      try {
        _dueDate = DateTime.parse(dd);
      } catch (_) {}
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final initial =
        isStart ? (_startDate ?? DateTime.now()) : (_dueDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final startStr = _startDate != null
        ? '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}'
        : null;
    final dueStr = _dueDate != null
        ? '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}'
        : null;

    final relatedTo = _relatedToType == 'others'
        ? (_otherRelatedCtrl.text.trim().isEmpty
            ? null
            : _otherRelatedCtrl.text.trim())
        : _relatedToId;

    final Map<String, dynamic> data = {
      'title': _titleCtrl.text.trim(),
      'assignedTo': _assignedToId,
      'startDate': startStr,
      'dueDate': dueStr,
      'relatedTo': relatedTo,
      'description':
          _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      'priority': _priorityId,
      'status': _status ?? 'Created',
      'relatedToType': _relatedToType ?? 'none',
      'createdby': widget.currentEmployeeId,
    };

    String? err;
    if (_isEdit) {
      err = await widget.onUpdate(widget.item!['id'], data);
    } else {
      err = await widget.onSave(data);
    }

    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      setState(() => _error = err);
    } else {
      Navigator.pop(context);
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xff6B7280)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xffD1D5DB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: kCrmBlue)),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );

  Widget _dropdown({
    required String hint,
    required String? value,
    required List<Map<String, dynamic>> items,
    required ValueChanged<String?> onChanged,
    bool required = false,
  }) {
    final strItems = items
        .map((e) => {
              'id': (e['id'] ?? '').toString(),
              'label': (e['label'] ?? '').toString(),
            })
        .where((e) => e['id']!.isNotEmpty)
        .toList();
    final valid = strItems.any((e) => e['id'] == value);
    return DropdownButtonFormField<String>(
      value: valid ? value : null,
      decoration: _dec(hint),
      hint: Text(hint,
          style: const TextStyle(fontSize: 13, color: Color(0xff9CA3AF))),
      style: const TextStyle(fontSize: 13, color: Color(0xff374151)),
      isExpanded: true,
      validator: required ? (v) => v == null ? 'Required' : null : null,
      items: strItems
          .map((e) => DropdownMenuItem<String>(
                value: e['id']!,
                child: Text(e['label']!, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _datePicker(String label, DateTime? date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: _dec(label),
        child: Row(
          children: [
            Expanded(
              child: Text(
                date != null
                    ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
                    : 'Select date',
                style: TextStyle(
                    fontSize: 13,
                    color: date != null
                        ? const Color(0xff374151)
                        : const Color(0xff9CA3AF)),
              ),
            ),
            const Icon(Icons.calendar_today_outlined,
                size: 16, color: Color(0xff9CA3AF)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleText = _isEdit ? 'Edit Task' : 'Add New Task';
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: white background, blue title, circle X button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(titleText,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: kCrmBlue)),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                          color: kCrmBlue, shape: BoxShape.circle),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
            // Body
            Flexible(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: kCrmBlue),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_error != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xffFEE2E2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(_error!,
                                    style: const TextStyle(
                                        color: Color(0xffDC2626),
                                        fontSize: 12)),
                              ),

                            // Row 1: Related To Type | client/lead dropdown or text field
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _relatedToType,
                                    decoration: _dec('Related To Type'),
                                    hint: const Text('Select Type',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xff9CA3AF))),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xff374151)),
                                    isExpanded: true,
                                    items: CompanyTasksViewModel
                                        .relatedToTypeOptions
                                        .map((opt) => DropdownMenuItem<String>(
                                              value: opt['value'],
                                              child: Text(opt['label']!),
                                            ))
                                        .toList(),
                                    onChanged: (v) {
                                      setState(() {
                                        _relatedToType = v;
                                        _relatedToId = null;
                                        _otherRelatedCtrl.clear();
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _relatedToType == 'others'
                                      ? TextFormField(
                                          controller: _otherRelatedCtrl,
                                          decoration: _dec('Enter Name'),
                                          style:
                                              const TextStyle(fontSize: 13),
                                        )
                                      : _dropdown(
                                          hint: _relatedToType == 'leads'
                                              ? 'Select Lead'
                                              : 'Select Client',
                                          value: _relatedToId,
                                          items: _relatedToItems,
                                          onChanged: (v) => setState(
                                              () => _relatedToId = v),
                                        ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Row 2: Task Title | Assigned To
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _titleCtrl,
                                    decoration: _dec('Task Title'),
                                    style: const TextStyle(fontSize: 13),
                                    validator: (v) =>
                                        (v?.trim().isEmpty ?? true)
                                            ? 'Required'
                                            : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _dropdown(
                                    hint: 'Assigned To',
                                    value: _assignedToId,
                                    items: _employees
                                        .map((e) => {
                                              'id':
                                                  e['id']?.toString() ?? '',
                                              'label':
                                                  e['employee_name']
                                                          ?.toString() ??
                                                      '',
                                            })
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _assignedToId = v),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Row 3: Priority | Start Date
                            Row(
                              children: [
                                Expanded(
                                  child: _dropdown(
                                    hint: 'Priority',
                                    value: _priorityId,
                                    items: _priorities,
                                    onChanged: (v) =>
                                        setState(() => _priorityId = v),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _datePicker('Start Date', _startDate,
                                      () => _pickDate(true)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Due Date (full width)
                            _datePicker(
                                'Due Date', _dueDate, () => _pickDate(false)),
                            const SizedBox(height: 12),

                            // Description
                            TextFormField(
                              controller: _notesCtrl,
                              decoration: _dec('Description'),
                              style: const TextStyle(fontSize: 13),
                              maxLines: 3,
                              minLines: 2,
                            ),

                            // Status (edit mode only)
                            if (_isEdit) ...[
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: _status,
                                decoration: _dec('Status'),
                                hint: const Text('Created',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xff9CA3AF))),
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xff374151)),
                                isExpanded: true,
                                items: CompanyTasksViewModel.statusOptions
                                    .map((s) => DropdownMenuItem(
                                          value: s,
                                          child: Text(s),
                                        ))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _status = v),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
            ),
            // Footer: single full-width submit button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kCrmBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          _isEdit ? 'UPDATE TASK' : 'SUBMIT TASK',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
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
