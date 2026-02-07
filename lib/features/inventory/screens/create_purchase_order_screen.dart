import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/purchase_order_item_model.dart';
import '../models/product_model.dart';
import '../models/supplier_model.dart';
import '../providers/inventory_provider.dart';
import '../services/purchase_order_service.dart';

class CreatePurchaseOrderScreen extends ConsumerStatefulWidget {
  const CreatePurchaseOrderScreen({super.key});

  @override
  ConsumerState<CreatePurchaseOrderScreen> createState() =>
      _CreatePurchaseOrderScreenState();
}

class _CreatePurchaseOrderScreenState
    extends ConsumerState<CreatePurchaseOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productSearchController = TextEditingController();
  final _supplierSearchController = TextEditingController();
  final _orderNumberController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  final _shippingCostController = TextEditingController(text: '0');

  final List<PurchaseOrderItem> _selectedItems = [];
  Supplier? _selectedSupplier;
  String? _selectedWarehouse;
  String? _selectedStaffId;
  DateTime _expectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isSplitLine = false;

  final List<String> _warehouses = ['Cửa hàng chính', 'Kho 1', 'Kho 2'];

  @override
  void initState() {
    super.initState();
    _generateOrderNumber();
  }

  @override
  void dispose() {
    _productSearchController.dispose();
    _supplierSearchController.dispose();
    _orderNumberController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    _discountController.dispose();
    _shippingCostController.dispose();
    super.dispose();
  }

  Future<void> _generateOrderNumber() async {
    try {
      final service = PurchaseOrderService();
      final orderNumber = await service.generateOrderNumber();
      setState(() {
        _orderNumberController.text = orderNumber;
      });
    } catch (e) {
      // Use fallback if generation fails
      final now = DateTime.now();
      _orderNumberController.text =
          'PO${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    }
  }

  void _addProduct(Product product) {
    setState(() {
      // Check if product already exists
      final existingIndex = _selectedItems.indexWhere(
        (item) => item.productId == product.id,
      );

      if (existingIndex >= 0) {
        // Increase quantity
        _selectedItems[existingIndex] = _selectedItems[existingIndex].copyWith(
          quantity: _selectedItems[existingIndex].quantity + 1,
        );
      } else {
        // Add new item
        _selectedItems.add(
          PurchaseOrderItem(
            id: '',
            purchaseOrderId: '',
            productId: product.id,
            productName: product.name,
            productUnit: product.unit,
            quantity: 1,
            unitPrice: 0,
            subtotal: 0,
            createdAt: DateTime.now(),
          ),
        );
      }
      _productSearchController.clear();
    });
  }

  void _removeProduct(int index) {
    setState(() {
      _selectedItems.removeAt(index);
    });
  }

  void _updateItemQuantity(int index, double quantity) {
    setState(() {
      _selectedItems[index] = _selectedItems[index].copyWith(
        quantity: quantity,
      );
    });
  }

  void _updateItemPrice(int index, double price) {
    setState(() {
      _selectedItems[index] = _selectedItems[index].copyWith(unitPrice: price);
    });
  }

  double get _totalAmount {
    return _selectedItems.fold(0, (sum, item) => sum + item.subtotal);
  }

  double get _discount {
    return double.tryParse(_discountController.text) ?? 0;
  }

  double get _shippingCost {
    return double.tryParse(_shippingCostController.text) ?? 0;
  }

  double get _finalAmount {
    return _totalAmount - _discount + _shippingCost;
  }

  Future<void> _savePurchaseOrder() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedItems.isEmpty) {
      _showMessage('Vui lòng thêm ít nhất một sản phẩm', isError: true);
      return;
    }

    if (_selectedSupplier == null) {
      _showMessage('Vui lòng chọn nhà cung cấp', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final service = PurchaseOrderService();
      await service.createPurchaseOrder(
        orderNumber: _orderNumberController.text,
        supplierId: _selectedSupplier!.id,
        items: _selectedItems,
        warehouse: _selectedWarehouse,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        receivedById: _selectedStaffId,
      );

      if (mounted) {
        _showMessage('Tạo đơn nhập hàng thành công!');
        Navigator.pop(context, true);
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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Tạo đơn nhập hàng'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _savePurchaseOrder,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Lưu đơn'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column - Products & Payment
            Expanded(flex: 3, child: _buildLeftColumn()),
            const SizedBox(width: 16),
            // Right column - Order Info
            Expanded(flex: 2, child: _buildRightColumn()),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftColumn() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProductSection(),
          const SizedBox(height: 16),
          _buildPaymentSection(),
        ],
      ),
    );
  }

  Widget _buildProductSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Sản phẩm',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Checkbox(
                value: _isSplitLine,
                onChanged: (value) {
                  setState(() {
                    _isSplitLine = value ?? false;
                  });
                },
              ),
              const Text('Tách dòng'),
            ],
          ),
          const SizedBox(height: 12),
          // Product search
          TextField(
            controller: _productSearchController,
            decoration: InputDecoration(
              hintText: 'Tìm theo tên, mã SKU, quét mã Barcode... (F3)',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: TextButton(
                onPressed: () {
                  // Show product selection dialog
                  _showProductSelectionDialog();
                },
                child: const Text('Chọn nhiều'),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              isDense: true,
            ),
            onChanged: (value) {
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          // Product search results
          if (_productSearchController.text.isNotEmpty)
            _buildProductSearchResults(),
          // Selected products list
          if (_selectedItems.isEmpty)
            _buildEmptyProductState()
          else
            _buildSelectedProductsList(),
        ],
      ),
    );
  }

  Widget _buildProductSearchResults() {
    final productsAsync = ref.watch(productsProvider);

    return productsAsync.when(
      data: (products) {
        final filteredProducts = products
            .where((p) {
              final query = _productSearchController.text.toLowerCase();
              return p.name.toLowerCase().contains(query) ||
                  (p.barcode?.toLowerCase().contains(query) ?? false);
            })
            .take(5)
            .toList();

        if (filteredProducts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Không tìm thấy sản phẩm'),
          );
        }

        return Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: filteredProducts.length,
            itemBuilder: (context, index) {
              final product = filteredProducts[index];
              return ListTile(
                title: Text(product.name),
                subtitle: product.barcode != null
                    ? Text('Mã: ${product.barcode}')
                    : null,
                onTap: () => _addProduct(product),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Text('Lỗi: $error'),
    );
  }

  Widget _buildEmptyProductState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Bạn chưa thêm sản phẩm nào',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _showProductSelectionDialog,
            icon: const Icon(Icons.add),
            label: const Text('Thêm sản phẩm'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedProductsList() {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Sản phẩm',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Số lượng',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Đơn giá',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Thành tiền',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(width: 40),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Items
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _selectedItems.length,
          itemBuilder: (context, index) {
            final item = _selectedItems[index];
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'Đơn vị: ${item.productUnit}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      initialValue: item.quantity.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        final qty = double.tryParse(value) ?? 0;
                        _updateItemQuantity(index, qty);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      initialValue: item.unitPrice.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        final price = double.tryParse(value) ?? 0;
                        _updateItemPrice(index, price);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text(
                      currencyFormat.format(item.subtotal),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeProduct(index),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _showProductSelectionDialog,
          icon: const Icon(Icons.add),
          label: const Text('Thêm sản phẩm'),
        ),
      ],
    );
  }

  Widget _buildPaymentSection() {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thanh toán',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildPaymentRow('Tổng tiền', currencyFormat.format(_totalAmount)),
          const SizedBox(height: 8),
          _buildPaymentInputRow(
            'Thêm giảm giá (F6)',
            _discountController,
            currencyFormat.format(_discount),
          ),
          const SizedBox(height: 8),
          _buildPaymentInputRow(
            'Chi phí nhập hàng (F7)',
            _shippingCostController,
            currencyFormat.format(_shippingCost),
          ),
          const Divider(height: 24),
          _buildPaymentRow(
            'Tiền cần trả NCC',
            currencyFormat.format(_finalAmount),
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentInputRow(
    String label,
    TextEditingController controller,
    String displayValue,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        SizedBox(
          width: 150,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {});
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRightColumn() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSupplierSection(),
          const SizedBox(height: 16),
          _buildWarehouseSection(),
          const SizedBox(height: 16),
          _buildAdditionalInfoSection(),
          const SizedBox(height: 16),
          _buildNotesSection(),
        ],
      ),
    );
  }

  Widget _buildSupplierSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nhà cung cấp',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _supplierSearchController,
            decoration: InputDecoration(
              hintText: 'Tìm theo tên, SĐT, mã NCC...(F4)',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              isDense: true,
            ),
            onChanged: (value) {
              setState(() {});
            },
          ),
          if (_supplierSearchController.text.isNotEmpty)
            _buildSupplierSearchResults(),
          if (_selectedSupplier != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedSupplier!.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (_selectedSupplier!.phone != null)
                          Text(
                            'SĐT: ${_selectedSupplier!.phone}',
                            style: const TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _selectedSupplier = null;
                        _supplierSearchController.clear();
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSupplierSearchResults() {
    return FutureBuilder<List<Supplier>>(
      future: PurchaseOrderService().getSuppliers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Text('Lỗi: ${snapshot.error}');
        }

        final suppliers = snapshot.data ?? [];
        final filteredSuppliers = suppliers
            .where((s) {
              final query = _supplierSearchController.text.toLowerCase();
              return s.name.toLowerCase().contains(query) ||
                  (s.code.toLowerCase().contains(query)) ||
                  (s.phone?.toLowerCase().contains(query) ?? false);
            })
            .take(5)
            .toList();

        if (filteredSuppliers.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Không tìm thấy nhà cung cấp'),
          );
        }

        return Container(
          margin: const EdgeInsets.only(top: 8),
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: filteredSuppliers.length,
            itemBuilder: (context, index) {
              final supplier = filteredSuppliers[index];
              return ListTile(
                title: Text(supplier.name),
                subtitle: Text('Mã: ${supplier.code}'),
                onTap: () {
                  setState(() {
                    _selectedSupplier = supplier;
                    _supplierSearchController.clear();
                  });
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildWarehouseSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chi nhánh nhập',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedWarehouse,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              isDense: true,
            ),
            hint: const Text('Cửa hàng chính'),
            items: _warehouses.map((warehouse) {
              return DropdownMenuItem(value: warehouse, child: Text(warehouse));
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedWarehouse = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfoSection() {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thông tin bổ sung',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Staff
          const Text('Nhân viên phụ trách', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            initialValue: _selectedStaffId,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              isDense: true,
            ),
            hint: const Text('Chris'),
            items: const [
              DropdownMenuItem(value: 'staff1', child: Text('Chris')),
              DropdownMenuItem(value: 'staff2', child: Text('John')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedStaffId = value;
              });
            },
          ),
          const SizedBox(height: 16),
          // Expected date
          const Text('Ngày nhập dự kiến', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _expectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() {
                  _expectedDate = picked;
                });
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                isDense: true,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(dateFormat.format(_expectedDate)),
                  const Icon(Icons.calendar_today, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Order number
          const Text('Mã đơn nhập', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          TextFormField(
            controller: _orderNumberController,
            decoration: InputDecoration(
              hintText: 'Nhập mã đơn',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              isDense: true,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Vui lòng nhập mã đơn';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Reference
          const Text('Tham chiếu', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          TextFormField(
            controller: _referenceController,
            decoration: InputDecoration(
              hintText: 'Nhập mã tham chiếu',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ghi chú',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'VD: Chỉ nhận hàng trong giờ hành chính',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  void _showProductSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn sản phẩm'),
        content: SizedBox(
          width: 500,
          height: 400,
          child: Consumer(
            builder: (context, ref, child) {
              final productsAsync = ref.watch(productsProvider);
              return productsAsync.when(
                data: (products) {
                  return ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return ListTile(
                        title: Text(product.name),
                        subtitle: product.barcode != null
                            ? Text('Mã: ${product.barcode}')
                            : null,
                        onTap: () {
                          _addProduct(product);
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Lỗi: $error')),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}
