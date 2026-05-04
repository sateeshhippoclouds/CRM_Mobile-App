import 'dart:io';
import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:stacked/stacked.dart';

import '../../../../../app/app.locator.dart';
import '../../../../../services/api_services.dart';
import 'company_sales_billing_viewmodel.dart';
import 'crm_widgets.dart';

// ── Column definition ─────────────────────────────────────────────────────────

class _ColDef {
  const _ColDef(this.label, this.key, this.width,
      {this.filterable = true, this.alwaysVisible = false});
  final String label;
  final String key;
  final double width;
  final bool filterable;
  final bool alwaysVisible;
}

// ── Sales tab columns ─────────────────────────────────────────────────────────

const _salesCols = [
  _ColDef('', 'checkbox', 48, filterable: false, alwaysVisible: true),
  _ColDef('S.No', 'sno', 56, filterable: false, alwaysVisible: true),
  _ColDef('Client', 'client_name', 160),
  _ColDef('Term', 'current_term', 60),
  _ColDef('Agreed (₹)', 'revised_total', 110),
  _ColDef('Carried (₹)', 'carried_over', 110),
  _ColDef('Paid (₹)', 'total_paid', 110),
  _ColDef('Balance (₹)', 'balance', 110),
  _ColDef('Status', 'pay_status', 100),
  _ColDef('Payments', 'payment_count', 80, filterable: false),
];

// ── Drafts tab columns ────────────────────────────────────────────────────────

const _draftsCols = [
  _ColDef('S.No', 'sno', 56, filterable: false, alwaysVisible: true),
  _ColDef('Invoice #', 'invoice_number', 140),
  _ColDef('Client', 'client_name', 160),
  _ColDef('Date', 'invoice_date', 100, filterable: false),
  _ColDef('Total (₹)', 'total_amount', 110, filterable: false),
  _ColDef('Paid (₹)', 'paid_amount', 110, filterable: false),
  _ColDef('Balance (₹)', 'remaining_balance', 110, filterable: false),
  _ColDef('Status', 'status', 90),
  _ColDef('Action', 'action', 140, filterable: false, alwaysVisible: true),
];

// ── History tab columns ───────────────────────────────────────────────────────

const _historyCols = [
  _ColDef('', 'checkbox', 48, filterable: false, alwaysVisible: true),
  _ColDef('S.No', 'sno', 56, filterable: false, alwaysVisible: true),
  _ColDef('Invoice #', 'invoice_number', 140),
  _ColDef('Customer', 'client_name', 150),
  _ColDef('Date', 'invoice_date', 100, filterable: false),
  _ColDef('Total (₹)', 'total_amount', 110),
  _ColDef('Paid (₹)', 'paid_amount', 110),
  _ColDef('Balance (₹)', 'remaining_balance', 110),
  _ColDef('Status', 'status', 100),
];

// ── Visible column helpers ────────────────────────────────────────────────────

List<_ColDef> _visSalesCols(CompanySalesBillingViewModel m) => _salesCols
    .where((c) => c.alwaysVisible || (m.salesColVis[c.key] ?? true))
    .toList();

List<_ColDef> _visHistCols(CompanySalesBillingViewModel m) => _historyCols
    .where((c) => c.alwaysVisible || (m.histColVis[c.key] ?? true))
    .toList();

// ── CSV export helper ─────────────────────────────────────────────────────────

String _buildCsv(
  List<_ColDef> cols,
  List<Map<String, dynamic>> rows, {
  Set<dynamic>? selected,
  String idKey = 'id',
  String Function(Map<String, dynamic>, _ColDef, int)? cellValue,
}) {
  final expCols =
      cols.where((c) => c.key != 'checkbox' && c.key != 'action').toList();
  final expRows = (selected != null && selected.isNotEmpty)
      ? rows.where((e) => selected.contains(e[idKey])).toList()
      : rows;
  final lines = <String>[
    expCols.map((c) => '"${c.label}"').join(','),
    ...expRows.asMap().entries.map((en) {
      final i = en.key;
      final item = en.value;
      return expCols.map((c) {
        final v = cellValue != null
            ? cellValue(item, c, i)
            : (c.key == 'sno' ? '${i + 1}' : item[c.key]?.toString() ?? '');
        return '"${v.replaceAll('"', '""')}"';
      }).join(',');
    }),
  ];
  return lines.join('\n');
}

// ── Main View ─────────────────────────────────────────────────────────────────

class CompanySalesBillingView extends StatefulWidget {
  const CompanySalesBillingView({super.key});

  @override
  State<CompanySalesBillingView> createState() =>
      _CompanySalesBillingViewState();
}

class _CompanySalesBillingViewState extends State<CompanySalesBillingView>
    with SingleTickerProviderStateMixin {
  final _draftsSearchCtrl = TextEditingController();
  final _salesSearchCtrl = TextEditingController();
  final _historySearchCtrl = TextEditingController();
  final _salesHScroll = ScrollController();
  final _histHScroll = ScrollController();
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _draftsSearchCtrl.dispose();
    _salesSearchCtrl.dispose();
    _historySearchCtrl.dispose();
    _salesHScroll.dispose();
    _histHScroll.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<CompanySalesBillingViewModel>.reactive(
      viewModelBuilder: () => CompanySalesBillingViewModel(),
      onViewModelReady: (m) => m.init(),
      builder: (context, model, _) {
        return Scaffold(
          backgroundColor: kCrmBg,
          appBar: crmAppBar('Sales & Billing'),
          body: model.isBusy
              ? const Center(child: CircularProgressIndicator(color: kCrmBlue))
              : Column(
                  children: [
                    Container(
                      color: Colors.white,
                      child: TabBar(
                        controller: _tabCtrl,
                        isScrollable: true,
                        labelPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        labelColor: kCrmBlue,
                        unselectedLabelColor: const Color(0xff6B7280),
                        indicatorColor: kCrmBlue,
                        labelStyle: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12),
                        unselectedLabelStyle: const TextStyle(fontSize: 12),
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('ENTRY / DRAFTS'),
                                if (model.draftsTotal > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: kCrmBlue,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${model.draftsTotal}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Tab(text: 'SALES'),
                          const Tab(text: 'HISTORY'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabCtrl,
                        children: [
                          _DraftsTab(
                            model: model,
                            searchCtrl: _draftsSearchCtrl,
                          ),
                          _SalesTab(
                            model: model,
                            searchCtrl: _salesSearchCtrl,
                            hScroll: _salesHScroll,
                          ),
                          _HistoryTab(
                            model: model,
                            searchCtrl: _historySearchCtrl,
                            hScroll: _histHScroll,
                          ),
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

// ── Drafts Tab ────────────────────────────────────────────────────────────────

class _DraftsTab extends StatelessWidget {
  const _DraftsTab({required this.model, required this.searchCtrl});
  final CompanySalesBillingViewModel model;
  final TextEditingController searchCtrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchCtrl,
                  onChanged: model.searchDrafts,
                  decoration: InputDecoration(
                    hintText: 'Search drafts...',
                    hintStyle:
                        const TextStyle(color: Color(0xff9CA3AF), fontSize: 13),
                    prefixIcon: const Icon(Icons.search,
                        color: Color(0xff9CA3AF), size: 20),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: searchCtrl,
                      builder: (_, v, __) => v.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close,
                                  size: 18, color: Color(0xff9CA3AF)),
                              onPressed: () {
                                searchCtrl.clear();
                                model.searchDrafts('');
                              },
                            )
                          : const SizedBox.shrink(),
                    ),
                    filled: true,
                    fillColor: const Color(0xffF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xffE5E7EB))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xffE5E7EB))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kCrmBlue)),
                  ),
                ),
              ),
              if (model.canWrite) ...[
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _openAddSale(context, model),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kCrmBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('ADD SALE',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ),
        if (model.draftsError != null)
          CrmErrorBody(error: model.draftsError!, onRetry: model.initDrafts)
        else if (model.drafts.isEmpty)
          const Expanded(
            child: CrmEmptyState(
              icon: Icons.drafts_outlined,
              title: 'No Drafts',
              subtitle: 'Draft entries will appear here',
            ),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Container(
                      color: const Color(0xffF8FAFC),
                      child: Row(
                        children: _draftsCols
                            .map((c) => _HeaderCell(
                                  col: c,
                                  filterValue: '',
                                  onFilter: (_) {},
                                ))
                            .toList(),
                      ),
                    ),
                    // Data rows
                    ...model.drafts.asMap().entries.map((e) => _DraftDataRow(
                          item: e.value,
                          rowIndex: e.key +
                              1 +
                              model.draftsPage * model.draftsPerPage,
                          model: model,
                          context: context,
                        )),
                  ],
                ),
              ),
            ),
          ),
        if (model.draftsTotal > 0)
          _PaginationBar(
            start: model.draftsStart,
            end: model.draftsEnd,
            total: model.draftsTotal,
            hasPrev: model.draftsPrev,
            hasNext: model.draftsNext,
            onPrev: model.draftsPrevPage,
            onNext: model.draftsNextPage,
          ),
      ],
    );
  }
}

