import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/cart_model.dart';
import '../../debt/models/customer_model.dart';

/// Invoice printing service
class InvoiceService {
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  /// Generate PDF invoice
  Future<Uint8List> generateInvoicePDF({
    required Sale sale,
    Customer? customer,
    String? companyName,
    String? companyAddress,
    String? companyPhone,
    String? companyTaxCode,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(
                companyName: companyName ?? 'CỬA HÀNG TẠP HÓA',
                companyAddress: companyAddress ?? 'Địa chỉ cửa hàng',
                companyPhone: companyPhone ?? '0123456789',
                companyTaxCode: companyTaxCode,
              ),
              pw.SizedBox(height: 20),

              // Invoice title
              pw.Center(
                child: pw.Text(
                  'HÓA ĐƠN BÁN HÀNG',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),

              // Invoice info
              _buildInvoiceInfo(sale, customer),
              pw.SizedBox(height: 20),

              // Items table
              _buildItemsTable(sale.items),
              pw.SizedBox(height: 20),

              // Totals
              _buildTotals(sale),
              pw.SizedBox(height: 20),

              // Payment info
              _buildPaymentInfo(sale),
              pw.SizedBox(height: 30),

              // Footer
              _buildFooter(),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Print invoice
  Future<void> printInvoice({
    required Sale sale,
    Customer? customer,
    String? companyName,
    String? companyAddress,
    String? companyPhone,
    String? companyTaxCode,
  }) async {
    final pdfBytes = await generateInvoicePDF(
      sale: sale,
      customer: customer,
      companyName: companyName,
      companyAddress: companyAddress,
      companyPhone: companyPhone,
      companyTaxCode: companyTaxCode,
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'Invoice_${sale.invoiceNumber}.pdf',
    );
  }

  /// Share invoice PDF
  Future<void> shareInvoice({
    required Sale sale,
    Customer? customer,
    String? companyName,
    String? companyAddress,
    String? companyPhone,
    String? companyTaxCode,
  }) async {
    final pdfBytes = await generateInvoicePDF(
      sale: sale,
      customer: customer,
      companyName: companyName,
      companyAddress: companyAddress,
      companyPhone: companyPhone,
      companyTaxCode: companyTaxCode,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Invoice_${sale.invoiceNumber}.pdf',
    );
  }

  pw.Widget _buildHeader({
    required String companyName,
    required String companyAddress,
    required String companyPhone,
    String? companyTaxCode,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          companyName,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'Địa chỉ: $companyAddress',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.Text(
          'Điện thoại: $companyPhone',
          style: const pw.TextStyle(fontSize: 10),
        ),
        if (companyTaxCode != null)
          pw.Text(
            'MST: $companyTaxCode',
            style: const pw.TextStyle(fontSize: 10),
          ),
      ],
    );
  }

  pw.Widget _buildInvoiceInfo(Sale sale, Customer? customer) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Số HĐ: ${sale.invoiceNumber}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'Ngày: ${_dateFormat.format(sale.createdAt ?? DateTime.now())}',
            ),
          ],
        ),
        if (customer != null)
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Khách hàng: ${customer.name}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              if (customer.phone != null) pw.Text('SĐT: ${customer.phone}'),
              if (customer.address != null)
                pw.Text('Địa chỉ: ${customer.address}'),
            ],
          )
        else
          pw.Text('Khách hàng: Khách vãng lai'),
      ],
    );
  }

  pw.Widget _buildItemsTable(List<SaleItem> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _buildTableCell('STT', isHeader: true),
            _buildTableCell('Tên hàng', isHeader: true),
            _buildTableCell('SL', isHeader: true),
            _buildTableCell('Đơn giá', isHeader: true),
            _buildTableCell('Giảm giá', isHeader: true),
            _buildTableCell('Thành tiền', isHeader: true),
          ],
        ),
        // Items
        ...items.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final item = entry.value;
          return pw.TableRow(
            children: [
              _buildTableCell(index.toString()),
              _buildTableCell(
                'Item ${item.productId}',
              ), // TODO: Get product name
              _buildTableCell(item.quantity.toInt().toString()),
              _buildTableCell(_currencyFormat.format(item.unitPrice)),
              _buildTableCell(_currencyFormat.format(item.discount)),
              _buildTableCell(_currencyFormat.format(item.subtotal)),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: isHeader ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  pw.Widget _buildTotals(Sale sale) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        _buildTotalRow('Tạm tính:', sale.totalAmount),
        if (sale.discountAmount > 0)
          _buildTotalRow('Giảm giá:', sale.discountAmount, isNegative: true),
        pw.Divider(),
        _buildTotalRow(
          'Tổng cộng:',
          sale.finalAmount,
          isBold: true,
          fontSize: 14,
        ),
      ],
    );
  }

  pw.Widget _buildTotalRow(
    String label,
    double amount, {
    bool isNegative = false,
    bool isBold = false,
    double fontSize = 11,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.SizedBox(width: 20),
          pw.Container(
            width: 120,
            child: pw.Text(
              '${isNegative ? "-" : ""}${_currencyFormat.format(amount)}',
              style: pw.TextStyle(
                fontSize: fontSize,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPaymentInfo(Sale sale) {
    String paymentMethodText;
    switch (sale.paymentMethod) {
      case 'cash':
        paymentMethodText = 'Tiền mặt';
        break;
      case 'transfer':
        paymentMethodText = 'Chuyển khoản';
        break;
      case 'debt':
        paymentMethodText = 'Bán chịu';
        break;
      default:
        paymentMethodText = sale.paymentMethod;
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Hình thức thanh toán: $paymentMethodText',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        if (sale.notes != null && sale.notes!.isNotEmpty) ...[
          pw.SizedBox(height: 5),
          pw.Text('Ghi chú: ${sale.notes}'),
        ],
      ],
    );
  }

  pw.Widget _buildFooter() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              'Khách hàng',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 50),
            pw.Text(
              '(Ký, ghi rõ họ tên)',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              'Người bán hàng',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 50),
            pw.Text(
              '(Ký, ghi rõ họ tên)',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
      ],
    );
  }
}
