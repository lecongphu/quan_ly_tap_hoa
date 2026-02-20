import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

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

  bool get _supportsBarcodeScanner {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  String _normalizeBarcode(String barcode) {
    return barcode.replaceAll(RegExp(r'\s+'), '').trim();
  }

  Product? _findProductByBarcode(List<Product> products, String barcode) {
    if (barcode.isEmpty) return null;
    final normalized = _normalizeBarcode(barcode);
    for (final product in products) {
      final existing = _normalizeBarcode(product.barcode ?? '');
      if (existing.isNotEmpty && existing == normalized) {
        return product;
      }
    }
    return null;
  }

  bool _addProductToCart(Product product) {
    final salePrice = product.salePrice ?? 0;
    if (salePrice <= 0) {
      _showMessage(
        'Sản phẩm "${product.name}" chưa có giá bán. Vui lòng cập nhật trong mục Sản phẩm.',
        isError: true,
      );
      return false;
    }

    ref.read(cartProvider.notifier).addProduct(product, unitPrice: salePrice);
    return true;
  }

  Future<void> _scanBarcodeAndAddProduct(List<Product> products) async {
    if (!_supportsBarcodeScanner) {
      _showMessage('Thiết bị này không hỗ trợ quét mã vạch.', isError: true);
      return;
    }

    final scannedValue = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _POSBarcodeScannerSheet(),
    );

    if (!mounted || scannedValue == null) return;

    final normalized = _normalizeBarcode(scannedValue);
    if (normalized.isEmpty) {
      _showMessage('Mã vạch không hợp lệ.', isError: true);
      return;
    }

    final matchedProduct = _findProductByBarcode(products, normalized);
    if (matchedProduct == null) {
      _showMessage(
        'Không tìm thấy sản phẩm cho mã vạch $normalized.',
        isError: true,
      );
      return;
    }

    if (_addProductToCart(matchedProduct)) {
      _showMessage('Đã thêm "${matchedProduct.name}" vào giỏ hàng.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final productsAsync = ref.watch(productsProvider);

    Future<void> handleSearchAction() async {
      final products = productsAsync.valueOrNull;
      if (products == null) {
        _showMessage(
          'Danh sách sản phẩm đang tải. Vui lòng thử lại.',
          isError: true,
        );
        return;
      }
      if (products.isEmpty) {
        _showMessage('Chưa có sản phẩm để tìm kiếm.', isError: true);
        return;
      }

      final selectedProduct = await showSearch<Product?>(
        context: context,
        delegate: _POSProductSearchDelegate(
          products: products,
          currencyFormat: _currencyFormat,
        ),
      );

      if (!mounted || selectedProduct == null) return;
      if (_addProductToCart(selectedProduct)) {
        _showMessage('Đã thêm "${selectedProduct.name}" vào giỏ hàng.');
      }
    }

    Future<void> handleScanAction() async {
      final products = productsAsync.valueOrNull;
      if (products == null) {
        _showMessage(
          'Danh sách sản phẩm đang tải. Vui lòng thử lại.',
          isError: true,
        );
        return;
      }
      await _scanBarcodeAndAddProduct(products);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bán hàng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Tìm sản phẩm',
            onPressed: handleSearchAction,
          ),
          if (_supportsBarcodeScanner)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded),
              tooltip: 'Quét mã vạch',
              onPressed: handleScanAction,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại dữ liệu sản phẩm',
            onPressed: () {
              ref.invalidate(productsProvider);
              ref.invalidate(categoriesProvider);
            },
          ),
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
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 16.h),
          child: _CartSection(
            cartState: cartState,
            currencyFormat: _currencyFormat,
            onCheckout: _handleCheckout,
          ),
        ),
      ),
    );
  }
}

class _POSBarcodeScannerSheet extends StatefulWidget {
  const _POSBarcodeScannerSheet();

  @override
  State<_POSBarcodeScannerSheet> createState() =>
      _POSBarcodeScannerSheetState();
}

class _POSBarcodeScannerSheetState extends State<_POSBarcodeScannerSheet> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _didDetect = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_didDetect) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw == null || raw.isEmpty) continue;
      _didDetect = true;
      _controller.stop();
      if (mounted) {
        Navigator.of(context).pop(raw);
      }
      break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return SizedBox(
      height: size.height * 0.82,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Quét mã vạch',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Đèn',
                  onPressed: _controller.toggleTorch,
                  icon: const Icon(Icons.flashlight_on_rounded),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Text(
              'Đặt mã vạch vào giữa khung để quét.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _POSProductSearchDelegate extends SearchDelegate<Product?> {
  final List<Product> products;
  final NumberFormat currencyFormat;

  _POSProductSearchDelegate({
    required this.products,
    required this.currencyFormat,
  });

  @override
  String get searchFieldLabel => 'Tìm tên hoặc mã vạch';

  List<Product> _filterProducts(String input) {
    final normalized = input.trim().toLowerCase();
    final source = products.where((product) => product.isActive);

    if (normalized.isEmpty) {
      return source.take(20).toList();
    }

    return source.where((product) {
      final name = product.name.toLowerCase();
      final barcode = product.barcode?.toLowerCase() ?? '';
      return name.contains(normalized) || barcode.contains(normalized);
    }).take(30).toList();
  }

  Widget _buildList(BuildContext context, List<Product> results) {
    final theme = Theme.of(context);

    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            query.trim().isEmpty
                ? 'Nhập tên hoặc mã vạch để tìm.'
                : 'Không tìm thấy sản phẩm phù hợp.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final product = results[index];
        final salePrice = product.salePrice ?? 0;
        final stock = product.currentStock?.toInt() ?? 0;
        final statusColor = product.isOutOfStock
            ? Colors.redAccent
            : product.isLowStock
            ? Colors.orange
            : theme.colorScheme.primary;

        return ListTile(
          onTap: () => close(context, product),
          leading: CircleAvatar(
            backgroundColor: statusColor.withValues(alpha: 0.14),
            child: Icon(
              Icons.inventory_2_outlined,
              color: statusColor,
              size: 18,
            ),
          ),
          title: Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${product.barcode ?? 'Không có mã'} • $stock ${product.unit}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            salePrice > 0 ? currencyFormat.format(salePrice) : 'Chưa có giá',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: salePrice > 0
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
          ),
        );
      },
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded),
          tooltip: 'Xóa',
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      tooltip: 'Đóng',
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final results = _filterProducts(query);
    return _buildList(context, results);
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = _filterProducts(query);
    return _buildList(context, results);
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
                ? const _EmptyCartState()
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

class _EmptyCartState extends StatelessWidget {
  const _EmptyCartState();

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
              'Dùng nút tìm kiếm hoặc quét mã vạch ở góc trên để thêm sản phẩm vào đơn hàng.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
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
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

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
