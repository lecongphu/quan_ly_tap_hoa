import '../../inventory/models/product_model.dart';

/// Cart item model
class CartItem {
  final Product product;
  double quantity;
  double unitPrice;
  double discount;
  String? batchId; // For FEFO tracking
  double? costPrice; // For profit calculation

  CartItem({
    required this.product,
    this.quantity = 1,
    required this.unitPrice,
    this.discount = 0,
    this.batchId,
    this.costPrice,
  });

  double get subtotal => (quantity * unitPrice) - discount;

  double get totalDiscount => discount;

  double get profit {
    if (costPrice == null) return 0;
    return subtotal - (quantity * costPrice!);
  }

  CartItem copyWith({
    Product? product,
    double? quantity,
    double? unitPrice,
    double? discount,
    String? batchId,
    double? costPrice,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discount: discount ?? this.discount,
      batchId: batchId ?? this.batchId,
      costPrice: costPrice ?? this.costPrice,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': product.id,
      'quantity': quantity,
      'unit_price': unitPrice,
      'discount': discount,
      'batch_id': batchId,
      'cost_price': costPrice ?? product.avgCostPrice ?? 0,
      'subtotal': subtotal,
    };
  }
}

/// Sale model
class Sale {
  final String? id;
  final String invoiceNumber;
  final String? customerId;
  final double totalAmount;
  final double discountAmount;
  final double finalAmount;
  final String paymentMethod;
  final String paymentStatus;
  final String? qrCodeData;
  final String? notes;
  final String? createdBy;
  final DateTime? createdAt;
  final List<SaleItem> items;

  Sale({
    this.id,
    required this.invoiceNumber,
    this.customerId,
    required this.totalAmount,
    this.discountAmount = 0,
    required this.finalAmount,
    required this.paymentMethod,
    this.paymentStatus = 'paid',
    this.qrCodeData,
    this.notes,
    this.createdBy,
    this.createdAt,
    this.items = const [],
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['id'] as String?,
      invoiceNumber: json['invoice_number'] as String,
      customerId: json['customer_id'] as String?,
      totalAmount: (json['total_amount'] as num).toDouble(),
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      finalAmount: (json['final_amount'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String,
      paymentStatus: json['payment_status'] as String? ?? 'paid',
      qrCodeData: json['qr_code_data'] as String?,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      items: json['items'] != null
          ? (json['items'] as List)
                .map((item) => SaleItem.fromJson(item))
                .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'invoice_number': invoiceNumber,
      'customer_id': customerId,
      'total_amount': totalAmount,
      'discount_amount': discountAmount,
      'final_amount': finalAmount,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'qr_code_data': qrCodeData,
      'notes': notes,
      'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  Sale copyWith({
    String? id,
    String? invoiceNumber,
    String? customerId,
    double? totalAmount,
    double? discountAmount,
    double? finalAmount,
    String? paymentMethod,
    String? paymentStatus,
    String? qrCodeData,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
    List<SaleItem>? items,
  }) {
    return Sale(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerId: customerId ?? this.customerId,
      totalAmount: totalAmount ?? this.totalAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      finalAmount: finalAmount ?? this.finalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      qrCodeData: qrCodeData ?? this.qrCodeData,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
    );
  }
}

/// Sale item model
class SaleItem {
  final String? id;
  final String? saleId;
  final String productId;
  final String? batchId;
  final double quantity;
  final double unitPrice;
  final double costPrice;
  final double discount;
  final double subtotal;
  final DateTime? createdAt;

  SaleItem({
    this.id,
    this.saleId,
    required this.productId,
    this.batchId,
    required this.quantity,
    required this.unitPrice,
    required this.costPrice,
    this.discount = 0,
    required this.subtotal,
    this.createdAt,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      id: json['id'] as String?,
      saleId: json['sale_id'] as String?,
      productId: json['product_id'] as String,
      batchId: json['batch_id'] as String?,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      costPrice: (json['cost_price'] as num).toDouble(),
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      subtotal: (json['subtotal'] as num).toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (saleId != null) 'sale_id': saleId,
      'product_id': productId,
      'batch_id': batchId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'cost_price': costPrice,
      'discount': discount,
      'subtotal': subtotal,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  double get profit => subtotal - (quantity * costPrice);
}
