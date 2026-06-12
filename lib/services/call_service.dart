import 'dart:convert';

import 'package:call_log/call_log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/call_record_model.dart';

class CallService {
  static final CallService instance = CallService._();
  CallService._();

  static const _historyKey = 'call_history_local';
  // Persisted so the pending call survives Android killing the background app
  // during long calls (20+ minutes).
  static const _pendingKey = 'call_pending_v1';

  String? _pendingNumber;
  String? _pendingContactName;
  String? _pendingContactId;
  String? _pendingContactType;
  DateTime? _callStartTime;

  bool get hasPendingCall => _pendingNumber != null;
  DateTime? get callStartTime => _callStartTime;

  // Prevents concurrent calls to resolveAfterResume() from saving duplicates.
  bool _isResolving = false;

  /// True when the last resolveAfterResume() couldn't read the call log.
  bool callLogPermissionNeeded = false;

  Future<bool> requestPermissions() async {
    final status = await Permission.phone.request();
    debugPrint('CallService permissions — phone:${status.isGranted}');
    return status.isGranted;
  }

  Future<bool> makeCall({
    required String phoneNumber,
    required String contactName,
    String contactId = '',
    String contactType = 'client',
  }) async {
    final granted = await requestPermissions();
    if (!granted) return false;

    final clean = phoneNumber.replaceAll(RegExp(r'[\s\-()]'), '');
    _pendingNumber = clean;
    _pendingContactName = contactName;
    _pendingContactId = contactId;
    _pendingContactType = contactType;
    _callStartTime = DateTime.now();

    // Persist immediately — if Android kills the app during a long call
    // (20+ min) all Dart state is lost. We restore from here on next launch.
    await _savePendingToPrefs();

    try {
      final result = await FlutterPhoneDirectCaller.callNumber(clean);
      return result ?? false;
    } catch (e) {
      debugPrint('CallService.makeCall error: $e');
      _clearPending();
      return false;
    }
  }

  /// Called once at app startup. If Android killed the app during a long call
  /// (e.g. 2-3 hours), the pending call data is still in SharedPreferences.
  /// This resolves that data and returns the record so the caller can POST it.
  /// Returns null if there was no pending call or if a live CallButton widget
  /// is already tracking it (in-memory _pendingNumber is set).
  Future<CallRecord?> checkAndResolveOnStartup({
    String? companyId,
    String? employeeId,
    String? employeeName,
  }) async {
    // If an active widget is already handling this call, skip.
    if (_pendingNumber != null) return null;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingKey);
    if (raw == null) return null;

