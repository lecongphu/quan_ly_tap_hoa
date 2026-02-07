import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App-wide constants and configuration
class AppConstants {
  // App Info
  static const String appName = 'Quản lý Tạp hóa';
  static const String appVersion = '1.0.0';

  // Supabase configuration (loaded from .env)
  static final String supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  static final String supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // Database Tables
  static const String tableProfiles = 'profiles';
  static const String tableRoles = 'roles';
  static const String tablePermissions = 'permissions';
  static const String tableRolePermissions = 'role_permissions';
  static const String tableAuditLogs = 'audit_logs';
  static const String tableCategories = 'categories';
  static const String tableProducts = 'products';
  static const String tableInventoryBatches = 'inventory_batches';
  static const String tableStockMovements = 'stock_movements';
  static const String tableSales = 'sales';
  static const String tableSaleItems = 'sale_items';
  static const String tableCustomers = 'customers';
  static const String tableDebtPayments = 'debt_payments';
  static const String tableDailyReports = 'daily_reports';

  // Payment Methods
  static const String paymentCash = 'cash';
  static const String paymentTransfer = 'transfer';
  static const String paymentDebt = 'debt';

  // Payment Status
  static const String paymentStatusPaid = 'paid';
  static const String paymentStatusPartial = 'partial';
  static const String paymentStatusUnpaid = 'unpaid';

  // Stock Movement Types
  static const String movementTypeIn = 'in';
  static const String movementTypeOut = 'out';
  static const String movementTypeAdjustment = 'adjustment';

  // Reference Types
  static const String refTypeSale = 'sale';
  static const String refTypePurchase = 'purchase';
  static const String refTypeStockTake = 'stock_take';

  // Audit Actions
  static const String actionLogin = 'login';
  static const String actionLogout = 'logout';
  static const String actionDeleteInvoice = 'delete_invoice';
  static const String actionEditInvoice = 'edit_invoice';
  static const String actionViewCost = 'view_cost';

  // Permissions
  static const String permPOSSell = 'pos.sell';
  static const String permPOSDeleteInvoice = 'pos.delete_invoice';
  static const String permInventoryView = 'inventory.view';
  static const String permInventoryViewCost = 'inventory.view_cost';
  static const String permInventoryEdit = 'inventory.edit';
  static const String permDebtView = 'debt.view';
  static const String permDebtEdit = 'debt.edit';
  static const String permReportView = 'report.view';
  static const String permReportExport = 'report.export';
  static const String permStaffManage = 'staff.manage';

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double defaultRadius = 8.0;
  static const int defaultPageSize = 20;
  // Pricing
  // Keep in sync with Angular POS price calculation: avg_cost_price * 1.3
  static const double defaultSalePriceMultiplier = 1.3;

  // Date Formats
  static const String dateFormat = 'dd/MM/yyyy';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';
  static const String timeFormat = 'HH:mm';

  // Alert Thresholds
  static const int expiryWarningDays = 7; // Cảnh báo hàng hết hạn trong 7 ngày
  static const int expiryDangerDays = 3; // Nguy hiểm: hết hạn trong 3 ngày

  // VietQR Configuration
  static const String vietQRBaseUrl = 'https://img.vietqr.io/image';
  static const String vietQRTemplate = 'compact';
}

/// Role names
class Roles {
  static const String admin = 'Admin';
  static const String manager = 'Manager';
  static const String cashier = 'Cashier';
  static const String warehouse = 'Warehouse';
}

/// Error messages
class ErrorMessages {
  static const String networkError = 'Lỗi kết nối mạng. Vui lòng thử lại.';
  static const String unauthorized =
      'Bạn không có quyền thực hiện thao tác này.';
  static const String invalidCredentials = 'Email hoặc mật khẩu không đúng.';
  static const String sessionExpired = 'Phiên đăng nhập đã hết hạn.';
  static const String insufficientStock = 'Không đủ hàng trong kho.';
  static const String productNotFound = 'Không tìm thấy sản phẩm.';
  static const String customerNotFound = 'Không tìm thấy khách hàng.';
}

/// Success messages
class SuccessMessages {
  static const String loginSuccess = 'Đăng nhập thành công!';
  static const String logoutSuccess = 'Đăng xuất thành công!';
  static const String saleSuccess = 'Bán hàng thành công!';
  static const String stockInSuccess = 'Nhập kho thành công!';
  static const String paymentSuccess = 'Thu nợ thành công!';
  static const String saveSuccess = 'Lưu thành công!';
  static const String deleteSuccess = 'Xóa thành công!';
}