class _DraftDataRow extends StatelessWidget {
  const _DraftDataRow({
    required this.item,
    required this.rowIndex,
    required this.model,
    required this.context,
  });
  final Map<String, dynamic> item;
  final int rowIndex;
  final CompanySalesBillingViewModel model;
  final BuildContext context;

  @override
  Widget build(BuildContext ctx) {
    return Container(
      decoration: BoxDecoration(
        color: rowIndex.isOdd ? Colors.white : const Color(0xffFAFAFB),
        border: const Border(bottom: BorderSide(color: Color(0xffF0F0F0))),
      ),
      child: Row(
        children: _draftsCols.map((col) {
          if (col.key == 'sno') {
            return _C(
                width: col.width,
                child: Text('$rowIndex',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xff6B7280))));
          }
          if (col.key == 'status') {
            final status = item['status']?.toString() ?? 'Draft';
            return _C(width: col.width, child: CrmBadge(status));
          }
          if (col.key == 'invoice_date') {
            return _C(
                width: col.width,
                child: Text(CompanySalesBillingViewModel.fmtDate(item[col.key]),
                    style: const TextStyle(fontSize: 12)));
          }
          if (col.key == 'total_amount' ||
              col.key == 'paid_amount' ||
              col.key == 'remaining_balance') {
            return _C(
                width: col.width,
                child: Text(CompanySalesBillingViewModel.fmtAmt(item[col.key]),
                    style: const TextStyle(fontSize: 12)));
          }
          if (col.key == 'action') {
            return SizedBox(
              width: col.width,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (model.canUpdate)
                      _ActionBtn(
                        icon: Icons.edit_outlined,
                        color: kCrmBlue,
                        tooltip: 'Edit',
                        onTap: () => _openEditSale(context, model, item),
                      ),
                    if (model.canUpdate) const SizedBox(width: 4),
                    if (model.canUpdate)
                      _ActionBtn(
                        icon: Icons.check_circle_outline,
                        color: const Color(0xff16A34A),
                        tooltip: 'Submit',
                        onTap: () => _confirmSubmitDraft(context, model, item),
                      ),
                    if (model.canDelete) const SizedBox(width: 4),
                    if (model.canDelete)
                      _ActionBtn(
                        icon: Icons.delete_outline,
                        color: const Color(0xffDC2626),
                        tooltip: 'Delete',
                        onTap: () => _confirmDelete(context, model, item['id']),
                      ),
                  ],
                ),
              ),
            );
          }
          return _C(
              width: col.width,
              child: Text(item[col.key]?.toString() ?? '—',
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis));
        }).toList(),
      ),
    );
  }
}

void _confirmSubmitDraft(BuildContext context,
    CompanySalesBillingViewModel model, Map<String, dynamic> draft) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Submit Invoice'),
      content: Text(
          'Submit draft "${draft['invoice_number'] ?? ''}" for ${draft['client_name'] ?? ''}?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff16A34A),
              foregroundColor: Colors.white),
          child: const Text('Submit'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final err = await model.submitDraft(draft);
  if (context.mounted && err != null) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red));
  }
}

void _confirmDelete(BuildContext context, CompanySalesBillingViewModel model,
    dynamic id) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Delete Invoice'),
      content: const Text('Are you sure you want to delete this invoice?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final err = await model.deleteSale(id);
  if (context.mounted && err != null) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red));
  }
}

// ── Sales Tab ─────────────────────────────────────────────────────────────────

class _SalesTab extends StatelessWidget {
  const _SalesTab(
      {required this.model, required this.searchCtrl, required this.hScroll});
  final CompanySalesBillingViewModel model;
  final TextEditingController searchCtrl;
  final ScrollController hScroll;

