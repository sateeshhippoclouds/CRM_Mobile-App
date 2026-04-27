import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'company_leads_viewmodel.dart';
import 'crm_widgets.dart';

class CompanyLeadsView extends StatefulWidget {
  const CompanyLeadsView({super.key});

  @override
  State<CompanyLeadsView> createState() => _CompanyLeadsViewState();
}

class _CompanyLeadsViewState extends State<CompanyLeadsView> {
  final _leadsCtrl = TextEditingController();
  final _followupsCtrl = TextEditingController();

  @override
  void dispose() {
    _leadsCtrl.dispose();
    _followupsCtrl.dispose();
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
          appBar: crmAppBar('Leads', actions: [
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
                  : DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          Container(
                            color: Colors.white,
                            child: crmTabBar(
                                const ['LEADS', 'FOLLOW-UPS']),
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _LeadsTab(
                                  model: model,
                                  controller: _leadsCtrl,
                                ),
                                _FollowupsTab(
                                  model: model,
                                  controller: _followupsCtrl,
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

// ── Leads Tab ─────────────────────────────────────────────────────────────────

class _LeadsTab extends StatelessWidget {
  const _LeadsTab({required this.model, required this.controller});
  final CompanyLeadsViewModel model;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final items = model.leads;
    return Column(
      children: [
        CrmSearchBar(
          controller: controller,
          hint: 'Search by Lead Name, Email, or City...',
          onChanged: model.searchLeads,
        ),
        Expanded(
          child: items.isEmpty
              ? const CrmEmptyState(
                  icon: Icons.bar_chart_rounded,
                  title: 'No Leads Found',
                  subtitle: 'Add your first lead to get started',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 16),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _LeadCard(item: items[i]),
                ),
        ),
      ],
    );
  }
}

class _LeadCard extends StatelessWidget {
  const _LeadCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final name = sv(item, 'lead_name');
    final contact = sv(item, 'contact_person');
    final phone = sv(item, 'phone');
    final email = sv(item, 'email');
    final source = sv(item, 'source', '');
    final city = sv(item, 'city', '');
    final address = sv(item, 'address', '');

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
                        color: kCrmBlue)),
              ),
              if (source.isNotEmpty) CrmBadge(source),
            ],
          ),
          if (contact != '—') CrmInfoRow('Contact', contact, icon: Icons.person_outline),
          if (phone != '—') CrmInfoRow('Phone', phone, icon: Icons.phone_outlined),
          if (email != '—') CrmInfoRow('Email', email, icon: Icons.email_outlined),
          if (city.isNotEmpty || address.isNotEmpty)
            CrmInfoRow(
              'Location',
              [city, address].where((s) => s.isNotEmpty).join(', '),
              icon: Icons.location_on_outlined,
            ),
        ],
      ),
    );
  }
}

// ── Follow-ups Tab ────────────────────────────────────────────────────────────

class _FollowupsTab extends StatelessWidget {
  const _FollowupsTab({required this.model, required this.controller});
  final CompanyLeadsViewModel model;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final items = model.followups;
    return Column(
      children: [
        CrmSearchBar(
          controller: controller,
          hint: 'Search by Lead Name, Status...',
          onChanged: model.searchFollowups,
        ),
        Expanded(
          child: items.isEmpty
              ? const CrmEmptyState(
                  icon: Icons.follow_the_signs_rounded,
                  title: 'No Follow-ups Found',
                  subtitle: 'Follow-ups will appear here',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 16),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _FollowupCard(item: items[i]),
                ),
        ),
      ],
    );
  }
}

class _FollowupCard extends StatelessWidget {
  const _FollowupCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final name = sv(item, 'lead_name');
    final assigned = sv(item, 'assigned_to', '');
    final status = sv(item, 'status', '');
    final service = sv(item, 'service_name', '');
    final duration = sv(item, 'duration', '');

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
              if (status.isNotEmpty) CrmBadge(status),
            ],
          ),
          if (assigned.isNotEmpty)
            CrmInfoRow('Assigned', assigned, icon: Icons.person_outline),
          if (service.isNotEmpty || duration.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  if (service.isNotEmpty)
                    Expanded(
                      child: CrmInfoRow('Service', service,
                          icon: Icons.miscellaneous_services_outlined),
                    ),
                  if (duration.isNotEmpty)
                    CrmBadge('$duration days',
                        bg: const Color(0xffEEF1FB),
                        fg: kCrmBlue),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
