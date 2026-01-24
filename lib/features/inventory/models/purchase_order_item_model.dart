class PurchaseOrderItem {
  final String id;
  final String purchaseOrderId;
  final String productId;
  final String? productName;
  final String? productUnit;
  final double quantity;
  final double unitPrice;
  final double subtotal;
  final DateTime createdAt;

  PurchaseOrderItem({
    required this.id,
    required this.purchaseOrderId,
    required this.productId,
    this.productName,
    this.productUnit,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.createdAt,
  });

  factory PurchaseOrderItem.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderItem(
      id: json['id'] as String,
      purchaseOrderId: json['purchase_order_id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String?,
      productUnit: json['product_unit'] as String?,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      subtotal: (json['subtotal'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'purchase_order_id': purchaseOrderId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'subtotal': subtotal,
      'created_at': createdAt.toIso8601String(),
    };
  }

  PurchaseOrderItem copyWith({
    String? id,
    String? purchaseOrderId,
    String? productId,
    String? productName,
    String? productUnit,
    double? quantity,
    double? unitPrice,
    double? subtotal,
    DateTime? createdAt,
  }) {
    final newQuantity = quantity ?? this.quantity;
    final newUnitPrice = unitPrice ?? this.unitPrice;
    final newSubtotal = subtotal ?? (newQuantity * newUnitPrice);

    return PurchaseOrderItem(
      id: id ?? this.id,
      purchaseOrderId: purchaseOrderId ?? this.purchaseOrderId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productUnit: productUnit ?? this.productUnit,
      quantity: newQuantity,
      unitPrice: newUnitPrice,
      subtotal: newSubtotal,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
