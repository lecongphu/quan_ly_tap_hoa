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

  void _clearSearch() {
    _searchController.clear();
    setState(() {});
  }

  void _refreshProducts() {
    ref.invalidate(productsProvider);
    setState(() {});
  }

  List<Product> _filterProducts(List<Product> products) {
    if (_searchController.text.isEmpty) return products;
    final query = _searchController.text.toLowerCase();
    return products
        .where(
          (p) =>
              p.name.toLowerCase().contains(query) ||
              (p.barcode?.contains(_searchController.text) ?? false),
        )
        .toList();
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
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới danh sách',
            onPressed: _refreshProducts,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1200;
            final horizontalPadding =
                constraints.maxWidth > 1400 ? 64.w : 24.w;
            final crossAxisCount = constraints.maxWidth >= 1700
                ? 5
                : constraints.maxWidth >= 1450
                    ? 4
                    : constraints.maxWidth >= 1150
                        ? 3
                        : 2;

            final content = [
              Expanded(
                flex: isWide ? 5 : 1,
                child: _ProductPanel(
                  searchController: _searchController,
                  onClearSearch: _clearSearch,
                  onRefresh: _refreshProducts,
                  onSearchChanged: () => setState(() {}),
                  productsAsync: productsAsync,
                  filterProducts: _filterProducts,
                  crossAxisCount: crossAxisCount,
                ),
              ),
              SizedBox(
                width: isWide ? 18.w : 0,
                height: isWide ? 0 : 18.h,
              ),
              SizedBox(
                width: isWide ? 420.w : double.infinity,
                child: _CartPanel(
                  cartState: cartState,
                  currencyFormat: _currencyFormat,
                  onCheckout: _handleCheckout,
                ),
              ),
            ];

            return Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                20.h,
                horizontalPadding,
                28.h,
              ),
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: content,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: content,
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _ProductPanel extends StatelessWidget {
  const _ProductPanel({
    required this.searchController,
    required this.onClearSearch,
    required this.onRefresh,
    required this.onSearchChanged,
    required this.productsAsync,
    required this.filterProducts,
    required this.crossAxisCount,
  });

  final TextEditingController searchController;
  final VoidCallback onClearSearch;
  final VoidCallback onRefresh;
  final VoidCallback onSearchChanged;
  final AsyncValue<List<Product>> productsAsync;
  final List<Product> Function(List<Product>) filterProducts;
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProductHeader(
          onRefresh: onRefresh,
          totalLabel: productsAsync.maybeWhen(
            data: (products) => 'Sản phẩm: ${products.length}',
            orElse: () => 'Sản phẩm',
          ),
        ),
        SizedBox(height: 14.h),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    onChanged: (_) => onSearchChanged(),
                    decoration: InputDecoration(
                      hintText: 'Tìm sản phẩm (tên hoặc mã vạch)...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'Xóa từ khóa',
                              onPressed: onClearSearch,
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.r),
                        borderSide:
                            BorderSide(color: scheme.outline.withOpacity(0.4)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.r),
                        borderSide:
                            BorderSide(color: scheme.outline.withOpacity(0.35)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.r),
                        borderSide: BorderSide(color: scheme.primary, width: 1.4),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 14.h,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                IconButton.filledTonal(
                  onPressed: onRefresh,
                  tooltip: 'Làm mới',
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 14.h),
        Expanded(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(12.w),
              child: productsAsync.when(
                data: (products) {
                  final filteredProducts = filterProducts(products);

                  if (filteredProducts.isEmpty) {
                    return const _ProductsEmptyState();
                  }

                  return GridView.builder(
                    padding: EdgeInsets.all(6.w),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12.w,
                      mainAxisSpacing: 12.h,
                      childAspectRatio: crossAxisCount <= 2 ? 0.92 : 0.86,
                    ),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      return _ProductCard(product: product);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _ProductsErrorState(error: '$error'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductHeader extends StatelessWidget {
  const _ProductHeader({required this.onRefresh, required this.totalLabel});

  final VoidCallback onRefresh;
  final String totalLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF38BDF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.24),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Wrap(
        spacing: 12.w,
        runSpacing: 12.h,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chọn sản phẩm',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Chạm để thêm nhanh vào giỏ hàng.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white.withOpacity(0.92),
                    ),
              ),
            ],
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2_rounded, color: scheme.primary),
                SizedBox(width: 8.w),
                Text(
                  totalLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
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

class _CartPanel extends ConsumerWidget {
  const _CartPanel({
    required this.cartState,
    required this.currencyFormat,
    required this.onCheckout,
  });

  final CartState cartState;
  final NumberFormat currencyFormat;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outline.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart_rounded, color: Colors.white),
                SizedBox(width: 8.w),
                Text(
                  'Giỏ hàng (${cartState.itemCount})',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (cartState.items.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: Colors.white,
                    tooltip: 'Xóa giỏ hàng',
                    onPressed: () => ref.read(cartProvider.notifier).clearCart(),
                  ),
              ],
            ),
          ),
          Expanded(
            child: cartState.items.isEmpty
                ? const _CartEmptyState()
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 6.h),
                    itemCount: cartState.items.length,
                    itemBuilder: (context, index) {
                      final item = cartState.items[index];
                      return _CartItemTile(item: item);
                    },
                  ),
          ),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: scheme.outline.withOpacity(0.08)),
              ),
            ),
            child: Column(
              children: [
                _SummaryRow(
                  label: 'Tạm tính',
                  value: currencyFormat.format(cartState.subtotal),
                ),
                if (cartState.discountAmount > 0)
                  _SummaryRow(
                    label: 'Giảm giá',
                    value: '-${currencyFormat.format(cartState.discountAmount)}',
                    valueColor: scheme.error,
                  ),
                Divider(height: 18.h),
                _SummaryRow(
                  label: 'Tổng cộng',
                  value: currencyFormat.format(cartState.finalAmount),
                  isTotal: true,
                ),
                SizedBox(height: 14.h),
                SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: FilledButton(
                    onPressed: cartState.items.isEmpty || cartState.isLoading
                        ? null
                        : onCheckout,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                    child: cartState.isLoading
                        ? SizedBox(
                            height: 22.h,
                            width: 22.h,
                            child: const CircularProgressIndicator(strokeWidth: 2.6),
                          )
                        : Text(
                            'Thanh toán ngay',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
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

class _ProductCard extends ConsumerWidget {
  const _ProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final currencyFormat =
        NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final price = product.avgCostPrice != null
        ? currencyFormat.format(product.avgCostPrice! * 1.3)
        : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: product.isOutOfStock
            ? null
            : () => ref.read(cartProvider.notifier).addProduct(product),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 104.h,
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.08),
              ),
              child: Center(
                child: Icon(
                  Icons.inventory_2_rounded,
                  size: 44.sp,
                  color: scheme.primary,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      product.categoryName ?? 'Chưa phân loại',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    if (price != null)
                      Text(
                        price,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: scheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    SizedBox(height: 6.h),
                    _StockBadge(product: product),
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

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final isOut = product.isOutOfStock;
    final color = isOut
        ? Theme.of(context).colorScheme.error
        : const Color(0xFF16A34A);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOut
                ? Icons.remove_circle_outline_rounded
                : Icons.check_circle_rounded,
            size: 16.sp,
            color: color,
          ),
          SizedBox(width: 6.w),
          Text(
            isOut
                ? 'Hết hàng'
                : '${product.currentStock?.toInt() ?? 0} ${product.unit}',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductsEmptyState extends StatelessWidget {
  const _ProductsEmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 52.sp,
            color: scheme.onSurfaceVariant,
          ),
          SizedBox(height: 10.h),
          Text(
            'Không tìm thấy sản phẩm',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Thử đổi từ khóa hoặc làm mới danh sách.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _ProductsErrorState extends StatelessWidget {
  const _ProductsErrorState({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Lỗi: $error'),
    );
  }
}

class _CartItemTile extends ConsumerWidget {
  const _CartItemTile({required this.item});

  final cart_model.CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final currencyFormat =
        NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
      child: Padding(
        padding: EdgeInsets.all(10.w),
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
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                  tooltip: 'Xóa sản phẩm',
                  onPressed: () =>
                      ref.read(cartProvider.notifier).removeProduct(item.product.id),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                IconButton.filledTonal(
                  icon: const Icon(Icons.remove_rounded),
                  onPressed: () => ref
                      .read(cartProvider.notifier)
                      .updateQuantity(item.product.id, item.quantity - 1),
                ),
                SizedBox(width: 6.w),
                Text(
                  '${item.quantity.toInt()}',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(width: 6.w),
                IconButton.filledTonal(
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () => ref
                      .read(cartProvider.notifier)
                      .updateQuantity(item.product.id, item.quantity + 1),
                ),
                const Spacer(),
                Text(
                  currencyFormat.format(item.subtotal),
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
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

class _CartEmptyState extends StatelessWidget {
  const _CartEmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_cart_rounded,
              size: 42.sp,
              color: scheme.primary,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'Giỏ hàng trống',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Chọn sản phẩm ở bên trái để bắt đầu bán hàng.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isTotal = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16.sp : 14.sp,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18.sp : 14.sp,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? (isTotal ? scheme.primary : null),
            ),
          ),
        ],
      ),
    );
  }
}
