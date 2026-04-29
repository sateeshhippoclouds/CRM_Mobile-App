import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:stacked/stacked.dart';

import 'company_role_management_viewmodel.dart';

// Module order + display labels
const _modules = [
  'employees', 'bills', 'masters', 'leads',
  'clients', 'rolemanagement', 'services', 'followup', 'task',
];
const _moduleLabels = {
  'employees': 'Employees',
  'bills': 'Bills',
  'masters': 'Masters',
  'leads': 'Leads',
  'clients': 'Clients',
  'rolemanagement': 'Role Management',
  'services': 'Services',
  'followup': 'Followup',
  'task': 'Tasks',
};

class CompanyRoleManagementView extends StatelessWidget {
  const CompanyRoleManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<CompanyRoleManagementViewModel>.reactive(
      viewModelBuilder: () => CompanyRoleManagementViewModel(),
      onViewModelReady: (m) => m.init(),
      builder: (context, model, child) {
        return Scaffold(
          backgroundColor: const Color(0xffF5F5F7),
          appBar: AppBar(
            backgroundColor: const Color(0xff3756DF),
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text('Role Management',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18)),
          ),
          body: model.isBusy
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xff3756DF)))
              : model.fetchError != null
                  ? _ErrorBody(error: model.fetchError!, onRetry: model.init)
                  : _RolesBody(model: model),
        );
      },
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _RolesBody extends StatefulWidget {
  const _RolesBody({required this.model});
  final CompanyRoleManagementViewModel model;

  @override
  State<_RolesBody> createState() => _RolesBodyState();
}

class _RolesBodyState extends State<_RolesBody> {
  String _query = '';

  List<Map<String, dynamic>> get _filtered {
    if (_query.isEmpty) return widget.model.roles;
    final q = _query.toLowerCase();
    return widget.model.roles
        .where((r) =>
            (r['role_name']?.toString() ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── toolbar ──
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search roles...',
                    hintStyle: const TextStyle(
                        color: Color(0xff9E9E9E), fontSize: 14),
                    suffixIcon: const Icon(Icons.search,
                        color: Color(0xff9E9E9E)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Excel download
              GestureDetector(
                onTap: () => _downloadCsv(context, widget.model.roles),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xff3756DF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.download_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
              if (widget.model.canWrite) ...[
                const SizedBox(width: 10),
                // Add role button
                GestureDetector(
                  onTap: () => _showCreateDialog(context, widget.model),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xff3756DF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: Colors.white, size: 18),
                        SizedBox(width: 4),
                        Text('ADD ROLE',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── table ──
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3))
              ],
            ),
            child: Column(
              children: [
                // header
                _TableHeader(),
                const Divider(height: 1, color: Color(0xffF0F2F8)),
                // rows
                Expanded(
                  child: _filtered.isEmpty
                      ? const Center(
                          child: Text('No roles found.',
                              style: TextStyle(color: Color(0xff9E9E9E))))
                      : RefreshIndicator(
                          onRefresh: widget.model.init,
                          child: ListView.separated(
                            separatorBuilder: (_, __) => const Divider(
                                height: 1, color: Color(0xffF0F2F8)),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) => _RoleRow(
                              index: i + 1,
                              role: _filtered[i],
                              canUpdate: widget.model.canUpdate,
                              canDelete: widget.model.canDelete,
                              onView: () => _showPermissionsDialog(
                                  context, _filtered[i]),
                              onEdit: () => _showEditDialog(
                                  context, widget.model, _filtered[i]),
                              onDelete: () => _confirmDelete(
                                  context, widget.model, _filtered[i]),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── dialogs / actions ──────────────────────────────────────────────────────

  void _showCreateDialog(
      BuildContext context, CompanyRoleManagementViewModel model) {
    showDialog(
      context: context,
      builder: (_) => _RoleFormDialog(
        onSubmit: (data) => model.addRole(data),
      ),
    );
  }

  void _showEditDialog(BuildContext context,
      CompanyRoleManagementViewModel model, Map<String, dynamic> role) {
    showDialog(
      context: context,
      builder: (_) => _RoleFormDialog(
        existing: role,
        onSubmit: (data) => model.editRole(data),
      ),
    );
  }

  void _showPermissionsDialog(
      BuildContext context, Map<String, dynamic> role) {
    showDialog(
      context: context,
      builder: (_) => _PermissionsViewDialog(role: role),
    );
  }

  Future<void> _confirmDelete(BuildContext context,
      CompanyRoleManagementViewModel model, Map<String, dynamic> role) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Role'),
        content: Text(
            'Delete "${role['role_name']}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      try {
        await model.removeRole(role['id'] as int);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', ''))));
        }
      }
    }
  }

  Future<void> _downloadCsv(
      BuildContext context, List<Map<String, dynamic>> roles) async {
    try {
      // Build CSV rows
      final buf = StringBuffer();
      // Header
      buf.write('S.NO,Role Name,Self Only');
      for (final m in _modules) {
        final lbl = _moduleLabels[m] ?? m;
        buf.write(',$lbl Read,$lbl Write,$lbl Update,$lbl Delete');
      }
      buf.writeln();

      // Data rows
      for (int i = 0; i < roles.length; i++) {
        final r = roles[i];
        final perms = r['permissions'] as Map<String, dynamic>? ?? {};
        buf.write('${i + 1},');
        buf.write('"${r['role_name'] ?? ''}"');
        buf.write(',${r['self_only'] == true ? 'Yes' : 'No'}');
        for (final m in _modules) {
          final p = perms[m] as Map<String, dynamic>? ?? {};
          buf.write(',${p['can_read'] == true ? 'Yes' : 'No'}');
          buf.write(',${p['can_write'] == true ? 'Yes' : 'No'}');
          buf.write(',${p['can_update'] == true ? 'Yes' : 'No'}');
          buf.write(',${p['can_delete'] == true ? 'Yes' : 'No'}');
        }
        buf.writeln();
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/roles_export.csv');
      await file.writeAsString(buf.toString());

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv', name: 'roles_export.csv')],
        subject: 'Role Management Export',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }
}

// ── Table Header ──────────────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xffF8F9FB),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: const Row(
        children: [
          SizedBox(
            width: 60,
            child: Text('S.NO',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff6B7280))),
          ),
          Expanded(
            child: Text('Role Name',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff6B7280))),
          ),
          SizedBox(
            width: 100,
            child: Text('Permissions',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff6B7280))),
          ),
          SizedBox(
            width: 90,
            child: Text('Actions',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff6B7280))),
          ),
        ],
      ),
    );
  }
}

