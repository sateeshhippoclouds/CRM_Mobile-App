import 'package:flutter/material.dart';

const _kBlue = Color(0xff3756DF);
const _kHeaderStyle = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xff6B7280));
const _kCellStyle = TextStyle(fontSize: 14, color: Color(0xff6B7280));
const _kValueStyle = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xff1A1F36));

// ─────────────────────────────────────────────────────────────────────────────
// Error body (reused across all masters screens)
// ─────────────────────────────────────────────────────────────────────────────

class MasterErrorBody extends StatelessWidget {
  const MasterErrorBody(
      {super.key, required this.error, required this.onRetry});
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
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue, foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Simple tab — input + table with S.No / Value / Actions
// ─────────────────────────────────────────────────────────────────────────────

class MasterSimpleTab extends StatefulWidget {
  const MasterSimpleTab({
    super.key,
    required this.items,
    required this.columnLabel,
    required this.hintText,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    this.canWrite = true,
    this.canUpdate = true,
    this.canDelete = true,
  });

  final List<Map<String, dynamic>> items;
  final String columnLabel;
  final String hintText;
  final Future<void> Function(String value) onAdd;
  final Future<void> Function(int id, String value) onEdit;
  final Future<void> Function(int id) onDelete;
  final bool canWrite;
  final bool canUpdate;
  final bool canDelete;

  @override
  State<MasterSimpleTab> createState() => _MasterSimpleTabState();
}

class _MasterSimpleTabState extends State<MasterSimpleTab> {
  final _ctrl = TextEditingController();
  bool _adding = false;
  String? _addError;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleAdd() async {
    final v = _ctrl.text.trim();
    if (v.isEmpty) {
      setState(() => _addError = 'Required');
      return;
    }
    setState(() {
      _adding = true;
      _addError = null;
    });
    try {
      await widget.onAdd(v);
      _ctrl.clear();
    } catch (e) {
      if (mounted) {
        setState(
            () => _addError = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.canWrite)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: const TextStyle(
                          color: Color(0xff9E9E9E), fontSize: 14),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
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
                      errorText: _addError,
                      errorStyle: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _adding ? null : _handleAdd,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: _adding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('ADD',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ],
            ),
          ),
        Expanded(
          child: _MasterTable(
            columnLabel: widget.columnLabel,
            items: widget.items,
            onEdit: (id, val) => _showEditDialog(context, id, val),
            onDelete: (id, val) => _confirmDelete(context, id, val),
            canUpdate: widget.canUpdate,
            canDelete: widget.canDelete,
          ),
        ),
      ],
    );
  }

  void _showEditDialog(BuildContext ctx, int id, String current) {
    showDialog(
      context: ctx,
      builder: (_) => _SimpleEditDialog(
          initialValue: current, onSave: (v) => widget.onEdit(id, v)),
    );
  }

  Future<void> _confirmDelete(
      BuildContext ctx, int id, String val) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(vertical: 24),
        title: const Text('Delete'),
        content: Text('Delete "$val"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true && ctx.mounted) {
      try {
        await widget.onDelete(id);
      } catch (e) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
              content: Text(
                  e.toString().replaceFirst('Exception: ', ''))));
        }
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Terms tab — title + notes list
// ─────────────────────────────────────────────────────────────────────────────

class MasterTermsTab extends StatefulWidget {
  const MasterTermsTab({
    super.key,
    required this.items,
    required this.addButtonLabel,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    this.canWrite = true,
    this.canUpdate = true,
    this.canDelete = true,
  });

  final List<Map<String, dynamic>> items;
  final String addButtonLabel;
  final Future<void> Function(String title, List<String> notes) onAdd;
  final Future<void> Function(int id, String title, List<String> notes) onEdit;
  final Future<void> Function(int id) onDelete;
  final bool canWrite;
  final bool canUpdate;
  final bool canDelete;

  @override
  State<MasterTermsTab> createState() => _MasterTermsTabState();
}

