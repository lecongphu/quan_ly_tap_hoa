import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../models/purchase_order_model.dart';
import '../models/purchase_order_item_model.dart';
import '../models/supplier_model.dart';

/// Purchase order service for managing purchase orders
class PurchaseOrderService {
  final SupabaseClient _supabase = SupabaseService.instance.client;

  /// Get all purchase orders with filters
  Future<List<PurchaseOrder>> getPurchaseOrders({
    PurchaseOrderStatus? status,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _supabase.from('purchase_orders').select('''
            *,
            suppliers:supplier_id(id, name),
            received_by_profile:profiles!purchase_orders_received_by_fkey(id, full_name),
            created_by_profile:profiles!purchase_orders_created_by_fkey(id, full_name)
          ''');

      if (status != null) {
        query = query.eq('status', status.value);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or('order_number.ilike.%$searchQuery%');
      }

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List).map((item) {
        final data = Map<String, dynamic>.from(item);

        // Extract supplier name
        if (data['suppliers'] != null) {
          data['supplier_name'] = data['suppliers']['name'];
        }

        // Extract received by name
        if (data['received_by_profile'] != null &&
            data['received_by_profile'] is Map) {
          data['received_by_name'] = data['received_by_profile']['full_name'];
        }

        // Extract created by name
        if (data['created_by_profile'] != null &&
            data['created_by_profile'] is Map) {
          data['created_by_name'] = data['created_by_profile']['full_name'];
        }

        return PurchaseOrder.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Lỗi khi tải danh sách đơn nhập hàng: ${e.toString()}');
    }
  }

  /// Get purchase order by ID with items
  Future<PurchaseOrder?> getPurchaseOrderById(String orderId) async {
    try {
      final response = await _supabase
          .from('purchase_orders')
          .select('''
            *,
            suppliers:supplier_id(id, name),
            received_by_profile:profiles!purchase_orders_received_by_fkey(id, full_name),
            created_by_profile:profiles!purchase_orders_created_by_fkey(id, full_name),
            purchase_order_items(
              *,
              products(id, name, unit)
            )
          ''')
          .eq('id', orderId)
          .maybeSingle();

      if (response == null) return null;

      final data = Map<String, dynamic>.from(response);

      // Extract supplier name
      if (data['suppliers'] != null) {
        data['supplier_name'] = data['suppliers']['name'];
      }

      // Extract received by name
      if (data['received_by_profile'] != null &&
          data['received_by_profile'] is Map) {
        data['received_by_name'] = data['received_by_profile']['full_name'];
      }

      // Extract created by name
      if (data['created_by_profile'] != null &&
          data['created_by_profile'] is Map) {
        data['created_by_name'] = data['created_by_profile']['full_name'];
      }

      // Process items
      if (data['purchase_order_items'] != null) {
        final items = (data['purchase_order_items'] as List).map((item) {
          final itemData = Map<String, dynamic>.from(item);
          if (itemData['products'] != null) {
            itemData['product_name'] = itemData['products']['name'];
            itemData['product_unit'] = itemData['products']['unit'];
          }
          return PurchaseOrderItem.fromJson(itemData);
        }).toList();
        data['items'] = items;
      }

      return PurchaseOrder.fromJson(data);
    } catch (e) {
      throw Exception('Lỗi khi tải đơn nhập hàng: ${e.toString()}');
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
      // Calculate total amount
      final totalAmount = items.fold<double>(
        0,
        (sum, item) => sum + item.subtotal,
      );

      // Get current user
      final userId = _supabase.auth.currentUser?.id;

      // Insert purchase order
      final orderResponse = await _supabase
          .from('purchase_orders')
          .insert({
            'order_number': orderNumber,
            'supplier_id': supplierId,
            'status': PurchaseOrderStatus.pending.value,
            'total_amount': totalAmount,
            'warehouse': warehouse,
            'notes': notes,
            'received_by': receivedById,
            'created_by': userId,
          })
          .select()
          .single();

      final orderId = orderResponse['id'] as String;

      // Insert purchase order items
      final itemsData = items
          .map(
            (item) => {
              'purchase_order_id': orderId,
              'product_id': item.productId,
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
              'subtotal': item.subtotal,
            },
          )
          .toList();

      await _supabase.from('purchase_order_items').insert(itemsData);

      // Fetch the complete order with items
      return (await getPurchaseOrderById(orderId))!;
    } catch (e) {
      throw Exception('Lỗi khi tạo đơn nhập hàng: ${e.toString()}');
    }
  }

  /// Update purchase order status
  Future<PurchaseOrder> updatePurchaseOrderStatus({
    required String orderId,
    required PurchaseOrderStatus status,
  }) async {
    try {
      await _supabase
          .from('purchase_orders')
          .update({'status': status.value})
          .eq('id', orderId);

      return (await getPurchaseOrderById(orderId))!;
    } catch (e) {
      throw Exception('Lỗi khi cập nhật trạng thái: ${e.toString()}');
    }
  }

  /// Delete purchase order
  Future<void> deletePurchaseOrder(String orderId) async {
    try {
      await _supabase.from('purchase_orders').delete().eq('id', orderId);
    } catch (e) {
      throw Exception('Lỗi khi xóa đơn nhập hàng: ${e.toString()}');
    }
  }

  /// Get all suppliers
  Future<List<Supplier>> getSuppliers({bool activeOnly = true}) async {
    try {
      var query = _supabase.from('suppliers').select();

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final response = await query.order('name');

      return (response as List).map((item) => Supplier.fromJson(item)).toList();
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
      final response = await _supabase
          .from('suppliers')
          .insert({
            'code': code,
            'name': name,
            'phone': phone,
            'email': email,
            'address': address,
            'tax_code': taxCode,
          })
          .select()
          .single();

      return Supplier.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi khi tạo nhà cung cấp: ${e.toString()}');
    }
  }

  /// Generate next order number
  Future<String> generateOrderNumber() async {
    try {
      final now = DateTime.now();
      final prefix = 'PO${now.year}${now.month.toString().padLeft(2, '0')}';

      final response = await _supabase
          .from('purchase_orders')
          .select('order_number')
          .like('order_number', '$prefix%')
          .order('order_number', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        return '${prefix}0001';
      }

      final lastNumber = response['order_number'] as String;
      final lastSequence = int.parse(lastNumber.substring(prefix.length));
      final nextSequence = (lastSequence + 1).toString().padLeft(4, '0');

      return '$prefix$nextSequence';
    } catch (e) {
      // Fallback to timestamp-based number
      final now = DateTime.now();
      return 'PO${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    }
  }
}