// ── Table Row ─────────────────────────────────────────────────────────────────

class _RoleRow extends StatelessWidget {
  const _RoleRow({
    required this.index,
    required this.role,
    required this.canUpdate,
    required this.canDelete,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });
  final int index;
  final Map<String, dynamic> role;
  final bool canUpdate;
  final bool canDelete;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = role['role_name']?.toString() ?? '—';
    final showActions = canUpdate || canDelete;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text('$index',
                style: const TextStyle(
                    fontSize: 14, color: Color(0xff6B7280))),
          ),
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff1A1F36))),
          ),
          // Permissions eye icon
          SizedBox(
            width: 100,
            child: Center(
              child: GestureDetector(
                onTap: onView,
                child: const Icon(Icons.remove_red_eye_rounded,
                    color: Color(0xff3756DF), size: 22),
              ),
            ),
          ),
          // Edit + Delete (hidden if no permissions)
          SizedBox(
            width: 90,
            child: showActions
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (canUpdate)
                        GestureDetector(
                          onTap: onEdit,
                          child: const Icon(Icons.edit_rounded,
                              color: Color(0xff3756DF), size: 20),
                        ),
                      if (canUpdate && canDelete) const SizedBox(width: 16),
                      if (canDelete)
                        GestureDetector(
                          onTap: onDelete,
                          child: const Icon(Icons.delete_rounded,
                              color: Color(0xffEF4444), size: 20),
                        ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── Permissions View Dialog ───────────────────────────────────────────────────

class _PermissionsViewDialog extends StatelessWidget {
  const _PermissionsViewDialog({required this.role});
  final Map<String, dynamic> role;

  @override
  Widget build(BuildContext context) {
    final name = role['role_name']?.toString() ?? '—';
    final perms = role['permissions'] as Map<String, dynamic>? ?? {};
    final selfOnly = role['self_only'] == true;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Text('Permissions for $name',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          const Divider(height: 1),
          // Table header
          Container(
            color: const Color(0xffF8F9FB),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text('Module Name',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xff6B7280))),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Permissions',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xff6B7280))),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Module rows
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ..._modules.map((m) {
                    final p = perms[m] as Map<String, dynamic>? ?? {};
                    return _PermRow(module: m, perms: p);
                  }),
                  // Self Only row
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        const Expanded(
                          flex: 2,
                          child: Text('Self Only',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xff374151))),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            selfOnly ? 'Enabled' : 'Disabled',
                            style: TextStyle(
                                fontSize: 13,
                                color: selfOnly
                                    ? const Color(0xff16A34A)
                                    : const Color(0xff6B7280)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _PermRow extends StatelessWidget {
  const _PermRow({required this.module, required this.perms});
  final String module;
  final Map<String, dynamic> perms;

  @override
  Widget build(BuildContext context) {
    final active = <String>[];
    if (perms['can_read'] == true) active.add('Read');
    if (perms['can_write'] == true) active.add('Write');
    if (perms['can_update'] == true) active.add('Update');
    if (perms['can_delete'] == true) active.add('Delete');

    const chipColors = {
      'Read': Color(0xff0EA5E9),
      'Write': Color(0xff22C55E),
      'Update': Color(0xffF59E0B),
      'Delete': Color(0xffEF4444),
    };

    return Column(
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(_moduleLabels[module] ?? module,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xff374151))),
              ),
              Expanded(
                flex: 3,
                child: active.isEmpty
                    ? const Text('No permissions',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xff9CA3AF)))
                    : Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: active.map((label) {
                          final color = chipColors[label]!;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              border: Border.all(color: color),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(label,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: color)),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xffF0F2F8)),
      ],
    );
  }
}

