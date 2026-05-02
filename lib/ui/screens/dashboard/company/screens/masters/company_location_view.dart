import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'company_location_viewmodel.dart';
import 'masters_widgets.dart';

class CompanyLocationView extends StatelessWidget {
  const CompanyLocationView({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<CompanyLocationViewModel>.reactive(
      viewModelBuilder: () => CompanyLocationViewModel(),
      onViewModelReady: (m) => m.init(),
      builder: (context, model, child) {
        return Scaffold(
          backgroundColor: const Color(0xffF5F5F7),
          appBar: AppBar(
            backgroundColor: const Color(0xff3756DF),
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text('Location',
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
                      length: 3,
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
                                  fontWeight: FontWeight.w600, fontSize: 12),
                              unselectedLabelStyle: TextStyle(fontSize: 12),
                              tabs: [
                                Tab(text: 'COUNTRIES'),
                                Tab(text: 'STATES'),
                                Tab(text: 'CITIES'),
                              ],
                            ),
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _CountriesTab(model: model),
                                _StatesTab(model: model),
                                _CitiesTab(model: model),
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

// ── Shared helpers ────────────────────────────────────────────────────────────

void _showError(BuildContext ctx, Object e) {
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
    content: Text(e.toString().replaceFirst('Exception: ', '')),
    backgroundColor: Colors.red,
  ));
}

Future<bool> _confirmDelete(BuildContext ctx, String entity) async {
  final result = await showDialog<bool>(
    context: ctx,
    builder: (_) => AlertDialog(
      insetPadding: const EdgeInsets.symmetric(vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text('Delete $entity'),
      content: const Text('Are you sure you want to delete this item?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel',
              style: TextStyle(color: Color(0xff6B7280))),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
  return result == true;
}

// ── Shared UI pieces ──────────────────────────────────────────────────────────

InputDecoration _inputDecoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xff9CA3AF)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xffE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xffE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xff3756DF)),
      ),
      filled: true,
      fillColor: Colors.white,
    );

Widget _addButton({
  required bool loading,
  required VoidCallback? onPressed,
  String label = 'ADD',
}) =>
    SizedBox(
      height: 42,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xff3756DF),
          disabledBackgroundColor: const Color(0xff9CA3AF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
      ),
    );

Widget _tableHeader(List<String> cols) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xffEEF1FB),
        border: Border(bottom: BorderSide(color: Color(0xffE5E7EB))),
      ),
      child: Row(
        children: cols.asMap().entries.map((e) {
          final isFirst = e.key == 0;
          final isLast = e.key == cols.length - 1;
          final text = Text(
            e.value,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xff374151)),
          );
          if (isFirst) return SizedBox(width: 40, child: text);
          if (isLast) return SizedBox(width: 80, child: text);
          return Expanded(child: text);
        }).toList(),
      ),
    );

Widget _tableRow({
  required int index,
  required List<String> values,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
}) {
  final showActions = onEdit != null || onDelete != null;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: index.isEven ? Colors.white : const Color(0xffF9FAFB),
      border:
          const Border(bottom: BorderSide(color: Color(0xffF3F4F6))),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 40,
          child: Text('${index + 1}',
              style: const TextStyle(fontSize: 12, color: Color(0xff6B7280))),
        ),
        ...values.map((v) => Expanded(
              child: Text(v,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xff1F2937))),
            )),
        if (showActions)
          SizedBox(
            width: 80,
            child: Row(
              children: [
                if (onEdit != null)
                  InkWell(
                    onTap: onEdit,
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.edit_outlined,
                          size: 16, color: Color(0xff3756DF)),
                    ),
                  ),
                if (onEdit != null && onDelete != null)
                  const SizedBox(width: 4),
                if (onDelete != null)
                  InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline,
                          size: 16, color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}

