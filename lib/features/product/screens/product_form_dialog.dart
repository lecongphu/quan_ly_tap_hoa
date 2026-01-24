import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../inventory/models/product_model.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../providers/product_provider.dart';

class ProductFormDialog extends ConsumerStatefulWidget {
  final Product? product; // null for create, non-null for edit

  const ProductFormDialog({super.key, this.product});

  @override
  ConsumerState<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends ConsumerState<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _unitController = TextEditingController();
  final _minStockController = TextEditingController();

  String? _selectedCategoryId;
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _nameController.text = widget.product!.name;
      _barcodeController.text = widget.product!.barcode ?? '';
      _unitController.text = widget.product!.unit;
      _minStockController.text = widget.product!.minStockLevel.toString();
      _selectedCategoryId = widget.product!.categoryId;
      _isActive = widget.product!.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _unitController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      _showMessage('Vui lòng chọn danh mục', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.product == null) {
        // Create new product
        await ref
            .read(productProvider.notifier)
            .createProduct(
              name: _nameController.text.trim(),
              unit: _unitController.text.trim(),
              categoryId: _selectedCategoryId!,
              barcode: _barcodeController.text.trim().isEmpty
                  ? null
                  : _barcodeController.text.trim(),
              minStockLevel: double.tryParse(_minStockController.text) ?? 0,
            );
        if (mounted) {
          _showMessage('Tạo sản phẩm thành công!');
          Navigator.pop(context, true);
        }
      } else {
        // Update existing product
        await ref
            .read(productProvider.notifier)
            .updateProduct(
              productId: widget.product!.id,
              name: _nameController.text.trim(),
              unit: _unitController.text.trim(),
              categoryId: _selectedCategoryId,
              barcode: _barcodeController.text.trim().isEmpty
                  ? null
                  : _barcodeController.text.trim(),
              minStockLevel: double.tryParse(_minStockController.text),
              isActive: _isActive,
            );
        if (mounted) {
          _showMessage('Cập nhật sản phẩm thành công!');
          Navigator.pop(context, true);
        }
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
    final categoriesAsync = ref.watch(categoriesProvider);

    return AlertDialog(
      title: Text(
        widget.product == null ? 'Thêm sản phẩm mới' : 'Sửa sản phẩm',
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Product name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên sản phẩm *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập tên sản phẩm';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Barcode
                TextFormField(
                  controller: _barcodeController,
                  decoration: const InputDecoration(
                    labelText: 'Mã barcode',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Category
                categoriesAsync.when(
                  data: (categories) {
                    return DropdownButtonFormField<String>(
                      value: _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Danh mục *',
                        border: OutlineInputBorder(),
                      ),
                      items: categories.map((category) {
                        return DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategoryId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Vui lòng chọn danh mục';
                        }
                        return null;
                      },
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (error, stack) => Text('Lỗi: $error'),
                ),
                const SizedBox(height: 16),

                // Unit
                TextFormField(
                  controller: _unitController,
                  decoration: const InputDecoration(
                    labelText: 'Đơn vị *',
                    hintText: 'VD: cái, hộp, kg, lít',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập đơn vị';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Min stock level
                TextFormField(
                  controller: _minStockController,
                  decoration: const InputDecoration(
                    labelText: 'Tồn tối thiểu',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final number = double.tryParse(value);
                      if (number == null || number < 0) {
                        return 'Giá trị phải >= 0';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Active status (only for edit)
                if (widget.product != null)
                  CheckboxListTile(
                    title: const Text('Sản phẩm đang hoạt động'),
                    value: _isActive,
                    onChanged: (value) {
                      setState(() {
                        _isActive = value ?? true;
                      });
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSubmit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.product == null ? 'Tạo' : 'Cập nhật'),
        ),
      ],
    );
  }
}
