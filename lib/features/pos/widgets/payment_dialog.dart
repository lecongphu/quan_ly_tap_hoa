import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../debt/providers/debt_provider.dart';
import '../../debt/models/customer_model.dart';
import '../../../core/constants/app_constants.dart';

/// Payment dialog with customer selection and QR code display
class PaymentDialog extends ConsumerStatefulWidget {
  final double totalAmount;

  const PaymentDialog({super.key, required this.totalAmount});

  @override
  ConsumerState<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<PaymentDialog> {
  String _paymentMethod = AppConstants.paymentCash;
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();
  Customer? _selectedCustomer;
  String? _qrCodeUrl;

  @override
  void dispose() {
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onPaymentMethodChanged(String? value) {
    if (value == null) return;

    setState(() {
      _paymentMethod = value;
      _selectedCustomer = null;
      _qrCodeUrl = null;

      // Generate QR code for transfer
      if (value == AppConstants.paymentTransfer) {
        _generateQRCode();
      }
    });
  }

  void _generateQRCode() {
    // TODO: Get bank info from settings
    const bankCode = '970422'; // VCB
    const accountNumber = '0123456789';
    final description =
        'Thanh toan don hang ${DateTime.now().millisecondsSinceEpoch}';

    _qrCodeUrl =
        '${AppConstants.vietQRBaseUrl}/$bankCode-$accountNumber-${AppConstants.vietQRTemplate}.jpg'
        '?amount=${widget.totalAmount.toInt()}'
        '&addInfo=${Uri.encodeComponent(description)}';
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return AlertDialog(
      title: const Text('Thanh toán'),
      content: SizedBox(
        width: 500.w,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Total amount
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tổng tiền:',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      currencyFormat.format(widget.totalAmount),
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),

              // Payment methods
              Text(
                'Phương thức thanh toán:',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.h),

              Row(
                children: [
                  Radio<String>(
                    value: AppConstants.paymentCash,
                    groupValue: _paymentMethod,
                    onChanged: _onPaymentMethodChanged,
                  ),
                  const Text('Tiền mặt'),
                ],
              ),
              Row(
                children: [
                  Radio<String>(
                    value: AppConstants.paymentTransfer,
                    groupValue: _paymentMethod,
                    onChanged: _onPaymentMethodChanged,
                  ),
                  const Text('Chuyển khoản'),
                ],
              ),
              Row(
                children: [
                  Radio<String>(
                    value: AppConstants.paymentDebt,
                    groupValue: _paymentMethod,
                    onChanged: _onPaymentMethodChanged,
                  ),
                  const Text('Bán chịu'),
                ],
              ),

              SizedBox(height: 16.h),

              // QR Code display for transfer
              if (_paymentMethod == AppConstants.paymentTransfer &&
                  _qrCodeUrl != null)
                _buildQRCodeSection(),

              // Customer selection for debt
              if (_paymentMethod == AppConstants.paymentDebt)
                _buildCustomerSelection(),

              SizedBox(height: 16.h),

              // Notes
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _canConfirm() ? _handleConfirm : null,
          child: const Text('Xác nhận'),
        ),
      ],
    );
  }

  Widget _buildQRCodeSection() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        children: [
          Text(
            'Quét mã QR để thanh toán',
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8.h),
          Image.network(
            _qrCodeUrl!,
            height: 250.h,
            width: 250.w,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return SizedBox(
                height: 250.h,
                width: 250.w,
                child: const Center(child: CircularProgressIndicator()),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 250.h,
                width: 250.w,
                color: Colors.grey[200],
                child: const Center(child: Icon(Icons.error_outline, size: 48)),
              );
            },
          ),
          SizedBox(height: 8.h),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _qrCodeUrl!));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã copy link QR code')),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy link QR'),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSelection() {
    final customersAsync = ref.watch(customersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chọn khách hàng:',
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8.h),

        // Search field
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Tìm khách hàng...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            isDense: true,
          ),
          onChanged: (value) {
            setState(() {});
          },
        ),
        SizedBox(height: 8.h),

        // Customer list
        Container(
          height: 200.h,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: customersAsync.when(
            data: (customers) {
              final filteredCustomers = _searchController.text.isEmpty
                  ? customers
                  : customers
                        .where(
                          (c) =>
                              c.name.toLowerCase().contains(
                                _searchController.text.toLowerCase(),
                              ) ||
                              (c.phone?.contains(_searchController.text) ??
                                  false),
                        )
                        .toList();

              if (filteredCustomers.isEmpty) {
                return const Center(child: Text('Không tìm thấy khách hàng'));
              }

              return ListView.builder(
                itemCount: filteredCustomers.length,
                itemBuilder: (context, index) {
                  final customer = filteredCustomers[index];
                  final isSelected = _selectedCustomer?.id == customer.id;
                  final canBorrow = customer.canBorrow(widget.totalAmount);

                  return ListTile(
                    selected: isSelected,
                    leading: Radio<String>(
                      value: customer.id,
                      groupValue: _selectedCustomer?.id,
                      onChanged: canBorrow
                          ? (value) {
                              setState(() {
                                _selectedCustomer = customer;
                              });
                            }
                          : null,
                    ),
                    title: Text(customer.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (customer.phone != null) Text(customer.phone!),
                        Text(
                          'Nợ: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(customer.currentDebt)} / ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(customer.debtLimit)}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: canBorrow ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    trailing: !canBorrow
                        ? const Icon(Icons.warning, color: Colors.red)
                        : null,
                    onTap: canBorrow
                        ? () {
                            setState(() {
                              _selectedCustomer = customer;
                            });
                          }
                        : null,
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Lỗi: $error')),
          ),
        ),

        if (_selectedCustomer != null) ...[
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Đã chọn: ${_selectedCustomer!.name}',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  bool _canConfirm() {
    if (_paymentMethod == AppConstants.paymentDebt) {
      return _selectedCustomer != null;
    }
    return true;
  }

  void _handleConfirm() {
    Navigator.pop(context, {
      'paymentMethod': _paymentMethod,
      'notes': _notesController.text,
      'customerId': _selectedCustomer?.id,
      'qrCodeData': _qrCodeUrl,
    });
  }
}
