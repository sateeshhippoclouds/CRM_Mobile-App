import 'package:flutter/material.dart';

import '../../../app/app.locator.dart';
import '../../../models/call_record_model.dart';
import '../../../services/api_services.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _blue   = Color(0xff3756DF);
const _green  = Color(0xff22C55E);
const _red    = Color(0xffEF4444);
const _orange = Color(0xffF59E0B);
const _text1  = Color(0xff1A1F36);
const _text2  = Color(0xff6B7280);
const _bg     = Color(0xffF5F5F7);
const double _rowH    = 52;
const double _headerH = 44;

// ── Column definitions ────────────────────────────────────────────────────────
class _Col {
  final String field;
  final String label;
  final double width;
  const _Col(this.field, this.label, this.width);
}

const _cols = [
  _Col('id',               'S.No',         60),
  _Col('phone_number',     'Phone Number', 150),
  _Col('contact_name',     'Contact Name', 150),
  _Col('contact_id',       'Contact ID',   110),
  _Col('contact_type',     'Contact Type', 120),
  _Col('lead_id',          'Lead ID',       90),
  _Col('start_time',       'Start Time',   160),
  _Col('duration_seconds', 'Duration (s)', 110),
  _Col('call_status',      'Call Status',  120),
  _Col('employee_name',    'Employee',     140),
  _Col('created_at',       'Created At',  160),
];

// ── Main view ─────────────────────────────────────────────────────────────────
class CallTestView extends StatefulWidget {
  const CallTestView({super.key});

  @override
  State<CallTestView> createState() => _CallTestViewState();
}

class _CallTestViewState extends State<CallTestView> {
  final _api = locator<HippoAuthService>();

  List<Map<String, dynamic>> _rows = [];
  int _total = 0;
  int _page  = 0;
  int _perPage = 25;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _api.getCallHistory({
        'currentpage': _page.toString(),
        'rowsPerPage': _perPage.toString(),
      });
      if (mounted) {
        setState(() {
          _rows    = List<Map<String, dynamic>>.from(result['rows'] as List);
          _total   = result['total'] as int;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  // Called by CallButton after a call is posted — refresh after short delay
  void refreshAfterCall(CallRecord _) =>
      Future.delayed(const Duration(seconds: 3), _fetch);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildContent()),
            if (!_loading && _rows.isNotEmpty) _buildPagination(),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(children: [
        const Text('Telecalling Logs',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _text1)),
        const Spacer(),
        if (_total > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: _blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Text('$_total records',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _blue)),
          ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: _blue, size: 22),
          tooltip: 'Refresh',
          onPressed: _fetch,
        ),
      ]),
    );
  }

  // ── Content ──────────────────────────────────────────────────────────────────
  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _blue, strokeWidth: 2));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded, color: _red, size: 40),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: _red)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetch,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
            ),
          ]),
        ),
      );
    }
    if (_rows.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.phone_missed_rounded, size: 56, color: _text2.withValues(alpha: 0.4)),
          const SizedBox(height: 14),
          const Text('No Data Found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _text2)),
          const SizedBox(height: 6),
          const Text('Call records will appear here after calls are made.',
              style: TextStyle(fontSize: 12, color: Color(0xff9CA3AF))),
        ]),
      );
    }
    return _TelecallingTable(rows: _rows);
  }

  // ── Pagination ───────────────────────────────────────────────────────────────
  Widget _buildPagination() {
    final totalPages = (_total / _perPage).ceil().clamp(1, 9999);
    final start = _page * _perPage + 1;
    final end   = ((_page + 1) * _perPage).clamp(0, _total);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Text('Rows per page: ', style: const TextStyle(fontSize: 12, color: _text2)),
        DropdownButton<int>(
          value: _perPage,
          underline: const SizedBox(),
          isDense: true,
          style: const TextStyle(fontSize: 12, color: _text1),
          items: [10, 25, 50].map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
          onChanged: (v) { if (v != null) { setState(() { _perPage = v; _page = 0; }); _fetch(); } },
        ),
        const SizedBox(width: 16),
        Text('$start–$end of $_total',
            style: const TextStyle(fontSize: 12, color: _text2)),
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 20),
          onPressed: _page > 0 ? () { setState(() => _page--); _fetch(); } : null,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded, size: 20),
          onPressed: _page < totalPages - 1 ? () { setState(() => _page++); _fetch(); } : null,
        ),
      ]),
    );
  }
}