  void _showCustomizeColumns(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _CustomizeColsDialog(
        title: 'Customize Sales Columns',
        allCols: _salesCols,
        colVis: model.salesColVis,
        onToggle: model.toggleSalesColVis,
        onSetAll: model.setAllSalesColVis,
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    try {
      final visCols = _visSalesCols(model);
      final csv = _buildCsv(
        visCols,
        model.sales,
        selected: model.hasSalesSel
            ? model.sales
                .where((e) => model.isSalesSel(e['client_id']))
                .map((e) => e['client_id'])
                .toSet()
            : null,
        idKey: 'client_id',
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/sales.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)],
          text: model.hasSalesSel
              ? 'Sales (${model.salesSelCount} selected)'
              : 'All Sales');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visCols = _visSalesCols(model);
    return Column(
      children: [
        _BillingToolbar(
          searchCtrl: searchCtrl,
          hint: 'Search by Client...',
          onSearch: model.searchSales,
          showRefresh: true,
          onRefresh: model.initSales,
          hasFilters: model.hasSalesFilters,
          onClearFilters: model.clearSalesFilters,
          onExportCsv: () => _exportCsv(context),
          onColumns: () => _showCustomizeColumns(context),
        ),
        if (model.hasSalesFilters)
          _BillingFilterChips(
            filters: model.salesColFilters,
            colLabel: (key) {
              final m = _salesCols.where((c) => c.key == key);
              return m.isNotEmpty ? m.first.label : key;
            },
            onRemove: (key) => model.setSalesFilter(key, ''),
            onClearAll: model.clearSalesFilters,
          ),
        if (model.hasSalesSel)
          _SelectionInfoBar(
              count: model.salesSelCount, onClear: model.clearSalesSel),
        if (model.salesError != null)
          CrmErrorBody(error: model.salesError!, onRetry: model.initSales)
        else
          Expanded(
            child: _BillingTable(
              cols: visCols,
              hScroll: hScroll,
              isEmpty: model.sales.isEmpty,
              emptyIcon: Icons.receipt_long_outlined,
              emptyTitle: 'No Sales Records',
              emptySubtitle: 'Sales data will appear here',
              itemCount: model.sales.length,
              allSelected: model.allSalesSel,
              someSelected: model.someSalesSel,
              onToggleSelectAll: model.toggleSelectAllSales,
              isFiltered: (key) => model.salesColFilters.containsKey(key),
              filterValue: (key) => model.salesColFilters[key] ?? '',
              onFilter: (key, v) => model.setSalesFilter(key, v),
              buildRow: (i) {
                final item = model.sales[i];
                final id = item['client_id'];
                return _SalesDataRow(
                  item: item,
                  rowIndex: i + 1,
                  cols: visCols,
                  isEven: i % 2 == 0,
                  isSelected: model.isSalesSel(id),
                  onToggleSelect: () => model.toggleSalesSel(id),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ── History Tab ───────────────────────────────────────────────────────────────

class _HistoryTab extends StatelessWidget {
  const _HistoryTab(
      {required this.model, required this.searchCtrl, required this.hScroll});
  final CompanySalesBillingViewModel model;
  final TextEditingController searchCtrl;
  final ScrollController hScroll;

  void _showCustomizeColumns(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _CustomizeColsDialog(
        title: 'Customize History Columns',
        allCols: _historyCols,
        colVis: model.histColVis,
        onToggle: model.toggleHistColVis,
        onSetAll: model.setAllHistColVis,
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    try {
      final visCols = _visHistCols(model);
      final csv = _buildCsv(
        visCols,
        model.history,
        selected: model.hasHistSel
            ? model.history
                .where((e) => model.isHistSel(e['id']))
                .map((e) => e['id'])
                .toSet()
            : null,
        idKey: 'id',
        cellValue: (item, c, i) {
          if (c.key == 'sno') {
            return '${model.historyPage * model.historyPerPage + i + 1}';
          }
          if (c.key == 'invoice_date') {
            return CompanySalesBillingViewModel.fmtDate(item[c.key]);
          }
          return item[c.key]?.toString() ?? '';
        },
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/billing_history.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)],
          text: model.hasHistSel
              ? 'History (${model.histSelCount} selected)'
              : 'All History');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visCols = _visHistCols(model);
    return Column(
      children: [
        _BillingToolbar(
          searchCtrl: searchCtrl,
          hint: 'Search by Invoice No or Customer...',
          onSearch: model.searchHistory,
          showRefresh: false,
          hasFilters: model.hasHistoryFilters,
          onClearFilters: model.clearHistoryFilters,
          onExportCsv: () => _exportCsv(context),
          onColumns: () => _showCustomizeColumns(context),
        ),
        if (model.hasHistoryFilters)
          _BillingFilterChips(
            filters: model.historyColFilters,
            colLabel: (key) {
              final m = _historyCols.where((c) => c.key == key);
              return m.isNotEmpty ? m.first.label : key;
            },
            onRemove: (key) => model.setHistoryFilter(key, ''),
            onClearAll: model.clearHistoryFilters,
          ),
        if (model.hasHistSel)
          _SelectionInfoBar(
              count: model.histSelCount, onClear: model.clearHistSel),
        if (model.historyError != null)
          CrmErrorBody(error: model.historyError!, onRetry: model.initHistory)
        else
          Expanded(
            child: _BillingTable(
              cols: visCols,
              hScroll: hScroll,
              isEmpty: model.history.isEmpty,
              emptyIcon: Icons.history_rounded,
              emptyTitle: 'No History',
              emptySubtitle: 'Past invoice records will appear here',
              itemCount: model.history.length,
              allSelected: model.allHistSel,
              someSelected: model.someHistSel,
              onToggleSelectAll: model.toggleSelectAllHist,
              isFiltered: (key) => model.historyColFilters.containsKey(key),
              filterValue: (key) => model.historyColFilters[key] ?? '',
              onFilter: (key, v) => model.setHistoryFilter(key, v),
              buildRow: (i) {
                final item = model.history[i];
                final id = item['id'];
                return _HistDataRow(
                  item: item,
                  rowIndex: model.historyPage * model.historyPerPage + i + 1,
                  cols: visCols,
                  isEven: i % 2 == 0,
                  isSelected: model.isHistSel(id),
                  onToggleSelect: () => model.toggleHistSel(id),
                );
              },
            ),
          ),
        if (model.historyTotal > 0)
          _PaginationBar(
            start: model.historyStart,
            end: model.historyEnd,
            total: model.historyTotal,
            hasPrev: model.historyPrev,
            hasNext: model.historyNext,
            onPrev: model.historyPrevPage,
            onNext: model.historyNextPage,
            rowsPerPage: model.historyPerPage,
            rowsOptions: CompanySalesBillingViewModel.rowsPerPageOptions,
            onRowsPerPage: model.setHistoryPerPage,
          ),
      ],
    );
  }
}

// ── Billing toolbar ───────────────────────────────────────────────────────────

class _BillingToolbar extends StatelessWidget {
  const _BillingToolbar({
    required this.searchCtrl,
    required this.hint,
    required this.onSearch,
    required this.showRefresh,
    this.onRefresh,
    required this.hasFilters,
    required this.onClearFilters,
    required this.onExportCsv,
    required this.onColumns,
  });
  final TextEditingController searchCtrl;
  final String hint;
  final ValueChanged<String> onSearch;
  final bool showRefresh;
  final VoidCallback? onRefresh;
  final bool hasFilters;
  final VoidCallback onClearFilters;
  final VoidCallback onExportCsv;
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
              width: 210,
              height: 38,
              child: TextField(
                controller: searchCtrl,
                onChanged: onSearch,
                decoration: InputDecoration(
                  hintText: hint,
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
                              onSearch('');
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
            if (showRefresh && onRefresh != null) ...[
              _TblIconBtn(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh',
                  onTap: onRefresh!),
              const SizedBox(width: 4),
            ],
            _TblIconBtn(
                icon: Icons.download_outlined,
                tooltip: 'Export CSV',
                onTap: onExportCsv),
            const SizedBox(width: 4),
            _TblIconBtn(
                icon: Icons.view_column_outlined,
                tooltip: 'Customize Columns',
                onTap: onColumns),
            if (hasFilters) ...[
              const SizedBox(width: 4),
              _TblIconBtn(
                  icon: Icons.filter_alt_off_rounded,
                  tooltip: 'Clear filters',
                  color: const Color(0xffDC2626),
                  onTap: onClearFilters),
            ],
          ],
        ),
      ),
    );
  }
}

class _TblIconBtn extends StatelessWidget {
  const _TblIconBtn(
      {required this.icon,
      required this.tooltip,
      required this.onTap,
      this.color});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

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
          child: Icon(icon,
              size: 18, color: color ?? const Color(0xff374151)),
        ),
      ),
    );
  }
}

// ── Filter chips bar ──────────────────────────────────────────────────────────

class _BillingFilterChips extends StatelessWidget {
  const _BillingFilterChips({
    required this.filters,
    required this.colLabel,
    required this.onRemove,
    required this.onClearAll,
  });
  final Map<String, String> filters;
  final String Function(String key) colLabel;
  final ValueChanged<String> onRemove;
  final VoidCallback onClearAll;

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
                children: filters.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Chip(
                      label: Text('${colLabel(e.key)}: ${e.value}',
                          style: const TextStyle(fontSize: 11)),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () => onRemove(e.key),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      backgroundColor:
                          kCrmBlue.withValues(alpha: 0.08),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          TextButton(
            onPressed: onClearAll,
            child: const Text('Clear All',
                style: TextStyle(fontSize: 11, color: Color(0xffDC2626))),
          ),
        ],
      ),
    );
  }
}

