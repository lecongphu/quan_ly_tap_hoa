import '../../../core/services/supabase_service.dart';
import '../../inventory/models/product_model.dart';

/// Product service for managing products via Supabase
class ProductService {
  /// Create a new product
  Future<Product> createProduct({
    required String name,
    required String unit,
    required String categoryId,
    String? barcode,
    double? minStockLevel,
  }) async {
    try {
      final supabase = SupabaseService.client;
      final data = await supabase
          .from('products')
          .insert({
            'name': name,
            'unit': unit,
            'category_id': categoryId,
            'barcode': barcode,
            'min_stock_level': minStockLevel ?? 0,
            'is_active': true,
          })
          .select('*, category:categories(name)')
          .single();

      return Product.fromJson({
        ...data,
        'category_name': (data['category'] as Map?)?['name'],
      });
    } catch (e) {
      throw Exception('Lỗi khi tạo sản phẩm: ${e.toString()}');
    }
  }

  /// Get all products with optional filters
  Future<List<Product>> getProducts({
    String? searchQuery,
    String? categoryId,
    bool? isActive,
  }) async {
    try {
      final supabase = SupabaseService.client;
      final includeInactive = isActive == null ? true : !isActive;

      var query = supabase
          .from('products')
          .select('*, category:categories(name)');

      if (!includeInactive) {
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

      if (searchQuery != null && searchQuery.isNotEmpty) {
        final queryLower = searchQuery.toLowerCase();
        mapped = mapped.where((product) {
          return product.name.toLowerCase().contains(queryLower) ||
              (product.barcode?.toLowerCase().contains(queryLower) ?? false);
        }).toList();
      }

      if (categoryId != null) {
        mapped = mapped.where((product) => product.categoryId == categoryId).toList();
      }

      if (isActive != null) {
        mapped = mapped.where((product) => product.isActive == isActive).toList();
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

  /// Delete product (soft delete)
  Future<void> deleteProduct(String productId) async {
    try {
      final supabase = SupabaseService.client;
      await supabase
          .from('products')
          .update({'is_active': false})
          .eq('id', productId);
    } catch (e) {
      throw Exception('Lỗi khi xóa sản phẩm: ${e.toString()}');
    }
  }

  /// Hard delete product (fallback to soft delete)
  Future<void> hardDeleteProduct(String productId) async {
    await deleteProduct(productId);
  }
}
