import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../models/customer_model.dart';

/// Customer and debt management service
class DebtService {
  String _sanitizeFileName(String fileName) {
    final sanitized = fileName.trim().replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]'),
      '_',
    );
    return sanitized.isEmpty ? 'image.jpg' : sanitized;
  }

  String _buildCustomerImagePath(String customerId, String fileName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$customerId/$timestamp-${_sanitizeFileName(fileName)}';
  }

  String _fileNameWithoutExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0) return fileName;
    return fileName.substring(0, dotIndex);
  }

  int _activeImageCountFromData(dynamic data) {
    return (data as List<dynamic>).length;
  }

  Future<void> _ensureCustomerImageLimit(String customerId) async {
    final supabase = SupabaseService.client;
    final existing = await supabase
        .from(AppConstants.tableCustomerImages)
        .select('id')
        .eq('customer_id', customerId)
        .eq('is_active', true);
    final count = _activeImageCountFromData(existing);
    if (count >= AppConstants.maxCustomerImages) {
      throw Exception(
        'Khach hang da dat gioi han ${AppConstants.maxCustomerImages} anh.',
      );
    }
  }

  ({Uint8List bytes, String fileName, String contentType})
  _prepareImageForUpload({
    required Uint8List sourceBytes,
    required String sourceFileName,
    String? sourceContentType,
  }) {
    final fallbackContentType = sourceContentType ?? 'image/jpeg';

    try {
      final decoded = img.decodeImage(sourceBytes);
      if (decoded == null) {
        return (
          bytes: sourceBytes,
          fileName: sourceFileName,
          contentType: fallbackContentType,
        );
      }

      final oriented = img.bakeOrientation(decoded);
      final resized = oriented.width > AppConstants.customerImageMaxWidth
          ? img.copyResize(oriented, width: AppConstants.customerImageMaxWidth)
          : oriented;
      final jpgBytes = img.encodeJpg(
        resized,
        quality: AppConstants.customerImageJpegQuality,
      );
      final compressedName =
          '${_fileNameWithoutExtension(sourceFileName)}_compressed.jpg';
      return (
        bytes: Uint8List.fromList(jpgBytes),
        fileName: compressedName,
        contentType: 'image/jpeg',
      );
    } catch (_) {
      return (
        bytes: sourceBytes,
        fileName: sourceFileName,
        contentType: fallbackContentType,
      );
    }
  }

  /// Get all customers
  Future<List<Customer>> getCustomers({
    bool activeOnly = true,
    String? searchQuery,
  }) async {
    try {
      final supabase = SupabaseService.client;
      var query = supabase.from('customers').select('*');

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final data = await query.order('created_at', ascending: false);
      var customers = (data as List<dynamic>)
          .map((item) => Customer.fromJson(item as Map<String, dynamic>))
          .toList();

      if (searchQuery != null && searchQuery.isNotEmpty) {
        final queryLower = searchQuery.toLowerCase();
        customers = customers.where((c) {
          return c.name.toLowerCase().contains(queryLower) ||
              (c.phone?.toLowerCase().contains(queryLower) ?? false);
        }).toList();
      }

      return customers;
    } catch (e) {
      throw Exception('Lỗi khi tải danh sách khách hàng: ${e.toString()}');
    }
  }

  /// Get customer by ID
  Future<Customer?> getCustomerById(String customerId) async {
    try {
      final supabase = SupabaseService.client;
      final data = await supabase
          .from('customers')
          .select('*')
          .eq('id', customerId)
          .single();
      return Customer.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  /// Get customer by phone
  Future<Customer?> getCustomerByPhone(String phone) async {
    try {
      final supabase = SupabaseService.client;
      final data = await supabase
          .from('customers')
          .select('*')
          .eq('phone', phone)
          .maybeSingle();
      if (data == null) return null;
      return Customer.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  /// Add new customer
  Future<Customer> addCustomer({
    required String name,
    String? phone,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final supabase = SupabaseService.client;
      final data = await supabase
          .from('customers')
          .insert({
            'name': name,
            'phone': phone,
            'address': address,
            'latitude': latitude,
            'longitude': longitude,
          })
          .select('*')
          .single();
      return Customer.fromJson(data);
    } catch (e) {
      throw Exception('Lỗi khi thêm khách hàng: ${e.toString()}');
    }
  }

  /// Update customer
  Future<Customer> updateCustomer({
    required String customerId,
    String? name,
    String? phone,
    String? address,
    double? latitude,
    double? longitude,
    bool updateLatitude = false,
    bool updateLongitude = false,
    bool? isActive,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (phone != null) updates['phone'] = phone;
      if (address != null) updates['address'] = address;
      if (updateLatitude) updates['latitude'] = latitude;
      if (updateLongitude) updates['longitude'] = longitude;
      if (isActive != null) updates['is_active'] = isActive;

      final supabase = SupabaseService.client;
      final data = await supabase
          .from('customers')
          .update(updates)
          .eq('id', customerId)
          .select('*')
          .single();
      return Customer.fromJson(data);
    } catch (e) {
      throw Exception('Lỗi khi cập nhật khách hàng: ${e.toString()}');
    }
  }

  /// Record debt payment
  Future<DebtPayment> recordPayment({
    required String customerId,
    required double amount,
    required String paymentMethod,
    String? receiptNumber,
    String? notes,
    String? createdBy,
  }) async {
    try {
      final supabase = SupabaseService.client;
      final data = await supabase
          .from('debt_payments')
          .insert({
            'customer_id': customerId,
            'amount': amount,
            'payment_method': paymentMethod,
            'notes': notes,
          })
          .select('*')
          .single();
      return DebtPayment.fromJson(data);
    } catch (e) {
      throw Exception('Lỗi khi ghi nhận thanh toán: ${e.toString()}');
    }
  }

  /// Get customer debt history
  Future<List<DebtPayment>> getCustomerPayments(String customerId) async {
    try {
      final supabase = SupabaseService.client;
      final data = await supabase
          .from('debt_payments')
          .select('*')
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);
      return (data as List<dynamic>)
          .map((item) => DebtPayment.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Lỗi khi tải lịch sử thanh toán: ${e.toString()}');
    }
  }

  /// Get customers with debt
  Future<List<Customer>> getCustomersWithDebt() async {
    try {
      final supabase = SupabaseService.client;
      final data = await supabase
          .from('customers')
          .select('*')
          .gt('current_debt', 0)
          .order('created_at', ascending: false);
      return (data as List<dynamic>)
          .map((item) => Customer.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Lỗi khi tải danh sách công nợ: ${e.toString()}');
    }
  }

  /// Soft delete customer (hide from active list).
  Future<void> deleteCustomer(String customerId) async {
    try {
      final supabase = SupabaseService.client;
      final updated = await supabase
          .from('customers')
          .update({'is_active': false})
          .eq('id', customerId)
          .select('id')
          .maybeSingle();

      if (updated != null) return;

      final existing = await supabase
          .from('customers')
          .select('id')
          .eq('id', customerId)
          .maybeSingle();

      if (existing == null) return;
      throw Exception('Không có quyền ẩn khách hàng.');
    } catch (e) {
      throw Exception('Lỗi khi ẩn khách hàng: ${e.toString()}');
    }
  }

  /// Get customer images
  Future<List<CustomerImage>> getCustomerImages(
    String customerId, {
    bool activeOnly = true,
  }) async {
    try {
      final supabase = SupabaseService.client;
      var query = supabase
          .from(AppConstants.tableCustomerImages)
          .select('*')
          .eq('customer_id', customerId);

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final data = await query.order('created_at', ascending: false);
      return (data as List<dynamic>)
          .map((item) => CustomerImage.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Loi khi tai anh khach hang: ${e.toString()}');
    }
  }

  /// Upload customer image (storage + metadata row)
  Future<CustomerImage> uploadCustomerImage({
    required String customerId,
    required Uint8List bytes,
    required String fileName,
    String? contentType,
    String? note,
  }) async {
    final supabase = SupabaseService.client;
    final prepared = _prepareImageForUpload(
      sourceBytes: bytes,
      sourceFileName: fileName,
      sourceContentType: contentType,
    );
    final imagePath = _buildCustomerImagePath(customerId, prepared.fileName);
    final bucket = AppConstants.bucketCustomerImages;

    try {
      await _ensureCustomerImageLimit(customerId);

      await supabase.storage
          .from(bucket)
          .uploadBinary(
            imagePath,
            prepared.bytes,
            fileOptions: FileOptions(
              contentType: prepared.contentType,
              upsert: false,
            ),
          );

      final inserted = await supabase
          .from(AppConstants.tableCustomerImages)
          .insert({
            'customer_id': customerId,
            'image_path': imagePath,
            'note': note,
            'created_by': supabase.auth.currentUser?.id,
          })
          .select('*')
          .single();

      return CustomerImage.fromJson(inserted);
    } catch (e) {
      try {
        await supabase.storage.from(bucket).remove([imagePath]);
      } catch (_) {}
      throw Exception('Loi khi tai anh len: ${e.toString()}');
    }
  }

  /// Resolve public URL from storage path
  String getCustomerImagePublicUrl(String imagePath) {
    return SupabaseService.client.storage
        .from(AppConstants.bucketCustomerImages)
        .getPublicUrl(imagePath);
  }

  /// Set or clear customer avatar by storage path
  Future<void> setCustomerAvatar({
    required String customerId,
    String? imagePath,
  }) async {
    try {
      final supabase = SupabaseService.client;
      if (imagePath != null && imagePath.isNotEmpty) {
        final existing = await supabase
            .from(AppConstants.tableCustomerImages)
            .select('id')
            .eq('customer_id', customerId)
            .eq('image_path', imagePath)
            .eq('is_active', true)
            .maybeSingle();
        if (existing == null) {
          throw Exception('Anh khong thuoc khach hang nay.');
        }
      }
      await supabase
          .from(AppConstants.tableCustomers)
          .update({'avatar_image_path': imagePath})
          .eq('id', customerId);
    } catch (e) {
      throw Exception('Loi khi cap nhat anh dai dien: ${e.toString()}');
    }
  }

  /// Delete customer image (storage + metadata row)
  Future<void> deleteCustomerImage(String imageId) async {
    try {
      final supabase = SupabaseService.client;
      final data = await supabase
          .from(AppConstants.tableCustomerImages)
          .select('id, image_path, customer_id')
          .eq('id', imageId)
          .maybeSingle();

      if (data == null) return;

      final imagePath = data['image_path'] as String?;
      final customerId = data['customer_id'] as String?;
      if (imagePath != null && imagePath.isNotEmpty) {
        if (customerId != null && customerId.isNotEmpty) {
          await supabase
              .from(AppConstants.tableCustomers)
              .update({'avatar_image_path': null})
              .eq('id', customerId)
              .eq('avatar_image_path', imagePath);
        }
        await supabase.storage.from(AppConstants.bucketCustomerImages).remove([
          imagePath,
        ]);
      }

      await supabase
          .from(AppConstants.tableCustomerImages)
          .delete()
          .eq('id', imageId);
    } catch (e) {
      throw Exception('Loi khi xoa anh khach hang: ${e.toString()}');
    }
  }

  /// Update debt payment
  Future<DebtPayment> updatePayment({
    required String paymentId,
    double? amount,
    String? paymentMethod,
    String? notes,
  }) async {
    try {
      final supabase = SupabaseService.client;
      final data = await supabase.rpc(
        'update_debt_payment',
        params: {
          'p_payment_id': paymentId,
          'p_amount': amount,
          'p_payment_method': paymentMethod,
          'p_notes': notes,
        },
      );

      return DebtPayment.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      throw Exception('Loi khi cap nhat thanh toan: ${e.toString()}');
    }
  }

  /// Delete debt payment
  Future<void> deletePayment(String paymentId) async {
    try {
      final supabase = SupabaseService.client;
      await supabase.rpc(
        'delete_debt_payment',
        params: {'p_payment_id': paymentId},
      );
    } catch (e) {
      throw Exception('Loi khi xoa thanh toan: ${e.toString()}');
    }
  }

  /// Get customer history (sales + payments)
  Future<({List<CustomerSale> sales, List<DebtPayment> payments})>
  getCustomerHistory(String customerId, {int? year}) async {
    try {
      final supabase = SupabaseService.client;

      var salesQuery = supabase
          .from('sales')
          .select(
            'id, invoice_number, total_amount, discount_amount, final_amount, payment_method, payment_status, created_at, due_date',
          )
          .eq('customer_id', customerId);

      var paymentsQuery = supabase
          .from('debt_payments')
          .select('id, amount, payment_method, notes, created_at')
          .eq('customer_id', customerId);

      if (year != null) {
        final start = DateTime(year, 1, 1);
        final end = DateTime(year + 1, 1, 1);
        salesQuery = salesQuery
            .gte('created_at', start.toIso8601String())
            .lt('created_at', end.toIso8601String());
        paymentsQuery = paymentsQuery
            .gte('created_at', start.toIso8601String())
            .lt('created_at', end.toIso8601String());
      }

      final salesData = await salesQuery.order('created_at', ascending: false);
      final paymentsData = await paymentsQuery.order(
        'created_at',
        ascending: false,
      );

      final sales = (salesData as List<dynamic>)
          .map((item) => CustomerSale.fromJson(item as Map<String, dynamic>))
          .toList();
      final payments = (paymentsData as List<dynamic>)
          .map((item) => DebtPayment.fromJson(item as Map<String, dynamic>))
          .toList();

      return (sales: sales, payments: payments);
    } catch (e) {
      throw Exception('Loi khi tai lich su khach hang: ${e.toString()}');
    }
  }

  /// Get debt lines for customer
  Future<List<DebtLine>> getDebtLines(String customerId, {int? year}) async {
    try {
      final supabase = SupabaseService.client;
      var query = supabase
          .from('sales')
          .select(
            'id, invoice_number, created_at, due_date, final_amount, notes, payment_method, sale_items(quantity, unit_price, subtotal, product:products(name, unit))',
          )
          .eq('customer_id', customerId)
          .eq('payment_method', 'debt');

      if (year != null) {
        final start = DateTime(year, 1, 1);
        final end = DateTime(year + 1, 1, 1);
        query = query
            .gte('created_at', start.toIso8601String())
            .lt('created_at', end.toIso8601String());
      }

      final data = await query.order('created_at', ascending: false);

      return (data as List<dynamic>).map((item) {
        final sale = Map<String, dynamic>.from(item as Map);
        final items = (sale['sale_items'] as List<dynamic>? ?? []).map((
          saleItem,
        ) {
          final itemMap = Map<String, dynamic>.from(saleItem as Map);
          return {
            'quantity': itemMap['quantity'],
            'unit_price': itemMap['unit_price'],
            'subtotal': itemMap['subtotal'],
            'product_name': (itemMap['product'] as Map?)?['name'] ?? '',
            'unit': (itemMap['product'] as Map?)?['unit'] ?? '',
          };
        }).toList();

        return DebtLine.fromJson({
          'id': sale['id'],
          'invoice_number': sale['invoice_number'],
          'created_at': sale['created_at'],
          'due_date': sale['due_date'],
          'final_amount': sale['final_amount'],
          'notes': sale['notes'],
          'items': items,
        });
      }).toList();
    } catch (e) {
      throw Exception('Loi khi tai dong no: ${e.toString()}');
    }
  }

  /// Get debt lines with duplicate purchase dates for customer
  Future<List<DebtLine>> getDuplicateDebtLines(
    String customerId, {
    int? year,
  }) async {
    try {
      final supabase = SupabaseService.client;
      final data = await supabase.rpc(
        'get_duplicate_debt_lines',
        params: {'p_customer_id': customerId, 'p_year': year},
      );

      return (data as List<dynamic>).map((item) {
        return DebtLine.fromJson(Map<String, dynamic>.from(item as Map));
      }).toList();
    } catch (e) {
      throw Exception('Loi khi tai dong no trung ngay: ${e.toString()}');
    }
  }

  /// Create debt line
  Future<DebtLine> createDebtLine({
    required String customerId,
    required double amount,
    String? purchaseDate,
    String? dueDate,
    String? notes,
  }) async {
    try {
      final supabase = SupabaseService.client;
      final createdAt = purchaseDate != null
          ? DateTime.parse(purchaseDate)
          : null;
      final data = await supabase
          .from('sales')
          .insert({
            'customer_id': customerId,
            'total_amount': amount,
            'discount_amount': 0,
            'final_amount': amount,
            'payment_method': 'debt',
            'payment_status': 'unpaid',
            'due_date': dueDate,
            'notes': notes,
            if (createdAt != null) 'created_at': createdAt.toIso8601String(),
            'created_by': supabase.auth.currentUser?.id,
          })
          .select('*')
          .single();

      return DebtLine.fromJson(data);
    } catch (e) {
      throw Exception('Loi khi them dong no: ${e.toString()}');
    }
  }

  /// Update debt line
  Future<DebtLine> updateDebtLine({
    required String debtLineId,
    double? amount,
    String? purchaseDate,
    String? dueDate,
    String? notes,
  }) async {
    try {
      final supabase = SupabaseService.client;
      final data = await supabase.rpc(
        'update_debt_line',
        params: {
          'p_sale_id': debtLineId,
          'p_amount': amount,
          'p_purchase_date': purchaseDate,
          'p_due_date': dueDate,
          'p_notes': notes,
        },
      );
      return DebtLine.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      throw Exception('Loi khi cap nhat dong no: ${e.toString()}');
    }
  }

  /// Delete debt line
  Future<void> deleteDebtLine(String debtLineId) async {
    try {
      final supabase = SupabaseService.client;
      await supabase.rpc('delete_debt_line', params: {'p_sale_id': debtLineId});
    } catch (e) {
      throw Exception('Loi khi xoa dong no: ${e.toString()}');
    }
  }
}
