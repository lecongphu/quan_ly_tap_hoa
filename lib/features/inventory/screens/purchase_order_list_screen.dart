import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/purchase_order_model.dart';
import '../providers/purchase_order_provider.dart';
import 'create_purchase_order_screen.dart';

class PurchaseOrderListScreen extends ConsumerStatefulWidget {
  const PurchaseOrderListScreen({super.key});

  @override
  ConsumerState<PurchaseOrderListScreen> createState() =>
      _PurchaseOrderListScreenState();
}

class _PurchaseOrderListScreenState
    extends ConsumerState<PurchaseOrderListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);

    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(purchaseOrderProvider.notifier).loadPurchaseOrders();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      PurchaseOrderStatus? status;
      switch (_tabController.index) {
        case 0:
          status = null; // All
          break;
        case 1:
          status = PurchaseOrderStatus.inProgress;
          break;
        case 2:
          status = PurchaseOrderStatus.completed;
          break;
      }
      ref.read(purchaseOrderProvider.notifier).setStatusFilter(status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(purchaseOrderProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Danh sách đơn nhập hàng'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Colors.blue,
              tabs: const [
                Tab(text: 'Tất cả'),
                Tab(text: 'Đang giao dịch'),
                Tab(text: 'Hoàn thành'),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                ? Center(child: Text('Lỗi: ${state.error}'))
                : _buildDataTable(state.orders),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm theo mã đơn nhập, tên ĐƠT, mã NCC',
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
                  onSubmitted: (value) {
                    ref
                        .read(purchaseOrderProvider.notifier)
                        .setSearchQuery(value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              _buildFilterButton('Trạng thái nhập', Icons.arrow_drop_down),
              const SizedBox(width: 8),
              _buildFilterButton('Ngày tạo', Icons.arrow_drop_down),
              const SizedBox(width: 8),
              _buildFilterButton('Sản phẩm', Icons.arrow_drop_down),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () {},
                tooltip: 'Bộ lọc khác',
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  ref.read(purchaseOrderProvider.notifier).refresh();
                },
                tooltip: 'Làm mới',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.file_download, size: 18),
                label: const Text('Xuất file'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.file_upload, size: 18),
                label: const Text('Nhập file'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreatePurchaseOrderScreen(),
                    ),
                  );
                  if (result == true) {
                    ref.read(purchaseOrderProvider.notifier).refresh();
                  }
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Tạo đơn nhập hàng'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
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

  Widget _buildDataTable(List<PurchaseOrder> orders) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Không có đơn nhập hàng nào',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreatePurchaseOrderScreen(),
                  ),
                );
                if (result == true) {
                  ref.read(purchaseOrderProvider.notifier).refresh();
                }
              },
              child: const Text('Tạo đơn nhập hàng mới'),
            ),
          ],
        ),
      );
    }

    return Container(
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
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                  columns: const [
                    DataColumn(label: Text('Mã đơn nhập')),
                    DataColumn(label: Text('Ngày tạo')),
                    DataColumn(label: Text('Chi nhánh nhập')),
                    DataColumn(label: Text('Trạng thái')),
                    DataColumn(label: Text('Nhà cung cấp')),
                    DataColumn(label: Text('Số lượng')),
                    DataColumn(label: Text('Nhân viên tạo')),
                    DataColumn(label: Text('Giá trị đơn')),
                  ],
                  rows: orders.map((order) => _buildDataRow(order)).toList(),
                ),
              ),
            ),
          ),
          _buildPagination(orders.length),
        ],
      ),
    );
  }

  DataRow _buildDataRow(PurchaseOrder order) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return DataRow(
      cells: [
        DataCell(
          Text(
            order.orderNumber,
            style: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        DataCell(Text(dateFormat.format(order.createdAt))),
        DataCell(Text(order.warehouse ?? '-')),
        DataCell(_buildStatusChip(order.status)),
        DataCell(Text(order.supplierName ?? '-')),
        DataCell(Text(order.totalItems.toString())),
        DataCell(Text(order.createdByName ?? '-')),
        DataCell(
          Text(
            NumberFormat.currency(
              locale: 'vi_VN',
              symbol: '₫',
            ).format(order.totalAmount),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(PurchaseOrderStatus status) {
    Color color;
    switch (status) {
      case PurchaseOrderStatus.pending:
        color = Colors.orange;
        break;
      case PurchaseOrderStatus.inProgress:
        color = Colors.blue;
        break;
      case PurchaseOrderStatus.completed:
        color = Colors.green;
        break;
      case PurchaseOrderStatus.cancelled:
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPagination(int totalItems) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Text(
            'Từ 1 đến 1 trên tổng $totalItems',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const Spacer(),
          Text(
            'Hiển thị',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButton<int>(
              value: 20,
              underline: const SizedBox(),
              items: [10, 20, 50, 100]
                  .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                  .toList(),
              onChanged: (value) {},
            ),
          ),
          const SizedBox(width: 16),
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
