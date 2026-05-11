import 'package:flutter/material.dart';

import '../../../models/call_record_model.dart';
import '../../../services/call_service.dart';
import '../../widgets/call_button.dart';

/// Temporary test screen — remove after backend /calls endpoint is ready.
class CallTestView extends StatefulWidget {
  const CallTestView({super.key});

  @override
  State<CallTestView> createState() => _CallTestViewState();
}

class _CallTestViewState extends State<CallTestView> {
  static const _blue = Color(0xff3756DF);
  static const _green = Color(0xff22C55E);
  static const _text1 = Color(0xff1A1F36);
  static const _text2 = Color(0xff6B7280);
  static const _bg = Color(0xffF5F5F7);

  // 5 test contacts — replace numbers with real ones for testing
  static const _contacts = [
    {
      'name': 'Test Client 1',
      'phone': '+919553935873',
      'type': 'client',
      'id': 'test-1'
    },
    {
      'name': 'Test Lead A',
      'phone': '+917093535963',
      'type': 'lead',
      'id': 'test-2'
    },
    {
      'name': 'Test Client 2',
      'phone': '+917654321098',
      'type': 'client',
      'id': 'test-3'
    },
    {
      'name': 'Test Lead B',
      'phone': '+916543210987',
      'type': 'lead',
      'id': 'test-4'
    },
    {
      'name': 'Test Client 3',
      'phone': '+915432109876',
      'type': 'client',
      'id': 'test-5'
    },
  ];

  List<CallRecord> _recorded = [];
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await CallService.instance.getLocalHistory();
    if (mounted) {
      setState(() {
        _recorded = history;
        _loadingHistory = false;
      });
    }
  }

  Future<void> _clearHistory() async {
    await CallService.instance.clearLocalHistory();
    if (mounted) setState(() => _recorded = []);
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
          'Call Feature Test',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: _text1),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Refresh history',
            onPressed: _loadHistory,
          ),
          if (_recorded.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 20, color: Color(0xffEF4444)),
              tooltip: 'Clear history',
              onPressed: _clearHistory,
            ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xffFEF3C7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('TEST MODE',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xffD97706))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xffEEF1FB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffC7D2FE)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: _blue),
                  SizedBox(width: 6),
                  Text('How to test',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _blue)),
                ]),
                SizedBox(height: 6),
                Text(
                  '1. Tap the green  button next to a contact\n'
                  '2. The native dialer opens — make the call\n'
                  '3. End the call and return to this screen\n'
                  '4. Call details auto-appear in "Recorded calls" below',
                  style: TextStyle(fontSize: 12, color: _text2, height: 1.6),
                ),
              ],
            ),
          ),

          // Test contacts
          const _SectionHeader(title: 'TEST CONTACTS'),
          const SizedBox(height: 8),
          ..._contacts.map(
            (c) => _ContactTile(
              name: c['name']!,
              phone: c['phone']!,
              type: c['type']!,
              id: c['id']!,
              onRecorded: (record) {
                _loadHistory(); // reload from SharedPreferences
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: _green,
                    content: Text(
                      '✓ Call recorded — ${record.formattedDuration} (${record.callStatus})',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),

          // Call history
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: _SectionHeader(
                title: _loadingHistory
                    ? 'CALL HISTORY (loading…)'
                    : 'CALL HISTORY (${_recorded.length})',
              ),
            ),
          ]),
          const SizedBox(height: 8),
          if (_loadingHistory)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                  child: CircularProgressIndicator(
                      color: Color(0xff3756DF), strokeWidth: 2)),
            )
          else if (_recorded.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'No calls yet.\nMake a call — history appears here automatically.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xff9CA3AF)),
                ),
              ),
            )
          else
            ..._recorded.map((r) => _RecordedRow(record: r)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Color(0xff9CA3AF)));
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.name,
    required this.phone,
    required this.type,
    required this.id,
    required this.onRecorded,
  });

  final String name, phone, type, id;
  final ValueChanged<CallRecord> onRecorded;

  static const _text1 = Color(0xff1A1F36);
  static const _text2 = Color(0xff6B7280);
  static const _blue = Color(0xff3756DF);

  @override
  Widget build(BuildContext context) {
    final isClient = type == 'client';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        // Avatar
        CircleAvatar(
          radius: 20,
          backgroundColor: (isClient ? _blue : const Color(0xff7C3AED))
              .withValues(alpha: 0.12),
          child: Text(
            name[0],
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isClient ? _blue : const Color(0xff7C3AED)),
          ),
        ),
        const SizedBox(width: 12),
        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _text1)),
              const SizedBox(height: 2),
              Text(phone, style: const TextStyle(fontSize: 12, color: _text2)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: (isClient ? _blue : const Color(0xff7C3AED))
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isClient ? 'Client' : 'Lead',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isClient ? _blue : const Color(0xff7C3AED)),
                ),
              ),
            ],
          ),
        ),
        // Call button
        CallButton(
          phoneNumber: phone,
          contactName: name,
          contactId: id,
          contactType: type,
          size: 42,
          onCallRecorded: onRecorded,
        ),
      ]),
    );
  }
}

class _RecordedRow extends StatelessWidget {
  const _RecordedRow({required this.record});
  final CallRecord record;

  static const _green = Color(0xff22C55E);
  static const _red = Color(0xffEF4444);
  static const _orange = Color(0xffF59E0B);
  static const _text1 = Color(0xff1A1F36);
  static const _text2 = Color(0xff6B7280);

  Color get _color {
    switch (record.callStatus) {
      case 'answered':
        return _green;
      case 'missed':
        return _red;
      default:
        return _orange;
    }
  }

  IconData get _icon {
    switch (record.callStatus) {
      case 'answered':
        return Icons.call_made_rounded;
      case 'missed':
        return Icons.call_missed_rounded;
      default:
        return Icons.call_end_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _color.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(_icon, color: _color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(record.contactName,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _text1)),
              Text(record.phoneNumber,
                  style: const TextStyle(fontSize: 11, color: _text2)),
            ],
          ),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            '${record.callStatus[0].toUpperCase()}${record.callStatus.substring(1)}',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: _color),
          ),
          Text(
            record.durationSeconds > 0 ? record.formattedDuration : 'No answer',
            style: const TextStyle(fontSize: 11, color: Color(0xff9CA3AF)),
          ),
        ]),
      ]),
    );
  }
}
