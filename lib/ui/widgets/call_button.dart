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

  bool _calling = false;
  bool _resolving = false;

  // True once the app has gone to background after initiating a call.
  bool _hasBeenToBackground = false;

  // Debounce timer: On OnePlus/OxygenOS, when the other party answers the
  // call the dialer fires a spurious "resumed" event (ringing→active
  // transition) before immediately going back to "paused". We wait 2 s after
  // every "resumed" — if "paused" fires again within that window we cancel and
  // wait for the real return. This prevents resolving the call too early.
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_calling || _resolving) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App went to background (dialer opened or call ongoing).
      _hasBeenToBackground = true;
      // If a return-timer is running (spurious resume), cancel it — we're back
      // in the dialer so it wasn't a real return yet.
      _returnTimer?.cancel();
      _returnTimer = null;
    } else if (state == AppLifecycleState.resumed && _hasBeenToBackground) {
      // Start a 2-second debounce timer.
      // If "paused" fires again within 2 s (spurious OnePlus answer-event),
      // the timer is cancelled above and we wait for the next cycle.
      // If we stay in foreground for 2 s, it is a genuine return from the call.
      _returnTimer?.cancel();
      _returnTimer = Timer(const Duration(milliseconds: 500), () {
        _returnTimer = null;
        if (!mounted || !_calling || _resolving) return;
        _hasBeenToBackground = false;
        _onReturnedFromCall();
      });
    }
  }

  Future<void> _onReturnedFromCall() async {
    if (!mounted) return;
    _resolving = true;
    setState(() => _calling = false);

    // resolveAfterResume() restores from SharedPreferences internally, so it
    // works even when Android killed the app during a long call (20+ min) and
    // the in-memory hasPendingCall is false.
    final record = await CallService.instance.resolveAfterResume(
      companyId: _user?.companyId?.toString(),
      employeeId: _user?.employeeId?.toString(),
      employeeName: _user?.name,
    );

    if (record != null) {
      try {
        await _api.postCallRecord(record.toJson());
      } catch (e) {
        debugPrint('postCallRecord error: $e');
      }
      if (mounted) widget.onCallRecorded?.call(record);
    }

    // READ_CALL_LOG denied — show dialog with exact steps for OnePlus.
    if (CallService.instance.callLogPermissionNeeded && mounted) {
      _showCallLogPermDialog();
    }

    _resolving = false;
  }

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
          '2. Tap Permissions\n'
          '3. Enable "Call logs"\n'
          '4. Return to the app\n\n'
          'OnePlus: Settings → Apps → this app → Permissions → Call logs → Allow',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff3756DF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _dial() async {
    if (_calling || widget.phoneNumber.isEmpty) {
      if (widget.phoneNumber.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No phone number available')),
        );
      }
      return;
    }

    final ok = await CallService.instance.makeCall(
      phoneNumber: widget.phoneNumber,
      contactName: widget.contactName,
      contactId: widget.contactId,
      contactType: widget.contactType,
    );

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone permission denied — enable it in Settings'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: openAppSettings,
          ),
        ),
      );
      return;
    }

    if (mounted) setState(() => _calling = true);

    // If a previous call couldn't read call log, remind user before this call.
    if (CallService.instance.callLogPermissionNeeded && mounted) {
      _showCallLogPermDialog();
    }
  }

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
        child: _calling
            ? Padding(
                padding: EdgeInsets.all(widget.size * 0.22),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xff22C55E),
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
