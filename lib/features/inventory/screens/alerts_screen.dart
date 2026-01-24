import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        title: const Text('Cảnh báo'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.warning), text: 'Hết hạn'),
            Tab(icon: Icon(Icons.inventory_2), text: 'Tồn kho thấp'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_ExpiryAlertsTab(), _LowStockAlertsTab()],
      ),
    );
  }
}

// Expiry alerts tab
class _ExpiryAlertsTab extends ConsumerWidget {
  const _ExpiryAlertsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    // TODO: Replace with actual data from provider
    final mockExpiryData = [
      {
        'name': 'Sữa tươi Vinamilk 1L',
        'barcode': '8934588043010',
        'quantity': 12,
        'unit': 'hộp',
        'expiryDate': DateTime.now().add(const Duration(days: 2)),
        'isDanger': true,
      },
      {
        'name': 'Coca Cola 330ml',
        'barcode': '8934588013010',
        'quantity': 24,
        'unit': 'lon',
        'expiryDate': DateTime.now().add(const Duration(days: 5)),
        'isDanger': false,
      },
    ];

    if (mockExpiryData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text('Không có hàng sắp hết hạn'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: mockExpiryData.length,
      itemBuilder: (context, index) {
        final item = mockExpiryData[index];
        final expiryDate = item['expiryDate'] as DateTime;
        final daysLeft = expiryDate.difference(DateTime.now()).inDays;
        final isDanger = item['isDanger'] as bool;

        return Card(
          margin: EdgeInsets.only(bottom: 12.h),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: isDanger ? Colors.red : Colors.orange,
                  width: 4,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning,
                        color: isDanger ? Colors.red : Colors.orange,
                        size: 24.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          item['name'] as String,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Mã: ${item['barcode']}',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Số lượng',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '${item['quantity']} ${item['unit']}',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hết hạn',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              dateFormat.format(expiryDate),
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: isDanger ? Colors.red : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: isDanger ? Colors.red[50] : Colors.orange[50],
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      isDanger
                          ? '⚠️ Còn $daysLeft ngày - Cần xử lý ngay!'
                          : '⏰ Còn $daysLeft ngày',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: isDanger ? Colors.red : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Low stock alerts tab
class _LowStockAlertsTab extends ConsumerWidget {
  const _LowStockAlertsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Replace with actual data from provider
    final mockLowStockData = [
      {
        'name': 'Mì Hảo Hảo tôm chua cay',
        'barcode': '8934588023010',
        'currentStock': 15,
        'minStock': 100,
        'unit': 'gói',
        'avgCost': 3500,
      },
      {
        'name': 'Nước suối Aquafina 500ml',
        'barcode': '8934588013034',
        'currentStock': 20,
        'minStock': 48,
        'unit': 'chai',
        'avgCost': 4000,
      },
    ];

    if (mockLowStockData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text('Tất cả sản phẩm đều đủ hàng'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: mockLowStockData.length,
      itemBuilder: (context, index) {
        final item = mockLowStockData[index];
        final currentStock = item['currentStock'] as int;
        final minStock = item['minStock'] as int;
        final stockPercentage = (currentStock / minStock * 100).toInt();

        return Card(
          margin: EdgeInsets.only(bottom: 12.h),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: stockPercentage < 20 ? Colors.red : Colors.orange,
                  width: 4,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2,
                        color: stockPercentage < 20
                            ? Colors.red
                            : Colors.orange,
                        size: 24.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          item['name'] as String,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Mã: ${item['barcode']}',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tồn hiện tại',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '$currentStock ${item['unit']}',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: stockPercentage < 20
                                    ? Colors.red
                                    : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tồn tối thiểu',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '$minStock ${item['unit']}',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  // Progress bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Mức tồn',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            '$stockPercentage%',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: stockPercentage < 20
                                  ? Colors.red
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      LinearProgressIndicator(
                        value: currentStock / minStock,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation(
                          stockPercentage < 20 ? Colors.red : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: stockPercentage < 20
                          ? Colors.red[50]
                          : Colors.orange[50],
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      stockPercentage < 20
                          ? '🚨 Cần nhập kho ngay!'
                          : '⚠️ Nên nhập thêm hàng',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: stockPercentage < 20
                            ? Colors.red
                            : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