// ── Table ─────────────────────────────────────────────────────────────────────
class _TelecallingTable extends StatelessWidget {
  const _TelecallingTable({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final totalW = _cols.fold(0.0, (s, c) => s + c.width);
    final hScroll = ScrollController();
    return LayoutBuilder(builder: (_, constraints) {
      return Scrollbar(
        controller: hScroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: hScroll,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalW,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Header row ────────────────────────────────────────────
              Container(
                height: _headerH,
                decoration: const BoxDecoration(
                  color: Color(0xffF3F4F6),
                  border: Border(bottom: BorderSide(color: Color(0xffE5E7EB))),
                ),
                child: Row(children: _cols.map((c) => _HeaderCell(col: c)).toList()),
              ),
              // ── Data rows ─────────────────────────────────────────────
              SizedBox(
                height: constraints.maxHeight - _headerH,
                child: ListView.builder(
                  itemCount: rows.length,
                  itemExtent: _rowH,
                  itemBuilder: (_, i) => _DataRow(
                    data: rows[i],
                    index: i,
                    isEven: i % 2 == 0,
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
    });
  }
}

// ── Header cell ───────────────────────────────────────────────────────────────
class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.col});
  final _Col col;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: col.width,
      height: _headerH,
      decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: Color(0xffD1D5DB), width: 0.8))),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      child: Text(col.label,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: _text2, letterSpacing: 0.2),
          overflow: TextOverflow.ellipsis),
    );
  }
}

// ── Data row ──────────────────────────────────────────────────────────────────
class _DataRow extends StatelessWidget {
  const _DataRow({required this.data, required this.index, required this.isEven});
  final Map<String, dynamic> data;
  final int index;
  final bool isEven;

  static const _cellDivider = BorderSide(color: Color(0xffE5E7EB), width: 0.5);

  Color get _statusColor {
    switch ((data['call_status'] ?? '').toString().toLowerCase()) {
      case 'answered': return _green;
      case 'missed':   return _red;
      default:         return _orange;
    }
  }

  String _fmt(dynamic v) {
    if (v == null) return '—';
    final s = v.toString();
    if (s.isEmpty) return '—';
    // Try parse as ISO date
    try {
      final dt = DateTime.parse(s).toLocal();
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}  '
             '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) {}
    return s;
  }

  String _duration(dynamic v) {
    final s = int.tryParse(v?.toString() ?? '') ?? 0;
    if (s <= 0) return '0s';
    if (s < 60) return '${s}s';
    final m = s ~/ 60; final r = s % 60;
    return r > 0 ? '${m}m ${r}s' : '${m}m';
  }

  Widget _cell(String field, double width) {
    Widget content;

    switch (field) {
      case 'call_status':
        final status = (data['call_status'] ?? '—').toString();
        final label  = status.isEmpty ? '—' : '${status[0].toUpperCase()}${status.substring(1)}';
        content = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor)),
        );
        break;

      case 'contact_type':
        final type  = (data['contact_type'] ?? '—').toString();
        final color = type == 'lead' ? const Color(0xff7C3AED) : _blue;
        final label = type.isEmpty ? '—' : '${type[0].toUpperCase()}${type.substring(1)}';
        content = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        );
        break;

      case 'start_time':
      case 'created_at':
        content = Text(_fmt(data[field]),
            style: const TextStyle(fontSize: 11, color: _text2));
        break;

      case 'duration_seconds':
        content = Text(_duration(data[field]),
            style: const TextStyle(fontSize: 12, color: _text1, fontWeight: FontWeight.w500));
        break;

      case 'id':
        content = Text('${data[field] ?? (index + 1)}',
            style: const TextStyle(fontSize: 11, color: _text2));
        break;

      default:
        final val = data[field];
        content = Text(val == null || val.toString().isEmpty ? '—' : val.toString(),
            style: const TextStyle(fontSize: 12, color: _text1),
            overflow: TextOverflow.ellipsis);
    }

    return Container(
      width: width,
      height: _rowH,
      decoration: const BoxDecoration(
          border: Border(right: _cellDivider, bottom: _cellDivider)),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: field == 'call_status' || field == 'contact_type'
          ? Alignment.center
          : Alignment.centerLeft,
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isEven ? Colors.white : const Color(0xffFAFAFA),
      child: Row(children: _cols.map((c) => _cell(c.field, c.width)).toList()),
    );
  }
}
