import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart_model.dart';
import '../services/pos_service.dart';
import '../../inventory/models/product_model.dart';
import '../../../core/constants/app_constants.dart';

/// Cart state
class CartState {
  final List<CartItem> items;
  final double discountAmount;
  final bool isLoading;
  final String? error;

  CartState({
    this.items = const [],
    this.discountAmount = 0,
    this.isLoading = false,
    this.error,
  });

  CartState copyWith({
    List<CartItem>? items,
    double? discountAmount,
    bool? isLoading,
    String? error,
  }) {
    return CartState(
      items: items ?? this.items,
      discountAmount: discountAmount ?? this.discountAmount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  double get subtotal =>
      items.fold<double>(0, (sum, item) => sum + item.subtotal);

  double get totalDiscount =>
      items.fold<double>(0, (sum, item) => sum + item.discount) +
      discountAmount;

  double get finalAmount => subtotal - discountAmount;

  int get itemCount => items.length;

  int get totalQuantity =>
      items.fold<int>(0, (sum, item) => sum + item.quantity.toInt());
}

/// Cart notifier
class CartNotifier extends StateNotifier<CartState> {
  final POSService _posService;

  CartNotifier(this._posService) : super(CartState());

  /// Add product to cart
  void addProduct(Product product, {double unitPrice = 0}) {
    final existingIndex = state.items.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (existingIndex >= 0) {
      // Update quantity if product already in cart
      final updatedItems = List<CartItem>.from(state.items);
      updatedItems[existingIndex] = updatedItems[existingIndex].copyWith(
        quantity: updatedItems[existingIndex].quantity + 1,
      );
      state = state.copyWith(items: updatedItems);
    } else {
      // Add new item to cart
      final newItem = CartItem(
        product: product,
        quantity: 1,
        unitPrice: unitPrice > 0
            ? unitPrice
            : (product.avgCostPrice ?? 0) *
                AppConstants.defaultSalePriceMultiplier,
        // Default markup 30%
        costPrice: product.avgCostPrice,
      );
      state = state.copyWith(items: [...state.items, newItem]);
    }
  }

  /// Update item quantity
  void updateQuantity(String productId, double quantity) {
    if (quantity <= 0) {
      removeProduct(productId);
      return;
    }

    final updatedItems = state.items.map((item) {
      if (item.product.id == productId) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();

    state = state.copyWith(items: updatedItems);
  }

  /// Update item price
  void updatePrice(String productId, double unitPrice) {
    final updatedItems = state.items.map((item) {
      if (item.product.id == productId) {
        return item.copyWith(unitPrice: unitPrice);
      }
      return item;
    }).toList();

    state = state.copyWith(items: updatedItems);
  }

  /// Update item discount
  void updateItemDiscount(String productId, double discount) {
    final updatedItems = state.items.map((item) {
      if (item.product.id == productId) {
        return item.copyWith(discount: discount);
      }
      return item;
    }).toList();

    state = state.copyWith(items: updatedItems);
  }

  /// Remove product from cart
  void removeProduct(String productId) {
    final updatedItems = state.items
        .where((item) => item.product.id != productId)
        .toList();
    state = state.copyWith(items: updatedItems);
  }

  /// Set cart discount
  void setDiscount(double discount) {
    state = state.copyWith(discountAmount: discount);
  }

  /// Clear cart
  void clearCart() {
    state = CartState();
  }

  /// Checkout
  Future<Sale> checkout({
    String? customerId,
    required String paymentMethod,
    double discountAmount = 0,
    DateTime? dueDate,
    String? notes,
    String? createdBy,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final sale = await _posService.createSale(
        cartItems: state.items,
        customerId: customerId,
        paymentMethod: paymentMethod,
        discountAmount: discountAmount,
        dueDate: dueDate,
        notes: notes,
        createdBy: createdBy,
      );

      // Clear cart after successful checkout
      clearCart();

      return sale;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }
}

/// POS service provider
final posServiceProvider = Provider<POSService>((ref) {
  return POSService();
});

/// Cart provider
final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  final posService = ref.watch(posServiceProvider);
  return CartNotifier(posService);
});

/// Cart item count provider
final cartItemCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).itemCount;
});

/// Cart total provider
final cartTotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).finalAmount;
});