// ── Selection info bar ────────────────────────────────────────────────────────

class _SelectionInfoBar extends StatelessWidget {
  const _SelectionInfoBar({required this.count, required this.onClear});
  final int count;
  final VoidCallback onClear;

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
              '$count row(s) selected — CSV exports selected only',
              style: const TextStyle(fontSize: 12, color: kCrmBlue),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(40, 24)),
            child: const Text('Clear',
                style: TextStyle(
                    fontSize: 11, color: Color(0xffDC2626))),
          ),
        ],
      ),
    );
  }
}

// ── Generic billing table (Sales + History share this) ────────────────────────

class _BillingTable extends StatelessWidget {
  const _BillingTable({
    required this.cols,
    required this.hScroll,
    required this.isEmpty,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.itemCount,
    required this.allSelected,
    required this.someSelected,
    required this.onToggleSelectAll,
    required this.isFiltered,
    required this.filterValue,
    required this.onFilter,
    required this.buildRow,
  });

  final List<_ColDef> cols;
  final ScrollController hScroll;
  final bool isEmpty;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final int itemCount;
  final bool allSelected;
  final bool someSelected;
  final VoidCallback onToggleSelectAll;
  final bool Function(String key) isFiltered;
  final String Function(String key) filterValue;
  final void Function(String key, String value) onFilter;
  final Widget Function(int index) buildRow;

  static const double _headerH = 44;
  static const double _rowH = 48;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
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
                Container(
                  height: _headerH,
                  decoration: const BoxDecoration(
                    color: Color(0xffF3F4F6),
                    border: Border(
                        bottom: BorderSide(color: Color(0xffE5E7EB))),
                  ),
                  child: Row(
                    children: cols
                        .map((c) => _BillingHeaderCell(
                              col: c,
                              allSelected: allSelected,
                              someSelected: someSelected,
                              onToggleSelectAll: onToggleSelectAll,
                              isFiltered: isFiltered(c.key),
                              filterValue: filterValue(c.key),
                              onFilter: (v) => onFilter(c.key, v),
                              screenCtx: context,
                            ))
                        .toList(),
                  ),
                ),
                Expanded(
                  child: isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(emptyIcon,
                                  size: 40,
                                  color: const Color(0xffD1D5DB)),
                              const SizedBox(height: 8),
                              Text(emptyTitle,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xff9CA3AF))),
                              const SizedBox(height: 4),
                              Text(emptySubtitle,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xffD1D5DB))),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: itemCount,
                          itemExtent: _rowH,
                          itemBuilder: (_, i) => buildRow(i),
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

// ── Billing header cell ───────────────────────────────────────────────────────

class _BillingHeaderCell extends StatelessWidget {
  const _BillingHeaderCell({
    required this.col,
    required this.allSelected,
    required this.someSelected,
    required this.onToggleSelectAll,
    required this.isFiltered,
    required this.filterValue,
    required this.onFilter,
    required this.screenCtx,
  });

  final _ColDef col;
  final bool allSelected;
  final bool someSelected;
  final VoidCallback onToggleSelectAll;
  final bool isFiltered;
  final String filterValue;
  final ValueChanged<String> onFilter;
  final BuildContext screenCtx;

  static const _div = BorderSide(color: Color(0xffD1D5DB), width: 0.8);

  @override
  Widget build(BuildContext context) {
    if (col.key == 'checkbox') {
      return Container(
        width: col.width,
        height: 44,
        decoration: const BoxDecoration(border: Border(right: _div)),
        child: Center(
          child: Checkbox(
            value: allSelected ? true : someSelected ? null : false,
            tristate: true,
            activeColor: kCrmBlue,
            onChanged: (_) => onToggleSelectAll(),
          ),
        ),
      );
    }
    return Container(
      width: col.width,
      height: 44,
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
                onTap: () => _showFilterDialog(screenCtx),
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

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _BillingColFilterDialog(
        label: col.label,
        initialValue: filterValue,
        onApply: onFilter,
      ),
    );
  }
}

class _BillingColFilterDialog extends StatefulWidget {
  const _BillingColFilterDialog({
    required this.label,
    required this.initialValue,
    required this.onApply,
  });
  final String label;
  final String initialValue;
  final ValueChanged<String> onApply;

  @override
  State<_BillingColFilterDialog> createState() =>
      _BillingColFilterDialogState();
}

class _BillingColFilterDialogState extends State<_BillingColFilterDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(vertical: 24),
      title: Text('Filter: ${widget.label}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Filter value',
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xffD1D5DB))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: kCrmBlue)),
        ),
        onSubmitted: (_) {
          widget.onApply(_ctrl.text);
          Navigator.pop(context);
        },
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onApply('');
            Navigator.pop(context);
          },
          child: const Text('CLEAR',
              style: TextStyle(color: Color(0xff6B7280))),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onApply(_ctrl.text);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: kCrmBlue, foregroundColor: Colors.white),
          child: const Text('APPLY'),
        ),
      ],
    );
  }
}

// ── Sales data row ────────────────────────────────────────────────────────────

class _SalesDataRow extends StatelessWidget {
  const _SalesDataRow({
    required this.item,
    required this.rowIndex,
    required this.cols,
    required this.isEven,
    required this.isSelected,
    required this.onToggleSelect,
  });
  final Map<String, dynamic> item;
  final int rowIndex;
  final List<_ColDef> cols;
  final bool isEven;
  final bool isSelected;
  final VoidCallback onToggleSelect;

