import 'purchase_order_item_model.dart';

enum PurchaseOrderStatus {
  pending,
  inProgress,
  completed,
  cancelled;

  String get displayName {
    switch (this) {
      case PurchaseOrderStatus.pending:
        return 'Chờ xử lý';
      case PurchaseOrderStatus.inProgress:
        return 'Đang giao dịch';
      case PurchaseOrderStatus.completed:
        return 'Hoàn thành';
      case PurchaseOrderStatus.cancelled:
        return 'Đã hủy';
    }
  }

  String get value {
    switch (this) {
      case PurchaseOrderStatus.pending:
        return 'pending';
      case PurchaseOrderStatus.inProgress:
        return 'in_progress';
      case PurchaseOrderStatus.completed:
        return 'completed';
      case PurchaseOrderStatus.cancelled:
        return 'cancelled';
    }
  }

  static PurchaseOrderStatus fromString(String status) {
    switch (status) {
      case 'pending':
        return PurchaseOrderStatus.pending;
      case 'in_progress':
        return PurchaseOrderStatus.inProgress;
      case 'completed':
        return PurchaseOrderStatus.completed;
      case 'cancelled':
        return PurchaseOrderStatus.cancelled;
      default:
        return PurchaseOrderStatus.pending;
    }
  }
}

class PurchaseOrder {
  final String id;
  final String orderNumber;
  final String? supplierId;
  final String? supplierName;
  final PurchaseOrderStatus status;
  final double totalAmount;
  final String? warehouse;
  final String? notes;
  final String? receivedById;
  final String? receivedByName;
  final String? createdById;
  final String? createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<PurchaseOrderItem> items;

  PurchaseOrder({
    required this.id,
    required this.orderNumber,
    this.supplierId,
    this.supplierName,
    required this.status,
    required this.totalAmount,
    this.warehouse,
    this.notes,
    this.receivedById,
    this.receivedByName,
    this.createdById,
    this.createdByName,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    return PurchaseOrder(
      id: json['id'] as String,
      orderNumber: json['order_number'] as String,
      supplierId: json['supplier_id'] as String?,
      supplierName: json['supplier_name'] as String?,
      status: PurchaseOrderStatus.fromString(json['status'] as String),
      totalAmount: (json['total_amount'] as num).toDouble(),
      warehouse: json['warehouse'] as String?,
      notes: json['notes'] as String?,
      receivedById: json['received_by'] as String?,
      receivedByName: json['received_by_name'] as String?,
      createdById: json['created_by'] as String?,
      createdByName: json['created_by_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      items:
          (json['items'] as List<dynamic>?)
              ?.map(
                (item) =>
                    PurchaseOrderItem.fromJson(item as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_number': orderNumber,
      'supplier_id': supplierId,
      'status': status.value,
      'total_amount': totalAmount,
      'warehouse': warehouse,
      'notes': notes,
      'received_by': receivedById,
      'created_by': createdById,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  PurchaseOrder copyWith({
    String? id,
    String? orderNumber,
    String? supplierId,
    String? supplierName,
    PurchaseOrderStatus? status,
    double? totalAmount,
    String? warehouse,
    String? notes,
    String? receivedById,
    String? receivedByName,
    String? createdById,
    String? createdByName,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<PurchaseOrderItem>? items,
  }) {
    return PurchaseOrder(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      warehouse: warehouse ?? this.warehouse,
      notes: notes ?? this.notes,
      receivedById: receivedById ?? this.receivedById,
      receivedByName: receivedByName ?? this.receivedByName,
      createdById: createdById ?? this.createdById,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }

  int get totalItems =>
      items.fold(0, (sum, item) => sum + item.quantity.toInt());
}
