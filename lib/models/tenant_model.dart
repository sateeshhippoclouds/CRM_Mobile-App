class TenantModel {
  final int? id;
  final String? tenantName;
  final String? contactPerson;
  final String? contactNumber;
  final String? email;
  final String? duration;
  final int? maxUsers;
  final int? subscriptionId;
  final String? subscriptionName;
  final double? price;
  final double? tax;
  final double? totalAmount;
  final String? startDate;
  final String? endDate;
  final String? status;
  final int? companyId;
  final String? createdAt;
  final String? updatedAt;

  TenantModel({
    this.id,
    this.tenantName,
    this.contactPerson,
    this.contactNumber,
    this.email,
    this.duration,
    this.maxUsers,
    this.subscriptionId,
    this.subscriptionName,
    this.price,
    this.tax,
    this.totalAmount,
    this.startDate,
    this.endDate,
    this.status,
    this.companyId,
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status?.toLowerCase() == 'active';

  factory TenantModel.fromJson(Map<String, dynamic> json) {
    return TenantModel(
      id: _parseInt(json['id']),
      tenantName: json['tenant_name']?.toString(),
      contactPerson: json['contact_person']?.toString(),
      contactNumber: json['contact_number']?.toString(),
      email: json['email']?.toString(),
      duration: json['duration']?.toString(),
      maxUsers: _parseInt(json['max_users']),
      subscriptionId: _parseInt(json['subscription_id']),
      subscriptionName: json['subscription_name']?.toString(),
      price: _parseDouble(json['price']),
      tax: _parseDouble(json['tax']),
      totalAmount: _parseDouble(json['total_amount']),
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
      status: json['status']?.toString() ?? 'active',
      companyId: _parseInt(json['company_id']),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
