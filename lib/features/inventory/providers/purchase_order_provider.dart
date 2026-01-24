import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/purchase_order_model.dart';
import '../services/purchase_order_service.dart';

/// Purchase order list state
class PurchaseOrderState {
  final List<PurchaseOrder> orders;
  final bool isLoading;
  final String? error;
  final PurchaseOrderStatus? selectedStatus;
  final String searchQuery;

  PurchaseOrderState({
    this.orders = const [],
    this.isLoading = false,
    this.error,
    this.selectedStatus,
    this.searchQuery = '',
  });

  PurchaseOrderState copyWith({
    List<PurchaseOrder>? orders,
    bool? isLoading,
    String? error,
    PurchaseOrderStatus? selectedStatus,
    String? searchQuery,
    bool clearError = false,
    bool clearStatus = false,
  }) {
    return PurchaseOrderState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      selectedStatus: clearStatus
          ? null
          : (selectedStatus ?? this.selectedStatus),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// Purchase order provider
class PurchaseOrderNotifier extends StateNotifier<PurchaseOrderState> {
  final PurchaseOrderService _service;

  PurchaseOrderNotifier(this._service) : super(PurchaseOrderState());

  /// Load purchase orders
  Future<void> loadPurchaseOrders() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final orders = await _service.getPurchaseOrders(
        status: state.selectedStatus,
        searchQuery: state.searchQuery.isEmpty ? null : state.searchQuery,
      );
      state = state.copyWith(orders: orders, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Set selected status filter
  void setStatusFilter(PurchaseOrderStatus? status) {
    state = state.copyWith(selectedStatus: status, clearStatus: status == null);
    loadPurchaseOrders();
  }

  /// Set search query
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    loadPurchaseOrders();
  }

  /// Refresh orders
  Future<void> refresh() async {
    await loadPurchaseOrders();
  }

  /// Update order status
  Future<void> updateOrderStatus(
    String orderId,
    PurchaseOrderStatus status,
  ) async {
    try {
      await _service.updatePurchaseOrderStatus(
        orderId: orderId,
        status: status,
      );
      await loadPurchaseOrders();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Delete order
  Future<void> deleteOrder(String orderId) async {
    try {
      await _service.deletePurchaseOrder(orderId);
      await loadPurchaseOrders();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

/// Purchase order provider instance
final purchaseOrderServiceProvider = Provider<PurchaseOrderService>((ref) {
  return PurchaseOrderService();
});

final purchaseOrderProvider =
    StateNotifierProvider<PurchaseOrderNotifier, PurchaseOrderState>((ref) {
      final service = ref.watch(purchaseOrderServiceProvider);
      return PurchaseOrderNotifier(service);
    });