  Widget _cell(_ColDef c) {
    if (c.key == 'checkbox') {
      return SizedBox(
        width: c.width,
        height: 48,
        child: Center(
          child: Checkbox(
            value: isSelected,
            activeColor: kCrmBlue,
            onChanged: (_) => onToggleSelect(),
          ),
        ),
      );
    }
    if (c.key == 'sno') {
      return _TC(
          width: c.width,
          child: Text('$rowIndex',
              style: const TextStyle(
                  fontSize: 12, color: Color(0xff6B7280))));
    }
    if (c.key == 'pay_status') {
      final s = item['pay_status']?.toString() ?? '—';
      return _TC(
          width: c.width,
          child: s == '—'
              ? Text(s,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xff6B7280)))
              : CrmBadge(s));
    }
    if (c.key == 'revised_total' ||
        c.key == 'carried_over' ||
        c.key == 'total_paid' ||
        c.key == 'balance') {
      return _TC(
          width: c.width,
          child: Text(CompanySalesBillingViewModel.fmtAmt(item[c.key]),
              style: const TextStyle(fontSize: 12)));
    }
    return _TC(
        width: c.width,
        child: Text(item[c.key]?.toString() ?? '—',
            style: const TextStyle(fontSize: 12, color: Color(0xff374151)),
            overflow: TextOverflow.ellipsis,
            maxLines: 1));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
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

// ── History data row ──────────────────────────────────────────────────────────

class _HistDataRow extends StatelessWidget {
  const _HistDataRow({
    required this.item,
    required this.rowIndex,
    required this.cols,
    required this.isEven,
    required this.isSelected,
    required this.onToggleSelect,
  });
  final Map<String, dynamic> item;
  final int rowIndex;
  final List<_ColDef> cols;
  final bool isEven;
  final bool isSelected;
  final VoidCallback onToggleSelect;

  Widget _cell(_ColDef c) {
    if (c.key == 'checkbox') {
      return SizedBox(
        width: c.width,
        height: 48,
        child: Center(
          child: Checkbox(
            value: isSelected,
            activeColor: kCrmBlue,
            onChanged: (_) => onToggleSelect(),
          ),
        ),
      );
    }
    if (c.key == 'sno') {
      return _TC(
          width: c.width,
          child: Text('$rowIndex',
              style: const TextStyle(
                  fontSize: 12, color: Color(0xff6B7280))));
    }
    if (c.key == 'status') {
      final s = item['status']?.toString() ?? '—';
      return _TC(
          width: c.width,
          child: s == '—'
              ? Text(s,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xff6B7280)))
              : CrmBadge(s));
    }
    if (c.key == 'invoice_date') {
      return _TC(
          width: c.width,
          child: Text(CompanySalesBillingViewModel.fmtDate(item[c.key]),
              style: const TextStyle(fontSize: 12)));
    }
    if (c.key == 'total_amount' ||
        c.key == 'paid_amount' ||
        c.key == 'remaining_balance') {
      return _TC(
          width: c.width,
          child: Text(CompanySalesBillingViewModel.fmtAmt(item[c.key]),
              style: const TextStyle(fontSize: 12)));
    }
    return _TC(
        width: c.width,
        child: Text(item[c.key]?.toString() ?? '—',
            style: const TextStyle(fontSize: 12, color: Color(0xff374151)),
            overflow: TextOverflow.ellipsis,
            maxLines: 1));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
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

// ── Table cell (Sales + History) ──────────────────────────────────────────────

class _TC extends StatelessWidget {
  const _TC({required this.width, required this.child});
  final double width;
  final Widget child;

  static const _div = BorderSide(color: Color(0xffEEEEEE), width: 0.8);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 48,
      decoration: const BoxDecoration(border: Border(right: _div)),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
  }
}

// ── Customize columns dialog ──────────────────────────────────────────────────

class _CustomizeColsDialog extends StatefulWidget {
  const _CustomizeColsDialog({
    required this.title,
    required this.allCols,
    required this.colVis,
    required this.onToggle,
    required this.onSetAll,
  });
  final String title;
  final List<_ColDef> allCols;
  final Map<String, bool> colVis;
  final ValueChanged<String> onToggle;
  final ValueChanged<bool> onSetAll;

  @override
  State<_CustomizeColsDialog> createState() => _CustomizeColsDlgState();
}

class _CustomizeColsDlgState extends State<_CustomizeColsDialog> {
  @override
  Widget build(BuildContext context) {
    final toggleable =
        widget.allCols.where((c) => !c.alwaysVisible).toList();
    final allChecked =
        toggleable.every((c) => widget.colVis[c.key] ?? true);
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(vertical: 24),
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Expanded(
            child: Text(widget.title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kCrmBlue)),
          ),
          TextButton(
            onPressed: () {
              widget.onSetAll(!allChecked);
              setState(() {});
            },
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
            final visible = widget.colVis[col.key] ?? true;
            return CheckboxListTile(
              value: visible,
              title: Text(col.label,
                  style: const TextStyle(fontSize: 14)),
              activeColor: kCrmBlue,
              dense: true,
              onChanged: (_) {
                widget.onToggle(col.key);
                setState(() {});
              },
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

// ── Shared table widgets ──────────────────────────────────────────────────────

class _C extends StatelessWidget {
  const _C({required this.width, required this.child});
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: child,
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.col,
    required this.filterValue,
    required this.onFilter,
  });
  final _ColDef col;
  final String filterValue;
  final ValueChanged<String> onFilter;

  @override
  Widget build(BuildContext context) {
    final hasFilter = filterValue.isNotEmpty;
    return SizedBox(
      width: col.width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                col.label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff374151)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (col.filterable)
              GestureDetector(
                onTap: () => _showFilterDialog(context),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: hasFilter
                        ? kCrmBlue.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    hasFilter
                        ? Icons.filter_alt_rounded
                        : Icons.filter_list_rounded,
                    size: 14,
                    color: hasFilter ? kCrmBlue : const Color(0xff9CA3AF),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _ColFilterDialog(
        label: col.label,
        initialValue: filterValue,
        onApply: onFilter,
      ),
    );
  }
}

class _ColFilterDialog extends StatefulWidget {
  const _ColFilterDialog({
    required this.label,
    required this.initialValue,
    required this.onApply,
  });
  final String label;
  final String initialValue;
  final ValueChanged<String> onApply;

