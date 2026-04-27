import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'company_masters_clients_viewmodel.dart';
import 'masters_widgets.dart';

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
            title: const Text('Clients Masters',
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
                                Tab(text: 'PREFERRED PAYMENT'),
                                Tab(text: 'PAYMENT TERMS'),
                              ],
                            ),
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                MasterSimpleTab(
                                  items: model.preferredPayments,
                                  columnLabel: 'Preferred Payment',
                                  hintText: 'Add new Preferred Payment',
                                  onAdd: (v) => model.addItem(1, v),
                                  onEdit: (id, v) =>
                                      model.editItem(id, 1, v),
                                  onDelete: (id) =>
                                      model.deleteItem(id, 1),
                                ),
                                MasterSimpleTab(
                                  items: model.paymentTerms,
                                  columnLabel: 'Payment Terms',
                                  hintText: 'Add new Payment Terms',
                                  onAdd: (v) => model.addItem(2, v),
                                  onEdit: (id, v) =>
                                      model.editItem(id, 2, v),
                                  onDelete: (id) =>
                                      model.deleteItem(id, 2),
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
