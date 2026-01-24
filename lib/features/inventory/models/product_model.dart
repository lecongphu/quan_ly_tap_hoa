/// Product model
class Product {
  final String id;
  final String? barcode;
  final String name;
  final String? categoryId;
  final String? categoryName;
  final String unit;
  final double minStockLevel;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // From current_inventory view
  final double? currentStock;
  final double? avgCostPrice;
  final DateTime? nearestExpiryDate;

  Product({
    required this.id,
    this.barcode,
    required this.name,
    this.categoryId,
    this.categoryName,
    required this.unit,
    this.minStockLevel = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.currentStock,
    this.avgCostPrice,
    this.nearestExpiryDate,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String? ?? json['product_id'] as String,
      barcode: json['barcode'] as String?,
      name: json['name'] as String,
      categoryId: json['category_id'] as String?,
      categoryName: json['category_name'] as String?,
      unit: json['unit'] as String,
      minStockLevel: (json['min_stock_level'] as num?)?.toDouble() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      currentStock: json['total_quantity'] != null
          ? (json['total_quantity'] as num).toDouble()
          : json['current_stock'] != null
          ? (json['current_stock'] as num).toDouble()
          : null,
      avgCostPrice: json['avg_cost_price'] != null
          ? (json['avg_cost_price'] as num).toDouble()
          : null,
      nearestExpiryDate: json['nearest_expiry_date'] != null
          ? DateTime.parse(json['nearest_expiry_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'barcode': barcode,
      'name': name,
      'category_id': categoryId,
      'unit': unit,
      'min_stock_level': minStockLevel,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Product copyWith({
    String? id,
    String? barcode,
    String? name,
    String? categoryId,
    String? categoryName,
    String? unit,
    double? minStockLevel,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? currentStock,
    double? avgCostPrice,
    DateTime? nearestExpiryDate,
  }) {
    return Product(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      unit: unit ?? this.unit,
      minStockLevel: minStockLevel ?? this.minStockLevel,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      currentStock: currentStock ?? this.currentStock,
      avgCostPrice: avgCostPrice ?? this.avgCostPrice,
      nearestExpiryDate: nearestExpiryDate ?? this.nearestExpiryDate,
    );
  }

  bool get isLowStock =>
      currentStock != null &&
      minStockLevel > 0 &&
      currentStock! <= minStockLevel;

  bool get isOutOfStock => currentStock == null || currentStock! <= 0;

  bool get isNearExpiry {
    if (nearestExpiryDate == null) return false;
    final daysUntilExpiry = nearestExpiryDate!
        .difference(DateTime.now())
        .inDays;
    return daysUntilExpiry <= 7 && daysUntilExpiry >= 0;
  }

  bool get isDangerExpiry {
    if (nearestExpiryDate == null) return false;
    final daysUntilExpiry = nearestExpiryDate!
        .difference(DateTime.now())
        .inDays;
    return daysUntilExpiry <= 3 && daysUntilExpiry >= 0;
  }
}

/// Category model
class Category {
  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;

  Category({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Inventory Batch model
class InventoryBatch {
  final String id;
  final String productId;
  final String? batchNumber;
  final double quantity;
  final double costPrice;
  final DateTime? expiryDate;
  final DateTime receivedDate;
  final DateTime createdAt;

  InventoryBatch({
    required this.id,
    required this.productId,
    this.batchNumber,
    required this.quantity,
    required this.costPrice,
    this.expiryDate,
    required this.receivedDate,
    required this.createdAt,
  });

  factory InventoryBatch.fromJson(Map<String, dynamic> json) {
    return InventoryBatch(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      batchNumber: json['batch_number'] as String?,
      quantity: (json['quantity'] as num).toDouble(),
      costPrice: (json['cost_price'] as num).toDouble(),
      expiryDate: json['expiry_date'] != null
          ? DateTime.parse(json['expiry_date'] as String)
          : null,
      receivedDate: DateTime.parse(json['received_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'batch_number': batchNumber,
      'quantity': quantity,
      'cost_price': costPrice,
      'expiry_date': expiryDate?.toIso8601String().split('T')[0],
      'received_date': receivedDate.toIso8601String().split('T')[0],
      'created_at': createdAt.toIso8601String(),
    };
  }

  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    return expiryDate!.difference(DateTime.now()).inDays;
  }

  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  bool get isNearExpiry {
    final days = daysUntilExpiry;
    return days != null && days <= 7 && days >= 0;
  }
}
