import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../models/cart_model.dart';

/// POS service for sales transactions
class POSService {
  /// Create a sale transaction
  Future<Sale> createSale({
    required List<CartItem> cartItems,
    String? customerId,
    required String paymentMethod,
    double discountAmount = 0,
    DateTime? dueDate,
    String? notes,
    String? createdBy,
  }) async {
    try {
      if (cartItems.isEmpty) {
        throw Exception('Giỏ hàng trống');
      }

      if (paymentMethod == AppConstants.paymentDebt) {
        if (customerId == null) {
          throw Exception('Phải chọn khách hàng khi bán chịu');
        }
      }

      final supabase = SupabaseService.client;
      final response = await supabase.rpc(
        'pos_checkout',
        params: {
          'p_payment_method': paymentMethod,
          'p_items': cartItems
              .map(
                (item) => {
                  'product_id': item.product.id,
                  'quantity': item.quantity,
                  'unit_price': item.unitPrice,
                },
              )
              .toList(),
          'p_customer_id': customerId,
          'p_discount_amount': discountAmount,
          'p_due_date': dueDate?.toIso8601String(),
          'p_notes': notes,
        },
      );

      final payload = Map<String, dynamic>.from(response as Map);
      final saleJson = payload['sale'] as Map<String, dynamic>?;
      final itemsJson = payload['items'] as List<dynamic>? ?? [];

      if (saleJson == null) {
        throw Exception('Lỗi khi tạo hóa đơn');
      }

      return Sale.fromJson({...saleJson, 'items': itemsJson});
    } catch (e) {
      throw Exception('Lỗi khi tạo hóa đơn: ${e.toString()}');
    }
  }

  /// Get sale by ID
  Future<Sale?> getSaleById(String saleId) async {
    try {
      final supabase = SupabaseService.client;
      final data = await supabase
          .from('sales')
          .select(
            'id, invoice_number, customer_id, total_amount, discount_amount, final_amount, payment_method, payment_status, due_date, notes, created_at, is_locked, locked_at, refunded_at, refund_notes, customer:customers(name, phone, address), items:sale_items(id, sale_id, product_id, batch_id, quantity, unit_price, cost_price, discount, subtotal, created_at, product:products(name, unit))',
          )
          .eq('id', saleId)
          .single();

      final items = (data['items'] as List<dynamic>? ?? []).map((item) {
        final itemMap = Map<String, dynamic>.from(item as Map);
        return {
          ...itemMap,
          'product_name': (itemMap['product'] as Map?)?['name'],
          'unit': (itemMap['product'] as Map?)?['unit'],
        };
      }).toList();

      return Sale.fromJson({
        ...data,
        'items': items,
        'customer_name': (data['customer'] as Map?)?['name'],
        'customer_phone': (data['customer'] as Map?)?['phone'],
        'customer_address': (data['customer'] as Map?)?['address'],
      });
    } catch (e) {
      return null;
    }
  }

  Future<void> lockInvoice(String saleId) async {
    final supabase = SupabaseService.client;
    await supabase.rpc('lock_sale', params: {'p_sale_id': saleId});
  }

  Future<void> refundInvoice(String saleId, {String? reason}) async {
    final supabase = SupabaseService.client;
    await supabase.rpc(
      'refund_sale',
      params: {'p_sale_id': saleId, 'p_reason': reason},
    );
  }

  /// Get sales by date range
  Future<List<Sale>> getSalesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final supabase = SupabaseService.client;
      var query = supabase
          .from('sales')
          .select(
            'id, invoice_number, customer_id, total_amount, discount_amount, final_amount, payment_method, payment_status, due_date, notes, created_at, is_locked, locked_at, refunded_at, refund_notes, customer:customers(name, phone, address)',
          )
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDate.toIso8601String());

      final data = await query.order('created_at', ascending: false);
      return (data as List<dynamic>).map((item) {
        final sale = Map<String, dynamic>.from(item as Map);
        return Sale.fromJson({
          ...sale,
          'customer_name': (sale['customer'] as Map?)?['name'],
          'customer_phone': (sale['customer'] as Map?)?['phone'],
          'customer_address': (sale['customer'] as Map?)?['address'],
        });
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get today's sales
  Future<List<Sale>> getTodaySales() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return getSalesByDateRange(startDate: startOfDay, endDate: endOfDay);
  }

  /// Generate VietQR code URL
  String generateVietQR({
    required String bankCode,
    required String accountNumber,
    required double amount,
    required String description,
  }) {
    final qrUrl =
        '${AppConstants.vietQRBaseUrl}/$bankCode-$accountNumber-${AppConstants.vietQRTemplate}.jpg'
        '?amount=${amount.toInt()}'
        '&addInfo=${Uri.encodeComponent(description)}';
    return qrUrl;
  }

  /// Calculate cart totals
  Map<String, double> calculateCartTotals(List<CartItem> items) {
    final subtotal = items.fold<double>(0, (sum, item) => sum + item.subtotal);
    final totalDiscount = items.fold<double>(
      0,
      (sum, item) => sum + item.discount,
    );
    final totalCost = items.fold<double>(
      0,
      (sum, item) => sum + (item.quantity * (item.costPrice ?? 0)),
    );
    final profit = subtotal - totalCost;

    return {
      'subtotal': subtotal,
      'totalDiscount': totalDiscount,
      'totalCost': totalCost,
      'profit': profit,
    };
  }
}
