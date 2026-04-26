import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'company_masters_clients_viewmodel.dart';

class CompanyMastersClientsView extends StatelessWidget {
  const CompanyMastersClientsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<CompanyMastersClientsViewModel>.reactive(
      viewModelBuilder: () => CompanyMastersClientsViewModel(),
      onViewModelReady: (m) => m.init(),
      builder: (context, model, child) {
        return Scaffold(
          backgroundColor: const Color(0xffF5F5F7),
          appBar: AppBar(
            backgroundColor: const Color(0xff3756DF),
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text('Masters › Clients',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18)),
            actions: [
              IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: () {}),
            ],
          ),
          body: model.isBusy
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xff3756DF)))
              : _MasterBody(
                  items: model.items,
                  icon: Icons.people_rounded,
                  label: 'No client types',
                  sub: 'Add client categories here',
                ),
        );
      },
    );
  }
}

class _MasterBody extends StatelessWidget {
  const _MasterBody({
    required this.items,
    required this.icon,
    required this.label,
    required this.sub,
  });
  final List<Map<String, dynamic>> items;
  final IconData icon;
  final String label, sub;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
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
                style:
                    const TextStyle(fontSize: 13, color: Color(0xff8E9BB5))),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) => Container(
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
        child: Text(items[i].toString()),
      ),
    );
  }
}
