import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../inventory/models/product_model.dart';
import '../services/product_service.dart';

/// Product state
class ProductState {
  final List<Product> products;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final String? selectedCategoryId;

  ProductState({
    this.products = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.selectedCategoryId,
  });

  ProductState copyWith({
    List<Product>? products,
    bool? isLoading,
    String? error,
    String? searchQuery,
    String? selectedCategoryId,
    bool clearError = false,
    bool clearCategoryFilter = false,
  }) {
    return ProductState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategoryId: clearCategoryFilter
          ? null
          : (selectedCategoryId ?? this.selectedCategoryId),
    );
  }
}

/// Product notifier
class ProductNotifier extends StateNotifier<ProductState> {
  final ProductService _service;

  ProductNotifier(this._service) : super(ProductState());

  /// Load products
  Future<void> loadProducts() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final products = await _service.getProducts(
        searchQuery: state.searchQuery.isEmpty ? null : state.searchQuery,
        categoryId: state.selectedCategoryId,
        isActive: true, // Only show active products
      );
      state = state.copyWith(products: products, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Set search query
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    loadProducts();
  }

  /// Set category filter
  void setCategoryFilter(String? categoryId) {
    state = state.copyWith(
      selectedCategoryId: categoryId,
      clearCategoryFilter: categoryId == null,
    );
    loadProducts();
  }

  /// Create product
  Future<void> createProduct({
    required String name,
    required String unit,
    required String categoryId,
    String? barcode,
    double? minStockLevel,
  }) async {
    try {
      await _service.createProduct(
        name: name,
        unit: unit,
        categoryId: categoryId,
        barcode: barcode,
        minStockLevel: minStockLevel,
      );
      await loadProducts();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Update product
  Future<void> updateProduct({
    required String productId,
    String? name,
    String? barcode,
    String? categoryId,
    String? unit,
    double? minStockLevel,
    bool? isActive,
  }) async {
    try {
      await _service.updateProduct(
        productId: productId,
        name: name,
        barcode: barcode,
        categoryId: categoryId,
        unit: unit,
        minStockLevel: minStockLevel,
        isActive: isActive,
      );
      await loadProducts();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Delete product
  Future<void> deleteProduct(String productId) async {
    try {
      await _service.deleteProduct(productId);
      await loadProducts();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Refresh products
  Future<void> refresh() async {
    await loadProducts();
  }
}

/// Product service provider
final productServiceProvider = Provider<ProductService>((ref) {
  return ProductService();
});

/// Product provider
final productProvider = StateNotifierProvider<ProductNotifier, ProductState>((
  ref,
) {
  final service = ref.watch(productServiceProvider);
  return ProductNotifier(service);
});
