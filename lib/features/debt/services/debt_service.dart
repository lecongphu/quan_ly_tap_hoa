import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/constants/app_constants.dart';
import '../models/customer_model.dart';

/// Customer and debt management service
class DebtService {
  final SupabaseClient _supabase = SupabaseService.instance.client;

  /// Get all customers
  Future<List<Customer>> getCustomers({
    bool activeOnly = true,
    String? searchQuery,
  }) async {
    try {
      var query = _supabase.from(AppConstants.tableCustomers).select();

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or(
          'name.ilike.%$searchQuery%,phone.ilike.%$searchQuery%',
        );
      }

      final response = await query.order('name');

      return (response as List).map((item) => Customer.fromJson(item)).toList();
    } catch (e) {
      throw Exception('Lỗi khi tải danh sách khách hàng: ${e.toString()}');
    }
  }

  /// Get customer by ID
  Future<Customer?> getCustomerById(String customerId) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableCustomers)
          .select()
          .eq('id', customerId)
          .maybeSingle();

      if (response == null) return null;
      return Customer.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi khi tải khách hàng: ${e.toString()}');
    }
  }

  /// Get customer by phone
  Future<Customer?> getCustomerByPhone(String phone) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableCustomers)
          .select()
          .eq('phone', phone)
          .maybeSingle();

      if (response == null) return null;
      return Customer.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi khi tìm khách hàng: ${e.toString()}');
    }
  }

  /// Check if customer can borrow
  Future<bool> canCustomerBorrow(String customerId, double amount) async {
    try {
      final customer = await getCustomerById(customerId);
      if (customer == null) return false;
      return customer.canBorrow(amount);
    } catch (e) {
      return false;
    }
  }

  /// Add new customer
  Future<Customer> addCustomer({
    required String name,
    String? phone,
    String? address,
    double debtLimit = 0,
  }) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableCustomers)
          .insert({
            'name': name,
            'phone': phone,
            'address': address,
            'debt_limit': debtLimit,
          })
          .select()
          .single();

      return Customer.fromJson(response);
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
    double? debtLimit,
    bool? isActive,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (phone != null) updates['phone'] = phone;
      if (address != null) updates['address'] = address;
      if (debtLimit != null) updates['debt_limit'] = debtLimit;
      if (isActive != null) updates['is_active'] = isActive;

      final response = await _supabase
          .from(AppConstants.tableCustomers)
          .update(updates)
          .eq('id', customerId)
          .select()
          .single();

      return Customer.fromJson(response);
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
      final response = await _supabase
          .from(AppConstants.tableDebtPayments)
          .insert({
            'customer_id': customerId,
            'amount': amount,
            'payment_method': paymentMethod,
            'receipt_number': receiptNumber,
            'notes': notes,
            'created_by': createdBy,
          })
          .select()
          .single();

      return DebtPayment.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi khi ghi nhận thanh toán: ${e.toString()}');
    }
  }

  /// Get customer debt history
  Future<List<DebtPayment>> getCustomerPayments(String customerId) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableDebtPayments)
          .select()
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => DebtPayment.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Lỗi khi tải lịch sử thanh toán: ${e.toString()}');
    }
  }

  /// Get customers with debt
  Future<List<Customer>> getCustomersWithDebt() async {
    try {
      final response = await _supabase
          .from(AppConstants.tableCustomers)
          .select()
          .gt('current_debt', 0)
          .eq('is_active', true)
          .order('current_debt', ascending: false);

      return (response as List).map((item) => Customer.fromJson(item)).toList();
    } catch (e) {
      throw Exception('Lỗi khi tải danh sách công nợ: ${e.toString()}');
    }
  }
}
