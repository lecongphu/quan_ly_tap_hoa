/// Customer model
class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final double debtLimit;
  final double currentDebt;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Customer({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.debtLimit = 0,
    this.currentDebt = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      debtLimit: (json['debt_limit'] as num?)?.toDouble() ?? 0,
      currentDebt: (json['current_debt'] as num?)?.toDouble() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'debt_limit': debtLimit,
      'current_debt': currentDebt,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    double? debtLimit,
    double? currentDebt,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      debtLimit: debtLimit ?? this.debtLimit,
      currentDebt: currentDebt ?? this.currentDebt,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  double get availableCredit => debtLimit - currentDebt;

  bool get hasDebt => currentDebt > 0;

  bool canBorrow(double amount) {
    return (currentDebt + amount) <= debtLimit;
  }
}

/// Debt Payment model
class DebtPayment {
  final String? id;
  final String customerId;
  final double amount;
  final String paymentMethod;
  final String? receiptNumber;
  final String? notes;
  final String? createdBy;
  final DateTime? createdAt;

  DebtPayment({
    this.id,
    required this.customerId,
    required this.amount,
    required this.paymentMethod,
    this.receiptNumber,
    this.notes,
    this.createdBy,
    this.createdAt,
  });

  factory DebtPayment.fromJson(Map<String, dynamic> json) {
    return DebtPayment(
      id: json['id'] as String?,
      customerId: json['customer_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String,
      receiptNumber: json['receipt_number'] as String?,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'customer_id': customerId,
      'amount': amount,
      'payment_method': paymentMethod,
      'receipt_number': receiptNumber,
      'notes': notes,
      'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}
