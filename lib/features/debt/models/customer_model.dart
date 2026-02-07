/// Customer model
class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final double currentDebt;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Customer({
    required this.id,
    required this.name,
    this.phone,
    this.address,
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
      currentDebt: currentDebt ?? this.currentDebt,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get hasDebt => currentDebt > 0;
}

/// Customer sale history model
class CustomerSale {
  final String id;
  final String invoiceNumber;
  final double totalAmount;
  final double discountAmount;
  final double finalAmount;
  final String paymentMethod;
  final String? paymentStatus;
  final DateTime? createdAt;
  final DateTime? dueDate;

  CustomerSale({
    required this.id,
    required this.invoiceNumber,
    required this.totalAmount,
    required this.discountAmount,
    required this.finalAmount,
    required this.paymentMethod,
    this.paymentStatus,
    this.createdAt,
    this.dueDate,
  });

  factory CustomerSale.fromJson(Map<String, dynamic> json) {
    return CustomerSale(
      id: json['id'] as String,
      invoiceNumber: json['invoice_number'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      finalAmount: (json['final_amount'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String,
      paymentStatus: json['payment_status'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'] as String)
          : null,
    );
  }
}

/// Debt Payment model
class DebtPayment {
  final String? id;
  final String? customerId;
  final double amount;
  final String paymentMethod;
  final String? receiptNumber;
  final String? notes;
  final String? createdBy;
  final DateTime? createdAt;

  DebtPayment({
    this.id,
    this.customerId,
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
      customerId: json['customer_id'] as String?,
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
      if (customerId != null) 'customer_id': customerId,
      'amount': amount,
      'payment_method': paymentMethod,
      'receipt_number': receiptNumber,
      'notes': notes,
      'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}

/// Debt line item
class DebtLineItem {
  final String productName;
  final String unit;
  final double quantity;
  final double unitPrice;
  final double subtotal;

  DebtLineItem({
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  factory DebtLineItem.fromJson(Map<String, dynamic> json) {
    return DebtLineItem(
      productName: json['product_name'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Debt line (manual or from sales)
class DebtLine {
  final String id;
  final String invoiceNumber;
  final DateTime? createdAt;
  final DateTime? dueDate;
  final double finalAmount;
  final String? notes;
  final List<DebtLineItem> items;

  DebtLine({
    required this.id,
    required this.invoiceNumber,
    this.createdAt,
    this.dueDate,
    required this.finalAmount,
    this.notes,
    this.items = const [],
  });

  factory DebtLine.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return DebtLine(
      id: json['id'] as String,
      invoiceNumber: json['invoice_number'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'] as String)
          : null,
      finalAmount: (json['final_amount'] as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String?,
      items: rawItems
          .map((item) => DebtLineItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
