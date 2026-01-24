import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../inventory/models/product_model.dart';
import '../../inventory/services/inventory_service.dart';

/// Inventory service provider
final inventoryServiceProvider = Provider<InventoryService>((ref) {
  return InventoryService();
});

/// Products provider
final productsProvider = FutureProvider<List<Product>>((ref) async {
  final inventoryService = ref.watch(inventoryServiceProvider);
  return await inventoryService.getProducts();
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
