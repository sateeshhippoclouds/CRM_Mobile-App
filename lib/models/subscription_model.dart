class SubscriptionModel {
  final int? id;
  final String? name;
  final String? duration;
  final double? price;
  final double? tax;
  final double? totalAmount;
  final String? status;
  final String? createdAt;
  final String? updatedAt;

  SubscriptionModel({
    this.id,
    this.name,
    this.duration,
    this.price,
    this.tax,
    this.totalAmount,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status?.toLowerCase() == 'active';

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: _parseInt(json['id']),
      name: json['name']?.toString(),
      duration: json['duration']?.toString(),
      price: _parseDouble(json['price']),
      tax: _parseDouble(json['tax']),
      totalAmount: _parseDouble(json['total_amount'] ?? json['totalAmount']),
      status: json['status']?.toString() ?? 'active',
      createdAt: json['created_at']?.toString() ?? json['createdAt']?.toString(),
      updatedAt: json['updated_at']?.toString() ?? json['updatedAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'duration': duration,
        'price': price,
        'tax': tax,
        'total_amount': totalAmount,
        'status': status,
      };

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
