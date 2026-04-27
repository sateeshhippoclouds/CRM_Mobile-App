import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'company_tasks_viewmodel.dart';
import 'crm_widgets.dart';

class CompanyTasksView extends StatefulWidget {
  const CompanyTasksView({super.key});

  @override
  State<CompanyTasksView> createState() => _CompanyTasksViewState();
}

class _CompanyTasksViewState extends State<CompanyTasksView> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<CompanyTasksViewModel>.reactive(
      viewModelBuilder: () => CompanyTasksViewModel(),
      onViewModelReady: (m) => m.init(),
      builder: (context, model, child) {
        return Scaffold(
          backgroundColor: kCrmBg,
          appBar: crmAppBar('Tasks', actions: [
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
                          hint: 'Search by Title or Assignee...',
                          onChanged: model.search,
                        ),
                        Expanded(
                          child: model.items.isEmpty
                              ? const CrmEmptyState(
                                  icon: Icons.task_alt_rounded,
                                  title: 'No Tasks Found',
                                  subtitle: 'Create your first task to get started',
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                      0, 10, 0, 16),
                                  itemCount: model.items.length,
                                  itemBuilder: (_, i) =>
                                      _TaskCard(item: model.items[i]),
                                ),
                        ),
                      ],
                    ),
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final title = sv(item, 'title');
    final relatedTo = sv(item, 'related_to', '');
    final assignedTo = sv(item, 'assigned_to', '');
    final dueDate = sv(item, 'due_date', '');
    final startDate = sv(item, 'start_date', '');
    final priority = sv(item, 'priority', '');
    final taskType = sv(item, 'task_type', '');
    final notes = sv(item, 'notes', '');

    return CrmCard(
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff1A1F36))),
              ),
              const SizedBox(width: 8),
              if (priority.isNotEmpty) CrmBadge(priority),
            ],
          ),
          const SizedBox(height: 6),
          if (relatedTo.isNotEmpty || taskType.isNotEmpty)
            Row(
              children: [
                if (relatedTo.isNotEmpty)
                  Expanded(
                    child: CrmInfoRow('Related', relatedTo,
                        icon: Icons.link_rounded),
                  ),
                if (taskType.isNotEmpty) CrmBadge(taskType),
              ],
            ),
          if (assignedTo.isNotEmpty)
            CrmInfoRow('Assigned', assignedTo, icon: Icons.person_outline),
          if (startDate.isNotEmpty || dueDate.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: CrmDividerRow([
                if (startDate.isNotEmpty) CrmStat('Start Date', startDate),
                if (dueDate.isNotEmpty) CrmStat('Due Date', dueDate),
              ]),
            ),
          if (notes.isNotEmpty && notes != 'Not ment' && notes != '—')
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(notes,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xff6B7280)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    );
  }
}
