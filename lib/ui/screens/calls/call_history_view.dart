import 'package:flutter/material.dart';

import '../../../app/app.locator.dart';
import '../../../models/call_record_model.dart';
import '../../../services/api_services.dart';

class CallHistoryView extends StatefulWidget {
  const CallHistoryView({super.key});

  @override
  State<CallHistoryView> createState() => _CallHistoryViewState();
}

class _CallHistoryViewState extends State<CallHistoryView> {
  final _api = locator<HippoAuthService>();

  List<CallRecord> _records = [];
  bool _loading = true;
  String? _error;

  static const _blue = Color(0xff3756DF);
  static const _text1 = Color(0xff1A1F36);
  static const _text2 = Color(0xff6B7280);
  static const _bg = Color(0xffF5F5F7);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await _api.getStoredUser();
      final params = <String, String>{};
      if (user?.companyId != null) {
        params['companyid'] = user!.companyId.toString();
      }
      if (user?.employeeId != null) {
        params['employeeid'] = user!.employeeId.toString();
      }
      final raw = await _api.getCallHistory(params);
      setState(() {
        _records = raw.map(CallRecord.fromJson).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _text1),
        title: const Text(
          'Call History',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: _text1),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _text2),
            onPressed: _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _blue))
            : _error != null
                ? _ErrorView(message: _error!, onRetry: _load)
                : _records.isEmpty
                    ? _EmptyView()
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _records.length,
                        itemBuilder: (_, i) =>
                            _CallCard(record: _records[i]),
                      ),
      ),
    );
  }
}

class _CallCard extends StatelessWidget {
  const _CallCard({required this.record});
  final CallRecord record;

  static const _green = Color(0xff22C55E);
  static const _red = Color(0xffEF4444);
  static const _orange = Color(0xffF59E0B);
  static const _text1 = Color(0xff1A1F36);
  static const _text2 = Color(0xff6B7280);
  static const _text3 = Color(0xff9CA3AF);

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  Color get _statusColor {
    switch (record.callStatus) {
      case 'answered':
        return _green;
      case 'missed':
        return _red;
      case 'rejected':
        return _orange;
      default:
        return _text3;
    }
  }

  IconData get _statusIcon {
    switch (record.callStatus) {
      case 'answered':
        return Icons.call_made_rounded;
      case 'missed':
        return Icons.call_missed_rounded;
      case 'rejected':
        return Icons.call_end_rounded;
      default:
        return Icons.call_rounded;
    }
  }

  String _fmtDate(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      final h = d.hour.toString().padLeft(2, '0');
      final m = d.minute.toString().padLeft(2, '0');
      return 'Today $h:$m';
    }
    return '${d.day} ${_months[d.month]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(children: [
        // Status icon circle
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _statusColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(_statusIcon, color: _statusColor, size: 22),
        ),
        const SizedBox(width: 12),
        // Contact info
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              record.contactName.isNotEmpty
                  ? record.contactName
                  : record.phoneNumber,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: _text1),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              record.phoneNumber,
              style: const TextStyle(fontSize: 12, color: _text2),
            ),
            const SizedBox(height: 4),
            Row(children: [
              // Type badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xffEEF1FB),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  record.contactType == 'lead' ? 'Lead' : 'Client',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xff3756DF)),
                ),
              ),
              const SizedBox(width: 8),
              // Status badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _cap(record.callStatus),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _statusColor),
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        // Duration + time
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            _fmtDate(record.startTime),
            style: const TextStyle(fontSize: 11, color: _text3),
          ),
          const SizedBox(height: 4),
          if (record.durationSeconds > 0)
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.timer_rounded, size: 12, color: _text3),
              const SizedBox(width: 3),
              Text(
                record.formattedDuration,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _text2),
              ),
            ])
          else
            const Text('No answer',
                style: TextStyle(fontSize: 11, color: _text3)),
        ]),
      ]),
    );
  }

  static String _cap(String s) =>
      s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : s;
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: Color(0xffEF4444)),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xff6B7280), fontSize: 13)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff3756DF)),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ]),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.call_outlined, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        const Text('No call history yet',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xff9CA3AF))),
        const SizedBox(height: 6),
        const Text('Calls made through the app will appear here.',
            style: TextStyle(fontSize: 12, color: Color(0xffD1D5DB))),
      ]),
    );
  }
}
