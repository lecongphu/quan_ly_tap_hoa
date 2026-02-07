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
  final _discountController = TextEditingController(text: '0');
  Customer? _selectedCustomer;
  String? _qrCodeUrl;
  DateTime? _dueDate;

  @override
  void dispose() {
    _notesController.dispose();
    _searchController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  double get _discountAmount {
    final parsed = double.tryParse(_discountController.text);
    if (parsed == null || parsed.isNaN) return 0;
    return parsed;
  }

  double get _finalAmount {
    final result = widget.totalAmount - _discountAmount;
    return result < 0 ? 0 : result;
  }

  void _onPaymentMethodChanged(String? value) {
    if (value == null) return;

    setState(() {
      _paymentMethod = value;
      _selectedCustomer = null;
      _qrCodeUrl = null;
      _dueDate = null;

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
        '?amount=${_finalAmount.toInt()}'
        '&addInfo=${Uri.encodeComponent(description)}';
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final initialDate = _dueDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
    }
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
                child: Column(
                  children: [
                    _AmountRow(
                      label: 'Tổng tiền',
                      value: currencyFormat.format(widget.totalAmount),
                    ),
                    if (_discountAmount > 0)
                      _AmountRow(
                        label: 'Giảm giá',
                        value: '-${currencyFormat.format(_discountAmount)}',
                        valueColor: Colors.red,
                      ),
                    Divider(height: 16.h),
                    _AmountRow(
                      label: 'Thành tiền',
                      value: currencyFormat.format(_finalAmount),
                      isBold: true,
                      valueColor: Theme.of(context).colorScheme.primary,
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

              RadioGroup<String>(
                groupValue: _paymentMethod,
                onChanged: _onPaymentMethodChanged,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Radio<String>(value: AppConstants.paymentCash),
                        const Text('Tiền mặt'),
                      ],
                    ),
                    Row(
                      children: [
                        Radio<String>(value: AppConstants.paymentTransfer),
                        const Text('Chuyển khoản'),
                      ],
                    ),
                    Row(
                      children: [
                        Radio<String>(value: AppConstants.paymentDebt),
                        const Text('Bán chịu'),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16.h),

              TextField(
                controller: _discountController,
                decoration: const InputDecoration(
                  labelText: 'Giảm giá',
                  suffixText: '₫',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) {
                  setState(() {
                    if (_paymentMethod == AppConstants.paymentTransfer) {
                      _generateQRCode();
                    }
                  });
                },
              ),

              if (_paymentMethod == AppConstants.paymentDebt) ...[
                SizedBox(height: 12.h),
                InkWell(
                  onTap: _pickDueDate,
                  borderRadius: BorderRadius.circular(8.r),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Hẹn trả',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      _dueDate == null
                          ? 'Chọn ngày'
                          : DateFormat('dd/MM/yyyy').format(_dueDate!),
                    ),
                  ),
                ),
              ],

              // QR Code display for transfer
              if (_paymentMethod == AppConstants.paymentTransfer &&
                  _qrCodeUrl != null)
                _buildQRCodeSection(),

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
    final isDebt = _paymentMethod == AppConstants.paymentDebt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isDebt ? 'Chọn khách hàng:' : 'Chọn khách hàng (tùy chọn):',
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

              return RadioGroup<String>(
                groupValue: _selectedCustomer?.id,
                onChanged: (value) {
                  if (value == null) {
                    setState(() => _selectedCustomer = null);
                    return;
                  }
                  Customer? selected;
                  for (final customer in filteredCustomers) {
                    if (customer.id == value) {
                      selected = customer;
                      break;
                    }
                  }
                  setState(() => _selectedCustomer = selected);
                },
                child: ListView.builder(
                  itemCount: filteredCustomers.length,
                  itemBuilder: (context, index) {
                    final customer = filteredCustomers[index];
                    final isSelected = _selectedCustomer?.id == customer.id;

                    return ListTile(
                      selected: isSelected,
                      leading: Radio<String>(value: customer.id),
                      title: Text(customer.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (customer.phone != null) Text(customer.phone!),
                          Text(
                            'Nợ: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(customer.currentDebt)}',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: customer.currentDebt > 0
                                  ? Colors.red
                                  : Colors.green,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => setState(() {
                        _selectedCustomer = customer;
                      }),
                    );
                  },
                ),
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
      'discountAmount': _discountAmount,
      'dueDate': _dueDate,
    });
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  const _AmountRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
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
              fontSize: 14.sp,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
