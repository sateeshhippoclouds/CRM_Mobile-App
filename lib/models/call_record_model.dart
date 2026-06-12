class CallRecord {
  final String phoneNumber;
  final String contactName;
  final String contactId;
  final String contactType; // 'client' | 'lead'
  final DateTime startTime;
  final int durationSeconds;
  final String callStatus; // 'answered' | 'missed' | 'rejected'
  final String? companyId;
  final String? employeeId;
  final String? employeeName;

  const CallRecord({
    required this.phoneNumber,
    required this.contactName,
    required this.contactId,
    required this.contactType,
    required this.startTime,
    required this.durationSeconds,
    required this.callStatus,
    this.companyId,
    this.employeeId,
    this.employeeName,
  });

  String get formattedDuration {
    if (durationSeconds <= 0) return '0s';
    if (durationSeconds < 60) return '${durationSeconds}s';
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return s > 0 ? '${m}m ${s}s' : '${m}m';
  }

  Map<String, dynamic> toJson() => {
        'phone_number': phoneNumber,
        'contact_name': contactName,
        'contact_id': contactId,
        'contact_type': contactType,
        // Explicit typed ID fields so the backend can identify without checking contact_type.
        if (contactType == 'lead') 'lead_id': contactId,
        if (contactType == 'client') 'client_id': contactId,
        'start_time': startTime.toIso8601String(),
        'duration_seconds': durationSeconds,
        'call_status': callStatus,
        'company_id': companyId,
        'employee_id': employeeId,
        'employee_name': employeeName,
      };

  factory CallRecord.fromJson(Map<String, dynamic> json) => CallRecord(
        phoneNumber: json['phone_number']?.toString() ?? '',
        contactName: json['contact_name']?.toString() ?? '',
        contactId: json['contact_id']?.toString() ?? '',
        contactType: json['contact_type']?.toString() ?? 'client',
        startTime: DateTime.tryParse(json['start_time']?.toString() ?? '') ??
            DateTime.now(),
        durationSeconds: json['duration_seconds'] is int
            ? json['duration_seconds'] as int
            : int.tryParse(json['duration_seconds']?.toString() ?? '') ?? 0,
        callStatus: json['call_status']?.toString() ?? 'answered',
        companyId: json['company_id']?.toString(),
        employeeId: json['employee_id']?.toString(),
        employeeName: json['employee_name']?.toString(),
      );
}
