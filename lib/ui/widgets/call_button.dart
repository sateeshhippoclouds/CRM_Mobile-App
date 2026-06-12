import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/app.locator.dart';
import '../../models/call_record_model.dart';
import '../../models/token_response_model.dart';
import '../../services/api_services.dart';
import '../../services/call_service.dart';

class CallButton extends StatefulWidget {
  const CallButton({
    super.key,
    required this.phoneNumber,
    required this.contactName,
    this.contactId = '',
    this.contactType = 'client',
    this.onCallRecorded,
    this.size = 34.0,
  });

  final String phoneNumber;
  final String contactName;
  final String contactId;
  final String contactType;
  final ValueChanged<CallRecord>? onCallRecorded;
  final double size;

  @override
  State<CallButton> createState() => _CallButtonState();
}

class _CallButtonState extends State<CallButton> with WidgetsBindingObserver {
  final _api = locator<HippoAuthService>();

  bool _calling   = false;
  bool _resolving = false;
  bool _hasBeenToBackground = false;

  // Debounce timer — cancelled when paused fires (spurious resume protection).
  Timer? _returnTimer;

  TokenResponseModel? _user;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUser();
  }

  @override
  void dispose() {
    _returnTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadUser() async {
    _user = await _api.getStoredUser();
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_calling || _resolving) return;
    debugPrint('CallButton lifecycle: $state '
        '(calling=$_calling hasBackground=$_hasBeenToBackground)');

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App went to background — dialer opened or call is ongoing.
      _hasBeenToBackground = true;
      // Cancel any pending return-timer (spurious resume while still in call).
      _returnTimer?.cancel();
      _returnTimer = null;

    } else if (state == AppLifecycleState.resumed && _hasBeenToBackground) {
      // App returned to foreground.
      // Protection against spurious "resumed" on OnePlus when other party
      // answers: the dialer fires resumed then immediately paused again.
      // The 2-second debounce is cancelled by the paused handler above,
      // so it only fires when the user genuinely returns from the call.
      _returnTimer?.cancel();
      _returnTimer = Timer(const Duration(seconds: 2), () {
        _returnTimer = null;
        if (!mounted || !_calling || _resolving) return;

        // Belt-and-suspenders: if the lifecycle state is not resumed right
        // now (unlikely but possible), we're still in the dialer — skip.
        final ls = WidgetsBinding.instance.lifecycleState;
        debugPrint('CallButton: debounce fired — lifecycleState=$ls');
        if (ls != AppLifecycleState.resumed) {
          debugPrint('CallButton: still in background — waiting');
          return;
        }

        // We are genuinely in the foreground. Resolve.
        _hasBeenToBackground = false;
        _onReturnedFromCall();
      });
    }
  }

  // ── Resolution ───────────────────────────────────────────────────────────────

  Future<void> _onReturnedFromCall() async {
    if (!mounted) return;
    setState(() { _calling = false; _resolving = true; });

    try {
      final record = await CallService.instance.resolveAfterResume(
        companyId:    _user?.companyId?.toString(),
        employeeId:   _user?.employeeId?.toString(),
        employeeName: _user?.name,
      );

      if (record != null) {
        debugPrint('── CallButton: RECORD BEFORE POST ─────────');
        debugPrint('  contactName  : ${record.contactName}');
        debugPrint('  phoneNumber  : ${record.phoneNumber}');
        debugPrint('  contactType  : ${record.contactType}');
        debugPrint('  contactId    : ${record.contactId}');
        debugPrint('  callStatus   : ${record.callStatus}');
        debugPrint('  durationSecs : ${record.durationSeconds}');
        debugPrint('  startTime    : ${record.startTime}');
        debugPrint('  companyId    : ${record.companyId}');
        debugPrint('  employeeId   : ${record.employeeId}');
        debugPrint('  employeeName : ${record.employeeName}');

        try {
          await _api.postCallRecord(record.toJson());
          debugPrint('  → POST /calls SUCCESS');
        } catch (e) {
          debugPrint('  → POST /calls ERROR: $e');
        }

        if (mounted) widget.onCallRecorded?.call(record);
      }
    } catch (e) {
      debugPrint('CallButton._onReturnedFromCall error: $e');
    } finally {
      if (mounted) setState(() => _resolving = false);
    }

    if (CallService.instance.callLogPermissionNeeded && mounted) {
      _showCallLogPermDialog();
    }
  }

  // ── Dialling ─────────────────────────────────────────────────────────────────

  Future<void> _dial() async {
    if (_calling || _resolving || widget.phoneNumber.isEmpty) {
      if (widget.phoneNumber.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No phone number available')),
        );
      }
      return;
    }

    final ok = await CallService.instance.makeCall(
      phoneNumber:  widget.phoneNumber,
      contactName:  widget.contactName,
      contactId:    widget.contactId,
      contactType:  widget.contactType,
    );

    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone permission denied — enable it in Settings'),
            action: SnackBarAction(label: 'Settings', onPressed: openAppSettings),
          ),
        );
      }
      return;
    }

    if (mounted) setState(() => _calling = true);

    if (CallService.instance.callLogPermissionNeeded && mounted) {
      _showCallLogPermDialog();
    }
  }

  // ── Permission dialog ────────────────────────────────────────────────────────

  void _showCallLogPermDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.phone_missed_rounded, color: Color(0xffEF4444), size: 22),
          SizedBox(width: 8),
          Text('Call Log Permission',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        content: const Text(
          'To record call duration and status, enable the '
          '"Call logs" permission:\n\n'
          '1. Tap "Open Settings" below\n'
          '2. Tap Permissions → Call logs → Allow\n\n'
          'OnePlus: Settings → Apps → this app → Permissions → Call logs',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Later')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff3756DF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () { Navigator.pop(ctx); openAppSettings(); },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dial,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: const Color(0xffE8F5E9),
          borderRadius: BorderRadius.circular(widget.size / 3),
        ),
        child: (_calling || _resolving)
            ? Padding(
                padding: EdgeInsets.all(widget.size * 0.22),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _resolving
                      ? const Color(0xffF59E0B)  // amber = reading call log
                      : const Color(0xff22C55E), // green  = call in progress
                ),
              )
            : Icon(
                Icons.call_rounded,
                size: widget.size * 0.52,
                color: const Color(0xff22C55E),
              ),
      ),
    );
  }
}