// ── Create / Edit Dialog ──────────────────────────────────────────────────────

class _RoleFormDialog extends StatefulWidget {
  const _RoleFormDialog({this.existing, required this.onSubmit});
  final Map<String, dynamic>? existing;
  final Future<void> Function(Map<String, dynamic>) onSubmit;

  @override
  State<_RoleFormDialog> createState() => _RoleFormDialogState();
}

class _RoleFormDialogState extends State<_RoleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  bool _selfOnly = false;
  bool _loading = false;
  String? _error;

  late Map<String, Map<String, bool>> _permissions;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
        text: widget.existing?['role_name']?.toString() ?? '');
    _selfOnly = widget.existing?['self_only'] == true;

    final ep =
        widget.existing?['permissions'] as Map<String, dynamic>? ?? {};
    _permissions = {
      for (final m in _modules)
        m: {
          'can_read': ep[m]?['can_read'] == true,
          'can_write': ep[m]?['can_write'] == true,
          'can_update': ep[m]?['can_update'] == true,
          'can_delete': ep[m]?['can_delete'] == true,
        }
    };
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = <String, dynamic>{
        if (widget.existing != null) 'id': widget.existing!['id'],
        'role_name': _nameCtrl.text.trim(),
        'self_only': _selfOnly,
        'permissions': _permissions,
      };
      await widget.onSubmit(data);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() =>
          _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + close
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isEdit ? 'Edit Role' : 'Create New Role',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xff3756DF)),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xffEEF1FB),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          size: 18, color: Color(0xff3756DF)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Role Name
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  hintText: 'Role Name',
                  filled: true,
                  fillColor: const Color(0xffF8F9FB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xffE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xffE5E7EB)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Required'
                    : null,
              ),
              const SizedBox(height: 16),

              // Permissions per module
              ..._modules.map((m) => _ModulePermRow(
                    module: m,
                    perms: _permissions[m]!,
                    onChanged: (key, val) => setState(() {
                      _permissions[m]![key] = val;
                      if (val && (key == 'can_write' || key == 'can_update' || key == 'can_delete')) {
                        _permissions[m]!['can_read'] = true;
                      } else if (!val && key == 'can_read') {
                        _permissions[m]!['can_write'] = false;
                        _permissions[m]!['can_update'] = false;
                        _permissions[m]!['can_delete'] = false;
                      }
                    }),
                  )),

              // Self Only
              Row(
                children: [
                  const Text('Self Only',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xff374151))),
                  const Spacer(),
                  Switch(
                    value: _selfOnly,
                    activeTrackColor: const Color(0xff3756DF),
                    onChanged: (v) => setState(() => _selfOnly = v),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              if (_error != null) ...[
                Text(_error!,
                    style: const TextStyle(
                        color: Colors.red, fontSize: 13)),
                const SizedBox(height: 8),
              ],

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff3756DF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          isEdit ? 'UPDATE ROLE' : 'CREATE ROLE',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              letterSpacing: 0.5),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModulePermRow extends StatelessWidget {
  const _ModulePermRow({
    required this.module,
    required this.perms,
    required this.onChanged,
  });
  final String module;
  final Map<String, bool> perms;
  final void Function(String key, bool val) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_moduleLabels[module] ?? module} Permissions',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff374151))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _CheckItem(
                  label: 'Read',
                  value: perms['can_read']!,
                  onChanged: (v) => onChanged('can_read', v)),
              _CheckItem(
                  label: 'Write',
                  value: perms['can_write']!,
                  onChanged: (v) => onChanged('can_write', v)),
              _CheckItem(
                  label: 'Update',
                  value: perms['can_update']!,
                  onChanged: (v) => onChanged('can_update', v)),
              _CheckItem(
                  label: 'Delete',
                  value: perms['can_delete']!,
                  onChanged: (v) => onChanged('can_delete', v)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  const _CheckItem({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: value,
            activeColor: const Color(0xff3756DF),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4)),
            onChanged: (v) => onChanged(v ?? false),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: Color(0xff374151))),
      ],
    );
  }
}

// ── Error body ────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