Widget _countryDropdown({
  required List<Map<String, dynamic>> countries,
  required int? value,
  required String hint,
  required ValueChanged<int?> onChanged,
}) =>
    Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<int>(
        value: value,
        hint: Text(hint,
            style:
                const TextStyle(fontSize: 13, color: Color(0xff9CA3AF))),
        isExpanded: true,
        underline: const SizedBox.shrink(),
        items: countries
            .map((c) => DropdownMenuItem<int>(
                  value: c['id'] as int,
                  child: Text(c['name'] as String,
                      style: const TextStyle(fontSize: 13)),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );

// ── Countries Tab ─────────────────────────────────────────────────────────────

class _CountriesTab extends StatefulWidget {
  const _CountriesTab({required this.model});
  final CompanyLocationViewModel model;

  @override
  State<_CountriesTab> createState() => _CountriesTabState();
}

class _CountriesTabState extends State<_CountriesTab> {
  final _ctrl = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _adding = true);
    try {
      await widget.model.addCountry(name);
      if (mounted) _ctrl.clear();
    } catch (e) {
      if (mounted) _showError(context, e);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _SingleFieldDialog(
        title: 'Edit Country',
        label: 'Country Name',
        initialValue: item['name'] as String,
      ),
    );
    if (result != null && mounted) {
      try {
        await widget.model.updateCountry(item['id'] as int, result);
      } catch (e) {
        if (mounted) _showError(context, e);
      }
    }
  }

  Future<void> _delete(int id) async {
    if (!await _confirmDelete(context, 'Country')) return;
    try {
      await widget.model.deleteCountry(id);
    } catch (e) {
      if (mounted) _showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.model.countries;
    final canWrite = widget.model.canWrite;
    final canUpdate = widget.model.canUpdate;
    final canDelete = widget.model.canDelete;
    return Column(
      children: [
        if (canWrite)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: _inputDecoration('Add Country'),
                    style: const TextStyle(fontSize: 13),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                _addButton(loading: _adding, onPressed: _adding ? null : _add),
              ],
            ),
          ),
        _tableHeader(
            canUpdate || canDelete
                ? const ['S.No', 'Country', 'Actions']
                : const ['S.No', 'Country']),
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Text('No countries added yet.',
                      style: TextStyle(
                          color: Color(0xff9CA3AF), fontSize: 13)))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) => _tableRow(
                    index: i,
                    values: [items[i]['name'] as String],
                    onEdit: canUpdate ? () => _edit(items[i]) : null,
                    onDelete: canDelete
                        ? () => _delete(items[i]['id'] as int)
                        : null,
                  ),
                ),
        ),
      ],
    );
  }
}

// ── States Tab ────────────────────────────────────────────────────────────────

class _StatesTab extends StatefulWidget {
  const _StatesTab({required this.model});
  final CompanyLocationViewModel model;

  @override
  State<_StatesTab> createState() => _StatesTabState();
}

class _StatesTabState extends State<_StatesTab> {
  final _ctrl = TextEditingController();
  int? _filterCountryId;
  bool _adding = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered => _filterCountryId == null
      ? widget.model.states
      : widget.model.states
          .where((s) => s['country_id'] == _filterCountryId)
          .toList();

