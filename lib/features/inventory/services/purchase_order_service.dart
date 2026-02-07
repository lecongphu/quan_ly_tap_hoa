import '../../../core/services/supabase_service.dart';
import '../models/purchase_order_model.dart';
import '../models/purchase_order_item_model.dart';
import '../models/supplier_model.dart';

/// Purchase order service for managing purchase orders
class PurchaseOrderService {
  /// Get all purchase orders with filters
  Future<List<PurchaseOrder>> getPurchaseOrders({
    PurchaseOrderStatus? status,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final supabase = SupabaseService.client;
      final data = await supabase
          .from('purchase_orders')
          .select('*, supplier:suppliers(name), items:purchase_order_items(*)')
          .order('created_at', ascending: false);

      var orders = (data as List<dynamic>).map((item) {
        final order = Map<String, dynamic>.from(item as Map);
        return PurchaseOrder.fromJson({
          ...order,
          'supplier_name': (order['supplier'] as Map?)?['name'],
          'items': order['items'] ?? [],
        });
      }).toList();

      if (status != null) {
        orders = orders.where((o) => o.status == status).toList();
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        final queryLower = searchQuery.toLowerCase();
        orders = orders
            .where((o) => o.orderNumber.toLowerCase().contains(queryLower))
            .toList();
      }

      if (startDate != null) {
        orders = orders.where((o) => o.createdAt.isAfter(startDate)).toList();
      }

      if (endDate != null) {
        final end = endDate.add(const Duration(days: 1));
        orders = orders.where((o) => o.createdAt.isBefore(end)).toList();
      }

      return orders;
    } catch (e) {
      throw Exception('Lỗi khi tải danh sách đơn nhập hàng: ${e.toString()}');
    }
  }

  /// Get purchase order by ID with items
  Future<PurchaseOrder?> getPurchaseOrderById(String orderId) async {
    try {
      final supabase = SupabaseService.client;
      final data = await supabase
          .from('purchase_orders')
          .select('*, supplier:suppliers(name), items:purchase_order_items(*)')
          .eq('id', orderId)
          .single();

      return PurchaseOrder.fromJson({
        ...data,
        'supplier_name': (data['supplier'] as Map?)?['name'],
        'items': data['items'] ?? [],
      });
    } catch (e) {
      return null;
    }
  }

  /// Create new purchase order
  Future<PurchaseOrder> createPurchaseOrder({
    required String orderNumber,
    required String supplierId,
    required List<PurchaseOrderItem> items,
    String? warehouse,
    String? notes,
    String? receivedById,
  }) async {
    try {
      final supabase = SupabaseService.client;
      final payloadItems = items
          .map(
            (item) => {
              'product_id': item.productId,
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
            },
          )
          .toList();

      final data = await supabase.rpc('create_purchase_order', params: {
        'p_items': payloadItems,
        'p_order_number': orderNumber,
        'p_supplier_id': supplierId,
        'p_warehouse': warehouse,
        'p_notes': notes,
      });

      final payload = Map<String, dynamic>.from(data as Map);
      final orderJson = Map<String, dynamic>.from(payload['order'] as Map);
      return PurchaseOrder.fromJson({
        ...orderJson,
        'supplier_name': null,
        'items': payloadItems,
      });
    } catch (e) {
      throw Exception('Lỗi khi tạo đơn nhập hàng: ${e.toString()}');
    }
  }

  /// Update purchase order status
  Future<PurchaseOrder> updatePurchaseOrderStatus({
    required String orderId,
    required PurchaseOrderStatus status,
  }) async {
    final supabase = SupabaseService.client;
    final data = await supabase
        .from('purchase_orders')
        .update({'status': status.value, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', orderId)
        .select('*, supplier:suppliers(name), items:purchase_order_items(*)')
        .single();

    return PurchaseOrder.fromJson({
      ...data,
      'supplier_name': (data['supplier'] as Map?)?['name'],
      'items': data['items'] ?? [],
    });
  }

  /// Delete purchase order
  Future<void> deletePurchaseOrder(String orderId) async {
    final supabase = SupabaseService.client;
    await supabase.from('purchase_orders').delete().eq('id', orderId);
  }

  /// Get all suppliers
  Future<List<Supplier>> getSuppliers({bool activeOnly = true}) async {
    try {
      final supabase = SupabaseService.client;
      final data = await supabase
          .from('suppliers')
          .select('*')
          .order('created_at', ascending: false);

      var suppliers = (data as List<dynamic>)
          .map((item) => Supplier.fromJson(item as Map<String, dynamic>))
          .toList();
      if (activeOnly) {
        suppliers = suppliers.where((s) => s.isActive).toList();
      }
      return suppliers;
    } catch (e) {
      throw Exception('Lỗi khi tải danh sách nhà cung cấp: ${e.toString()}');
    }
  }

  /// Create new supplier
  Future<Supplier> createSupplier({
    required String code,
    required String name,
    String? phone,
    String? email,
    String? address,
    String? taxCode,
  }) async {
    try {
      final supabase = SupabaseService.client;
      final data = await supabase
          .from('suppliers')
          .insert({
            'code': code,
            'name': name,
            'phone': phone,
            'email': email,
            'address': address,
            'tax_code': taxCode,
          })
          .select('*')
          .single();

      return Supplier.fromJson(data);
    } catch (e) {
      throw Exception('Lỗi khi tạo nhà cung cấp: ${e.toString()}');
    }
  }

  /// Generate next order number (client-side)
  Future<String> generateOrderNumber() async {
    final now = DateTime.now();
    final prefix = 'PO${now.year}${now.month.toString().padLeft(2, '0')}';
    final sequence = now.millisecondsSinceEpoch.toString().substring(7);
    return '$prefix$sequence';
  }
}
