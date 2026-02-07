import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../models/customer_model.dart';
import '../providers/debt_provider.dart';
import '../../../core/constants/app_constants.dart';

class DebtPaymentScreen extends ConsumerStatefulWidget {
  final Customer customer;

  const DebtPaymentScreen({super.key, required this.customer});

  @override
  ConsumerState<DebtPaymentScreen> createState() => _DebtPaymentScreenState();
}

class _DebtPaymentScreenState extends ConsumerState<DebtPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String _paymentMethod = AppConstants.paymentCash;
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handlePayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final debtService = ref.read(debtServiceProvider);
      final amount = double.parse(_amountController.text);

      await debtService.recordPayment(
        customerId: widget.customer.id,
        amount: amount,
        paymentMethod: _paymentMethod,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      if (mounted) {
        _showMessage('Ghi nhận thanh toán thành công!');
        ref.invalidate(customersProvider);
        ref.invalidate(customersWithDebtProvider);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Lỗi: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Scaffold(
      appBar: AppBar(title: const Text('Thu nợ')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16.w),
          children: [
            // Customer info card
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          child: const Icon(Icons.person, color: Colors.blue),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.customer.name,
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (widget.customer.phone != null)
                                Text(
                                  widget.customer.phone!,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    Divider(height: 1.h),
                    SizedBox(height: 16.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nợ hiện tại',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              currencyFormat.format(
                                widget.customer.currentDebt,
                              ),
                              style: TextStyle(
                                fontSize: 24.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24.h),

            // Payment form
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thông tin thanh toán',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Amount
                    TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: 'Số tiền thu *',
                        suffixText: '₫',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập số tiền';
                        }
                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) {
                          return 'Số tiền phải lớn hơn 0';
                        }
                        if (amount > widget.customer.currentDebt) {
                          return 'Số tiền không được lớn hơn nợ hiện tại';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 16.h),

                    // Payment method
                    Text(
                      'Hình thức thanh toán',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    RadioGroup<String>(
                      groupValue: _paymentMethod,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _paymentMethod = value);
                      },
                      child: Row(
                        children: [
                          Radio<String>(value: AppConstants.paymentCash),
                          const SizedBox(width: 8),
                          const Text('Tiền mặt'),
                          const SizedBox(width: 24),
                          Radio<String>(value: AppConstants.paymentTransfer),
                          const SizedBox(width: 8),
                          const Text('Chuyển khoản'),
                        ],
                      ),
                    ),

                    SizedBox(height: 16.h),

                    // Notes
                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: 'Ghi chú (tùy chọn)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24.h),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handlePayment,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Xác nhận thanh toán'),
              ),
            ),

            SizedBox(height: 16.h),

            // Quick amount buttons
            Text(
              'Số tiền nhanh:',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
            ),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                _QuickAmountButton(
                  label: '50%',
                  amount: widget.customer.currentDebt / 2,
                  onTap: (amount) {
                    _amountController.text = amount.toInt().toString();
                  },
                ),
                _QuickAmountButton(
                  label: '100%',
                  amount: widget.customer.currentDebt,
                  onTap: (amount) {
                    _amountController.text = amount.toInt().toString();
                  },
                ),
                _QuickAmountButton(
                  label: '100K',
                  amount: 100000,
                  onTap: (amount) {
                    _amountController.text = amount.toInt().toString();
                  },
                ),
                _QuickAmountButton(
                  label: '500K',
                  amount: 500000,
                  onTap: (amount) {
                    _amountController.text = amount.toInt().toString();
                  },
                ),
                _QuickAmountButton(
                  label: '1M',
                  amount: 1000000,
                  onTap: (amount) {
                    _amountController.text = amount.toInt().toString();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAmountButton extends StatelessWidget {
  final String label;
  final double amount;
  final Function(double) onTap;

  const _QuickAmountButton({
    required this.label,
    required this.amount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(onPressed: () => onTap(amount), child: Text(label));
  }
}