    debugPrint('CallService.checkAndResolveOnStartup: '
        'pending call found from previous session — resolving');
    return resolveAfterResume(
      companyId: companyId,
      employeeId: employeeId,
      employeeName: employeeName,
    );
  }

  /// Called when the app resumes after a phone call.
  Future<CallRecord?> resolveAfterResume({
    String? companyId,
    String? employeeId,
    String? employeeName,
  }) async {
    // Guard against concurrent calls (spurious resume + real resume overlap).
    if (_isResolving) return null;
    _isResolving = true;

    // Restore pending data in case Android killed the app during the call.
    await _restorePendingFromPrefs();

    if (_pendingNumber == null || _callStartTime == null) {
      _isResolving = false;
      return null;
    }

    final number = _pendingNumber!;
    final contactName = _pendingContactName ?? '';
    final contactId = _pendingContactId ?? '';
    final contactType = _pendingContactType ?? 'client';
    final startTime = _callStartTime!;

    _clearPending(); // clears memory + SharedPreferences

    // Base record — always saved so the call is never lost even if call log
    // query fails (permission denied, plugin error, etc.)
    CallRecord record = CallRecord(
      phoneNumber: number,
      contactName: contactName,
      contactId: contactId,
      contactType: contactType,
      startTime: startTime,
      durationSeconds: 0,
      callStatus: 'missed',
      companyId: companyId,
      employeeId: employeeId,
      employeeName: employeeName,
    );

    try {
      // The call log timestamp = call START time, not end time, so
      // "startTime - 30 s" correctly covers any call regardless of duration.
      final from = startTime.millisecondsSinceEpoch - 30000;

      // Do NOT pass dateFrom to CallLog.query — on OnePlus/OxygenOS the
      // native SQL filter silently returns 0 rows even when READ_CALL_LOG is
      // granted. Fetch all entries and filter by timestamp in Dart instead.
      //
      // Query immediately — by the time the user physically returns to the app
      // the OS has already written the call log entry (even for 20+ min calls).
      // One retry with 2 s covers very short calls or slow devices.
      Iterable<CallLogEntry> allEntries = const [];
      List<CallLogEntry> entries = [];

      // 3 attempts: 1s / 2s / 3s gaps.
      // Break early ONLY when a COMPLETE entry is found:
      //   - duration > 0  (call was answered and OS has written the duration)
      //   - OR type is missed/rejected (0-duration is correct for these)
      // If only a 0-duration outgoing entry is present, the OS hasn't flushed
      // the duration yet — keep retrying.
      for (int attempt = 0; attempt < 3; attempt++) {
        final delays = [1, 2, 3];
        await Future.delayed(Duration(seconds: delays[attempt]));
        try {
          allEntries = await CallLog.query();
          entries = allEntries.where((e) => (e.timestamp ?? 0) >= from).toList();
          debugPrint('CallService attempt $attempt: '
              'total=${allEntries.length} inWindow=${entries.length}');
          for (final e in entries) {
            debugPrint('  num=${e.number}  dur=${e.duration}s  '
                'type=${e.callType}  ts=${e.timestamp}');
          }
          if (entries.isEmpty) continue; // nothing yet, retry
          // Check if any entry is complete (duration written or definitive type)
          final hasComplete = entries.any((e) =>
              (e.duration ?? 0) > 0 ||
              e.callType == CallType.missed ||
              e.callType == CallType.rejected);
          if (hasComplete) {
            debugPrint('CallService: complete entry found on attempt $attempt');
            break;
          }
          debugPrint('CallService: entries found but duration=0 — retrying…');
        } catch (e) {
          debugPrint('CallService: CallLog.query error: $e');
          break;
        }
      }

      if (allEntries.isEmpty) {
        debugPrint('CallService: call log empty — READ_CALL_LOG not granted');
        callLogPermissionNeeded = true;
        await _saveLocally(record);
        _isResolving = false;
        return record;
      }

      callLogPermissionNeeded = false;

      // Pass 1 — number match inside time window
      CallLogEntry? best = _findBestMatch(entries, number, from);

      // Pass 2 — most recent outgoing inside window (handles number format mismatch)
      if (best == null) {
        debugPrint('CallService: no number match — latest outgoing in window');
        for (final e in entries) {
          if (e.callType == CallType.outgoing) {
            final ts = e.timestamp ?? 0;
            if (best == null || ts > (best.timestamp ?? 0)) best = e;
          }
        }
      }

      // Pass 3 — fallback: most recent entry with highest duration in window
      if (best == null && entries.isNotEmpty) {
        debugPrint('CallService: fallback — picking highest-duration entry');
        best = entries.reduce((a, b) =>
            (a.duration ?? 0) >= (b.duration ?? 0) ? a : b);
      }

      debugPrint('── CallService: FINAL ENTRY ───────────────');
      debugPrint('  number   : ${best?.number}');
      debugPrint('  duration : ${best?.duration}s');
      debugPrint('  callType : ${best?.callType}');
      debugPrint('  timestamp: ${best?.timestamp}');

      if (best != null) {
        final dur = best.duration ?? 0;
        final status = _statusFromType(best.callType, dur);
        debugPrint('  → callStatus : $status');
        debugPrint('  → durationSec: $dur');
        record = CallRecord(
          phoneNumber: number,
          contactName: contactName,
          contactId: contactId,
          contactType: contactType,
          startTime: DateTime.fromMillisecondsSinceEpoch(
              best.timestamp ?? startTime.millisecondsSinceEpoch),
          durationSeconds: dur,
          callStatus: status,
          companyId: companyId,
          employeeId: employeeId,
          employeeName: employeeName,
        );
      }
    } catch (e) {
      debugPrint('CallService.resolveAfterResume error: $e');
      _isResolving = false;
    }

    await _saveLocally(record);
    _isResolving = false;
    return record;
  }

  // ── Pending call persistence (survives app kills during long calls) ────────

  Future<void> _savePendingToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _pendingKey,
        jsonEncode({
          'number': _pendingNumber,
          'contactName': _pendingContactName,
          'contactId': _pendingContactId,
          'contactType': _pendingContactType,
          'startTime': _callStartTime?.millisecondsSinceEpoch,
        }),
      );
    } catch (e) {
      debugPrint('CallService._savePendingToPrefs error: $e');
    }
  }

  Future<void> _restorePendingFromPrefs() async {
    if (_pendingNumber != null) return; // already in memory — no need to restore
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingKey);
      if (raw == null) return;
      // Delete immediately so a second restore call never reads the same data.
      await prefs.remove(_pendingKey);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _pendingNumber = data['number'] as String?;
      _pendingContactName = data['contactName'] as String?;
      _pendingContactId = data['contactId'] as String?;
      _pendingContactType = data['contactType'] as String?;
      final startMs = data['startTime'] as int?;
      if (startMs != null) {
        _callStartTime = DateTime.fromMillisecondsSinceEpoch(startMs);
        debugPrint('CallService: restored pending call from prefs '
            '(started ${DateTime.now().difference(_callStartTime!).inMinutes} min ago)');
      }
    } catch (e) {
      debugPrint('CallService._restorePendingFromPrefs error: $e');
    }
  }

  Future<void> _clearPendingFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingKey);
    } catch (e) {
      debugPrint('CallService._clearPendingFromPrefs error: $e');
    }
  }

  // ── Local history ─────────────────────────────────────────────────────────

  Future<void> _saveLocally(CallRecord record) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_historyKey) ?? [];
      raw.insert(0, jsonEncode(record.toJson()));
      if (raw.length > 100) raw.removeRange(100, raw.length);
      await prefs.setStringList(_historyKey, raw);
    } catch (e) {
      debugPrint('CallService._saveLocally error: $e');
    }
  }

  Future<List<CallRecord>> getLocalHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_historyKey) ?? [];
      return raw
          .map((s) =>
              CallRecord.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('CallService.getLocalHistory error: $e');
      return [];
    }
  }

  Future<void> clearLocalHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _last10(String number) {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  static CallLogEntry? _findBestMatch(
      Iterable<CallLogEntry> entries, String number, int fromMs) {
    final target = _last10(number);
    CallLogEntry? best;
    for (final e in entries) {
      final ts = e.timestamp ?? 0;
      if (ts < fromMs) continue;
      if (_last10(e.number ?? '') == target) {
        // Prefer entry with higher duration (most complete record wins).
        final betterDuration = (e.duration ?? 0) > (best?.duration ?? 0);
        final sameOrNewerTime = ts >= (best?.timestamp ?? 0);
        if (best == null || betterDuration || (sameOrNewerTime && (best.duration ?? 0) == 0)) best = e;
      }
    }
    return best;
  }

  static String _statusFromType(CallType? type, int durationSecs) {
    switch (type) {
      case CallType.outgoing:
        return durationSecs > 0 ? 'answered' : 'missed';
      case CallType.missed:
        return 'missed';
      case CallType.rejected:
        return 'rejected';
      case CallType.incoming:
        return 'answered';
      default:
        return durationSecs > 0 ? 'answered' : 'missed';
    }
  }

  void _clearPending() {
    _pendingNumber = null;
    _pendingContactName = null;
    _pendingContactId = null;
    _pendingContactType = null;
    _callStartTime = null;
    _clearPendingFromPrefs(); // fire-and-forget
  }
}
