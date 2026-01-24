import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer_model.dart';
import '../services/debt_service.dart';

/// Debt service provider
final debtServiceProvider = Provider<DebtService>((ref) {
  return DebtService();
});

/// Customers provider
final customersProvider = FutureProvider<List<Customer>>((ref) async {
  final debtService = ref.watch(debtServiceProvider);
  return await debtService.getCustomers();
});

/// Customer search provider
final customerSearchProvider = FutureProvider.family<List<Customer>, String>((
  ref,
  query,
) async {
  final debtService = ref.watch(debtServiceProvider);
  return await debtService.getCustomers(searchQuery: query);
});

/// Customers with debt provider
final customersWithDebtProvider = FutureProvider<List<Customer>>((ref) async {
  final debtService = ref.watch(debtServiceProvider);
  return await debtService.getCustomersWithDebt();
});
