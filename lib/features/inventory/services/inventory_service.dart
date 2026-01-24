import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/constants/app_constants.dart';
import '../models/product_model.dart';

/// Inventory service for product and stock management
class InventoryService {
  final SupabaseClient _supabase = SupabaseService.instance.client;

  /// Get all products with current inventory
  ///
  /// [stockStatus] can be: 'all', 'in_stock', 'out_of_stock', 'low_stock'
  /// [dateFrom] and [dateTo] filter by created_at date
  Future<List<Product>> getProducts({
    String? categoryId,
    String? searchQuery,
    String stockStatus = 'all',
    DateTime? dateFrom,
    DateTime? dateTo,
    bool activeOnly = true,
  }) async {
    try {
      var query = _supabase.from('current_inventory').select();

      if (activeOnly) {
        // Note: current_inventory view already filters active products
      }

      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or(
          'name.ilike.%$searchQuery%,barcode.ilike.%$searchQuery%',
        );
      }

      // Filter by stock status
      switch (stockStatus) {
        case 'in_stock':
          query = query.gt('total_quantity', 0);
          break;
        case 'out_of_stock':
          query = query.or('total_quantity.is.null,total_quantity.lte.0');
          break;
        case 'low_stock':
          // Products where stock <= min_stock_level
          query = query.not('min_stock_level', 'eq', 0);
          break;
      }

      // Filter by date range
      if (dateFrom != null) {
        query = query.gte('created_at', dateFrom.toIso8601String());
      }
      if (dateTo != null) {
        // Add 1 day to include the end date
        final endDate = dateTo.add(const Duration(days: 1));
        query = query.lt('created_at', endDate.toIso8601String());
      }

      final response = await query.order('name');

      List<Product> products = (response as List)
          .map((item) => Product.fromJson(item))
          .toList();

      // Additional client-side filtering for low_stock
      // (since SQL comparison with min_stock_level requires more complex query)
      if (stockStatus == 'low_stock') {
        products = products.where((p) {
          return p.minStockLevel > 0 &&
              (p.currentStock ?? 0) <= p.minStockLevel;
        }).toList();
      }

      return products;
    } catch (e) {
      throw Exception('Lỗi khi tải danh sách sản phẩm: ${e.toString()}');
    }
  }

  /// Get product by ID
  Future<Product?> getProductById(String productId) async {
    try {
      final response = await _supabase
          .from('current_inventory')
          .select()
          .eq('product_id', productId)
          .maybeSingle();

      if (response == null) return null;
      return Product.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi khi tải sản phẩm: ${e.toString()}');
    }
  }

  /// Get product by barcode
  Future<Product?> getProductByBarcode(String barcode) async {
    try {
      final response = await _supabase
          .from('current_inventory')
          .select()
          .eq('barcode', barcode)
          .maybeSingle();

      if (response == null) return null;
      return Product.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi khi tìm sản phẩm: ${e.toString()}');
    }
  }

  /// Get all categories
  Future<List<Category>> getCategories() async {
    try {
      final response = await _supabase
          .from(AppConstants.tableCategories)
          .select()
          .order('name');

      return (response as List).map((item) => Category.fromJson(item)).toList();
    } catch (e) {
      throw Exception('Lỗi khi tải danh mục: ${e.toString()}');
    }
  }

  /// Get inventory batches for a product (for FEFO)
  Future<List<InventoryBatch>> getProductBatches(String productId) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableInventoryBatches)
          .select()
          .eq('product_id', productId)
          .gt('quantity', 0)
          .order('expiry_date', ascending: true)
          .order('received_date', ascending: true);

      return (response as List)
          .map((item) => InventoryBatch.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Lỗi khi tải lô hàng: ${e.toString()}');
    }
  }

  /// Get FEFO batch for a product (First Expired, First Out)
  Future<InventoryBatch?> getFEFOBatch(
    String productId,
    double quantity,
  ) async {
    try {
      final batches = await getProductBatches(productId);

      // Find first batch with enough quantity
      for (var batch in batches) {
        if (batch.quantity >= quantity) {
          return batch;
        }
      }

      // If no single batch has enough, return the first batch
      // (caller will need to handle multiple batches)
      return batches.isNotEmpty ? batches.first : null;
    } catch (e) {
      throw Exception('Lỗi khi lấy lô hàng FEFO: ${e.toString()}');
    }
  }

  /// Get products near expiry
  Future<List<Map<String, dynamic>>> getProductsNearExpiry({
    int daysThreshold = 7,
  }) async {
    try {
      final response = await _supabase.rpc(
        'get_products_near_expiry',
        params: {'days_threshold': daysThreshold},
      );

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      throw Exception('Lỗi khi tải hàng sắp hết hạn: ${e.toString()}');
    }
  }

  /// Get low stock products
  Future<List<Map<String, dynamic>>> getLowStockProducts() async {
    try {
      final response = await _supabase.rpc('get_low_stock_products');
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      throw Exception('Lỗi khi tải hàng tồn kho thấp: ${e.toString()}');
    }
  }

  /// Add new product
  Future<Product> addProduct({
    required String name,
    String? barcode,
    String? categoryId,
    required String unit,
    double minStockLevel = 0,
  }) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableProducts)
          .insert({
            'name': name,
            'barcode': barcode,
            'category_id': categoryId,
            'unit': unit,
            'min_stock_level': minStockLevel,
          })
          .select()
          .single();

      return Product.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi khi thêm sản phẩm: ${e.toString()}');
    }
  }

  /// Update product
  Future<Product> updateProduct({
    required String productId,
    String? name,
    String? barcode,
    String? categoryId,
    String? unit,
    double? minStockLevel,
    bool? isActive,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (barcode != null) updates['barcode'] = barcode;
      if (categoryId != null) updates['category_id'] = categoryId;
      if (unit != null) updates['unit'] = unit;
      if (minStockLevel != null) updates['min_stock_level'] = minStockLevel;
      if (isActive != null) updates['is_active'] = isActive;

      final response = await _supabase
          .from(AppConstants.tableProducts)
          .update(updates)
          .eq('id', productId)
          .select()
          .single();

      return Product.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi khi cập nhật sản phẩm: ${e.toString()}');
    }
  }

  /// Stock in (nhập kho)
  Future<InventoryBatch> stockIn({
    required String productId,
    required double quantity,
    required double costPrice,
    String? batchNumber,
    DateTime? expiryDate,
    DateTime? receivedDate,
  }) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableInventoryBatches)
          .insert({
            'product_id': productId,
            'quantity': quantity,
            'cost_price': costPrice,
            'batch_number': batchNumber,
            'expiry_date': expiryDate?.toIso8601String().split('T')[0],
            'received_date': (receivedDate ?? DateTime.now())
                .toIso8601String()
                .split('T')[0],
          })
          .select()
          .single();

      return InventoryBatch.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi khi nhập kho: ${e.toString()}');
    }
  }

  /// Check stock availability
  Future<bool> checkStockAvailability(String productId, double quantity) async {
    try {
      final product = await getProductById(productId);
      if (product == null) return false;
      return product.currentStock != null && product.currentStock! >= quantity;
    } catch (e) {
      return false;
    }
  }
}
