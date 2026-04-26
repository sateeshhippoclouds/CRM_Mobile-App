import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'company_leads_viewmodel.dart';

class CompanyLeadsView extends StatelessWidget {
  const CompanyLeadsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<CompanyLeadsViewModel>.reactive(
      viewModelBuilder: () => CompanyLeadsViewModel(),
      onViewModelReady: (m) => m.init(),
      builder: (context, model, child) {
        return Scaffold(
          backgroundColor: const Color(0xffF5F5F7),
          appBar: AppBar(
            backgroundColor: const Color(0xff3756DF),
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text('Leads',
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
              : _LeadsBody(model: model),
        );
      },
    );
  }
}

class _LeadsBody extends StatelessWidget {
  const _LeadsBody({required this.model});
  final CompanyLeadsViewModel model;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search leads...',
              hintStyle:
                  const TextStyle(color: Color(0xff9E9E9E), fontSize: 14),
              prefixIcon:
                  const Icon(Icons.search, color: Color(0xff9E9E9E)),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: model.items.isEmpty
              ? const _EmptyState(
                  icon: Icons.bar_chart_rounded,
                  label: 'No leads yet',
                  sub: 'Add your first lead to get started',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: model.items.length,
                  itemBuilder: (_, i) => _ItemCard(item: model.items[i]),
                ),
        ),
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item});
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
              style: const TextStyle(
                  fontSize: 13, color: Color(0xff8E9BB5))),
        ],
      ),
    );
  }
}
