import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../inventory/models/product_model.dart';

/// Product service for managing products in Supabase
class ProductService {
  final SupabaseClient _supabase = SupabaseService.instance.client;

  /// Create a new product
  Future<Product> createProduct({
    required String name,
    required String unit,
    required String categoryId,
    String? barcode,
    double? minStockLevel,
  }) async {
    try {
      final response = await _supabase
          .from('products')
          .insert({
            'name': name,
            'unit': unit,
            'category_id': categoryId,
            'barcode': barcode,
            'min_stock_level': minStockLevel ?? 0,
            'is_active': true,
          })
          .select()
          .single();

      return Product.fromJson(response);
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
      var query = _supabase.from('products').select('''
            *,
            categories:category_id(id, name)
          ''');

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or(
          'name.ilike.%$searchQuery%,barcode.ilike.%$searchQuery%',
        );
      }

      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }

      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }

      final response = await query.order('name');

      return (response as List).map((item) {
        final data = Map<String, dynamic>.from(item);

        // Extract category name
        if (data['categories'] != null) {
          data['category_name'] = data['categories']['name'];
        }

        return Product.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Lỗi khi tải danh sách sản phẩm: ${e.toString()}');
    }
  }

  /// Get product by ID
  Future<Product?> getProductById(String productId) async {
    try {
      final response = await _supabase
          .from('products')
          .select('''
            *,
            categories:category_id(id, name)
          ''')
          .eq('id', productId)
          .maybeSingle();

      if (response == null) return null;

      final data = Map<String, dynamic>.from(response);

      // Extract category name
      if (data['categories'] != null) {
        data['category_name'] = data['categories']['name'];
      }

      return Product.fromJson(data);
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
      final updateData = <String, dynamic>{};

      if (name != null) updateData['name'] = name;
      if (barcode != null) updateData['barcode'] = barcode;
      if (categoryId != null) updateData['category_id'] = categoryId;
      if (unit != null) updateData['unit'] = unit;
      if (minStockLevel != null) updateData['min_stock_level'] = minStockLevel;
      if (isActive != null) updateData['is_active'] = isActive;

      updateData['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('products')
          .update(updateData)
          .eq('id', productId)
          .select('''
            *,
            categories:category_id(id, name)
          ''')
          .single();

      final data = Map<String, dynamic>.from(response);

      // Extract category name
      if (data['categories'] != null) {
        data['category_name'] = data['categories']['name'];
      }

      return Product.fromJson(data);
    } catch (e) {
      throw Exception('Lỗi khi cập nhật sản phẩm: ${e.toString()}');
    }
  }

  /// Delete product (soft delete by setting is_active to false)
  Future<void> deleteProduct(String productId) async {
    try {
      await _supabase
          .from('products')
          .update({'is_active': false})
          .eq('id', productId);
    } catch (e) {
      throw Exception('Lỗi khi xóa sản phẩm: ${e.toString()}');
    }
  }

  /// Hard delete product (permanently remove from database)
  Future<void> hardDeleteProduct(String productId) async {
    try {
      await _supabase.from('products').delete().eq('id', productId);
    } catch (e) {
      throw Exception('Lỗi khi xóa vĩnh viễn sản phẩm: ${e.toString()}');
    }
  }
}
