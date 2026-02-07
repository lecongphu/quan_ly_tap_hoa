import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../debt/models/customer_model.dart';
import '../models/cart_model.dart';
import '../services/invoice_service.dart';
import '../services/pos_service.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final String saleId;
  final Sale? summary;

  const InvoiceDetailScreen({super.key, required this.saleId, this.summary});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final POSService _service = POSService();
  final InvoiceService _invoiceService = InvoiceService();
  final NumberFormat _currency = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
  );
  final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

  late Future<Sale?> _saleFuture;
  bool _isPrinting = false;
  bool _isLocking = false;
  bool _isRefunding = false;

  @override
  void initState() {
    super.initState();
    _saleFuture = _service.getSaleById(widget.saleId);
  }

  String _paymentLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Tiền mặt';
      case 'transfer':
        return 'Chuyển khoản';
      case 'debt':
        return 'Bán chịu';
      default:
        return method;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết hóa đơn')),
      body: FutureBuilder<Sale?>(
        future: _saleFuture,
        builder: (context, snapshot) {
          final sale = snapshot.data ?? widget.summary;

          if (snapshot.connectionState == ConnectionState.waiting &&
              sale == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError && sale == null) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }
          if (sale == null) {
            return const Center(child: Text('Không tìm thấy hóa đơn'));
          }

          final createdAt = sale.createdAt ?? DateTime.now();

          return ListView(
            padding: EdgeInsets.all(16.w),
            children: [
              _buildHeaderCard(sale, createdAt),
              SizedBox(height: 12.h),
              _buildActionRow(sale),
              SizedBox(height: 16.h),
              _buildItemsCard(sale.items),
              SizedBox(height: 16.h),
              _buildTotalsCard(sale),
              if (sale.notes != null && sale.notes!.isNotEmpty) ...[
                SizedBox(height: 16.h),
                _buildNotesCard(sale.notes!),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(Sale sale, DateTime createdAt) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sale.invoiceNumber,
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6.h),
          Text(
            _dateTimeFormat.format(createdAt),
            style: TextStyle(color: Colors.grey[600], fontSize: 12.sp),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              const Icon(Icons.person, size: 18),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  sale.customerName ?? 'Khách lẻ',
                  style: TextStyle(fontSize: 13.sp),
                ),
              ),
            ],
          ),
          if (sale.customerPhone != null || sale.customerAddress != null) ...[
            SizedBox(height: 6.h),
            if (sale.customerPhone != null)
              Row(
                children: [
                  const Icon(Icons.phone, size: 16),
                  SizedBox(width: 6.w),
                  Text(
                    sale.customerPhone!,
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
                  ),
                ],
              ),
            if (sale.customerAddress != null)
              Padding(
                padding: EdgeInsets.only(top: 4.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, size: 16),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        sale.customerAddress!,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          SizedBox(height: 10.h),
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  _paymentLabel(sale.paymentMethod),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.sp,
                  ),
                ),
              ),
              if (sale.dueDate != null) ...[
                SizedBox(width: 8.w),
                Text(
                  'Hẹn trả: ${DateFormat('dd/MM/yyyy').format(sale.dueDate!)}',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
                ),
              ],
            ],
          ),
          if (sale.isLocked || sale.refundedAt != null) ...[
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 6.h,
              children: [
                if (sale.isLocked)
                  _StatusChip(label: 'Đã khóa', color: Colors.grey),
                if (sale.refundedAt != null)
                  _StatusChip(label: 'Đã hoàn tiền', color: Colors.redAccent),
              ],
            ),
          ],
          if (sale.isLocked && sale.lockedAt != null) ...[
            SizedBox(height: 6.h),
            Text(
              'Khóa lúc: ${_dateTimeFormat.format(sale.lockedAt!)}',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
            ),
          ],
          if (sale.refundedAt != null) ...[
            SizedBox(height: 6.h),
            Text(
              'Hoàn tiền lúc: ${_dateTimeFormat.format(sale.refundedAt!)}',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
            ),
          ],
          if (sale.refundNotes != null && sale.refundNotes!.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text(
              'Lý do: ${sale.refundNotes}',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionRow(Sale sale) {
    final isLocked = sale.isLocked;
    final isRefunded = sale.refundedAt != null;
    return Wrap(
      spacing: 10.w,
      runSpacing: 10.h,
      children: [
        ElevatedButton.icon(
          onPressed: _isPrinting ? null : () => _handlePrint(sale),
          icon: _isPrinting
              ? SizedBox(
                  width: 16.w,
                  height: 16.w,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.print),
          label: const Text('In hóa đơn'),
        ),
        OutlinedButton.icon(
          onPressed: (_isLocking || isLocked) ? null : () => _handleLock(sale),
          icon: const Icon(Icons.lock),
          label: Text(isLocked ? 'Đã khóa' : 'Khóa hóa đơn'),
        ),
        OutlinedButton.icon(
          onPressed: (_isRefunding || isRefunded)
              ? null
              : () => _handleRefund(sale),
          icon: const Icon(Icons.reply),
          label: Text(isRefunded ? 'Đã hoàn tiền' : 'Hoàn tiền'),
        ),
      ],
    );
  }

  Future<void> _reloadSale() async {
    setState(() {
      _saleFuture = _service.getSaleById(widget.saleId);
    });
  }

  Future<void> _handlePrint(Sale sale) async {
    setState(() => _isPrinting = true);
    try {
      final customer = sale.customerName == null
          ? null
          : Customer(
              id: sale.customerId ?? 'guest',
              name: sale.customerName ?? 'Khách hàng',
              phone: sale.customerPhone,
              address: sale.customerAddress,
              currentDebt: 0,
              isActive: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
      await _invoiceService.printInvoice(sale: sale, customer: customer);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã gửi lệnh in hóa đơn')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể in hóa đơn: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  Future<void> _handleLock(Sale sale) async {
    if (sale.isLocked) {
      return;
    }
    final confirmed = await _confirmAction(
      title: 'Khóa hóa đơn',
      message: 'Bạn có chắc muốn khóa hóa đơn này không?',
    );
    if (!confirmed) return;
    setState(() => _isLocking = true);
    try {
      await _service.lockInvoice(sale.id ?? widget.saleId);
      await _reloadSale();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã khóa hóa đơn.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể khóa hóa đơn: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLocking = false);
      }
    }
  }

  Future<void> _handleRefund(Sale sale) async {
    if (sale.refundedAt != null) {
      return;
    }
    final decision = await _promptRefundDecision();
    if (!decision.confirmed) return;
    setState(() => _isRefunding = true);
    try {
      await _service.refundInvoice(
        sale.id ?? widget.saleId,
        reason: decision.reason,
      );
      await _reloadSale();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã hoàn tiền hóa đơn.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể hoàn tiền: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isRefunding = false);
      }
    }
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Xác nhận'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<_RefundDecision> _promptRefundDecision() async {
    final controller = TextEditingController();
    bool confirmed = false;
    await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hoàn tiền'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Nhập lý do hoàn tiền (không bắt buộc).'),
              SizedBox(height: 12.h),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Ví dụ: Khách trả hàng',
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                confirmed = true;
                Navigator.of(context).pop(true);
              },
              child: const Text('Xác nhận'),
            ),
          ],
        );
      },
    );

    if (!confirmed) {
      return const _RefundDecision(confirmed: false);
    }
    final reason = controller.text.trim();
    return _RefundDecision(
      confirmed: true,
      reason: reason.isEmpty ? null : reason,
    );
  }

  Widget _buildItemsCard(List<SaleItem> items) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Danh sách hàng',
            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12.h),
          if (items.isEmpty)
            Text('Chưa có sản phẩm.', style: TextStyle(color: Colors.grey[600]))
          else
            ...items.map((item) {
              return Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName ?? item.productId,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.sp,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            '${item.quantity.toStringAsFixed(0)} ${item.unit ?? ''} x ${_currency.format(item.unitPrice)}',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _currency.format(item.subtotal),
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTotalsCard(Sale sale) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          _buildTotalRow('Tạm tính', sale.totalAmount),
          if (sale.discountAmount > 0)
            _buildTotalRow('Giảm giá', sale.discountAmount),
          const Divider(),
          _buildTotalRow('Thành tiền', sale.finalAmount, isBold: true),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            _currency.format(amount),
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard(String notes) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ghi chú',
            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8.h),
          Text(notes),
        ],
      ),
    );
  }
}

class _RefundDecision {
  final bool confirmed;
  final String? reason;

  const _RefundDecision({required this.confirmed, this.reason});
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12.sp,
        ),
      ),
    );
  }
}
