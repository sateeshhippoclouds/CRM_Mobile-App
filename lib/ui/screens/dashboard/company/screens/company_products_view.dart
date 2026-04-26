import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'company_products_viewmodel.dart';

class CompanyProductsView extends StatelessWidget {
  const CompanyProductsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<CompanyProductsViewModel>.reactive(
      viewModelBuilder: () => CompanyProductsViewModel(),
      onViewModelReady: (m) => m.init(),
      builder: (context, model, child) {
        return Scaffold(
          backgroundColor: const Color(0xffF5F5F7),
          appBar: AppBar(
            backgroundColor: const Color(0xff3756DF),
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text('Products',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18)),
            actions: [
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),
          body: model.isBusy
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xff3756DF)))
              : model.items.isEmpty
                  ? const _EmptyState(
                      icon: Icons.inventory_2_rounded,
                      label: 'No products yet',
                      sub: 'Add your first product',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: model.items.length,
                      itemBuilder: (_, i) =>
                          _ProductCard(item: model.items[i]),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Text(item.toString()),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(
      {required this.icon, required this.label, required this.sub});
  final IconData icon;
  final String label, sub;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xffEEF1FB),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(icon, size: 40, color: const Color(0xff3756DF)),
          ),
          const SizedBox(height: 16),
          Text(label,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff1A1F36))),
          const SizedBox(height: 6),
          Text(sub,
              style: const TextStyle(fontSize: 13, color: Color(0xff8E9BB5))),
        ],
      ),
    );
  }
}
