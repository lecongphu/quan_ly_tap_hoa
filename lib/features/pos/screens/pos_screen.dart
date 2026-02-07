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
import 'invoice_list_screen.dart';

class POSScreen extends ConsumerStatefulWidget {
  const POSScreen({super.key});

  @override
  ConsumerState<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends ConsumerState<POSScreen> {
  final _searchController = TextEditingController();
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
  String _selectedStockStatus = 'all';
  String? _selectedCategoryId;

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

      final discountAmount =
          (result['discountAmount'] as num?)?.toDouble() ?? 0;
      ref.read(cartProvider.notifier).setDiscount(discountAmount);

      await ref
          .read(cartProvider.notifier)
          .checkout(
            customerId: result['customerId'],
            paymentMethod: result['paymentMethod'],
            discountAmount: discountAmount,
            dueDate: result['dueDate'] as DateTime?,
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

  void _openCartSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final height = MediaQuery.sizeOf(context).height;
        return Consumer(
          builder: (context, ref, _) {
            final cartState = ref.watch(cartProvider);
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 16.h),
                child: SizedBox(
                  height: height * 0.85,
                  child: _CartSection(
                    cartState: cartState,
                    currencyFormat: _currencyFormat,
                    onCheckout: _handleCheckout,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final productsAsync = ref.watch(productsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final shortestSide = MediaQuery.sizeOf(context).shortestSide;
        final isTablet = shortestSide >= 600;
        final isPhone = !isTablet;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Bán hàng'),
            actions: [
              IconButton(
                icon: const Icon(Icons.receipt_long),
                tooltip: 'Danh sách hóa đơn',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const InvoiceListScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          bottomNavigationBar: isPhone
              ? _MobileCartBar(
                  cartState: cartState,
                  currencyFormat: _currencyFormat,
                  onOpenCart: _openCartSheet,
                  onCheckout: _handleCheckout,
                )
              : null,
          body: productsAsync.when(
        data: (products) {
          final query = _searchController.text.trim().toLowerCase();
          bool matchesQuery(Product product) =>
              query.isEmpty ||
              product.name.toLowerCase().contains(query) ||
              (product.barcode?.toLowerCase().contains(query) ?? false);
          bool matchesStockStatus(Product product) {
            switch (_selectedStockStatus) {
              case 'in_stock':
                return !product.isOutOfStock;
              case 'low_stock':
                return product.isLowStock;
              case 'out_of_stock':
                return product.isOutOfStock;
              default:
                return true;
            }
          }
          bool matchesCategory(Product product) =>
              _selectedCategoryId == null ||
              product.categoryId == _selectedCategoryId;
          final filteredProducts = products
              .where(
                (product) =>
                    matchesQuery(product) &&
                    matchesStockStatus(product) &&
                    matchesCategory(product),
              )
              .toList();
          final hasActiveFilters =
              _selectedStockStatus != 'all' || _selectedCategoryId != null;
          final categories =
              categoriesAsync.asData?.value ?? const <Category>[];
          final inStockCount = products
              .where((product) => !product.isOutOfStock)
              .length;
          final lowStockCount = products
              .where((product) => product.isLowStock)
              .length;
          final outOfStockCount = products
              .where((product) => product.isOutOfStock)
              .length;

          return LayoutBuilder(
            builder: (context, constraints) {
              final size = MediaQuery.sizeOf(context);
              final shortestSide = size.shortestSide;
              final isTablet = shortestSide >= 600;
              final isLargeTablet = shortestSide >= 840;
              final isSmallTablet = isTablet && !isLargeTablet;
              final isPhone = !isTablet;
              final isWideLayout = constraints.maxWidth >= 900;
              final useSplitView = isTablet && isWideLayout;
              final cartWidth = useSplitView
                  ? (isLargeTablet ? 420.0 : 360.0)
                  : constraints.maxWidth;
              final productAreaWidth = useSplitView
                  ? (constraints.maxWidth - cartWidth - 16.w)
                      .clamp(320.0, constraints.maxWidth)
                  : constraints.maxWidth;

              final gridMinWidth = isLargeTablet
                  ? 200.0
                  : isSmallTablet
                  ? 170.0
                  : isPhone
                  ? 150.0
                  : 170.0;
              final gridMaxCount = isLargeTablet ? 6 : useSplitView ? 5 : 4;
              final gridCount =
                  (productAreaWidth / gridMinWidth).floor().clamp(2, gridMaxCount);
              final gridAspectRatio = isLargeTablet
                  ? 0.9
                  : isSmallTablet
                  ? 0.84
                  : isPhone
                  ? 0.78
                  : 0.82;

              final filterChips = <Widget>[
                _POSFilterChip(
                  label: 'Tất cả',
                  selected: _selectedStockStatus == 'all',
                  onSelected: () {
                    setState(() {
                      _selectedStockStatus = 'all';
                    });
                  },
                ),
                _POSFilterChip(
                  label: 'Còn hàng',
                  selected: _selectedStockStatus == 'in_stock',
                  onSelected: () {
                    setState(() {
                      _selectedStockStatus = 'in_stock';
                    });
                  },
                ),
                _POSFilterChip(
                  label: 'Sắp hết',
                  selected: _selectedStockStatus == 'low_stock',
                  onSelected: () {
                    setState(() {
                      _selectedStockStatus = 'low_stock';
                    });
                  },
                ),
                _POSFilterChip(
                  label: 'Hết hàng',
                  selected: _selectedStockStatus == 'out_of_stock',
                  onSelected: () {
                    setState(() {
                      _selectedStockStatus = 'out_of_stock';
                    });
                  },
                ),
              ];

              final categoryDropdown = SizedBox(
                width: useSplitView ? 240.w : constraints.maxWidth,
                child: categoriesAsync.when(
                  data: (_) {
                    return DropdownButtonFormField<String?>(
                      initialValue: _selectedCategoryId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Danh mục',
                        filled: true,
                        fillColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Tất cả danh mục'),
                        ),
                        ...categories.map(
                          (category) => DropdownMenuItem<String?>(
                            value: category.id,
                            child: Text(category.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCategoryId = value;
                        });
                      },
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stack) => Text(
                    'Lỗi tải danh mục',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
              );

              final productSection = Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Tìm nhanh (tên hoặc mã vạch)...',
                                prefixIcon: const Icon(Icons.search),
                                filled: true,
                                fillColor: Theme.of(
                                  context,
                                ).colorScheme.surface.withValues(alpha: 0.9),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14.r),
                                  borderSide: BorderSide.none,
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
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Tooltip(
                            message: 'Tải lại danh sách sản phẩm',
                            child: IconButton.filledTonal(
                              icon: const Icon(Icons.refresh),
                              onPressed: () {
                                ref.invalidate(productsProvider);
                                ref.invalidate(categoriesProvider);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.filter_alt,
                              size: 16.sp,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              'Bộ lọc nhanh',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const Spacer(),
                            if (hasActiveFilters)
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _selectedStockStatus = 'all';
                                    _selectedCategoryId = null;
                                  });
                                },
                                icon: const Icon(
                                  Icons.filter_alt_off,
                                  size: 16,
                                ),
                                label: const Text('Xóa lọc'),
                              ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        if (isPhone)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (final chip in filterChips)
                                      Padding(
                                        padding: EdgeInsets.only(right: 8.w),
                                        child: chip,
                                      ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 10.h),
                              categoryDropdown,
                            ],
                          )
                        else
                          Wrap(
                            spacing: 8.w,
                            runSpacing: 8.h,
                            children: [
                              ...filterChips,
                              categoryDropdown,
                            ],
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            query.isEmpty
                                ? '${products.length} sản phẩm sẵn sàng bán'
                                : '${filteredProducts.length}/${products.length} sản phẩm phù hợp',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (hasActiveFilters)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 6.h,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              'Đang lọc',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
                    child: Wrap(
                      spacing: 12.w,
                      runSpacing: 12.h,
                      children: [
                        _POSStatCard(
                          title: 'Còn hàng',
                          value: '$inStockCount',
                          icon: Icons.inventory_2_outlined,
                          color: Colors.green,
                        ),
                        _POSStatCard(
                          title: 'Sắp hết',
                          value: '$lowStockCount',
                          icon: Icons.warning_amber_rounded,
                          color: Colors.orange,
                        ),
                        _POSStatCard(
                          title: 'Hết hàng',
                          value: '$outOfStockCount',
                          icon: Icons.remove_circle_outline,
                          color: Colors.redAccent,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: filteredProducts.isEmpty
                        ? _EmptyProductState(
                            hasQuery: query.isNotEmpty,
                            onClearQuery: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : GridView.builder(
                            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: gridCount,
                                  crossAxisSpacing: 12.w,
                                  mainAxisSpacing: 12.h,
                                  childAspectRatio: gridAspectRatio,
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
                          ),
                  ),
                ],
              );

              final cartSection = Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: cartWidth.toDouble(),
                  child: _CartSection(
                    cartState: cartState,
                    currencyFormat: _currencyFormat,
                    onCheckout: _handleCheckout,
                  ),
                ),
              );

              if (isPhone) {
                return productSection;
              }

              if (!useSplitView) {
                return Column(
                  children: [
                    Expanded(flex: 3, child: productSection),
                    SizedBox(height: 12.h),
                    Expanded(flex: 2, child: cartSection),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 3, child: productSection),
                  SizedBox(width: 16.w),
                  cartSection,
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Lỗi: $error')),
      ),
    );
      },
    );
  }
}

class _CartSection extends ConsumerWidget {
  final CartState cartState;
  final NumberFormat currencyFormat;
  final Future<void> Function() onCheckout;

  const _CartSection({
    required this.cartState,
    required this.currencyFormat,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primaryContainer,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            ),
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
                    tooltip: 'Xóa toàn bộ giỏ hàng',
                    onPressed: () =>
                        ref.read(cartProvider.notifier).clearCart(),
                  ),
              ],
            ),
          ),
          Expanded(
            child: cartState.items.isEmpty
                ? _EmptyCartState(
                    onSuggestProduct: () {
                      final controller = PrimaryScrollController.of(context);
                      if (controller.hasClients) {
                        controller.animateTo(
                          0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    },
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(8.w, 8.h, 8.w, 0),
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
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(20.r),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                _SummaryRow(
                  label: 'Tạm tính:',
                  value: currencyFormat.format(cartState.subtotal),
                ),
                if (cartState.discountAmount > 0)
                  _SummaryRow(
                    label: 'Giảm giá:',
                    value:
                        '-${currencyFormat.format(cartState.discountAmount)}',
                    valueColor: Colors.red,
                  ),
                Divider(height: 16.h),
                _SummaryRow(
                  label: 'Tổng cộng:',
                  value: currencyFormat.format(cartState.finalAmount),
                  isTotal: true,
                ),
                SizedBox(height: 16.h),
                SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: ElevatedButton.icon(
                    onPressed: cartState.items.isEmpty || cartState.isLoading
                        ? null
                        : onCheckout,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    icon: cartState.isLoading
                        ? SizedBox(
                            width: 18.w,
                            height: 18.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.payment),
                    label: Text(
                      cartState.isLoading ? 'Đang xử lý...' : 'Thanh toán',
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
    );
  }
}

class _MobileCartBar extends StatelessWidget {
  final CartState cartState;
  final NumberFormat currencyFormat;
  final VoidCallback onOpenCart;
  final Future<void> Function() onCheckout;

  const _MobileCartBar({
    required this.cartState,
    required this.currencyFormat,
    required this.onOpenCart,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDisabled = cartState.items.isEmpty || cartState.isLoading;

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onOpenCart,
                borderRadius: BorderRadius.circular(14.r),
                child: Row(
                  children: [
                    Container(
                      width: 44.w,
                      height: 44.w,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: Icon(
                        Icons.shopping_cart,
                        color: scheme.primary,
                        size: 22.sp,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Giỏ hàng (${cartState.itemCount})',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            currencyFormat.format(cartState.finalAmount),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 12.w),
            SizedBox(
              height: 44.h,
              child: FilledButton.icon(
                onPressed: isDisabled ? null : onCheckout,
                icon: cartState.isLoading
                    ? SizedBox(
                        width: 16.w,
                        height: 16.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.payment),
                label: Text(
                  cartState.isLoading ? 'Đang xử lý' : 'Thanh toán',
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyProductState extends StatelessWidget {
  final bool hasQuery;
  final VoidCallback onClearQuery;

  const _EmptyProductState({
    required this.hasQuery,
    required this.onClearQuery,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery ? Icons.search_off : Icons.inventory_2_outlined,
              size: 56.sp,
              color: theme.colorScheme.primary,
            ),
            SizedBox(height: 12.h),
            Text(
              hasQuery ? 'Không tìm thấy sản phẩm phù hợp' : 'Chưa có sản phẩm',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 6.h),
            Text(
              hasQuery
                  ? 'Thử thay đổi từ khóa hoặc xóa bộ lọc để xem toàn bộ sản phẩm.'
                  : 'Hãy nhập kho sản phẩm để bắt đầu bán hàng.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasQuery) ...[
              SizedBox(height: 14.h),
              FilledButton.tonalIcon(
                onPressed: onClearQuery,
                icon: const Icon(Icons.refresh),
                label: const Text('Xóa tìm kiếm'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyCartState extends StatelessWidget {
  final VoidCallback onSuggestProduct;

  const _EmptyCartState({required this.onSuggestProduct});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.remove_shopping_cart_outlined,
              size: 56.sp,
              color: theme.colorScheme.primary,
            ),
            SizedBox(height: 12.h),
            Text(
              'Giỏ hàng đang trống',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Chọn sản phẩm từ danh sách bên trái để thêm vào đơn hàng.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 14.h),
            FilledButton.tonalIcon(
              onPressed: onSuggestProduct,
              icon: const Icon(Icons.touch_app),
              label: const Text('Gợi ý thao tác'),
            ),
          ],
        ),
      ),
    );
  }
}

class _POSFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _POSFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600),
      selectedColor: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: 0.15),
    );
  }
}

class _POSStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _POSStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: color, size: 18.sp),
          ),
          SizedBox(width: 10.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
              ),
            ],
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
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = product.isOutOfStock
        ? Colors.redAccent
        : product.isLowStock
        ? Colors.orange
        : Colors.green;
    final statusLabel = product.isOutOfStock
        ? 'Hết hàng'
        : product.isLowStock
        ? 'Sắp hết'
        : 'Còn hàng';

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: product.isOutOfStock ? null : onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image placeholder
            Container(
              height: 96.h,
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.surfaceContainerHighest,
                    colorScheme.surfaceContainerLow,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ),
            ),

            Expanded(
              child: Padding(
                padding: EdgeInsets.all(10.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    if (product.avgCostPrice != null)
                      Text(
                        currencyFormat.format(
                          product.avgCostPrice! *
                              AppConstants.defaultSalePriceMultiplier,
                        ),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Text(
                          '${product.currentStock?.toInt() ?? 0} ${product.unit}',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.add_circle,
                          size: 18.sp,
                          color: product.isOutOfStock
                              ? Colors.grey
                              : statusColor,
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

  Future<void> _showQuantityKeypad(BuildContext context, WidgetRef ref) async {
    var quantityText = item.quantity.toInt().toString();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final colorScheme = Theme.of(context).colorScheme;

            void appendDigit(String digit) {
              setState(() {
                if (quantityText == '0') {
                  quantityText = digit;
                } else {
                  quantityText += digit;
                }
              });
            }

            void backspace() {
              setState(() {
                if (quantityText.length <= 1) {
                  quantityText = '0';
                } else {
                  quantityText = quantityText.substring(
                    0,
                    quantityText.length - 1,
                  );
                }
              });
            }

            void clearAll() {
              setState(() {
                quantityText = '0';
              });
            }

            void confirm() {
              final parsedQuantity = int.tryParse(quantityText) ?? 0;
              if (parsedQuantity <= 0) {
                return;
              }

              ref
                  .read(cartProvider.notifier)
                  .updateQuantity(item.product.id, parsedQuantity.toDouble());
              Navigator.of(dialogContext).pop();
            }

            Widget buildKey(
              String label, {
              VoidCallback? onTap,
              IconData? icon,
            }) {
              return Padding(
                padding: EdgeInsets.all(4.w),
                child: SizedBox(
                  height: 56.h,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      textStyle: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: icon != null ? Icon(icon) : Text(label),
                  ),
                ),
              );
            }

            return AlertDialog(
              title: const Text('Cập nhật số lượng'),
              content: SizedBox(
                width: 260.w,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 10.h,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        quantityText,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.2,
                      children: [
                        buildKey('1', onTap: () => appendDigit('1')),
                        buildKey('2', onTap: () => appendDigit('2')),
                        buildKey('3', onTap: () => appendDigit('3')),
                        buildKey('4', onTap: () => appendDigit('4')),
                        buildKey('5', onTap: () => appendDigit('5')),
                        buildKey('6', onTap: () => appendDigit('6')),
                        buildKey('7', onTap: () => appendDigit('7')),
                        buildKey('8', onTap: () => appendDigit('8')),
                        buildKey('9', onTap: () => appendDigit('9')),
                        buildKey('C', onTap: clearAll),
                        buildKey('0', onTap: () => appendDigit('0')),
                        buildKey(
                          '',
                          onTap: backspace,
                          icon: Icons.backspace_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: confirm,
                  child: const Text('Cập nhật'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
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
          SizedBox(height: 6.h),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () {
                        ref
                            .read(cartProvider.notifier)
                            .updateQuantity(item.product.id, item.quantity - 1);
                      },
                    ),
                    InkWell(
                      onTap: () => _showQuantityKeypad(context, ref),
                      borderRadius: BorderRadius.circular(8.r),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),
                        child: Text(
                          '${item.quantity.toInt()}',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                  ],
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currencyFormat.format(item.subtotal),
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    currencyFormat.format(item.unitPrice),
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
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
