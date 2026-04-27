import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'company_products_viewmodel.dart';
import 'crm_widgets.dart';

class CompanyProductsView extends StatefulWidget {
  const CompanyProductsView({super.key});

  @override
  State<CompanyProductsView> createState() => _CompanyProductsViewState();
}

class _CompanyProductsViewState extends State<CompanyProductsView> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: () {},
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
                        CrmSearchBar(
                          controller: _searchCtrl,
                          hint: 'Search services...',
                          onChanged: model.search,
                        ),
                        Expanded(
                          child: model.items.isEmpty
                              ? const CrmEmptyState(
                                  icon: Icons.inventory_2_outlined,
                                  title: 'No Products Found',
                                  subtitle: 'Add your first product or service',
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                      0, 10, 0, 16),
                                  itemCount: model.items.length,
                                  itemBuilder: (_, i) =>
                                      _ProductCard(item: model.items[i]),
                                ),
                        ),
                      ],
                    ),
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final name = sv(item, 'service_name');
    final category = sv(item, 'category', '');
    final duration = sv(item, 'duration', '');
    final basePrice = sv(item, 'base_price', '');
    final taxRate = sv(item, 'tax_rate', '');
    final total = sv(item, 'total_amount', '');

    return CrmCard(
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff1A1F36))),
              ),
              if (category.isNotEmpty) CrmBadge(category),
            ],
          ),
          if (duration.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const Icon(Icons.access_time_outlined,
                      size: 13, color: Color(0xff6B7280)),
                  const SizedBox(width: 4),
                  Text('$duration days',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xff6B7280))),
                ],
              ),
            ),
          if (basePrice.isNotEmpty || taxRate.isNotEmpty || total.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: CrmDividerRow([
                if (basePrice.isNotEmpty) CrmStat('Base Price', '₹$basePrice'),
                if (taxRate.isNotEmpty) CrmStat('Tax Rate', '$taxRate%'),
                if (total.isNotEmpty) CrmStat('Total', '₹$total'),
              ]),
            ),
        ],
      ),
    );
  }
}