  Future<void> _add() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty || _filterCountryId == null) return;
    setState(() => _adding = true);
    try {
      await widget.model.addState(name, _filterCountryId!);
      if (mounted) _ctrl.clear();
    } catch (e) {
      if (mounted) _showError(context, e);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    final result = await showDialog<_StateResult>(
      context: context,
      builder: (_) => _StateEditDialog(
        countries: widget.model.countries,
        initialName: item['name'] as String,
        initialCountryId: item['country_id'] as int,
      ),
    );
    if (result != null && mounted) {
      try {
        await widget.model.updateState(
            item['id'] as int, result.name, result.countryId);
      } catch (e) {
        if (mounted) _showError(context, e);
      }
    }
  }

  Future<void> _delete(int id) async {
    if (!await _confirmDelete(context, 'State')) return;
    try {
      await widget.model.deleteState(id);
    } catch (e) {
      if (mounted) _showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    final canWrite = widget.model.canWrite;
    final canUpdate = widget.model.canUpdate;
    final canDelete = widget.model.canDelete;
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _countryDropdown(
                countries: widget.model.countries,
                value: _filterCountryId,
                hint: 'Select Country',
                onChanged: (v) => setState(() {
                  _filterCountryId = v;
                  _ctrl.clear();
                }),
              ),
              if (canWrite) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        enabled: _filterCountryId != null,
                        decoration: _inputDecoration('Add State'),
                        style: const TextStyle(fontSize: 13),
                        onSubmitted: (_) => _add(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _addButton(
                      loading: _adding,
                      onPressed: (_adding || _filterCountryId == null)
                          ? null
                          : _add,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        _tableHeader(
            canUpdate || canDelete
                ? const ['S.No', 'State', 'Country', 'Actions']
                : const ['S.No', 'State', 'Country']),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    _filterCountryId == null
                        ? 'Select a country to view states.'
                        : 'No states found for selected country.',
                    style: const TextStyle(
                        color: Color(0xff9CA3AF), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) => _tableRow(
                    index: i,
                    values: [
                      items[i]['name'] as String,
                      items[i]['country_name'] as String? ?? '',
                    ],
                    onEdit: canUpdate ? () => _edit(items[i]) : null,
                    onDelete: canDelete
                        ? () => _delete(items[i]['id'] as int)
                        : null,
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Cities Tab ────────────────────────────────────────────────────────────────

class _CitiesTab extends StatefulWidget {
  const _CitiesTab({required this.model});
  final CompanyLocationViewModel model;

  @override
  State<_CitiesTab> createState() => _CitiesTabState();
}

class _CitiesTabState extends State<_CitiesTab> {
  final _ctrl = TextEditingController();
  int? _filterCountryId;
  int? _filterStateId;
  bool _adding = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _statesForCountry =>
      _filterCountryId == null
          ? []
          : widget.model.states
              .where((s) => s['country_id'] == _filterCountryId)
              .toList();

  List<Map<String, dynamic>> get _filtered => _filterStateId == null
      ? widget.model.cities
      : widget.model.cities
          .where((c) => c['state_id'] == _filterStateId)
          .toList();

  Future<void> _add() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty || _filterStateId == null || _filterCountryId == null) {
      return;
    }
    setState(() => _adding = true);
    try {
      await widget.model.addCity(name, _filterStateId!, _filterCountryId!);
      if (mounted) _ctrl.clear();
    } catch (e) {
      if (mounted) _showError(context, e);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    final result = await showDialog<_CityResult>(
      context: context,
      builder: (_) => _CityEditDialog(
        countries: widget.model.countries,
        states: widget.model.states,
        initialName: item['name'] as String,
        initialCountryId: item['country_id'] as int,
        initialStateId: item['state_id'] as int,
      ),
    );
    if (result != null && mounted) {
      try {
        await widget.model.updateCity(
            item['id'] as int, result.name, result.stateId, result.countryId);
      } catch (e) {
        if (mounted) _showError(context, e);
      }
    }
  }

  Future<void> _delete(int id) async {
    if (!await _confirmDelete(context, 'City')) return;
    try {
      await widget.model.deleteCity(id);
    } catch (e) {
      if (mounted) _showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    final statesForCountry = _statesForCountry;
    final canWrite = widget.model.canWrite;
    final canUpdate = widget.model.canUpdate;
    final canDelete = widget.model.canDelete;

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _countryDropdown(
                countries: widget.model.countries,
                value: _filterCountryId,
                hint: 'Select Country',
                onChanged: (v) => setState(() {
                  _filterCountryId = v;
                  _filterStateId = null;
                  _ctrl.clear();
                }),
              ),
              const SizedBox(height: 8),
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: _filterCountryId == null
                      ? const Color(0xffF9FAFB)
                      : Colors.white,
                  border: Border.all(color: const Color(0xffE5E7EB)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<int>(
                  value: _filterStateId,
                  hint: Text(
                    _filterCountryId == null
                        ? 'Select Country first'
                        : 'Select State',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xff9CA3AF)),
                  ),
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: statesForCountry
                      .map((s) => DropdownMenuItem<int>(
                            value: s['id'] as int,
                            child: Text(s['name'] as String,
                                style: const TextStyle(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: _filterCountryId == null
                      ? null
                      : (v) => setState(() {
                            _filterStateId = v;
                            _ctrl.clear();
                          }),
                ),
              ),
              if (canWrite) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        enabled: _filterStateId != null,
                        decoration: _inputDecoration('Add City'),
                        style: const TextStyle(fontSize: 13),
                        onSubmitted: (_) => _add(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _addButton(
                      loading: _adding,
                      onPressed: (_adding || _filterStateId == null)
                          ? null
                          : _add,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        _tableHeader(
            canUpdate || canDelete
                ? const ['S.No', 'City', 'Country', 'State', 'Actions']
                : const ['S.No', 'City', 'Country', 'State']),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    _filterStateId == null
                        ? 'Select a country and state to view cities.'
                        : 'No cities found for selected state.',
                    style: const TextStyle(
                        color: Color(0xff9CA3AF), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) => _tableRow(
                    index: i,
                    values: [
                      items[i]['name'] as String,
                      items[i]['country_name'] as String? ?? '',
                      items[i]['state_name'] as String? ?? '',
                    ],
                    onEdit: canUpdate ? () => _edit(items[i]) : null,
                    onDelete: canDelete
                        ? () => _delete(items[i]['id'] as int)
                        : null,
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Dialogs ───────────────────────────────────────────────────────────────────

class _SingleFieldDialog extends StatefulWidget {
  const _SingleFieldDialog({
    required this.title,
    required this.label,
    required this.initialValue,
  });
  final String title, label, initialValue;

  @override
  State<_SingleFieldDialog> createState() => _SingleFieldDialogState();
}

class _SingleFieldDialogState extends State<_SingleFieldDialog> {
  late final TextEditingController _ctrl;

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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(widget.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      content: TextField(
        controller: _ctrl,
        decoration: _inputDecoration(widget.label),
        style: const TextStyle(fontSize: 13),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: Color(0xff6B7280))),
        ),
        ElevatedButton(
          onPressed: () {
            final v = _ctrl.text.trim();
            if (v.isNotEmpty) Navigator.pop(context, v);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xff3756DF),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Save',
              style: TextStyle(color: Colors.white, fontSize: 13)),
        ),
      ],
    );
  }
}

class _StateResult {
  final String name;
  final int countryId;
  const _StateResult(this.name, this.countryId);
}

class _StateEditDialog extends StatefulWidget {
  const _StateEditDialog({
    required this.countries,
    required this.initialName,
    required this.initialCountryId,
  });
  final List<Map<String, dynamic>> countries;
  final String initialName;
  final int initialCountryId;

  @override
  State<_StateEditDialog> createState() => _StateEditDialogState();
}

class _StateEditDialogState extends State<_StateEditDialog> {
  late final TextEditingController _nameCtrl;
  late int _selectedCountryId;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _selectedCountryId = widget.initialCountryId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('Edit State',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _countryDropdown(
            countries: widget.countries,
            value: _selectedCountryId,
            hint: 'Select Country',
            onChanged: (v) {
              if (v != null) setState(() => _selectedCountryId = v);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: _inputDecoration('State Name'),
            style: const TextStyle(fontSize: 13),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: Color(0xff6B7280))),
        ),
        ElevatedButton(
          onPressed: () {
            final v = _nameCtrl.text.trim();
            if (v.isNotEmpty) {
              Navigator.pop(
                  context, _StateResult(v, _selectedCountryId));
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xff3756DF),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Save',
              style: TextStyle(color: Colors.white, fontSize: 13)),
        ),
      ],
    );
  }
}

class _CityResult {
  final String name;
  final int countryId;
  final int stateId;
  const _CityResult(this.name, this.countryId, this.stateId);
}

class _CityEditDialog extends StatefulWidget {
  const _CityEditDialog({
    required this.countries,
    required this.states,
    required this.initialName,
    required this.initialCountryId,
    required this.initialStateId,
  });
  final List<Map<String, dynamic>> countries;
  final List<Map<String, dynamic>> states;
  final String initialName;
  final int initialCountryId;
  final int initialStateId;

  @override
  State<_CityEditDialog> createState() => _CityEditDialogState();
}

class _CityEditDialogState extends State<_CityEditDialog> {
  late final TextEditingController _nameCtrl;
  late int _selectedCountryId;
  late int? _selectedStateId;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _selectedCountryId = widget.initialCountryId;
    _selectedStateId = widget.initialStateId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _statesForCountry => widget.states
      .where((s) => s['country_id'] == _selectedCountryId)
      .toList();

  @override
  Widget build(BuildContext context) {
    final statesForCountry = _statesForCountry;
    // Reset state selection if the state no longer belongs to new country
    if (_selectedStateId != null &&
        !statesForCountry.any((s) => s['id'] == _selectedStateId)) {
      _selectedStateId = null;
    }

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('Edit City',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _countryDropdown(
            countries: widget.countries,
            value: _selectedCountryId,
            hint: 'Select Country',
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  _selectedCountryId = v;
                  _selectedStateId = null;
                });
              }
            },
          ),
          const SizedBox(height: 12),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xffE5E7EB)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<int>(
              value: _selectedStateId,
              hint: const Text('Select State',
                  style:
                      TextStyle(fontSize: 13, color: Color(0xff9CA3AF))),
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: statesForCountry
                  .map((s) => DropdownMenuItem<int>(
                        value: s['id'] as int,
                        child: Text(s['name'] as String,
                            style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedStateId = v),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: _inputDecoration('City Name'),
            style: const TextStyle(fontSize: 13),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: Color(0xff6B7280))),
        ),
        ElevatedButton(
          onPressed: () {
            final v = _nameCtrl.text.trim();
            if (v.isNotEmpty && _selectedStateId != null) {
              Navigator.pop(context,
                  _CityResult(v, _selectedCountryId, _selectedStateId!));
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xff3756DF),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Save',
              style: TextStyle(color: Colors.white, fontSize: 13)),
        ),
      ],
    );
  }
}
