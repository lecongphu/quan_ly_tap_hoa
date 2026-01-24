import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/product_model.dart';

/// Service for handling Excel import/export operations
class ExcelService {
  /// Export products to Excel file
  Future<String?> exportStockToExcel(List<Product> products) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Tồn kho'];

      // Header row
      final headers = [
        'STT',
        'Mã sản phẩm',
        'Tên sản phẩm',
        'Barcode',
        'Danh mục',
        'Đơn vị',
        'Tồn kho',
        'Tồn tối thiểu',
        'Giá vốn TB',
        'Ngày hết hạn gần nhất',
        'Trạng thái',
      ];

      // Add headers
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..value = TextCellValue(headers[i])
          ..cellStyle = CellStyle(
            bold: true,
            backgroundColorHex: ExcelColor.fromHexString('#4472C4'),
            fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
          );
      }

      // Add data rows
      final dateFormat = DateFormat('dd/MM/yyyy');
      for (int i = 0; i < products.length; i++) {
        final product = products[i];
        final row = i + 1;

        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value = IntCellValue(
          i + 1,
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
            .value = TextCellValue(
          product.id,
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
            .value = TextCellValue(
          product.name,
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
            .value = TextCellValue(
          product.barcode ?? '',
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
            .value = TextCellValue(
          product.categoryName ?? '',
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
            .value = TextCellValue(
          product.unit,
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
            .value = DoubleCellValue(
          product.currentStock ?? 0,
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
            .value = DoubleCellValue(
          product.minStockLevel,
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
            .value = DoubleCellValue(
          product.avgCostPrice ?? 0,
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row))
            .value = TextCellValue(
          product.nearestExpiryDate != null
              ? dateFormat.format(product.nearestExpiryDate!)
              : '',
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row))
            .value = TextCellValue(
          _getStockStatus(product),
        );
      }

      // Auto-fit columns
      for (int i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(i, 15);
      }
      sheet.setColumnWidth(2, 30); // Product name column wider

      // Delete default sheet
      excel.delete('Sheet1');

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${directory.path}/ton_kho_$timestamp.xlsx';

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);
        return filePath;
      }
      return null;
    } catch (e) {
      throw Exception('Lỗi khi xuất file Excel: ${e.toString()}');
    }
  }

  /// Export to user-selected location
  Future<String?> exportStockToExcelWithPicker(List<Product> products) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Tồn kho'];

      // Header row
      final headers = [
        'STT',
        'Mã sản phẩm',
        'Tên sản phẩm',
        'Barcode',
        'Danh mục',
        'Đơn vị',
        'Tồn kho',
        'Tồn tối thiểu',
        'Giá vốn TB',
        'Ngày hết hạn gần nhất',
        'Trạng thái',
      ];

      // Add headers with styling
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..value = TextCellValue(headers[i])
          ..cellStyle = CellStyle(
            bold: true,
            backgroundColorHex: ExcelColor.fromHexString('#4472C4'),
            fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
          );
      }

      // Add data rows
      final dateFormat = DateFormat('dd/MM/yyyy');
      for (int i = 0; i < products.length; i++) {
        final product = products[i];
        final row = i + 1;

        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value = IntCellValue(
          i + 1,
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
            .value = TextCellValue(
          product.id,
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
            .value = TextCellValue(
          product.name,
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
            .value = TextCellValue(
          product.barcode ?? '',
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
            .value = TextCellValue(
          product.categoryName ?? '',
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
            .value = TextCellValue(
          product.unit,
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
            .value = DoubleCellValue(
          product.currentStock ?? 0,
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
            .value = DoubleCellValue(
          product.minStockLevel,
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
            .value = DoubleCellValue(
          product.avgCostPrice ?? 0,
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row))
            .value = TextCellValue(
          product.nearestExpiryDate != null
              ? dateFormat.format(product.nearestExpiryDate!)
              : '',
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row))
            .value = TextCellValue(
          _getStockStatus(product),
        );
      }

      // Set column widths
      for (int i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(i, 15);
      }
      sheet.setColumnWidth(2, 30);

      excel.delete('Sheet1');

      // Let user choose save location
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Lưu file Excel',
        fileName: 'ton_kho_$timestamp.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null) {
        final fileBytes = excel.save();
        if (fileBytes != null) {
          final file = File(result);
          await file.writeAsBytes(fileBytes);
          return result;
        }
      }
      return null;
    } catch (e) {
      throw Exception('Lỗi khi xuất file Excel: ${e.toString()}');
    }
  }

  /// Import products from Excel file
  Future<List<Map<String, dynamic>>> importStockFromExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        dialogTitle: 'Chọn file Excel để nhập',
      );

      if (result == null || result.files.isEmpty) {
        return [];
      }

      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      final List<Map<String, dynamic>> importedData = [];

      // Get first sheet
      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName];

      if (sheet == null || sheet.rows.isEmpty) {
        throw Exception('File Excel trống hoặc không hợp lệ');
      }

      // Skip header row (first row)
      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        if (row.isEmpty) continue;

        // Parse row data based on expected columns
        final data = <String, dynamic>{
          'row_number': i + 1,
          'name': _getCellValue(row, 2), // Column C - Tên sản phẩm
          'barcode': _getCellValue(row, 3), // Column D - Barcode
          'category': _getCellValue(row, 4), // Column E - Danh mục
          'unit': _getCellValue(row, 5), // Column F - Đơn vị
          'quantity': _getNumericCellValue(row, 6), // Column G - Tồn kho
          'min_stock': _getNumericCellValue(row, 7), // Column H - Tồn tối thiểu
          'cost_price': _getNumericCellValue(row, 8), // Column I - Giá vốn
        };

        // Only add if has product name
        if (data['name'] != null && data['name'].toString().isNotEmpty) {
          importedData.add(data);
        }
      }

      return importedData;
    } catch (e) {
      throw Exception('Lỗi khi đọc file Excel: ${e.toString()}');
    }
  }

  String _getCellValue(List<Data?> row, int index) {
    if (index >= row.length || row[index] == null) return '';
    final value = row[index]!.value;
    if (value == null) return '';
    return value.toString();
  }

  double _getNumericCellValue(List<Data?> row, int index) {
    if (index >= row.length || row[index] == null) return 0;
    final value = row[index]!.value;
    if (value == null) return 0;
    if (value is DoubleCellValue) return value.value;
    if (value is IntCellValue) return value.value.toDouble();
    final parsed = double.tryParse(value.toString());
    return parsed ?? 0;
  }

  String _getStockStatus(Product product) {
    if (product.isOutOfStock) return 'Hết hàng';
    if (product.isLowStock) return 'Sắp hết';
    return 'Còn hàng';
  }

  /// Download template Excel file
  Future<String?> downloadTemplate() async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Mẫu nhập kho'];

      // Header row
      final headers = [
        'STT',
        'Mã sản phẩm (để trống nếu tạo mới)',
        'Tên sản phẩm (*)',
        'Barcode',
        'Danh mục',
        'Đơn vị (*)',
        'Số lượng nhập',
        'Tồn tối thiểu',
        'Giá vốn',
      ];

      // Add headers
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..value = TextCellValue(headers[i])
          ..cellStyle = CellStyle(
            bold: true,
            backgroundColorHex: ExcelColor.fromHexString('#4472C4'),
            fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
          );
      }

      // Example row
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
          .value = IntCellValue(
        1,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 1))
          .value = TextCellValue(
        'Coca Cola 330ml',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 1))
          .value = TextCellValue(
        '8934588013010',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 1))
          .value = TextCellValue(
        'Nước giải khát',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 1))
          .value = TextCellValue(
        'lon',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 1))
          .value = IntCellValue(
        100,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 1))
          .value = IntCellValue(
        24,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 1))
          .value = IntCellValue(
        7500,
      );

      // Set column widths
      for (int i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(i, 20);
      }
      sheet.setColumnWidth(1, 30);
      sheet.setColumnWidth(2, 25);

      excel.delete('Sheet1');

      // Save to user location
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Lưu file mẫu Excel',
        fileName: 'mau_nhap_kho.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null) {
        final fileBytes = excel.save();
        if (fileBytes != null) {
          final file = File(result);
          await file.writeAsBytes(fileBytes);
          return result;
        }
      }
      return null;
    } catch (e) {
      throw Exception('Lỗi khi tạo file mẫu: ${e.toString()}');
    }
  }
}
