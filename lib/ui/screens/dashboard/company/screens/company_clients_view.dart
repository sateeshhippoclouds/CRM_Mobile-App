import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'company_clients_viewmodel.dart';
import 'crm_widgets.dart';

class CompanyClientsView extends StatefulWidget {
  const CompanyClientsView({super.key});

  @override
  State<CompanyClientsView> createState() => _CompanyClientsViewState();
}

class _CompanyClientsViewState extends State<CompanyClientsView> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<CompanyClientsViewModel>.reactive(
      viewModelBuilder: () => CompanyClientsViewModel(),
      onViewModelReady: (m) => m.init(),
      builder: (context, model, child) {
        return Scaffold(
          backgroundColor: kCrmBg,
          appBar: crmAppBar('Clients', actions: [
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
                          hint: 'Search by Client Name, Email...',
                          onChanged: model.search,
                        ),
                        Expanded(
                          child: model.items.isEmpty
                              ? const CrmEmptyState(
                                  icon: Icons.people_outline_rounded,
                                  title: 'No Clients Found',
                                  subtitle:
                                      'Add your first client to get started',
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                      0, 10, 0, 16),
                                  itemCount: model.items.length,
                                  itemBuilder: (_, i) =>
                                      _ClientCard(item: model.items[i]),
                                ),
                        ),
                      ],
                    ),
        );
      },
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final rawName = sv(item, 'company_name');
    final name = rawName != '—' ? rawName : sv(item, 'client_name');
    final contact = sv(item, 'contact_person', '');
    final email = sv(item, 'email', '');
    final phone = sv(item, 'phone', '');
    final city = sv(item, 'city', '');
    final status = sv(item, 'status', '');

    return CrmCard(
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xffEEF1FB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'C',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: kCrmBlue),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff1A1F36))),
              ),
              if (status.isNotEmpty) CrmBadge(status),
            ],
          ),
          const SizedBox(height: 6),
          if (contact.isNotEmpty)
            CrmInfoRow('Contact', contact, icon: Icons.person_outline),
          if (email.isNotEmpty)
            CrmInfoRow('Email', email, icon: Icons.email_outlined),
          if (phone.isNotEmpty)
            CrmInfoRow('Phone', phone, icon: Icons.phone_outlined),
          if (city.isNotEmpty)
            CrmInfoRow('City', city, icon: Icons.location_on_outlined),
        ],
      ),
    );
  }
}
