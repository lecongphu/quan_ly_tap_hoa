import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/product_model.dart';
import '../../providers/inventory_provider.dart';
import '../../services/excel_service.dart';
import '../stock_in_screen.dart';

class StockListTab extends ConsumerStatefulWidget {
  const StockListTab({super.key});

  @override
  ConsumerState<StockListTab> createState() => _StockListTabState();
}

class _StockListTabState extends ConsumerState<StockListTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _excelService = ExcelService();
  bool _isExporting = false;
  bool _isImporting = false;
  List<Product> _currentProducts = [];

  // Date filter state
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String _selectedDateOption =
      'all'; // all, today, this_week, this_month, custom

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      String stockStatus;
      switch (_tabController.index) {
        case 0:
          stockStatus = 'all';
          break;
        case 1:
          stockStatus = 'in_stock';
          break;
        case 2:
          stockStatus = 'low_stock';
          break;
        case 3:
          stockStatus = 'out_of_stock';
          break;
        default:
          stockStatus = 'all';
      }
      // Update the provider filter
      ref
          .read(inventoryFilterProvider.notifier)
          .update((state) => state.copyWith(stockStatus: stockStatus));
    }
  }

  Future<void> _exportToExcel() async {
    if (_currentProducts.isEmpty) {
      _showMessage('Không có dữ liệu để xuất', isError: true);
      return;
    }

    setState(() => _isExporting = true);
    try {
      final filePath = await _excelService.exportStockToExcelWithPicker(
        _currentProducts,
      );
      if (filePath != null && mounted) {
        _showMessage('Xuất file thành công: $filePath');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Lỗi: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _importFromExcel() async {
    setState(() => _isImporting = true);
    try {
      final data = await _excelService.importStockFromExcel();
      if (data.isEmpty) {
        if (mounted) {
          _showMessage('Không có dữ liệu để nhập hoặc đã hủy', isError: true);
        }
        return;
      }

      // Show import preview dialog
      if (mounted) {
        await _showImportPreviewDialog(data);
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Lỗi: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _downloadTemplate() async {
    try {
      final filePath = await _excelService.downloadTemplate();
      if (filePath != null && mounted) {
        _showMessage('Đã tải file mẫu: $filePath');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Lỗi: ${e.toString()}', isError: true);
      }
    }
  }

  Future<void> _showImportPreviewDialog(List<Map<String, dynamic>> data) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận nhập dữ liệu'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tìm thấy ${data.length} dòng dữ liệu:'),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Dòng')),
                        DataColumn(label: Text('Tên SP')),
                        DataColumn(label: Text('Barcode')),
                        DataColumn(label: Text('Đơn vị')),
                        DataColumn(label: Text('Số lượng')),
                        DataColumn(label: Text('Giá vốn')),
                      ],
                      rows: data.take(10).map((row) {
                        return DataRow(
                          cells: [
                            DataCell(Text(row['row_number'].toString())),
                            DataCell(Text(row['name'] ?? '')),
                            DataCell(Text(row['barcode'] ?? '')),
                            DataCell(Text(row['unit'] ?? '')),
                            DataCell(Text(row['quantity'].toString())),
                            DataCell(Text(row['cost_price'].toString())),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              if (data.length > 10)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '... và ${data.length - 10} dòng khác',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showMessage('Đã nhập ${data.length} dòng dữ liệu thành công!');
              // TODO: Actually import the data to database
            },
            child: const Text('Nhập dữ liệu'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _showProductDetailDialog(Product product) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final dateFormat = DateFormat('dd/MM/yyyy');
    final scheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 520,
          constraints: const BoxConstraints(maxHeight: 650),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.primaryContainer,
                      scheme.secondaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.inventory_2_rounded,
                        color: scheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chi tiết sản phẩm',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            product.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: scheme.onPrimaryContainer,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: scheme.onPrimaryContainer,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stock Status Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.inventory,
                              label: 'Tồn kho',
                              value: '${(product.currentStock ?? 0).toInt()}',
                              color: (product.currentStock ?? 0) <= 0
                                  ? Colors.red
                                  : (product.currentStock ?? 0) <=
                                        product.minStockLevel
                                  ? Colors.orange
                                  : Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.attach_money,
                              label: 'Giá vốn TB',
                              value: currencyFormat.format(
                                product.avgCostPrice ?? 0,
                              ),
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Product Info Section
                      _buildSectionHeader('Thông tin cơ bản'),
                      const SizedBox(height: 12),
                      _buildInfoRow('Mã sản phẩm', product.id.substring(0, 8)),
                      _buildInfoRow('Barcode', product.barcode ?? 'Chưa có'),
                      _buildInfoRow('Đơn vị tính', product.unit),
                      _buildInfoRow(
                        'Danh mục',
                        product.categoryName ?? 'Chưa phân loại',
                      ),
                      _buildInfoRow(
                        'Mức tồn kho tối thiểu',
                        product.minStockLevel.toInt().toString(),
                      ),
                      const SizedBox(height: 20),

                      // Status Section
                      _buildSectionHeader('Trạng thái'),
                      const SizedBox(height: 12),
                      _buildStatusChips(product),
                      const SizedBox(height: 20),

                      // Date Info Section
                      _buildSectionHeader('Thông tin thời gian'),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        'Ngày tạo',
                        dateFormat.format(product.createdAt),
                      ),
                      _buildInfoRow(
                        'Cập nhật lần cuối',
                        dateFormat.format(product.updatedAt),
                      ),
                      if (product.nearestExpiryDate != null)
                        _buildInfoRow(
                          'Ngày hết hạn gần nhất',
                          dateFormat.format(product.nearestExpiryDate!),
                          valueColor: product.isDangerExpiry
                              ? Colors.red
                              : product.isNearExpiry
                              ? Colors.orange
                              : null,
                        ),
                    ],
                  ),
                ),
              ),

              // Footer Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        // TODO: Navigate to edit product
                      },
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Chỉnh sửa'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const StockInScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                      label: const Text('Nhập kho'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChips(Product product) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Active status
        _buildChip(
          label: product.isActive ? 'Đang bán' : 'Ngừng bán',
          color: product.isActive ? Colors.green : Colors.grey,
          icon: product.isActive ? Icons.check_circle : Icons.cancel,
        ),
        // Stock status
        if (product.isOutOfStock)
          _buildChip(label: 'Hết hàng', color: Colors.red, icon: Icons.error)
        else if (product.isLowStock)
          _buildChip(
            label: 'Sắp hết',
            color: Colors.orange,
            icon: Icons.warning,
          )
        else
          _buildChip(label: 'Còn hàng', color: Colors.green, icon: Icons.check),
        // Expiry status
        if (product.isDangerExpiry)
          _buildChip(
            label: 'Sắp hết hạn',
            color: Colors.red,
            icon: Icons.schedule,
          )
        else if (product.isNearExpiry)
          _buildChip(
            label: 'Gần hết hạn',
            color: Colors.orange,
            icon: Icons.schedule,
          ),
      ],
    );
  }

  Widget _buildChip({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(filteredProductsProvider);
    final filter = ref.watch(inventoryFilterProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Tabs
          Container(
            color: Colors.white,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 520;

                return TabBar(
                  controller: _tabController,
                  isScrollable: isCompact,
                  labelPadding: isCompact
                      ? const EdgeInsets.symmetric(horizontal: 12)
                      : null,
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: Colors.blue,
                  tabs: const [
                    Tab(text: 'Tất cả'),
                    Tab(text: 'Còn hàng'),
                    Tab(text: 'Sắp hết'),
                    Tab(text: 'Hết hàng'),
                  ],
                );
              },
            ),
          ),
          // Search and filter bar
          _buildFilterBar(filter),
          // Product table
          Expanded(
            child: productsAsync.when(
              data: (products) => _buildProductTable(products),
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

  Widget _buildFilterBar(InventoryFilter filter) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;

        final searchField = TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Tìm kiếm theo mã SKU, tên sản phẩm, barcode',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(inventoryFilterProvider.notifier).update(
                            (state) => state.copyWith(searchQuery: ''),
                          );
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            isDense: true,
          ),
          onChanged: (value) {
            ref
                .read(inventoryFilterProvider.notifier)
                .update((state) => state.copyWith(searchQuery: value));
          },
        );

        final clearFiltersButton = OutlinedButton.icon(
          onPressed: _clearAllFilters,
          icon: const Icon(Icons.clear_all, size: 18),
          label: Text('Xóa bộ lọc (${filter.activeFilterCount})'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            foregroundColor: Colors.red,
          ),
        );

        final exportButton = OutlinedButton.icon(
          onPressed: _isExporting ? null : _exportToExcel,
          icon: _isExporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_download, size: 18),
          label: const Text('Xuất Excel'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        );

        final importButton = PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'import') {
              _importFromExcel();
            } else if (value == 'template') {
              _downloadTemplate();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'import',
              child: Row(
                children: [
                  Icon(Icons.file_upload, size: 18),
                  SizedBox(width: 8),
                  Text('Nhập từ Excel'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'template',
              child: Row(
                children: [
                  Icon(Icons.download, size: 18),
                  SizedBox(width: 8),
                  Text('Tải file mẫu'),
                ],
              ),
            ),
          ],
          child: OutlinedButton.icon(
            onPressed: null,
            icon: _isImporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_upload, size: 18),
            label: const Text('Nhập Excel'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
          ),
        );

        if (isNarrow) {
          return Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildDateFilterButton(filter),
                    _buildCategoryFilterButton(filter),
                    if (filter.hasActiveFilters) clearFiltersButton,
                    exportButton,
                    importButton,
                  ],
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(child: searchField),
              const SizedBox(width: 12),
              _buildDateFilterButton(filter),
              const SizedBox(width: 8),
              _buildCategoryFilterButton(filter),
              if (filter.hasActiveFilters) ...[
                const SizedBox(width: 8),
                clearFiltersButton,
              ],
              const Spacer(),
              exportButton,
              const SizedBox(width: 8),
              importButton,
            ],
          ),
        );
      },
    );
  }

  void _clearAllFilters() {
    _searchController.clear();
    _dateFrom = null;
    _dateTo = null;
    _selectedDateOption = 'all';
    _tabController.animateTo(0);
    ref.read(inventoryFilterProvider.notifier).state = const InventoryFilter();
  }

  Widget _buildDateFilterButton(InventoryFilter filter) {
    final hasDateFilter = filter.dateFrom != null || filter.dateTo != null;
    final dateFormat = DateFormat('dd/MM/yyyy');

    String label = 'Ngày tạo';
    if (_selectedDateOption == 'today') {
      label = 'Hôm nay';
    } else if (_selectedDateOption == 'this_week') {
      label = 'Tuần này';
    } else if (_selectedDateOption == 'this_month') {
      label = 'Tháng này';
    } else if (hasDateFilter) {
      if (filter.dateFrom != null && filter.dateTo != null) {
        label =
            '${dateFormat.format(filter.dateFrom!)} - ${dateFormat.format(filter.dateTo!)}';
      } else if (filter.dateFrom != null) {
        label = 'Từ ${dateFormat.format(filter.dateFrom!)}';
      } else if (filter.dateTo != null) {
        label = 'Đến ${dateFormat.format(filter.dateTo!)}';
      }
    }

    return PopupMenuButton<String>(
      onSelected: (value) => _handleDateFilter(value),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'all',
          child: Row(
            children: [
              Icon(
                _selectedDateOption == 'all' ? Icons.check : Icons.access_time,
                size: 18,
                color: _selectedDateOption == 'all' ? Colors.blue : null,
              ),
              const SizedBox(width: 8),
              const Text('Tất cả'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'today',
          child: Row(
            children: [
              Icon(
                _selectedDateOption == 'today' ? Icons.check : Icons.today,
                size: 18,
                color: _selectedDateOption == 'today' ? Colors.blue : null,
              ),
              const SizedBox(width: 8),
              const Text('Hôm nay'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'this_week',
          child: Row(
            children: [
              Icon(
                _selectedDateOption == 'this_week'
                    ? Icons.check
                    : Icons.date_range,
                size: 18,
                color: _selectedDateOption == 'this_week' ? Colors.blue : null,
              ),
              const SizedBox(width: 8),
              const Text('Tuần này'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'this_month',
          child: Row(
            children: [
              Icon(
                _selectedDateOption == 'this_month'
                    ? Icons.check
                    : Icons.calendar_month,
                size: 18,
                color: _selectedDateOption == 'this_month' ? Colors.blue : null,
              ),
              const SizedBox(width: 8),
              const Text('Tháng này'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'custom',
          child: Row(
            children: [
              Icon(Icons.edit_calendar, size: 18),
              SizedBox(width: 8),
              Text('Tùy chọn...'),
            ],
          ),
        ),
      ],
      child: OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          backgroundColor: hasDateFilter ? Colors.blue.withValues(alpha: 0.1) : null,
          side: hasDateFilter ? const BorderSide(color: Colors.blue) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasDateFilter)
              const Icon(Icons.check_circle, size: 16, color: Colors.blue)
            else
              const Icon(Icons.calendar_today, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: hasDateFilter ? Colors.blue : null,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }

  void _handleDateFilter(String option) async {
    DateTime? dateFrom;
    DateTime? dateTo;
    final now = DateTime.now();

    switch (option) {
      case 'all':
        _selectedDateOption = 'all';
        dateFrom = null;
        dateTo = null;
        break;
      case 'today':
        _selectedDateOption = 'today';
        dateFrom = DateTime(now.year, now.month, now.day);
        dateTo = DateTime(now.year, now.month, now.day);
        break;
      case 'this_week':
        _selectedDateOption = 'this_week';
        // Start of week (Monday)
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        dateFrom = DateTime(
          startOfWeek.year,
          startOfWeek.month,
          startOfWeek.day,
        );
        dateTo = DateTime(now.year, now.month, now.day);
        break;
      case 'this_month':
        _selectedDateOption = 'this_month';
        dateFrom = DateTime(now.year, now.month, 1);
        dateTo = DateTime(now.year, now.month, now.day);
        break;
      case 'custom':
        _selectedDateOption = 'custom';
        await _showCustomDatePicker();
        return;
    }

    setState(() {
      _dateFrom = dateFrom;
      _dateTo = dateTo;
    });

    ref
        .read(inventoryFilterProvider.notifier)
        .update(
          (state) => state.copyWith(
            dateFrom: dateFrom,
            dateTo: dateTo,
            clearDateFrom: dateFrom == null,
            clearDateTo: dateTo == null,
          ),
        );
  }

  Future<void> _showCustomDatePicker() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateFrom != null && _dateTo != null
          ? DateTimeRange(start: _dateFrom!, end: _dateTo!)
          : null,
      locale: const Locale('vi', 'VN'),
      helpText: 'Chọn khoảng thời gian',
      cancelText: 'Hủy',
      confirmText: 'Áp dụng',
      saveText: 'Lưu',
    );

    if (result != null) {
      setState(() {
        _dateFrom = result.start;
        _dateTo = result.end;
      });

      ref
          .read(inventoryFilterProvider.notifier)
          .update(
            (state) =>
                state.copyWith(dateFrom: result.start, dateTo: result.end),
          );
    }
  }

  Widget _buildCategoryFilterButton(InventoryFilter filter) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final hasFilter = filter.categoryId != null;

    return categoriesAsync.when(
      data: (categories) {
        String label = 'Danh mục';
        if (hasFilter) {
          final category = categories.firstWhere(
            (c) => c.id == filter.categoryId,
            orElse: () =>
                Category(id: '', name: 'Tất cả', createdAt: DateTime.now()),
          );
          label = category.name;
        }

        return PopupMenuButton<String?>(
          onSelected: (value) {
            ref
                .read(inventoryFilterProvider.notifier)
                .update(
                  (state) => state.copyWith(
                    categoryId: value,
                    clearCategory: value == null,
                  ),
                );
          },
          itemBuilder: (context) => [
            PopupMenuItem<String?>(
              value: null,
              child: Row(
                children: [
                  Icon(
                    !hasFilter ? Icons.check : Icons.category,
                    size: 18,
                    color: !hasFilter ? Colors.blue : null,
                  ),
                  const SizedBox(width: 8),
                  const Text('Tất cả danh mục'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            ...categories.map(
              (category) => PopupMenuItem<String?>(
                value: category.id,
                child: Row(
                  children: [
                    Icon(
                      filter.categoryId == category.id
                          ? Icons.check
                          : Icons.folder,
                      size: 18,
                      color: filter.categoryId == category.id
                          ? Colors.blue
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(category.name),
                  ],
                ),
              ),
            ),
          ],
          child: OutlinedButton(
            onPressed: null,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              backgroundColor: hasFilter ? Colors.blue.withValues(alpha: 0.1) : null,
              side: hasFilter ? const BorderSide(color: Colors.blue) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasFilter)
                  const Icon(Icons.check_circle, size: 16, color: Colors.blue)
                else
                  const Icon(Icons.category, size: 16),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: hasFilter ? Colors.blue : null,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
        );
      },
      loading: () => OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Danh mục'),
          ],
        ),
      ),
      error: (error, stack) => OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: const Text('Danh mục'),
      ),
    );
  }

  Widget _buildProductTable(List<Product> products) {
    // Products are already filtered by the provider
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    // Store current products for export
    _currentProducts = products;

    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Không tìm thấy sản phẩm nào',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                  columns: const [
                    DataColumn(label: Text('')),
                    DataColumn(label: Text('Sản phẩm')),
                    DataColumn(label: Text('SKU')),
                    DataColumn(label: Text('Barcode')),
                    DataColumn(label: Text('Đơn vị tính')),
                    DataColumn(label: Text('Tồn kho')),
                    DataColumn(label: Text('Có thể bán')),
                    DataColumn(label: Text('Giá bán')),
                    DataColumn(label: Text('Giá vốn')),
                  ],
                  rows: products.map((product) {
                    return DataRow(
                      cells: [
                        // Checkbox + Image
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(value: false, onChanged: (value) {}),
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(
                                  Icons.image,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Product name - clickable
                        DataCell(
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Text(
                              product.name,
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.blue,
                              ),
                            ),
                          ),
                          onTap: () => _showProductDetailDialog(product),
                        ),
                        // SKU
                        DataCell(Text(product.barcode ?? '-')),
                        // Barcode
                        DataCell(Text(product.barcode ?? '')),
                        // Unit
                        DataCell(Text(product.unit)),
                        // Stock quantity
                        DataCell(
                          Text(
                            (product.currentStock ?? 0).toInt().toString(),
                            style: TextStyle(
                              color: (product.currentStock ?? 0) <= 0
                                  ? Colors.red
                                  : (product.currentStock ?? 0) <=
                                        product.minStockLevel
                                  ? Colors.orange
                                  : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Available for sale
                        DataCell(
                          Text(
                            (product.currentStock ?? 0).toInt().toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        // Sell price
                        DataCell(Text(currencyFormat.format(0))),
                        // Cost price
                        DataCell(
                          Text(
                            currencyFormat.format(product.avgCostPrice ?? 0),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        // Pagination
        _buildPagination(products.length),
      ],
    );
  }

  Widget _buildPagination(int totalItems) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Text(
            'Từ 1 đến ${totalItems > 20 ? 20 : totalItems} trên tổng $totalItems',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const Spacer(),
          Text(
            'Hiển thị',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButton<int>(
              value: 20,
              underline: const SizedBox(),
              isDense: true,
              items: [10, 20, 50, 100]
                  .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                  .toList(),
              onChanged: (value) {},
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Kết quả',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: null,
            iconSize: 20,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '1',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: null,
            iconSize: 20,
          ),
        ],
      ),
    );
  }
}
