import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../providers/inventory_provider.dart';
import '../models/product_model.dart';

class StockInScreen extends ConsumerStatefulWidget {
  const StockInScreen({super.key});

  @override
  ConsumerState<StockInScreen> createState() => _StockInScreenState();
}

class _StockInScreenState extends ConsumerState<StockInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _quantityController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _batchNumberController = TextEditingController();

  Product? _selectedProduct;
  DateTime? _expiryDate;
  DateTime _receivedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    _costPriceController.dispose();
    _batchNumberController.dispose();
    super.dispose();
  }

  Future<void> _selectExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (picked != null) {
      setState(() {
        _expiryDate = picked;
      });
    }
  }

  Future<void> _selectReceivedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _receivedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _receivedDate = picked;
      });
    }
  }

  Future<void> _handleStockIn() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProduct == null) {
      _showMessage('Vui lòng chọn sản phẩm', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final inventoryService = ref.read(inventoryServiceProvider);

      await inventoryService.stockIn(
        productId: _selectedProduct!.id,
        quantity: double.parse(_quantityController.text),
        costPrice: double.parse(_costPriceController.text),
        batchNumber: _batchNumberController.text.isEmpty
            ? null
            : _batchNumberController.text,
        expiryDate: _expiryDate,
        receivedDate: _receivedDate,
      );

      if (mounted) {
        _showMessage('Nhập kho thành công!');
        _resetForm();
        ref.invalidate(productsProvider);
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

  void _resetForm() {
    setState(() {
      _selectedProduct = null;
      _expiryDate = null;
      _receivedDate = DateTime.now();
    });
    _searchController.clear();
    _quantityController.clear();
    _costPriceController.clear();
    _batchNumberController.clear();
    _formKey.currentState?.reset();
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
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Nhập kho')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16.w),
          children: [
            // Product selection
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chọn sản phẩm',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12.h),

                    // Product search
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Tìm sản phẩm...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {});
                      },
                    ),

                    SizedBox(height: 12.h),

                    // Product list
                    if (_searchController.text.isNotEmpty) _buildProductList(),

                    // Selected product display
                    if (_selectedProduct != null) ...[
                      SizedBox(height: 12.h),
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedProduct!.name,
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_selectedProduct!.barcode != null)
                                    Text(
                                      'Mã: ${_selectedProduct!.barcode}',
                                      style: TextStyle(fontSize: 12.sp),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _selectedProduct = null;
                                  _searchController.clear();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            SizedBox(height: 16.h),

            // Stock in details
            if (_selectedProduct != null) ...[
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thông tin nhập kho',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Quantity
                      TextFormField(
                        controller: _quantityController,
                        decoration: InputDecoration(
                          labelText: 'Số lượng *',
                          suffixText: _selectedProduct!.unit,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập số lượng';
                          }
                          if (double.tryParse(value) == null ||
                              double.parse(value) <= 0) {
                            return 'Số lượng phải lớn hơn 0';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 16.h),

                      // Cost price
                      TextFormField(
                        controller: _costPriceController,
                        decoration: InputDecoration(
                          labelText: 'Giá vốn *',
                          suffixText: '₫',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập giá vốn';
                          }
                          if (double.tryParse(value) == null ||
                              double.parse(value) <= 0) {
                            return 'Giá vốn phải lớn hơn 0';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 16.h),

                      // Batch number
                      TextFormField(
                        controller: _batchNumberController,
                        decoration: InputDecoration(
                          labelText: 'Số lô (tùy chọn)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                      ),

                      SizedBox(height: 16.h),

                      // Received date
                      InkWell(
                        onTap: _selectReceivedDate,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Ngày nhập',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(dateFormat.format(_receivedDate)),
                              const Icon(Icons.calendar_today),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 16.h),

                      // Expiry date
                      InkWell(
                        onTap: _selectExpiryDate,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Hạn sử dụng (tùy chọn)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _expiryDate != null
                                    ? dateFormat.format(_expiryDate!)
                                    : 'Chọn ngày hết hạn',
                                style: TextStyle(
                                  color: _expiryDate != null
                                      ? Colors.black
                                      : Colors.grey,
                                ),
                              ),
                              const Icon(Icons.calendar_today),
                            ],
                          ),
                        ),
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
                  onPressed: _isLoading ? null : _handleStockIn,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Nhập kho'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProductList() {
    final productsAsync = ref.watch(productsProvider);

    return productsAsync.when(
      data: (products) {
        final filteredProducts = products.where((p) {
          return p.name.toLowerCase().contains(
                _searchController.text.toLowerCase(),
              ) ||
              (p.barcode?.contains(_searchController.text) ?? false);
        }).toList();

        if (filteredProducts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Không tìm thấy sản phẩm'),
          );
        }

        return Container(
          constraints: BoxConstraints(maxHeight: 200.h),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8.r),
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
                onTap: () {
                  setState(() {
                    _selectedProduct = product;
                    _searchController.clear();
                  });
                },
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Text('Lỗi: $error'),
    );
  }
}
