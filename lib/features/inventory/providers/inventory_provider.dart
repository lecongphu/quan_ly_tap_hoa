import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../inventory/models/product_model.dart';
import '../../inventory/services/inventory_service.dart';

/// Filter model for inventory
class InventoryFilter {
  final String searchQuery;
  final String stockStatus; // all, in_stock, out_of_stock, low_stock
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? categoryId;

  const InventoryFilter({
    this.searchQuery = '',
    this.stockStatus = 'all',
    this.dateFrom,
    this.dateTo,
    this.categoryId,
  });

  InventoryFilter copyWith({
    String? searchQuery,
    String? stockStatus,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? categoryId,
    bool clearDateFrom = false,
    bool clearDateTo = false,
    bool clearCategory = false,
  }) {
    return InventoryFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      stockStatus: stockStatus ?? this.stockStatus,
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InventoryFilter &&
        other.searchQuery == searchQuery &&
        other.stockStatus == stockStatus &&
        other.dateFrom == dateFrom &&
        other.dateTo == dateTo &&
        other.categoryId == categoryId;
  }

  @override
  int get hashCode {
    return Object.hash(searchQuery, stockStatus, dateFrom, dateTo, categoryId);
  }

  bool get hasActiveFilters {
    return searchQuery.isNotEmpty ||
        stockStatus != 'all' ||
        dateFrom != null ||
        dateTo != null ||
        categoryId != null;
  }

  int get activeFilterCount {
    int count = 0;
    if (searchQuery.isNotEmpty) count++;
    if (stockStatus != 'all') count++;
    if (dateFrom != null || dateTo != null) count++;
    if (categoryId != null) count++;
    return count;
  }
}

/// Inventory service provider
final inventoryServiceProvider = Provider<InventoryService>((ref) {
  return InventoryService();
});

/// Current filter state provider
final inventoryFilterProvider = StateProvider<InventoryFilter>((ref) {
  return const InventoryFilter();
});

/// Products provider (unfiltered)
final productsProvider = FutureProvider<List<Product>>((ref) async {
  final inventoryService = ref.watch(inventoryServiceProvider);
  return await inventoryService.getProducts();
});

/// Filtered products provider
final filteredProductsProvider = FutureProvider<List<Product>>((ref) async {
  final inventoryService = ref.watch(inventoryServiceProvider);
  final filter = ref.watch(inventoryFilterProvider);

  return await inventoryService.getProducts(
    searchQuery: filter.searchQuery.isEmpty ? null : filter.searchQuery,
    stockStatus: filter.stockStatus,
    dateFrom: filter.dateFrom,
    dateTo: filter.dateTo,
    categoryId: filter.categoryId,
  );
});

/// Product search provider
final productSearchProvider = FutureProvider.family<List<Product>, String>((
  ref,
  query,
) async {
  final inventoryService = ref.watch(inventoryServiceProvider);
  return await inventoryService.getProducts(searchQuery: query);
});

/// Categories provider
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final inventoryService = ref.watch(inventoryServiceProvider);
  return await inventoryService.getCategories();
});

/// Products by category provider
final productsByCategoryProvider = FutureProvider.family<List<Product>, String>(
  (ref, categoryId) async {
    final inventoryService = ref.watch(inventoryServiceProvider);
    return await inventoryService.getProducts(categoryId: categoryId);
  },
);
