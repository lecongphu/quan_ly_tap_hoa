import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../providers/inventory_provider.dart';
import '../models/product_model.dart';
import 'stock_in_screen.dart';
import 'alerts_screen.dart';

class InventoryListScreen extends ConsumerStatefulWidget {
  const InventoryListScreen({super.key});

  @override
  ConsumerState<InventoryListScreen> createState() =>
      _InventoryListScreenState();
}

class _InventoryListScreenState extends ConsumerState<InventoryListScreen> {
  final _searchController = TextEditingController();
  String? _selectedCategoryId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Kho'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AlertsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Navigate to add product screen
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(productsProvider);
              ref.invalidate(categoriesProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter bar
          Container(
            padding: EdgeInsets.all(16.w),
            color: Colors.grey[100],
            child: Column(
              children: [
                // Search field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm sản phẩm...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
                SizedBox(height: 12.h),

                // Category filter
                categoriesAsync.when(
                  data: (categories) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            label: const Text('Tất cả'),
                            selected: _selectedCategoryId == null,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategoryId = null;
                              });
                            },
                          ),
                          SizedBox(width: 8.w),
                          ...categories.map((category) {
                            return Padding(
                              padding: EdgeInsets.only(right: 8.w),
                              child: FilterChip(
                                label: Text(category.name),
                                selected: _selectedCategoryId == category.id,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedCategoryId = selected
                                        ? category.id
                                        : null;
                                  });
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          // Product list
          Expanded(
            child: productsAsync.when(
              data: (products) {
                // Filter products
                var filteredProducts = products;

                if (_searchController.text.isNotEmpty) {
                  filteredProducts = filteredProducts.where((p) {
                    return p.name.toLowerCase().contains(
                          _searchController.text.toLowerCase(),
                        ) ||
                        (p.barcode?.contains(_searchController.text) ?? false);
                  }).toList();
                }

                if (_selectedCategoryId != null) {
                  filteredProducts = filteredProducts.where((p) {
                    return p.categoryId == _selectedCategoryId;
                  }).toList();
                }

                if (filteredProducts.isEmpty) {
                  return const Center(child: Text('Không tìm thấy sản phẩm'));
                }

                return ListView.builder(
                  padding: EdgeInsets.all(16.w),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return _ProductCard(
                      product: product,
                      currencyFormat: currencyFormat,
                      onTap: () {
                        // TODO: Navigate to product detail
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Lỗi: $error')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const StockInScreen()),
          );
        },
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Nhập kho'),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final NumberFormat currencyFormat;
  final VoidCallback onTap;

  const _ProductCard({
    required this.product,
    required this.currencyFormat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (product.barcode != null) ...[
                          SizedBox(height: 4.h),
                          Text(
                            'Mã: ${product.barcode}',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                        if (product.categoryName != null) ...[
                          SizedBox(height: 4.h),
                          Text(
                            product.categoryName!,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Stock status badge
                  _buildStockBadge(),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Stock info
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tồn kho',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${product.currentStock?.toInt() ?? 0} ${product.unit}',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: product.isLowStock
                              ? Colors.orange
                              : product.isOutOfStock
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                    ],
                  ),

                  // Cost price (only if user has permission)
                  if (product.avgCostPrice != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Giá vốn TB',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          currencyFormat.format(product.avgCostPrice),
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              // Expiry warning
              if (product.isNearExpiry || product.isDangerExpiry) ...[
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: product.isDangerExpiry
                        ? Colors.red[50]
                        : Colors.orange[50],
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning,
                        size: 16.sp,
                        color: product.isDangerExpiry
                            ? Colors.red
                            : Colors.orange,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        product.isDangerExpiry
                            ? 'Sắp hết hạn (${product.nearestExpiryDate != null ? DateFormat('dd/MM/yyyy').format(product.nearestExpiryDate!) : ""})'
                            : 'Gần hết hạn (${product.nearestExpiryDate != null ? DateFormat('dd/MM/yyyy').format(product.nearestExpiryDate!) : ""})',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: product.isDangerExpiry
                              ? Colors.red
                              : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockBadge() {
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    if (product.isOutOfStock) {
      badgeColor = Colors.red;
      badgeText = 'Hết hàng';
      badgeIcon = Icons.remove_circle;
    } else if (product.isLowStock) {
      badgeColor = Colors.orange;
      badgeText = 'Sắp hết';
      badgeIcon = Icons.warning;
    } else {
      badgeColor = Colors.green;
      badgeText = 'Còn hàng';
      badgeIcon = Icons.check_circle;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: badgeColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 16.sp, color: badgeColor),
          SizedBox(width: 4.w),
          Text(
            badgeText,
            style: TextStyle(
              fontSize: 12.sp,
              color: badgeColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
