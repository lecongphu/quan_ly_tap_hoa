import '../../../core/services/supabase_service.dart';
import '../models/product_model.dart';

/// Inventory service for product and stock management
class InventoryService {
  /// Get all products with current inventory
  Future<List<Product>> getProducts({
    String? categoryId,
    String? searchQuery,
    String stockStatus = 'all',
    DateTime? dateFrom,
    DateTime? dateTo,
    bool activeOnly = true,
  }) async {
    try {
      final supabase = SupabaseService.client;
      var query = supabase
          .from('products')
          .select('*, category:categories(name)');

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final products = await query.order('created_at', ascending: false);
      final inventoryRows =
          await supabase.from('current_inventory').select('*');

      final inventoryMap = <String, Map<String, dynamic>>{};
      for (final row in inventoryRows) {
        inventoryMap[row['product_id'] as String] =
            Map<String, dynamic>.from(row as Map);
      }

      var mapped = (products as List<dynamic>).map((item) {
        final product = Map<String, dynamic>.from(item as Map);
        final inventory = inventoryMap[product['id'] as String];
        return Product.fromJson({
          ...product,
          'category_name': (product['category'] as Map?)?['name'],
          'total_quantity': inventory?['total_quantity'],
          'avg_cost_price': inventory?['avg_cost_price'],
          'nearest_expiry_date': inventory?['nearest_expiry_date'],
        });
      }).toList();

      if (categoryId != null) {
        mapped = mapped.where((p) => p.categoryId == categoryId).toList();
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        final queryLower = searchQuery.toLowerCase();
        mapped = mapped.where((p) {
          return p.name.toLowerCase().contains(queryLower) ||
              (p.barcode?.toLowerCase().contains(queryLower) ?? false);
        }).toList();
      }

      switch (stockStatus) {
        case 'in_stock':
          mapped = mapped.where((p) => !p.isOutOfStock).toList();
          break;
        case 'out_of_stock':
          mapped = mapped.where((p) => p.isOutOfStock).toList();
          break;
        case 'low_stock':
          mapped = mapped.where((p) => p.isLowStock).toList();
          break;
      }

      if (dateFrom != null) {
        mapped = mapped.where((p) => p.createdAt.isAfter(dateFrom)).toList();
      }
      if (dateTo != null) {
        final endDate = dateTo.add(const Duration(days: 1));
        mapped = mapped.where((p) => p.createdAt.isBefore(endDate)).toList();
      }

      return mapped;
    } catch (e) {
      throw Exception('Lỗi khi tải danh sách sản phẩm: ${e.toString()}');
    }
  }

  /// Get product by ID
  Future<Product?> getProductById(String productId) async {
    try {
      final supabase = SupabaseService.client;
      final product = await supabase
          .from('products')
          .select('*, category:categories(name)')
          .eq('id', productId)
          .maybeSingle();

      if (product == null) return null;

      final inventory = await supabase
          .from('current_inventory')
          .select('*')
          .eq('product_id', productId)
          .maybeSingle();

      return Product.fromJson({
        ...Map<String, dynamic>.from(product),
        'category_name': (product['category'] as Map?)?['name'],
        'total_quantity': inventory?['total_quantity'],
        'avg_cost_price': inventory?['avg_cost_price'],
        'nearest_expiry_date': inventory?['nearest_expiry_date'],
      });
    } catch (e) {
      throw Exception('Lỗi khi tải sản phẩm: ${e.toString()}');
    }
  }

  /// Get product by barcode
  Future<Product?> getProductByBarcode(String barcode) async {
    try {
      final supabase = SupabaseService.client;
      final product = await supabase
          .from('products')
          .select('*, category:categories(name)')
          .eq('barcode', barcode)
          .maybeSingle();

      if (product == null) return null;

      final inventory = await supabase
          .from('current_inventory')
          .select('*')
          .eq('product_id', product['id'] as String)
          .maybeSingle();

      return Product.fromJson({
        ...Map<String, dynamic>.from(product),
        'category_name': (product['category'] as Map?)?['name'],
        'total_quantity': inventory?['total_quantity'],
        'avg_cost_price': inventory?['avg_cost_price'],
        'nearest_expiry_date': inventory?['nearest_expiry_date'],
      });
    } catch (e) {
      throw Exception('Lỗi khi tìm sản phẩm: ${e.toString()}');
    }
  }

  /// Get all categories
  Future<List<Category>> getCategories() async {
    try {
      final supabase = SupabaseService.client;
      final data = await supabase
          .from('categories')
          .select('*')
          .order('name', ascending: true);

      return (data as List<dynamic>)
          .map((item) => Category.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Lỗi khi tải danh mục: ${e.toString()}');
    }
  }

  /// Get products near expiry
  Future<List<Map<String, dynamic>>> getProductsNearExpiry({
    int daysThreshold = 7,
  }) async {
    try {
      final supabase = SupabaseService.client;
      final data = await supabase.rpc('get_products_near_expiry', params: {
        'days_threshold': daysThreshold,
      });
      return List<Map<String, dynamic>>.from(
        (data as List<dynamic>? ?? const []),
      );
    } catch (e) {
      throw Exception('Lỗi khi tải hàng sắp hết hạn: ${e.toString()}');
    }
  }

  /// Get low stock products
  Future<List<Map<String, dynamic>>> getLowStockProducts() async {
    try {
      final supabase = SupabaseService.client;
      final data = await supabase.rpc('get_low_stock_products');
      return List<Map<String, dynamic>>.from(
        (data as List<dynamic>? ?? const []),
      );
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
      final supabase = SupabaseService.client;
      final data = await supabase
          .from('products')
          .insert({
            'name': name,
            'barcode': barcode,
            'category_id': categoryId,
            'unit': unit,
            'min_stock_level': minStockLevel,
            'is_active': true,
          })
          .select('*, category:categories(name)')
          .single();

      return Product.fromJson({
        ...data,
        'category_name': (data['category'] as Map?)?['name'],
      });
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

      final supabase = SupabaseService.client;
      final data = await supabase
          .from('products')
          .update(updates)
          .eq('id', productId)
          .select('*, category:categories(name)')
          .single();

      return Product.fromJson({
        ...data,
        'category_name': (data['category'] as Map?)?['name'],
      });
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
      final supabase = SupabaseService.client;
      final data = await supabase.rpc('stock_in', params: {
        'p_product_id': productId,
        'p_quantity': quantity,
        'p_cost_price': costPrice,
        'p_batch_number': batchNumber,
        'p_expiry_date': expiryDate?.toIso8601String().split('T').first,
        'p_received_date':
            (receivedDate ?? DateTime.now()).toIso8601String().split('T').first,
      });

      return InventoryBatch.fromJson(Map<String, dynamic>.from(data as Map));
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