  @override
  State<_ColFilterDialog> createState() => _ColFilterDialogState();
}

class _ColFilterDialogState extends State<_ColFilterDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Filter: ${widget.label}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Enter filter value',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        onSubmitted: (_) {
          widget.onApply(_ctrl.text);
          Navigator.pop(context);
        },
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onApply('');
            Navigator.pop(context);
          },
          child:
              const Text('CLEAR', style: TextStyle(color: Color(0xff6B7280))),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onApply(_ctrl.text);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: kCrmBlue, foregroundColor: Colors.white),
          child: const Text('APPLY'),
        ),
      ],
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.start,
    required this.end,
    required this.total,
    required this.hasPrev,
    required this.hasNext,
    required this.onPrev,
    required this.onNext,
    this.rowsPerPage,
    this.rowsOptions,
    this.onRowsPerPage,
  });
  final int start, end, total;
  final bool hasPrev, hasNext;
  final VoidCallback onPrev, onNext;
  final int? rowsPerPage;
  final List<int>? rowsOptions;
  final ValueChanged<int>? onRowsPerPage;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (rowsPerPage != null && rowsOptions != null) ...[
            const Text('Rows per page:',
                style: TextStyle(fontSize: 12, color: Color(0xff6B7280))),
            const SizedBox(width: 6),
            DropdownButton<int>(
              value: rowsPerPage,
              underline: const SizedBox.shrink(),
              isDense: true,
              style: const TextStyle(fontSize: 12, color: Color(0xff1F2937)),
              items: rowsOptions!
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                  .toList(),
              onChanged: (v) => v != null ? onRowsPerPage!(v) : null,
            ),
            const SizedBox(width: 16),
          ],
          Text('$start–$end of $total',
              style: const TextStyle(fontSize: 12, color: Color(0xff6B7280))),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: hasPrev ? onPrev : null,
            color: const Color(0xff374151),
            disabledColor: const Color(0xffD1D5DB),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: hasNext ? onNext : null,
            color: const Color(0xff374151),
            disabledColor: const Color(0xffD1D5DB),
          ),
        ],
      ),
    );
  }
}

// ── Amount chip (drafts card) ─────────────────────────────────────────────────

// ── Add / Edit Sale dialog helpers ────────────────────────────────────────────

void _openAddSale(
    BuildContext context, CompanySalesBillingViewModel model) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AddSaleDialog(model: model),
  );
}

void _openEditSale(BuildContext context, CompanySalesBillingViewModel model,
    Map<String, dynamic> draft) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AddSaleDialog(model: model, draft: draft),
  );
}

// ── Add/Edit Sale Dialog ──────────────────────────────────────────────────────

class _AddSaleDialog extends StatefulWidget {
  const _AddSaleDialog({required this.model, this.draft});
  final CompanySalesBillingViewModel model;
  final Map<String, dynamic>? draft;

  @override
  State<_AddSaleDialog> createState() => _AddSaleDialogState();
}

class _AddSaleDialogState extends State<_AddSaleDialog> {
  final _api = locator<HippoAuthService>();
  final _formKey = GlobalKey<FormState>();
  final _invoiceNumCtrl = TextEditingController();
  final _currentlyPayingCtrl = TextEditingController(text: '0.00');
  final _notesCtrl = TextEditingController();
  final _transactionIdCtrl = TextEditingController();
  final _paymentNotesCtrl = TextEditingController();

  DateTime _invoiceDate = DateTime.now();
  DateTime _paymentDate = DateTime.now();
  String _paymentMethod = 'Cash';

  static const _paymentMethods = [
    'Cash',
    'Bank Transfer',
    'Cheque',
    'Credit Card',
    'Debit Card',
    'UPI',
    'Online',
  ];

  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _employees = [];
  Map<String, dynamic>? _selectedClient;
  Map<String, dynamic>? _clientDetail;
  int? _selectedCreatedById;
  String _clientQuery = '';

  bool _loadingMasters = true;
  bool _loadingDetail = false;
  bool _submitting = false;
  String? _masterError;

  bool get _isEdit => widget.draft != null;

  // Safe summary field accessor
  dynamic _s(String key) {
    try {
      final summary = _clientDetail?['summary'];
      if (summary is Map) return summary[key];
    } catch (_) {}
    return null;
  }

  double get _termAmount =>
      double.tryParse(_s('revised_total')?.toString() ?? '0') ?? 0;
  double get _balanceFromPrevious =>
      double.tryParse(_s('carried_over')?.toString() ?? '0') ?? 0;
  double get _toCollect =>
      double.tryParse(_s('to_collect')?.toString() ?? '0') ?? 0;
  double get _alreadyPaid =>
      double.tryParse(_s('total_paid')?.toString() ?? '0') ?? 0;
  double get _currentlyPaying =>
      double.tryParse(_currentlyPayingCtrl.text) ?? 0;
  double get _remainingBalance =>
      (_toCollect - _alreadyPaid - _currentlyPaying).clamp(0, double.infinity);

