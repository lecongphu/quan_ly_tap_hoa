import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../inventory/models/product_model.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../providers/product_provider.dart';
import 'product_form_dialog.dart';

class ProductManagementScreen extends ConsumerStatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  ConsumerState<ProductManagementScreen> createState() =>
      _ProductManagementScreenState();
}

class _ProductManagementScreenState
    extends ConsumerState<ProductManagementScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load products on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productProvider.notifier).loadProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showProductForm({Product? product}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ProductFormDialog(product: product),
    );
    if (result == true) {
      ref.read(productProvider.notifier).refresh();
    }
  }

  Future<void> _deleteProduct(String productId, String productName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa sản phẩm "$productName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(productProvider.notifier).deleteProduct(productId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Xóa sản phẩm thành công!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _applySearch() {
    ref.read(productProvider.notifier).setSearchQuery(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Sản phẩm'),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 12.w),
            child: FilledButton.tonalIcon(
              onPressed: () => _showProductForm(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm sản phẩm'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding =
                constraints.maxWidth > 1400 ? 72.w : 28.w;

            return RefreshIndicator(
              onRefresh: () async {
                await ref.read(productProvider.notifier).refresh();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  24.h,
                  horizontalPadding,
                  36.h,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProductHeader(state: state),
                    SizedBox(height: 20.h),
                    _buildFilterBar(categoriesAsync),
                    SizedBox(height: 18.h),
                    if (state.isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (state.error != null)
                      _ErrorState(message: state.error!)
                    else
                      _buildProductTable(state.products, scheme),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: constraintsBasedFab(state.isLoading),
    );
  }

  Widget constraintsBasedFab(bool isLoading) {
    if (isLoading) {
      return const SizedBox.shrink();
    }
    return FloatingActionButton.extended(
      onPressed: () => _showProductForm(),
      icon: const Icon(Icons.add),
      label: const Text('Thêm'),
    );
  }

  Widget _buildFilterBar(AsyncValue<List<Category>> categoriesAsync) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(18.w),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _applySearch(),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm theo tên hoặc mã sản phẩm...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'Xóa từ khóa',
                              onPressed: () {
                                _searchController.clear();
                                _applySearch();
                                setState(() {});
                              },
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            BorderSide(color: scheme.outline.withOpacity(0.4)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            BorderSide(color: scheme.outline.withOpacity(0.35)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: scheme.primary, width: 1.4),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 14.h,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(width: 10.w),
                FilledButton.icon(
                  onPressed: _applySearch,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Lọc'),
                ),
                SizedBox(width: 8.w),
                IconButton.filledTonal(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(productProvider.notifier).refresh();
                    setState(() {});
                  },
                  tooltip: 'Làm mới',
                ),
              ],
            ),
            SizedBox(height: 14.h),
            categoriesAsync.when(
              data: (categories) {
                final productState = ref.watch(productProvider);
                return Align(
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: [
                        FilterChip(
                          label: const Text('Tất cả'),
                          selected: productState.selectedCategoryId == null,
                          onSelected: (_) => ref
                              .read(productProvider.notifier)
                              .setCategoryFilter(null),
                        ),
                        ...categories.map(
                          (category) => FilterChip(
                            label: Text(category.name),
                            selected:
                                productState.selectedCategoryId == category.id,
                            onSelected: (selected) {
                              ref
                                  .read(productProvider.notifier)
                                  .setCategoryFilter(
                                    selected ? category.id : null,
                                  );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductTable(List<Product> products, ColorScheme scheme) {
    if (products.isEmpty) {
      return _EmptyState(onCreate: () => _showProductForm());
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              headingRowHeight: 56.h,
              dataRowMinHeight: 60.h,
              dataRowMaxHeight: 68.h,
              horizontalMargin: 20.w,
              columnSpacing: 28.w,
              headingRowColor:
                  WidgetStateProperty.all(scheme.primary.withOpacity(0.06)),
              columns: [
                _buildColumnLabel('Mã sản phẩm'),
                _buildColumnLabel('Tên sản phẩm'),
                _buildColumnLabel('Danh mục'),
                _buildColumnLabel('Đơn vị'),
                _buildColumnLabel('Tồn tối thiểu'),
                _buildColumnLabel('Trạng thái'),
                _buildColumnLabel('Thao tác'),
              ],
              rows: products.map<DataRow>((product) {
                return DataRow(
                  cells: [
                    DataCell(Text(product.barcode ?? '-')),
                    DataCell(
                      Text(
                        product.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataCell(Text(product.categoryName ?? '-')),
                    DataCell(Text(product.unit)),
                    DataCell(Text(product.minStockLevel.toInt().toString())),
                    DataCell(_StatusBadge(isActive: product.isActive)),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton.filledTonal(
                            icon: const Icon(Icons.edit_rounded, size: 20),
                            onPressed: () => _showProductForm(product: product),
                            tooltip: 'Sửa',
                          ),
                          SizedBox(width: 6.w),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              size: 22,
                              color: scheme.error,
                            ),
                            onPressed: () => _deleteProduct(product.id, product.name),
                            tooltip: 'Xóa',
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  DataColumn _buildColumnLabel(String label) {
    return DataColumn(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14.sp,
        ),
      ),
    );
  }
}

class _ProductHeader extends StatelessWidget {
  const _ProductHeader({required this.state});

  final ProductState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = state.products.length;
    final active = state.products.where((p) => p.isActive).length;
    final inactive = total - active;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0EA5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.22),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Wrap(
        spacing: 16.w,
        runSpacing: 16.h,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 720.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Danh mục sản phẩm',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Theo dõi trạng thái kinh doanh, cập nhật nhanh thông tin hàng hóa và giữ dữ liệu luôn đồng bộ.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withOpacity(0.92),
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            children: [
              _HeaderMetric(
                label: 'Tổng sản phẩm',
                value: '$total',
                icon: Icons.inventory_2_rounded,
                color: Colors.white,
                foreground: scheme.primary,
              ),
              _HeaderMetric(
                label: 'Đang hoạt động',
                value: '$active',
                icon: Icons.check_circle_rounded,
                color: const Color(0xFFDCFCE7),
                foreground: const Color(0xFF166534),
              ),
              _HeaderMetric(
                label: 'Tạm ngưng',
                value: '$inactive',
                icon: Icons.pause_circle_rounded,
                color: const Color(0xFFFFEDD5),
                foreground: const Color(0xFF9A3412),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.foreground,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: foreground.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: foreground, size: 20.sp),
          ),
          SizedBox(width: 10.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: foreground.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFF16A34A);
    final inactiveColor = const Color(0xFF64748B);
    final color = isActive ? activeColor : inactiveColor;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8.sp, color: color),
          SizedBox(width: 6.w),
          Text(
            isActive ? 'Hoạt động' : 'Ngưng',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 64.h, horizontal: 24.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline.withOpacity(0.08)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(18.w),
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_rounded,
              size: 46.sp,
              color: scheme.primary,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'Chưa có sản phẩm nào',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Hãy thêm sản phẩm đầu tiên để bắt đầu quản lý kho và bán hàng hiệu quả hơn.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
          ),
          SizedBox(height: 18.h),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Thêm sản phẩm mới'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 56.h, horizontal: 24.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Theme.of(context).colorScheme.error,
          ),
          SizedBox(height: 8.h),
          Text('Đã xảy ra lỗi: $message'),
        ],
      ),
    );
  }
}
