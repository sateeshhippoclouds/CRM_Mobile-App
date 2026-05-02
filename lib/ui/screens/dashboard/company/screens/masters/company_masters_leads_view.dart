import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'company_masters_leads_viewmodel.dart';
import 'masters_widgets.dart';

class CompanyMastersLeadsView extends StatelessWidget {
  const CompanyMastersLeadsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<CompanyMastersLeadsViewModel>.reactive(
      viewModelBuilder: () => CompanyMastersLeadsViewModel(),
      onViewModelReady: (m) => m.init(),
      builder: (context, model, child) {
        return Scaffold(
          backgroundColor: const Color(0xffF5F5F7),
          appBar: AppBar(
            backgroundColor: const Color(0xff3756DF),
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text('Leads Masters',
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
                      length: 4,
                      child: Column(
                        children: [
                          Container(
                            color: Colors.white,
                            child: const TabBar(
                              isScrollable: true,
                              tabAlignment: TabAlignment.start,
                              labelColor: Color(0xff3756DF),
                              unselectedLabelColor: Color(0xff6B7280),
                              indicatorColor: Color(0xff3756DF),
                              labelStyle: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12),
                              unselectedLabelStyle:
                                  TextStyle(fontSize: 12),
                              tabs: [
                                Tab(text: 'SOURCE TYPE'),
                                Tab(text: 'INTEREST LEVEL'),
                                Tab(text: 'LEAD STAGE'),
                                Tab(text: 'CATEGORY'),
                              ],
                            ),
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                MasterSimpleTab(
                                  items: model.sourceTypes,
                                  columnLabel: 'Source Type',
                                  hintText: 'Add new Source Type',
                                  onAdd: (v) => model.addItem(1, v),
                                  onEdit: (id, v) =>
                                      model.editItem(id, 1, v),
                                  onDelete: (id) =>
                                      model.deleteItem(id, 1),
                                  canWrite: model.canWrite,
                                  canUpdate: model.canUpdate,
                                  canDelete: model.canDelete,
                                ),
                                MasterSimpleTab(
                                  items: model.interestLevels,
                                  columnLabel: 'Interest Level',
                                  hintText: 'Add new Interest Level',
                                  onAdd: (v) => model.addItem(2, v),
                                  onEdit: (id, v) =>
                                      model.editItem(id, 2, v),
                                  onDelete: (id) =>
                                      model.deleteItem(id, 2),
                                  canWrite: model.canWrite,
                                  canUpdate: model.canUpdate,
                                  canDelete: model.canDelete,
                                ),
                                MasterSimpleTab(
                                  items: model.leadStages,
                                  columnLabel: 'Lead Stage',
                                  hintText: 'Add new Lead Stage',
                                  onAdd: (v) => model.addItem(3, v),
                                  onEdit: (id, v) =>
                                      model.editItem(id, 3, v),
                                  onDelete: (id) =>
                                      model.deleteItem(id, 3),
                                  canWrite: model.canWrite,
                                  canUpdate: model.canUpdate,
                                  canDelete: model.canDelete,
                                ),
                                MasterSimpleTab(
                                  items: model.categories,
                                  columnLabel: 'Category',
                                  hintText: 'Add new Category',
                                  onAdd: (v) => model.addItem(4, v),
                                  onEdit: (id, v) =>
                                      model.editItem(id, 4, v),
                                  onDelete: (id) =>
                                      model.deleteItem(id, 4),
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