  List<Map<String, dynamic>> get _services {
    try {
      final raw = _clientDetail?['client']?['services'];
      if (raw is List) {
        return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  List<Map<String, dynamic>> get _filteredClients {
    if (_clientQuery.isEmpty) return _clients;
    final q = _clientQuery.toLowerCase();
    return _clients
        .where((c) =>
            (c['client_name'] ?? '').toString().toLowerCase().contains(q) ||
            _phone(c).contains(q))
        .toList();
  }

  String _phone(Map<String, dynamic> c) =>
      (c['mobile'] ?? c['phone'] ?? c['mobilenumber'] ?? c['contact'] ?? '')
          .toString();

  @override
  void initState() {
    super.initState();
    _loadMasters();
  }

  @override
  void dispose() {
    _invoiceNumCtrl.dispose();
    _currentlyPayingCtrl.dispose();
    _notesCtrl.dispose();
    _transactionIdCtrl.dispose();
    _paymentNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMasters() async {
    try {
      final results = await Future.wait([
        _api.getAllClientsForSale(),
        _api.getAllEmployeesForSale(),
      ]);
      _clients = results[0];
      _employees = results[1];

      // Prefill if editing
      if (_isEdit) {
        final d = widget.draft!;
        _invoiceNumCtrl.text = d['invoice_number']?.toString() ?? '';
        _notesCtrl.text = d['notes']?.toString() ?? '';
        if (d['invoice_date'] != null) {
          try {
            _invoiceDate = DateTime.parse(d['invoice_date'].toString());
          } catch (_) {}
        }
        _selectedCreatedById = d['created_by_id'] is int
            ? d['created_by_id'] as int
            : int.tryParse(d['created_by_id']?.toString() ?? '');
        // Find and select client
        final cid = d['client_id']?.toString();
        if (cid != null) {
          final match = _clients.firstWhere(
              (c) =>
                  c['id']?.toString() == cid ||
                  c['client_id']?.toString() == cid,
              orElse: () => <String, dynamic>{});
          if (match.isNotEmpty) {
            _selectedClient = match;
            _loadClientDetail(match);
          }
        }
      }

      if (mounted) setState(() => _loadingMasters = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingMasters = false;
          _masterError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _loadClientDetail(Map<String, dynamic> client) async {
    final clientId = client['id'] ?? client['client_id'];
    if (clientId == null) return;
    setState(() => _loadingDetail = true);
    try {
      final detail = await _api.getClientDetailForSale(clientId);
      if (mounted) {
        setState(() {
          _clientDetail = detail;
          _loadingDetail = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _invoiceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _invoiceDate = picked);
  }

  Future<void> _pickPaymentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _paymentDate = picked);
  }

  Future<void> _submit(bool isDraft) async {
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a customer'),
          backgroundColor: Colors.red));
      return;
    }

    setState(() => _submitting = true);

    final clientId = _selectedClient!['id'] ?? _selectedClient!['client_id'];
    final clientName = _selectedClient!['client_name']?.toString() ?? '';
    final subscriptionId = _clientDetail?['client']?['current_subscription_id'];
    final termNumber = _clientDetail?['client']?['current_term_number'] ?? 1;

    List<dynamic> services = [];
    try {
      final raw = _clientDetail?['client']?['services'];
      if (raw is List) services = raw;
    } catch (_) {}

    final dateStr =
        '${_invoiceDate.year}-${_invoiceDate.month.toString().padLeft(2, '0')}-${_invoiceDate.day.toString().padLeft(2, '0')}';

    final Map<String, dynamic> data = {
      'clientId': clientId,
      'clientName': clientName,
      'invoiceDate': dateStr,
      'invoiceNumber': _invoiceNumCtrl.text.trim(),
      'subscriptionId': subscriptionId,
      'termNumber': termNumber,
      'revised_total_amount': _termAmount,
      'original_total_amount': _termAmount,
      'revised_taxable_amount': 0,
      'revised_tax_amount': 0,
      'original_taxable_amount': 0,
      'original_tax_amount': 0,
      'discount': 0,
      'tax_option': 'including',
      'round_off': 0,
      'services': services,
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      'status': isDraft ? 'Draft' : 'Pending',
      'createdBy': _selectedCreatedById,
      'currentlyPaying': _currentlyPaying,
      'paymentMethod': _paymentMethod,
      'paymentDate':
          '${_paymentDate.year}-${_paymentDate.month.toString().padLeft(2, '0')}-${_paymentDate.day.toString().padLeft(2, '0')}',
      if (_transactionIdCtrl.text.trim().isNotEmpty)
        'transactionId': _transactionIdCtrl.text.trim(),
      if (_paymentNotesCtrl.text.trim().isNotEmpty)
        'paymentNotes': _paymentNotesCtrl.text.trim(),
    };

    String? err;
    if (_isEdit) {
      data.remove('currentlyPaying');
      data.remove('paymentMethod');
      err = await widget.model.updateSale(widget.draft!['id'], data);
    } else {
      err = await widget.model.addSale(data);
    }

    if (mounted) setState(() => _submitting = false);

    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red));
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Text(
                      _isEdit ? 'Edit Sale Entry' : 'New Sale Entry',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: kCrmBlue),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xffF3F4F6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            size: 18, color: Color(0xff374151)),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (_loadingMasters)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: kCrmBlue),
                )
              else if (_masterError != null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_masterError!,
                      style: const TextStyle(color: Colors.red)),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.zero,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Invoice Details
                          _sectionHeader('Invoice Details'),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _invoiceNumCtrl,
                                  decoration:
                                      _inputDec('Invoice Number (optional)'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: _pickDate,
                                  child: InputDecorator(
                                    decoration: _inputDec('Invoice Date *'),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${_invoiceDate.day.toString().padLeft(2, '0')}/${_invoiceDate.month.toString().padLeft(2, '0')}/${_invoiceDate.year}',
                                            style:
                                                const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                        const Icon(
                                            Icons.calendar_today_outlined,
                                            size: 16,
                                            color: Color(0xff9CA3AF)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Customer Details
                          _sectionHeader('Customer Details'),
                          const SizedBox(height: 10),
                          _ClientSearchField(
                            clients: _filteredClients,
                            selected: _selectedClient,
                            query: _clientQuery,
                            onQueryChanged: (q) =>
                                setState(() => _clientQuery = q),
                            onSelected: (c) {
                              setState(() {
                                _selectedClient = c;
                                _clientDetail = null;
                              });
                              _loadClientDetail(c);
                            },
                            onClear: () => setState(() {
                              _selectedClient = null;
                              _clientDetail = null;
                              _clientQuery = '';
                            }),
                            phoneOf: _phone,
                          ),
                          const SizedBox(height: 18),

                          // Client detail (services + payment) after selection
                          if (_loadingDetail)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child:
                                    CircularProgressIndicator(color: kCrmBlue),
                              ),
                            )
                          else if (_clientDetail != null) ...[
                            // Services table
                            if (_services.isNotEmpty) ...[
                              _sectionHeader('Services'),
                              const SizedBox(height: 8),
                              _ServicesTable(services: _services),
                              const SizedBox(height: 18),
                            ],

                            // Payment Details
                            _sectionHeader('Payment Details'),
                            const SizedBox(height: 10),
                            _PaymentRow(
                                label: 'Current Term Amount',
                                value: '₹${_termAmount.toStringAsFixed(2)}',
                                color: const Color(0xff1D4ED8)),
                            if (_balanceFromPrevious > 0)
                              _PaymentRow(
                                  label: 'Balance from Previous Term',
                                  value:
                                      '+₹${_balanceFromPrevious.toStringAsFixed(2)}',
                                  color: const Color(0xffD97706)),
                            _PaymentRow(
                                label: 'Total to Collect This Term',
                                value: '₹${_toCollect.toStringAsFixed(2)}',
                                color: const Color(0xff1D4ED8)),
                            _PaymentRow(
                                label: 'Already Paid This Term',
                                value: '₹${_alreadyPaid.toStringAsFixed(2)}',
                                color: const Color(0xff16A34A)),
                            const SizedBox(height: 6),
                            // Currently Paying (editable)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xffFFFBEB),
                                border:
                                    Border.all(color: const Color(0xffFDE68A)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Expanded(
                                    child: Text('Currently Paying',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xff1F2937))),
                                  ),
                                  SizedBox(
                                    width: 100,
                                    child: TextFormField(
                                      controller: _currentlyPayingCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                            RegExp(r'[\d.]')),
                                      ],
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(fontSize: 13),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 6),
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            _PaymentRow(
                                label: 'Remaining Balance',
                                value:
                                    '₹${_remainingBalance.toStringAsFixed(2)}',
                                color: _remainingBalance > 0
                                    ? const Color(0xffDC2626)
                                    : const Color(0xff16A34A)),
                            if (_currentlyPaying > 0) ...[
                              const SizedBox(height: 14),
                              _sectionHeader('Payment Info'),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                initialValue: _paymentMethod,
                                decoration: _inputDec('Payment Method'),
                                items: _paymentMethods
                                    .map((m) => DropdownMenuItem<String>(
                                          value: m,
                                          child: Text(m,
                                              style: const TextStyle(
                                                  fontSize: 13)),
                                        ))
                                    .toList(),
                                onChanged: (v) => setState(
                                    () => _paymentMethod = v ?? 'Cash'),
                              ),
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: _pickPaymentDate,
                                child: InputDecorator(
                                  decoration: _inputDec('Payment Date'),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${_paymentDate.day.toString().padLeft(2, '0')}/${_paymentDate.month.toString().padLeft(2, '0')}/${_paymentDate.year}',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      const Icon(Icons.calendar_today_outlined,
                                          size: 16, color: Color(0xff9CA3AF)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _transactionIdCtrl,
                                decoration: _inputDec(
                                    'Transaction ID / Ref (optional)'),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _paymentNotesCtrl,
                                maxLines: 2,
                                decoration:
                                    _inputDec('Payment Notes (optional)'),
                              ),
                            ],
                            const SizedBox(height: 18),
                          ],

                          // Created By
                          _sectionHeader('Created By'),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<int>(
                            initialValue: _selectedCreatedById,
                            decoration: _inputDec('Created By'),
                            items: _employees.map((e) {
                              final id = e['id'] is int
                                  ? e['id'] as int
                                  : int.tryParse(e['id']?.toString() ?? '');
                              final name =
                                  (e['employee_name'] ?? e['name'] ?? 'Unknown')
                                      .toString();
                              return DropdownMenuItem<int>(
                                value: id,
                                child: Text(name,
                                    style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => _selectedCreatedById = v),
                          ),
                          const SizedBox(height: 12),

                          // Notes
                          TextFormField(
                            controller: _notesCtrl,
                            maxLines: 2,
                            decoration: _inputDec('Notes (optional)'),
                          ),
                          const SizedBox(height: 24),

                          // Buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed:
                                      _submitting ? null : () => _submit(true),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 13),
                                    side: const BorderSide(
                                        color: Color(0xffD1D5DB)),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.drafts_outlined,
                                      size: 16, color: Color(0xff6B7280)),
                                  label: const Text('Save as Draft',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xff374151))),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _submitting ? null : () => _submit(false),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kCrmBlue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 13),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: _submitting
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white))
                                      : const Icon(Icons.check_circle_outline,
                                          size: 16),
                                  label: Text(
                                      _isEdit ? 'Update Sale' : 'Submit Sale'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Client search field ───────────────────────────────────────────────────────

class _ClientSearchField extends StatefulWidget {
  const _ClientSearchField({
    required this.clients,
    required this.selected,
    required this.query,
    required this.onQueryChanged,
    required this.onSelected,
    required this.onClear,
    required this.phoneOf,
  });
  final List<Map<String, dynamic>> clients;
  final Map<String, dynamic>? selected;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<Map<String, dynamic>> onSelected;
  final VoidCallback onClear;
  final String Function(Map<String, dynamic>) phoneOf;

  @override
  State<_ClientSearchField> createState() => _ClientSearchFieldState();
}

class _ClientSearchFieldState extends State<_ClientSearchField> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _open = false;

  @override
  void initState() {
    super.initState();
    if (widget.selected != null) {
      _ctrl.text = widget.selected!['client_name']?.toString() ?? '';
    }
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) setState(() => _open = false);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _ctrl,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: 'Select Customer *',
            labelStyle: const TextStyle(fontSize: 13, color: Color(0xff6B7280)),
            suffixIcon: widget.selected != null
                ? IconButton(
                    icon: const Icon(Icons.close,
                        size: 16, color: Color(0xff9CA3AF)),
                    onPressed: () {
                      _ctrl.clear();
                      widget.onClear();
                      widget.onQueryChanged('');
                      setState(() => _open = false);
                    },
                  )
                : const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Color(0xff9CA3AF)),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xffD1D5DB))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xffD1D5DB))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: kCrmBlue, width: 2)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          readOnly: widget.selected != null,
          onChanged: (v) {
            widget.onQueryChanged(v);
            setState(() => _open = v.isNotEmpty);
          },
          onTap: () {
            if (widget.selected == null) setState(() => _open = true);
          },
          validator: (_) => widget.selected == null ? 'Required' : null,
        ),
        if (_open && widget.clients.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xffE5E7EB)),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.clients.length,
              itemBuilder: (_, i) {
                final c = widget.clients[i];
                final name = c['client_name']?.toString() ?? '—';
                final phone = widget.phoneOf(c);
                return InkWell(
                  onTap: () {
                    _ctrl.text = name;
                    widget.onSelected(c);
                    widget.onQueryChanged('');
                    setState(() => _open = false);
                    _focusNode.unfocus();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500)),
                        if (phone.isNotEmpty)
                          Text(phone,
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xff9CA3AF))),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ── Services table ────────────────────────────────────────────────────────────

