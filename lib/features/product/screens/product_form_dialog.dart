import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../inventory/models/product_model.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../providers/product_provider.dart';

class ProductFormDialog extends ConsumerStatefulWidget {
  final Product? product;

  const ProductFormDialog({super.key, this.product});

  @override
  ConsumerState<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends ConsumerState<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _unitController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _minStockController = TextEditingController();

  String? _selectedCategoryId;
  bool _isActive = true;
  bool _isLoading = false;

  bool _isBarcodeLookupLoading = false;
  String? _barcodeLookupMessage;
  bool _isBarcodeLookupError = false;
  int _barcodeLookupRequestId = 0;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _nameController.text = widget.product!.name;
      _barcodeController.text = widget.product!.barcode ?? '';
      _unitController.text = widget.product!.unit;
      _salePriceController.text = widget.product!.salePrice?.toString() ?? '';
      _minStockController.text = widget.product!.minStockLevel.toString();
      _selectedCategoryId = widget.product!.categoryId;
      _isActive = widget.product!.isActive;
    }
  }

  @override
  void dispose() {
    _barcodeLookupRequestId += 1;
    _nameController.dispose();
    _barcodeController.dispose();
    _unitController.dispose();
    _salePriceController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  bool get _supportsBarcodeScanner {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final normalizedBarcode = _normalizeBarcode(_barcodeController.text);
    _barcodeController.text = normalizedBarcode;
    final salePriceText = _salePriceController.text.trim();
    final salePrice = salePriceText.isEmpty
        ? null
        : double.tryParse(salePriceText);

    final duplicateProduct = _findDuplicateBarcodeProduct(normalizedBarcode);
    if (duplicateProduct != null) {
      _showMessage(
        'Mã vạch đã tồn tại ở sản phẩm "${duplicateProduct.name}".',
        isError: true,
      );
      return;
    }

    if (_selectedCategoryId == null) {
      _showMessage('Vui lòng chọn danh mục', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.product == null) {
        await ref
            .read(productProvider.notifier)
            .createProduct(
              name: _nameController.text.trim(),
              unit: _unitController.text.trim(),
              categoryId: _selectedCategoryId!,
              barcode: normalizedBarcode.isEmpty ? null : normalizedBarcode,
              salePrice: salePrice,
              minStockLevel: double.tryParse(_minStockController.text) ?? 0,
            );
        ref.invalidate(productsProvider);
        ref.invalidate(categoriesProvider);
        if (mounted) {
          _showMessage('Tạo sản phẩm thành công!');
          Navigator.pop(context, true);
        }
      } else {
        await ref
            .read(productProvider.notifier)
            .updateProduct(
              productId: widget.product!.id,
              name: _nameController.text.trim(),
              unit: _unitController.text.trim(),
              categoryId: _selectedCategoryId,
              barcode: normalizedBarcode.isEmpty ? null : normalizedBarcode,
              salePrice: salePrice,
              minStockLevel: double.tryParse(_minStockController.text),
              isActive: _isActive,
            );
        ref.invalidate(productsProvider);
        ref.invalidate(categoriesProvider);
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

  Future<void> _lookupProductByBarcode({String? barcode}) async {
    final normalizedBarcode = _normalizeBarcode(
      barcode ?? _barcodeController.text,
    );
    _barcodeController.text = normalizedBarcode;

    if (normalizedBarcode.isEmpty) {
      _setBarcodeLookupStatus(
        message: 'Vui lòng nhập hoặc quét mã vạch.',
        isError: true,
      );
      return;
    }

    final duplicateProduct = _findDuplicateBarcodeProduct(normalizedBarcode);
    if (duplicateProduct != null) {
      _setBarcodeLookupStatus(
        message: 'Mã vạch đã tồn tại ở sản phẩm "${duplicateProduct.name}".',
        isError: true,
      );
      return;
    }

    final requestId = ++_barcodeLookupRequestId;
    setState(() {
      _isBarcodeLookupLoading = true;
      _barcodeLookupMessage = null;
      _isBarcodeLookupError = false;
    });

    final httpClient = HttpClient();
    try {
      final path =
          '/api/v2/product/${Uri.encodeComponent(normalizedBarcode)}.json';
      final uri = Uri.https('world.openfoodfacts.org', path, {
        'fields':
            'product_name,product_name_vi,generic_name,generic_name_vi,quantity,brands,status',
      });

      final request = await httpClient.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Lookup failed with status ${response.statusCode}');
      }

      final payloadString = await response.transform(utf8.decoder).join();
      final payload = jsonDecode(payloadString);
      if (payload is! Map<String, dynamic>) {
        throw Exception('Invalid response format');
      }

      final status = payload['status'] as num? ?? 0;
      final productRaw = payload['product'];
      if (status != 1 || productRaw is! Map) {
        _setBarcodeLookupStatus(
          message: 'Không tìm thấy thông tin hàng hóa cho mã vạch này.',
          isError: true,
          requestId: requestId,
        );
        return;
      }

      final productMap = Map<String, dynamic>.from(productRaw);
      final resolvedName =
          (productMap['product_name_vi'] as String?)?.trim() ??
          (productMap['product_name'] as String?)?.trim() ??
          (productMap['generic_name_vi'] as String?)?.trim() ??
          (productMap['generic_name'] as String?)?.trim() ??
          '';

      if (resolvedName.isEmpty) {
        _setBarcodeLookupStatus(
          message: 'Đã tìm thấy mã vạch nhưng chưa có tên sản phẩm.',
          isError: true,
          requestId: requestId,
        );
        return;
      }

      if (!mounted || requestId != _barcodeLookupRequestId) {
        return;
      }

      final unitText = _unitController.text.trim();
      final suggestedUnit = _suggestUnitFromQuantity(
        (productMap['quantity'] as String?)?.trim(),
      );

      setState(() {
        _nameController.text = resolvedName;
        if ((unitText.isEmpty || unitText == 'sp') && suggestedUnit != null) {
          _unitController.text = suggestedUnit;
        }
      });

      final brands = (productMap['brands'] as String?)?.trim() ?? '';
      final quantity = (productMap['quantity'] as String?)?.trim() ?? '';
      final detailParts = <String>[
        if (brands.isNotEmpty) brands,
        if (quantity.isNotEmpty) quantity,
      ];
      final detailText = detailParts.isEmpty
          ? ''
          : ' (${detailParts.join(' - ')})';

      _setBarcodeLookupStatus(
        message: 'Đã điền thông tin từ mã vạch$detailText.',
        isError: false,
        requestId: requestId,
      );
    } catch (_) {
      _setBarcodeLookupStatus(
        message: 'Không thể tra cứu mã vạch. Vui lòng thử lại.',
        isError: true,
        requestId: requestId,
      );
    } finally {
      httpClient.close(force: true);
      if (mounted && requestId == _barcodeLookupRequestId) {
        setState(() {
          _isBarcodeLookupLoading = false;
        });
      }
    }
  }

  Future<void> _scanAndLookupBarcode() async {
    if (!_supportsBarcodeScanner) {
      _showMessage(
        'Thiết bị này không hỗ trợ quét mã vạch bằng camera.',
        isError: true,
      );
      return;
    }

    final scannedValue = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _BarcodeScannerSheet(),
    );

    if (!mounted || scannedValue == null) return;

    final normalized = _normalizeBarcode(scannedValue);
    if (normalized.isEmpty) return;
    await _lookupProductByBarcode(barcode: normalized);
  }

  Product? _findDuplicateBarcodeProduct(String barcode) {
    if (barcode.isEmpty) return null;
    final normalizedBarcode = _normalizeBarcode(barcode);
    final currentProductId = widget.product?.id;
    final products = ref.read(productProvider).products;

    for (final product in products) {
      final existingBarcode = _normalizeBarcode(product.barcode ?? '');
      if (existingBarcode.isEmpty) continue;
      if (existingBarcode == normalizedBarcode &&
          product.id != currentProductId) {
        return product;
      }
    }
    return null;
  }

  String _normalizeBarcode(String barcode) {
    return barcode.replaceAll(RegExp(r'\s+'), '').trim();
  }

  String? _suggestUnitFromQuantity(String? quantity) {
    final value = quantity?.toLowerCase().trim();
    if (value == null || value.isEmpty) return null;
    if (RegExp(r'(ml|\bl\b|lit)').hasMatch(value)) return 'chai';
    if (RegExp(r'(kg|\bg\b|gram)').hasMatch(value)) return 'goi';
    if (RegExp(r'(lon|can)').hasMatch(value)) return 'lon';
    if (RegExp(r'(chai|bottle)').hasMatch(value)) return 'chai';
    return null;
  }

  void _setBarcodeLookupStatus({
    required String message,
    required bool isError,
    int? requestId,
  }) {
    if (!mounted) return;
    if (requestId != null && requestId != _barcodeLookupRequestId) return;
    setState(() {
      _barcodeLookupMessage = message;
      _isBarcodeLookupError = isError;
    });
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

    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 40,
        vertical: 24,
      ),
      title: Text(
        widget.product == null ? 'Thêm sản phẩm mới' : 'Sửa sản phẩm',
      ),
      content: SizedBox(
        width: isMobile ? double.infinity : 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                TextFormField(
                  controller: _barcodeController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _lookupProductByBarcode(),
                  decoration: const InputDecoration(
                    labelText: 'Mã barcode',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isBarcodeLookupLoading
                            ? null
                            : () => _lookupProductByBarcode(),
                        icon: _isBarcodeLookupLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.search_rounded),
                        label: Text(
                          _isBarcodeLookupLoading
                              ? 'Đang tra cứu'
                              : 'Tra cứu mã vạch',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Quét mã vạch',
                      onPressed: _isBarcodeLookupLoading
                          ? null
                          : _scanAndLookupBarcode,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                    ),
                  ],
                ),
                if (_barcodeLookupMessage != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _barcodeLookupMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: _isBarcodeLookupError
                            ? Theme.of(context).colorScheme.error
                            : const Color(0xFF0F766E),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                categoriesAsync.when(
                  data: (categories) {
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedCategoryId,
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
                TextFormField(
                  controller: _salePriceController,
                  decoration: const InputDecoration(
                    labelText: 'Giá bán',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      if (widget.product == null) {
                        return 'Vui lòng nhập giá bán';
                      }
                      return null;
                    }
                    final number = double.tryParse(value.trim());
                    if (number == null || number < 0) {
                      return 'Giá bán phải >= 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
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

class _BarcodeScannerSheet extends StatefulWidget {
  const _BarcodeScannerSheet();

  @override
  State<_BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<_BarcodeScannerSheet> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  bool _didDetect = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_didDetect) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value == null || value.isEmpty) {
        continue;
      }

      _didDetect = true;
      _controller.stop();
      if (mounted) {
        Navigator.of(context).pop(value);
      }
      break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return SizedBox(
      height: size.height * 0.82,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Quét mã vạch',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Đèn',
                  onPressed: _controller.toggleTorch,
                  icon: const Icon(Icons.flashlight_on_rounded),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Text(
              'Đặt mã vạch vào giữa khung để quét.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
