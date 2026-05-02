import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'company_terms_viewmodel.dart';
import 'masters_widgets.dart';

class CompanyTermsView extends StatelessWidget {
  const CompanyTermsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<CompanyTermsViewModel>.reactive(
      viewModelBuilder: () => CompanyTermsViewModel(),
      onViewModelReady: (m) => m.init(),
      builder: (context, model, child) {
        return Scaffold(
          backgroundColor: const Color(0xffF5F5F7),
          appBar: AppBar(
            backgroundColor: const Color(0xff3756DF),
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text('CRM',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18)),
          ),
          body: model.isBusy
              ? const Center(
                  child:
                      CircularProgressIndicator(color: Color(0xff3756DF)))
              : model.fetchError != null
                  ? MasterErrorBody(
                      error: model.fetchError!, onRetry: model.init)
                  : DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          Container(
                            color: Colors.white,
                            child: const TabBar(
                              labelColor: Color(0xff3756DF),
                              unselectedLabelColor: Color(0xff6B7280),
                              indicatorColor: Color(0xff3756DF),
                              labelStyle: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12),
                              unselectedLabelStyle:
                                  TextStyle(fontSize: 12),
                              tabs: [
                                Tab(text: 'FOLLOWUP TERMS'),
                                Tab(text: 'CLIENT TERMS'),
                              ],
                            ),
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                MasterTermsTab(
                                  items: model.followupQuotations,
                                  addButtonLabel: 'ADD FOLLOWUP QUOTATION',
                                  onAdd: (title, notes) =>
                                      model.addItem(1, title, notes),
                                  onEdit: (id, title, notes) =>
                                      model.editItem(id, 1, title, notes),
                                  onDelete: (id) =>
                                      model.deleteItem(id, 1),
                                  canWrite: model.canWrite,
                                  canUpdate: model.canUpdate,
                                  canDelete: model.canDelete,
                                ),
                                MasterTermsTab(
                                  items: model.clientQuotations,
                                  addButtonLabel: 'ADD CLIENT TERMS',
                                  onAdd: (title, notes) =>
                                      model.addItem(2, title, notes),
                                  onEdit: (id, title, notes) =>
                                      model.editItem(id, 2, title, notes),
                                  onDelete: (id) =>
                                      model.deleteItem(id, 2),
                                  canWrite: model.canWrite,
                                  canUpdate: model.canUpdate,
                                  canDelete: model.canDelete,
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