class _ServicesTable extends StatelessWidget {
  const _ServicesTable({required this.services});
  final List<Map<String, dynamic>> services;

  static const double _wSno = 40;
  static const double _wName = 160;
  static const double _wDate = 90;
  static const double _wAmt = 80;

  Widget _cell(double w, Widget child, {EdgeInsets? padding}) => SizedBox(
        width: w,
        child: Padding(
          padding:
              padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xffE5E7EB)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                color: const Color(0xffF8FAFC),
                child: Row(
                  children: [
                    _cell(
                        _wSno,
                        const Text('S.No',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff374151)))),
                    _cell(
                        _wName,
                        const Text('Service Name',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff374151)))),
                    _cell(
                        _wDate,
                        const Text('Start Date',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff374151)))),
                    _cell(
                        _wDate,
                        const Text('End Date',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff374151)))),
                    _cell(
                        _wAmt,
                        const Text('Amount',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff374151)))),
                  ],
                ),
              ),
              // Data rows
              ...services.asMap().entries.map((e) {
                final s = e.value;
                final name =
                    (s['name'] ?? s['service_name'] ?? s['servicename'] ?? '—')
                        .toString();
                final start = CompanySalesBillingViewModel.fmtDate(
                    s['start_date'] ?? s['startdate']);
                final end = CompanySalesBillingViewModel.fmtDate(
                    s['end_date'] ?? s['enddate']);
                final amt = CompanySalesBillingViewModel.fmtAmt(
                    s['amount'] ?? s['total_amount']);
                return Container(
                  decoration: BoxDecoration(
                    color: e.key.isOdd ? const Color(0xffFAFAFB) : Colors.white,
                    border:
                        const Border(top: BorderSide(color: Color(0xffF0F0F0))),
                  ),
                  child: Row(
                    children: [
                      _cell(
                          _wSno,
                          Text('${e.key + 1}',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xff6B7280)))),
                      _cell(
                          _wName,
                          Text(name,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis)),
                      _cell(_wDate,
                          Text(start, style: const TextStyle(fontSize: 12))),
                      _cell(_wDate,
                          Text(end, style: const TextStyle(fontSize: 12))),
                      _cell(
                          _wAmt,
                          Text(amt,
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12))),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Payment row ───────────────────────────────────────────────────────────────

class _PaymentRow extends StatelessWidget {
  const _PaymentRow(
      {required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xff1F2937)))),
          Text(value,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// ── Action button (table rows) ────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _sectionHeader(String title) => Text(
      title,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xff1F2937)),
    );

InputDecoration _inputDec(String label) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: Color(0xff6B7280)),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xffD1D5DB))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xffD1D5DB))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kCrmBlue, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
