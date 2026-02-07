import 'package:flutter/material.dart';
import '../../models/supplier_model.dart';
import '../../services/purchase_order_service.dart';

class SuppliersTab extends StatefulWidget {
  const SuppliersTab({super.key});

  @override
  State<SuppliersTab> createState() => _SuppliersTabState();
}

class _SuppliersTabState extends State<SuppliersTab> {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<Supplier>> _suppliersFuture;

  @override
  void initState() {
    super.initState();
    _suppliersFuture = _loadSuppliers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Supplier>> _loadSuppliers() {
    return PurchaseOrderService().getSuppliers(activeOnly: false);
  }

  void _refresh() {
    setState(() {
      _suppliersFuture = _loadSuppliers();
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
      ),
    );
  }

  Future<void> _showCreateSupplierDialog() async {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();
    final taxCodeController = TextEditingController();
    var isSubmitting = false;

    Future<void> submit(StateSetter setDialogState) async {
      if (isSubmitting) return;
      final code = codeController.text.trim();
      final name = nameController.text.trim();
      if (code.isEmpty || name.isEmpty) {
        _showMessage('Vui lòng nhập mã và tên nhà cung cấp', isError: true);
        return;
      }
      setDialogState(() {
        isSubmitting = true;
      });
      try {
        await PurchaseOrderService().createSupplier(
          code: code,
          name: name,
          phone: phoneController.text.trim().isEmpty
              ? null
              : phoneController.text.trim(),
          email: emailController.text.trim().isEmpty
              ? null
              : emailController.text.trim(),
          address: addressController.text.trim().isEmpty
              ? null
              : addressController.text.trim(),
          taxCode: taxCodeController.text.trim().isEmpty
              ? null
              : taxCodeController.text.trim(),
        );
        if (mounted) {
          Navigator.of(context).pop();
          _showMessage('Tạo nhà cung cấp thành công!');
          _refresh();
        }
      } catch (e) {
        _showMessage('Lỗi: ${e.toString()}', isError: true);
      } finally {
        if (mounted) {
          setDialogState(() {
            isSubmitting = false;
          });
        }
      }
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Thêm nhà cung cấp'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTextField(
                      controller: codeController,
                      label: 'Mã nhà cung cấp *',
                      icon: Icons.confirmation_number_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: nameController,
                      label: 'Tên nhà cung cấp *',
                      icon: Icons.storefront_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: phoneController,
                      label: 'Số điện thoại',
                      icon: Icons.phone_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: emailController,
                      label: 'Email',
                      icon: Icons.email_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: addressController,
                      label: 'Địa chỉ',
                      icon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: taxCodeController,
                      label: 'Mã số thuế',
                      icon: Icons.receipt_long_outlined,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton.icon(
                  onPressed: isSubmitting ? null : () => submit(setDialogState),
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildToolbar(),
          Expanded(
            child: FutureBuilder<List<Supplier>>(
              future: _suppliersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Lỗi: ${snapshot.error}'),
                  );
                }

                final suppliers = snapshot.data ?? [];
                final filtered = _filterSuppliers(suppliers);

                if (filtered.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _buildSupplierCard(filtered[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm theo mã, tên, SĐT hoặc email',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Làm mới'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _showCreateSupplierDialog,
                icon: const Icon(Icons.add_business, size: 18),
                label: const Text('Thêm nhà cung cấp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Supplier> _filterSuppliers(List<Supplier> suppliers) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return suppliers;
    }
    return suppliers.where((supplier) {
      final name = supplier.name.toLowerCase();
      final code = supplier.code.toLowerCase();
      final phone = supplier.phone?.toLowerCase() ?? '';
      final email = supplier.email?.toLowerCase() ?? '';
      return name.contains(query) ||
          code.contains(query) ||
          phone.contains(query) ||
          email.contains(query);
    }).toList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Chưa có nhà cung cấp nào',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _showCreateSupplierDialog,
            child: const Text('Thêm nhà cung cấp đầu tiên'),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierCard(Supplier supplier) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue.withValues(alpha: 0.1),
                child: const Icon(Icons.storefront, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supplier.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mã: ${supplier.code}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(supplier.isActive),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _buildInfoRow(Icons.phone_outlined, supplier.phone ?? 'Chưa có'),
              _buildInfoRow(Icons.email_outlined, supplier.email ?? 'Chưa có'),
              _buildInfoRow(
                Icons.location_on_outlined,
                supplier.address ?? 'Chưa có',
              ),
              _buildInfoRow(
                Icons.receipt_long_outlined,
                supplier.taxCode ?? 'Chưa có',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text(
          value,
          style: TextStyle(color: Colors.grey[700]),
        ),
      ],
    );
  }

  Widget _buildStatusChip(bool isActive) {
    final color = isActive ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isActive ? 'Đang hợp tác' : 'Tạm ngưng',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
