import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../providers/debt_provider.dart';
import '../models/customer_model.dart';
import 'debt_payment_screen.dart';

class DebtManagementScreen extends ConsumerStatefulWidget {
  const DebtManagementScreen({super.key});

  @override
  ConsumerState<DebtManagementScreen> createState() =>
      _DebtManagementScreenState();
}

class _DebtManagementScreenState extends ConsumerState<DebtManagementScreen> {
  final _searchController = TextEditingController();
  bool _showOnlyDebt = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = _showOnlyDebt
        ? ref.watch(customersWithDebtProvider)
        : ref.watch(customersProvider);
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Công nợ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              // TODO: Navigate to add customer screen
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(customersProvider);
              ref.invalidate(customersWithDebtProvider);
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
                    hintText: 'Tìm khách hàng...',
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

                // Filter chip
                Row(
                  children: [
                    FilterChip(
                      label: const Text('Chỉ hiện khách nợ'),
                      selected: _showOnlyDebt,
                      onSelected: (selected) {
                        setState(() {
                          _showOnlyDebt = selected;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Customer list
          Expanded(
            child: customersAsync.when(
              data: (customers) {
                // Filter customers by search
                var filteredCustomers = customers;
                if (_searchController.text.isNotEmpty) {
                  filteredCustomers = customers.where((c) {
                    return c.name.toLowerCase().contains(
                          _searchController.text.toLowerCase(),
                        ) ||
                        (c.phone?.contains(_searchController.text) ?? false);
                  }).toList();
                }

                if (filteredCustomers.isEmpty) {
                  return const Center(child: Text('Không tìm thấy khách hàng'));
                }

                // Calculate total debt
                final totalDebt = filteredCustomers.fold<double>(
                  0,
                  (sum, customer) => sum + customer.currentDebt,
                );

                return Column(
                  children: [
                    // Total debt summary
                    if (_showOnlyDebt && filteredCustomers.isNotEmpty)
                      Container(
                        padding: EdgeInsets.all(16.w),
                        color: Colors.red[50],
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tổng công nợ:',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              currencyFormat.format(totalDebt),
                              style: TextStyle(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Customer list
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.all(16.w),
                        itemCount: filteredCustomers.length,
                        itemBuilder: (context, index) {
                          final customer = filteredCustomers[index];
                          return _CustomerCard(
                            customer: customer,
                            currencyFormat: currencyFormat,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      DebtPaymentScreen(customer: customer),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Lỗi: $error')),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final NumberFormat currencyFormat;
  final VoidCallback onTap;

  const _CustomerCard({
    required this.customer,
    required this.currencyFormat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasDebt = customer.currentDebt > 0;
    final debtPercentage = customer.debtLimit > 0
        ? (customer.currentDebt / customer.debtLimit * 100).toInt()
        : 0;

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
                  CircleAvatar(
                    backgroundColor: hasDebt
                        ? Colors.red[100]
                        : Colors.blue[100],
                    child: Icon(
                      Icons.person,
                      color: hasDebt ? Colors.red : Colors.blue,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (customer.phone != null) ...[
                          SizedBox(height: 4.h),
                          Row(
                            children: [
                              Icon(
                                Icons.phone,
                                size: 14.sp,
                                color: Colors.grey[600],
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                customer.phone!,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (hasDebt)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: debtPercentage >= 80
                            ? Colors.red[50]
                            : Colors.orange[50],
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: debtPercentage >= 80
                              ? Colors.red
                              : Colors.orange,
                        ),
                      ),
                      child: Text(
                        'Đang nợ',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: debtPercentage >= 80
                              ? Colors.red
                              : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),

              if (customer.address != null) ...[
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14.sp,
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        customer.address!,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              SizedBox(height: 12.h),
              Divider(height: 1.h),
              SizedBox(height: 12.h),

              // Debt info
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nợ hiện tại',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          currencyFormat.format(customer.currentDebt),
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: hasDebt ? Colors.red : Colors.green,
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
                          'Hạn mức',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          currencyFormat.format(customer.debtLimit),
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
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Còn lại',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          currencyFormat.format(customer.availableCredit),
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Debt progress bar
              if (hasDebt && customer.debtLimit > 0) ...[
                SizedBox(height: 12.h),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mức sử dụng',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '$debtPercentage%',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: debtPercentage >= 80
                                ? Colors.red
                                : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    LinearProgressIndicator(
                      value: customer.currentDebt / customer.debtLimit,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation(
                        debtPercentage >= 80 ? Colors.red : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