class _MasterTermsTabState extends State<MasterTermsTab> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.canWrite)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => _showFormDialog(null),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                      color: _kBlue,
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, color: Colors.white, size: 18),
                      const SizedBox(width: 4),
                      Text(widget.addButtonLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                Container(
                  color: const Color(0xffF8F9FB),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: const Row(
                    children: [
                      SizedBox(
                          width: 50,
                          child: Text('S.No', style: _kHeaderStyle)),
                      Expanded(
                          flex: 2,
                          child: Text('Title', style: _kHeaderStyle)),
                      Expanded(
                          flex: 3,
                          child: Text('Terms', style: _kHeaderStyle)),
                      SizedBox(
                          width: 100,
                          child: Text('Actions',
                              textAlign: TextAlign.center,
                              style: _kHeaderStyle)),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xffF0F2F8)),
                Expanded(
                  child: widget.items.isEmpty
                      ? const Center(
                          child: Text('No items found.',
                              style: TextStyle(
                                  color: Color(0xff9E9E9E))))
                      : ListView.separated(
                          separatorBuilder: (_, __) => const Divider(
                              height: 1, color: Color(0xffF0F2F8)),
                          itemCount: widget.items.length,
                          itemBuilder: (_, i) {
                            final item = widget.items[i];
                            final id = item['id'] as int;
                            final title =
                                item['title']?.toString() ?? '—';
                            final notes = _parseNotes(item['notes']);
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  SizedBox(
                                      width: 50,
                                      child: Text('${i + 1}',
                                          style: _kCellStyle)),
                                  Expanded(
                                      flex: 2,
                                      child: Text(title,
                                          style: _kValueStyle)),
                                  Expanded(
                                    flex: 3,
                                    child: Row(
                                      children: [
                                        const Icon(
                                            Icons
                                                .format_list_bulleted_rounded,
                                            size: 15,
                                            color: Color(0xff6B7280)),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${notes.length} point${notes.length == 1 ? '' : 's'}',
                                          style: _kCellStyle,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 100,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        GestureDetector(
                                          onTap: () => _showViewDialog(
                                              title, notes),
                                          child: const Icon(
                                              Icons
                                                  .remove_red_eye_rounded,
                                              color: Color(0xff22C55E),
                                              size: 20),
                                        ),
                                        if (widget.canUpdate) ...[
                                          const SizedBox(width: 10),
                                          GestureDetector(
                                            onTap: () =>
                                                _showFormDialog(item),
                                            child: const Icon(
                                                Icons.edit_rounded,
                                                color: _kBlue,
                                                size: 20),
                                          ),
                                        ],
                                        if (widget.canDelete) ...[
                                          const SizedBox(width: 10),
                                          GestureDetector(
                                            onTap: () =>
                                                _confirmDelete(id, title),
                                            child: const Icon(
                                                Icons.delete_rounded,
                                                color: Color(0xffEF4444),
                                                size: 20),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<String> _parseNotes(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return [];
  }

  void _showViewDialog(String title, List<String> notes) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(vertical: 24),
        title: Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700)),
        content: notes.isEmpty
            ? const Text('No terms/notes added.',
                style: TextStyle(color: Color(0xff9E9E9E)))
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: notes
                      .asMap()
                      .entries
                      .map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text('${e.key + 1}. ',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                Expanded(
                                    child: Text(e.value,
                                        style: const TextStyle(
                                            fontSize: 13))),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'))
        ],
      ),
    );
  }

  void _showFormDialog(Map<String, dynamic>? existing) {
    showDialog(
      context: context,
      builder: (_) => _TermsFormDialog(
        existing: existing,
        onSubmit: existing == null
            ? (title, notes) => widget.onAdd(title, notes)
            : (title, notes) =>
                widget.onEdit(existing['id'] as int, title, notes),
      ),
    );
  }

  Future<void> _confirmDelete(int id, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(vertical: 24),
        title: const Text('Delete'),
        content: Text('Delete "$title"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        await widget.onDelete(id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  e.toString().replaceFirst('Exception: ', ''))));
        }
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal shared table
// ─────────────────────────────────────────────────────────────────────────────

class _MasterTable extends StatelessWidget {
  const _MasterTable({
    required this.columnLabel,
    required this.items,
    required this.onEdit,
    required this.onDelete,
    this.canUpdate = true,
    this.canDelete = true,
  });

  final String columnLabel;
  final List<Map<String, dynamic>> items;
  final void Function(int id, String val) onEdit;
  final void Function(int id, String val) onDelete;
  final bool canUpdate;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
          Container(
            color: const Color(0xffF8F9FB),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const SizedBox(
                    width: 50,
                    child: Text('S.No', style: _kHeaderStyle)),
                Expanded(child: Text(columnLabel, style: _kHeaderStyle)),
                if (canUpdate || canDelete)
                  const SizedBox(
                      width: 90,
                      child: Text('Actions',
                          textAlign: TextAlign.center,
                          style: _kHeaderStyle)),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xffF0F2F8)),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text('No items found.',
                        style: TextStyle(color: Color(0xff9E9E9E))))
                : ListView.separated(
                    separatorBuilder: (_, __) => const Divider(
                        height: 1, color: Color(0xffF0F2F8)),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final item = items[i];
                      final id = item['id'] as int;
                      final val = item['value']?.toString() ?? '—';
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            SizedBox(
                                width: 50,
                                child: Text('${i + 1}',
                                    style: _kCellStyle)),
                            Expanded(
                                child: Text(val, style: _kValueStyle)),
                            if (canUpdate || canDelete)
                              SizedBox(
                                width: 90,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    if (canUpdate)
                                      GestureDetector(
                                        onTap: () => onEdit(id, val),
                                        child: const Icon(
                                            Icons.edit_rounded,
                                            color: _kBlue,
                                            size: 20),
                                      ),
                                    if (canUpdate && canDelete)
                                      const SizedBox(width: 16),
                                    if (canDelete)
                                      GestureDetector(
                                        onTap: () => onDelete(id, val),
                                        child: const Icon(
                                            Icons.delete_rounded,
                                            color: Color(0xffEF4444),
                                            size: 20),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Simple edit dialog
// ─────────────────────────────────────────────────────────────────────────────

class _SimpleEditDialog extends StatefulWidget {
  const _SimpleEditDialog(
      {required this.initialValue, required this.onSave});
  final String initialValue;
  final Future<void> Function(String) onSave;

  @override
  State<_SimpleEditDialog> createState() => _SimpleEditDialogState();
}

class _SimpleEditDialogState extends State<_SimpleEditDialog> {
  late final TextEditingController _ctrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = _ctrl.text.trim();
    if (v.isEmpty) {
      setState(() => _error = 'Required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(v);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(
            () => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(vertical: 24),
      title: const Text('Edit',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: InputDecoration(
          errorText: _error,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
              backgroundColor: _kBlue, foregroundColor: Colors.white),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Terms form dialog (title + dynamic notes list)
// ─────────────────────────────────────────────────────────────────────────────

class _TermsFormDialog extends StatefulWidget {
  const _TermsFormDialog({this.existing, required this.onSubmit});
  final Map<String, dynamic>? existing;
  final Future<void> Function(String title, List<String> notes) onSubmit;

  @override
  State<_TermsFormDialog> createState() => _TermsFormDialogState();
}

class _TermsFormDialogState extends State<_TermsFormDialog> {
  final _titleCtrl = TextEditingController();
  // Active controllers shown in the form
  final List<TextEditingController> _noteCtrls = [];
  // All ever-created controllers — disposed in dispose() even if removed
  final List<TextEditingController> _allCtrls = [];
  bool _saving = false;
  String? _error;

  TextEditingController _newCtrl([String text = '']) {
    final c = TextEditingController(text: text);
    _allCtrls.add(c);
    return c;
  }

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _titleCtrl.text = widget.existing!['title']?.toString() ?? '';
      final raw = widget.existing!['notes'];
      if (raw is List && raw.isNotEmpty) {
        for (final n in raw) {
          _noteCtrls.add(_newCtrl(n.toString()));
        }
      }
    }
    if (_noteCtrls.isEmpty) _noteCtrls.add(_newCtrl());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    for (final c in _allCtrls) {
      c.dispose(); // dispose every controller ever created
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required');
      return;
    }
    final notes = _noteCtrls
        .map((c) => c.text.trim())
        .where((v) => v.isNotEmpty)
        .toList();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(title, notes);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(
            () => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addNote() => setState(() => _noteCtrls.add(_newCtrl()));

  void _removeNote(int i) {
    // Do NOT dispose here — controller is still referenced by the widget tree
    // until the next frame. _allCtrls tracks it for disposal in dispose().
    setState(() => _noteCtrls.removeAt(i));
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(vertical: 24),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isEdit ? 'Edit Terms' : 'Add Terms',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _kBlue),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        color: Color(0xffEEF1FB),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.close,
                        size: 18, color: _kBlue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Title',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff374151))),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                hintText: 'Enter title',
                filled: true,
                fillColor: const Color(0xffF8F9FB),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xffE5E7EB))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xffE5E7EB))),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text('Terms / Notes',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xff374151))),
                ),
                GestureDetector(
                  onTap: _addNote,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: const Color(0xffEEF1FB),
                        borderRadius: BorderRadius.circular(6)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 14, color: _kBlue),
                        SizedBox(width: 2),
                        Text('Add Point',
                            style: TextStyle(
                                fontSize: 12,
                                color: _kBlue,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(
              _noteCtrls.length,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text('${i + 1}. ',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xff374151))),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _noteCtrls[i],
                        decoration: InputDecoration(
                          hintText: 'Enter point ${i + 1}',
                          filled: true,
                          fillColor: const Color(0xffF8F9FB),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: Color(0xffE5E7EB))),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: Color(0xffE5E7EB))),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_noteCtrls.length > 1) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _removeNote(i),
                        child: const Icon(Icons.close,
                            size: 18, color: Color(0xffEF4444)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(_error!,
                  style: const TextStyle(
                      color: Colors.red, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(isEdit ? 'UPDATE' : 'CREATE',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
