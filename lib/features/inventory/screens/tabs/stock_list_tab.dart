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
  String _stockFilter = 'all'; // all, in_stock, out_of_stock
  bool _isExporting = false;
  bool _isImporting = false;
  List<Product> _currentProducts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      setState(() {
        switch (_tabController.index) {
          case 0:
            _stockFilter = 'all';
            break;
          case 1:
            _stockFilter = 'in_stock';
            break;
          case 2:
            _stockFilter = 'out_of_stock';
            break;
        }
      });
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

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Tabs
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Colors.blue,
              tabs: const [
                Tab(text: 'Tất cả'),
                Tab(text: 'Còn hàng'),
                Tab(text: 'Hết hàng'),
              ],
            ),
          ),
          // Search and filter bar
          _buildFilterBar(),
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

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          // Search field
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm theo mã SKU, tên sản phẩm, barcode',
                prefixIcon: const Icon(Icons.search, size: 20),
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
                setState(() {});
              },
            ),
          ),
          const SizedBox(width: 12),
          // Date filter
          _buildFilterButton('Ngày tạo', Icons.arrow_drop_down),
          const SizedBox(width: 8),
          // Stock filter
          _buildFilterButton('Tồn kho', Icons.arrow_drop_down),
          const SizedBox(width: 8),
          // More filters
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.filter_list, size: 18),
            label: const Text('Bộ lọc khác'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(width: 8),
          // Save filter
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text('Lưu bộ lọc'),
          ),
          const SizedBox(width: 16),
          // Export button
          OutlinedButton.icon(
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
          ),
          const SizedBox(width: 8),
          // Import button
          PopupMenuButton<String>(
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
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, IconData icon) {
    return OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Icon(icon, size: 18),
        ],
      ),
    );
  }

  Widget _buildProductTable(List<Product> products) {
    // Filter products based on search and tab
    var filteredProducts = products;

    // Search filter
    if (_searchController.text.isNotEmpty) {
      filteredProducts = filteredProducts.where((p) {
        final query = _searchController.text.toLowerCase();
        return p.name.toLowerCase().contains(query) ||
            (p.barcode?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Stock filter
    switch (_stockFilter) {
      case 'in_stock':
        filteredProducts = filteredProducts.where((p) {
          return (p.currentStock ?? 0) > 0;
        }).toList();
        break;
      case 'out_of_stock':
        filteredProducts = filteredProducts.where((p) {
          return (p.currentStock ?? 0) <= 0;
        }).toList();
        break;
    }

    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    // Store current products for export
    _currentProducts = filteredProducts;

    if (filteredProducts.isEmpty) {
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
                  rows: filteredProducts.map((product) {
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
                        // Product name
                        DataCell(
                          Text(
                            product.name,
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
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
        _buildPagination(filteredProducts.length),
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
