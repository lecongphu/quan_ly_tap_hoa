import 'package:flutter/material.dart';
import 'tabs/stock_list_tab.dart';
import 'tabs/purchase_orders_tab.dart';
import 'tabs/alerts_tab.dart';

class InventoryManagementScreen extends StatefulWidget {
  const InventoryManagementScreen({super.key});

  @override
  State<InventoryManagementScreen> createState() =>
      _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends State<InventoryManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Kho'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2), text: 'Tồn kho'),
            Tab(icon: Icon(Icons.shopping_cart), text: 'Đơn nhập hàng'),
            Tab(icon: Icon(Icons.warning), text: 'Cảnh báo'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [StockListTab(), PurchaseOrdersTab(), AlertsTab()],
      ),
    );
  }
}
