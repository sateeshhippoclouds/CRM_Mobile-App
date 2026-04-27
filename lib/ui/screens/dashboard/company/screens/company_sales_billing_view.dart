import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'company_sales_billing_viewmodel.dart';
import 'crm_widgets.dart';

class CompanySalesBillingView extends StatefulWidget {
  const CompanySalesBillingView({super.key});

  @override
  State<CompanySalesBillingView> createState() =>
      _CompanySalesBillingViewState();
}

class _CompanySalesBillingViewState extends State<CompanySalesBillingView> {
  final _draftsCtrl = TextEditingController();
  final _salesCtrl = TextEditingController();
  final _historyCtrl = TextEditingController();

  @override
  void dispose() {
    _draftsCtrl.dispose();
    _salesCtrl.dispose();
    _historyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<CompanySalesBillingViewModel>.reactive(
      viewModelBuilder: () => CompanySalesBillingViewModel(),
      onViewModelReady: (m) => m.init(),
      builder: (context, model, child) {
        return Scaffold(
          backgroundColor: kCrmBg,
          appBar: crmAppBar('Sales & Billing'),
          body: model.isBusy
              ? const Center(
                  child: CircularProgressIndicator(color: kCrmBlue))
              : model.fetchError != null
                  ? CrmErrorBody(
                      error: model.fetchError!, onRetry: model.init)
                  : DefaultTabController(
                      length: 3,
                      child: Column(
                        children: [
                          Container(
                            color: Colors.white,
                            child: crmTabBar(
                              const ['ENTRY / DRAFTS', 'SALES', 'HISTORY'],
                              scrollable: true,
                            ),
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _SalesListTab(
                                  items: model.drafts,
                                  controller: _draftsCtrl,
                                  onSearch: model.searchDrafts,
                                  emptyTitle: 'No Drafts',
                                  emptySubtitle:
                                      'Draft entries will appear here',
                                  icon: Icons.drafts_outlined,
                                ),
                                _SalesListTab(
                                  items: model.sales,
                                  controller: _salesCtrl,
                                  onSearch: model.searchSales,
                                  emptyTitle: 'No Sales Records',
                                  emptySubtitle: 'Sales data will appear here',
                                  icon: Icons.receipt_long_outlined,
                                ),
                                _SalesListTab(
                                  items: model.history,
                                  controller: _historyCtrl,
                                  onSearch: model.searchHistory,
                                  emptyTitle: 'No History',
                                  emptySubtitle:
                                      'Past records will appear here',
                                  icon: Icons.history_rounded,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
        );
      },
    );
  }
}

class _SalesListTab extends StatelessWidget {
  const _SalesListTab({
    required this.items,
    required this.controller,
    required this.onSearch,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.icon,
  });
  final List<Map<String, dynamic>> items;
  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final String emptyTitle, emptySubtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CrmSearchBar(
          controller: controller,
          hint: 'Search by Client...',
          onChanged: onSearch,
        ),
        Expanded(
          child: items.isEmpty
              ? CrmEmptyState(
                  icon: icon,
                  title: emptyTitle,
                  subtitle: emptySubtitle,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 16),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _SalesCard(item: items[i]),
                ),
        ),
      ],
    );
  }
}

class _SalesCard extends StatelessWidget {
  const _SalesCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final client = sv(item, 'client');
    final term = sv(item, 'term', '');
    final agreed = sv(item, 'agreed', '');
    final paid = sv(item, 'paid', '');
    final balance = sv(item, 'balance', '');
    final carried = sv(item, 'carried', '');
    final status = sv(item, 'status', '');

    final balanceNum = double.tryParse(balance) ?? 0;
    final balanceColor =
        balanceNum > 0 ? const Color(0xffDC2626) : const Color(0xff16A34A);

    return CrmCard(
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(client,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff1A1F36))),
              ),
              if (status.isNotEmpty) CrmBadge(status),
            ],
          ),
          if (term.isNotEmpty)
            CrmInfoRow('Term', term, icon: Icons.article_outlined),
          const SizedBox(height: 8),
          if (agreed.isNotEmpty || paid.isNotEmpty)
            Row(
              children: [
                if (agreed.isNotEmpty)
                  Expanded(
                    child: _AmountChip(
                        label: 'Agreed',
                        amount: agreed,
                        color: const Color(0xff1D4ED8)),
                  ),
                if (agreed.isNotEmpty && paid.isNotEmpty)
                  const SizedBox(width: 8),
                if (paid.isNotEmpty)
                  Expanded(
                    child: _AmountChip(
                        label: 'Paid',
                        amount: paid,
                        color: const Color(0xff16A34A)),
                  ),
              ],
            ),
          if (carried.isNotEmpty || balance.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (carried.isNotEmpty)
                  Expanded(
                    child: _AmountChip(
                        label: 'Carried',
                        amount: carried,
                        color: const Color(0xff9333EA)),
                  ),
                if (carried.isNotEmpty && balance.isNotEmpty)
                  const SizedBox(width: 8),
                if (balance.isNotEmpty)
                  Expanded(
                    child: _AmountChip(
                        label: 'Balance',
                        amount: balance,
                        color: balanceColor),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AmountChip extends StatelessWidget {
  const _AmountChip(
      {required this.label, required this.amount, required this.color});
  final String label, amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: color.withValues(alpha: 0.8))),
          Text('₹$amount',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}
