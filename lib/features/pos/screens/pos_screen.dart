import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../providers/cart_provider.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../inventory/models/product_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/cart_model.dart' as cart_model;
import '../widgets/payment_dialog.dart';

class POSScreen extends ConsumerStatefulWidget {
  const POSScreen({super.key});

  @override
  ConsumerState<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends ConsumerState<POSScreen> {
  final _searchController = TextEditingController();
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleCheckout() async {
    final cartState = ref.read(cartProvider);

    if (cartState.items.isEmpty) {
      _showMessage('Giỏ hàng trống', isError: true);
      return;
    }

    // Show payment dialog
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => PaymentDialog(totalAmount: cartState.finalAmount),
    );

    if (result == null) return;

    try {
      final user = ref.read(currentUserProvider);

      await ref
          .read(cartProvider.notifier)
          .checkout(
            customerId: result['customerId'],
            paymentMethod: result['paymentMethod'],
            notes: result['notes'],
            createdBy: user?.id,
          );

      if (mounted) {
        _showMessage(SuccessMessages.saleSuccess);
      }
    } catch (e) {
      if (mounted) {
        _showMessage(e.toString(), isError: true);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bán hàng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(productsProvider);
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // Product list (left side)
          Expanded(
            flex: 2,
            child: Column(
              children: [
                // Search bar
                Padding(
                  padding: EdgeInsets.all(16.w),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Tìm sản phẩm (tên hoặc mã vạch)...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                ),

                // Product grid
                Expanded(
                  child: productsAsync.when(
                    data: (products) {
                      final filteredProducts = _searchController.text.isEmpty
                          ? products
                          : products
                                .where(
                                  (p) =>
                                      p.name.toLowerCase().contains(
                                        _searchController.text.toLowerCase(),
                                      ) ||
                                      (p.barcode?.contains(
                                            _searchController.text,
                                          ) ??
                                          false),
                                )
                                .toList();

                      if (filteredProducts.isEmpty) {
                        return const Center(
                          child: Text('Không tìm thấy sản phẩm'),
                        );
                      }

                      return GridView.builder(
                        padding: EdgeInsets.all(16.w),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 16.w,
                          mainAxisSpacing: 16.h,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index];
                          return _ProductCard(
                            product: product,
                            onTap: () {
                              ref
                                  .read(cartProvider.notifier)
                                  .addProduct(product);
                            },
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Center(child: Text('Lỗi: $error')),
                  ),
                ),
              ],
            ),
          ),

          // Cart (right side)
          Container(
            width: 400.w,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(-2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Cart header
                Container(
                  padding: EdgeInsets.all(16.w),
                  color: Theme.of(context).colorScheme.primary,
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_cart, color: Colors.white),
                      SizedBox(width: 8.w),
                      Text(
                        'Giỏ hàng (${cartState.itemCount})',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (cartState.items.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white),
                          onPressed: () {
                            ref.read(cartProvider.notifier).clearCart();
                          },
                        ),
                    ],
                  ),
                ),

                // Cart items
                Expanded(
                  child: cartState.items.isEmpty
                      ? const Center(child: Text('Giỏ hàng trống'))
                      : ListView.builder(
                          itemCount: cartState.items.length,
                          itemBuilder: (context, index) {
                            final item = cartState.items[index];
                            return _CartItemTile(item: item);
                          },
                        ),
                ),

                // Cart summary
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _SummaryRow(
                        label: 'Tạm tính:',
                        value: _currencyFormat.format(cartState.subtotal),
                      ),
                      if (cartState.discountAmount > 0)
                        _SummaryRow(
                          label: 'Giảm giá:',
                          value:
                              '-${_currencyFormat.format(cartState.discountAmount)}',
                          valueColor: Colors.red,
                        ),
                      Divider(height: 16.h),
                      _SummaryRow(
                        label: 'Tổng cộng:',
                        value: _currencyFormat.format(cartState.finalAmount),
                        isTotal: true,
                      ),
                      SizedBox(height: 16.h),
                      SizedBox(
                        width: double.infinity,
                        height: 50.h,
                        child: ElevatedButton(
                          onPressed:
                              cartState.items.isEmpty || cartState.isLoading
                              ? null
                              : _handleCheckout,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: cartState.isLoading
                              ? const CircularProgressIndicator()
                              : Text(
                                  'Thanh toán',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Product card widget
class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: product.isOutOfStock ? null : onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image placeholder
            Container(
              height: 100.h,
              color: Colors.grey[300],
              child: Center(
                child: Icon(
                  Icons.inventory_2,
                  size: 40.sp,
                  color: Colors.grey[600],
                ),
              ),
            ),

            Expanded(
              child: Padding(
                padding: EdgeInsets.all(8.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    if (product.avgCostPrice != null)
                      Text(
                        currencyFormat.format(product.avgCostPrice! * 1.3),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Icon(
                          product.isOutOfStock
                              ? Icons.remove_circle
                              : Icons.check_circle,
                          size: 14.sp,
                          color: product.isOutOfStock
                              ? Colors.red
                              : Colors.green,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          product.isOutOfStock
                              ? 'Hết hàng'
                              : '${product.currentStock?.toInt() ?? 0} ${product.unit}',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: product.isOutOfStock
                                ? Colors.red
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Cart item tile
class _CartItemTile extends ConsumerWidget {
  final cart_model.CartItem item;

  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      child: Padding(
        padding: EdgeInsets.all(8.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.product.name,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    ref
                        .read(cartProvider.notifier)
                        .removeProduct(item.product.id);
                  },
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                // Quantity controls
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () {
                    ref
                        .read(cartProvider.notifier)
                        .updateQuantity(item.product.id, item.quantity - 1);
                  },
                ),
                Text(
                  '${item.quantity.toInt()}',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    ref
                        .read(cartProvider.notifier)
                        .updateQuantity(item.product.id, item.quantity + 1);
                  },
                ),
                const Spacer(),
                Text(
                  currencyFormat.format(item.subtotal),
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Summary row
class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isTotal;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16.sp : 14.sp,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18.sp : 14.sp,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color:
                  valueColor ??
                  (isTotal ? Theme.of(context).colorScheme.primary : null),
            ),
          ),
        ],
      ),
    );
  }
}
