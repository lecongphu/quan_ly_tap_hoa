-- ============================================
-- Seed Data for Initial Setup
-- ============================================

-- ============================================
-- 1. ROLES
-- ============================================

INSERT INTO roles (name, description) VALUES
('Admin', 'Quản trị viên - Toàn quyền'),
('Manager', 'Quản lý - Xem báo cáo, quản lý kho'),
('Cashier', 'Thu ngân - Chỉ bán hàng'),
('Warehouse', 'Thủ kho - Quản lý nhập xuất kho');

-- ============================================
-- 2. PERMISSIONS
-- ============================================

INSERT INTO permissions (code, name, module, description) VALUES
-- POS permissions
('pos.sell', 'Bán hàng', 'pos', 'Quyền bán hàng tại quầy'),
('pos.delete_invoice', 'Xóa hóa đơn', 'pos', 'Quyền xóa hóa đơn đã tạo'),
('pos.edit_invoice', 'Sửa hóa đơn', 'pos', 'Quyền sửa hóa đơn'),

-- Inventory permissions
('inventory.view', 'Xem kho', 'inventory', 'Quyền xem danh sách sản phẩm và tồn kho'),
('inventory.view_cost', 'Xem giá vốn', 'inventory', 'Quyền xem giá vốn sản phẩm'),
('inventory.edit', 'Quản lý kho', 'inventory', 'Quyền nhập/xuất/chỉnh sửa kho'),
('inventory.stock_take', 'Kiểm kho', 'inventory', 'Quyền thực hiện kiểm kho'),

-- Debt permissions
('debt.view', 'Xem công nợ', 'debt', 'Quyền xem danh sách công nợ'),
('debt.edit', 'Quản lý công nợ', 'debt', 'Quyền thu nợ và quản lý khách hàng'),

-- Report permissions
('report.view', 'Xem báo cáo', 'report', 'Quyền xem các báo cáo'),
('report.export', 'Xuất báo cáo', 'report', 'Quyền xuất báo cáo Excel/PDF'),

-- Staff permissions
('staff.manage', 'Quản lý nhân viên', 'staff', 'Quyền quản lý tài khoản nhân viên');

-- ============================================
-- 3. ROLE-PERMISSION MAPPINGS
-- ============================================

-- Admin: All permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.name = 'Admin';

-- Manager: All except staff management
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.name = 'Manager'
  AND p.code IN (
    'pos.sell', 'pos.delete_invoice', 'pos.edit_invoice',
    'inventory.view', 'inventory.view_cost', 'inventory.edit', 'inventory.stock_take',
    'debt.view', 'debt.edit',
    'report.view', 'report.export'
  );

-- Cashier: Only POS and basic debt view
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.name = 'Cashier'
  AND p.code IN (
    'pos.sell',
    'inventory.view',
    'debt.view'
  );

-- Warehouse: Inventory management only
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.name = 'Warehouse'
  AND p.code IN (
    'inventory.view', 'inventory.view_cost', 'inventory.edit', 'inventory.stock_take'
  );

-- ============================================
-- 4. SAMPLE CATEGORIES
-- ============================================

INSERT INTO categories (name, description) VALUES
('Đồ uống', 'Nước ngọt, nước suối, bia, rượu'),
('Thực phẩm khô', 'Mì gói, bánh kẹo, gia vị'),
('Thực phẩm tươi sống', 'Rau củ, thịt, cá'),
('Đồ dùng gia đình', 'Bột giặt, nước rửa chén, giấy vệ sinh'),
('Sữa & Sản phẩm từ sữa', 'Sữa tươi, sữa hộp, yaourt'),
('Dầu ăn & Gia vị', 'Dầu ăn, nước mắm, tương ớt'),
('Đồ ăn vặt', 'Snack, kẹo, bánh quy'),
('Thuốc lá & Rượu', 'Thuốc lá các loại, rượu, bia');

-- ============================================
-- 5. SAMPLE PRODUCTS
-- ============================================

INSERT INTO products (barcode, name, category_id, unit, min_stock_level) VALUES
-- Đồ uống
('8934588013010', 'Coca Cola 330ml', (SELECT id FROM categories WHERE name = 'Đồ uống'), 'lon', 24),
('8934588013027', 'Pepsi 330ml', (SELECT id FROM categories WHERE name = 'Đồ uống'), 'lon', 24),
('8934588013034', 'Nước suối Aquafina 500ml', (SELECT id FROM categories WHERE name = 'Đồ uống'), 'chai', 48),
('8934588013041', 'Sting dâu 330ml', (SELECT id FROM categories WHERE name = 'Đồ uống'), 'lon', 24),

-- Thực phẩm khô
('8934588023010', 'Mì Hảo Hảo tôm chua cay', (SELECT id FROM categories WHERE name = 'Thực phẩm khô'), 'gói', 100),
('8934588023027', 'Mì Omachi sườn heo', (SELECT id FROM categories WHERE name = 'Thực phẩm khô'), 'gói', 100),
('8934588023034', 'Muối I-ốt 500g', (SELECT id FROM categories WHERE name = 'Thực phẩm khô'), 'gói', 20),
('8934588023041', 'Đường trắng 1kg', (SELECT id FROM categories WHERE name = 'Thực phẩm khô'), 'gói', 30),

-- Dầu ăn & Gia vị
('8934588033010', 'Dầu ăn Neptune 1L', (SELECT id FROM categories WHERE name = 'Dầu ăn & Gia vị'), 'chai', 10),
('8934588033027', 'Nước mắm Nam Ngư 500ml', (SELECT id FROM categories WHERE name = 'Dầu ăn & Gia vị'), 'chai', 15),
('8934588033034', 'Tương ớt Chinsu 250g', (SELECT id FROM categories WHERE name = 'Dầu ăn & Gia vị'), 'chai', 20),

-- Sữa
('8934588043010', 'Sữa tươi Vinamilk 1L', (SELECT id FROM categories WHERE name = 'Sữa & Sản phẩm từ sữa'), 'hộp', 12),
('8934588043027', 'Sữa đặc Ông Thọ 380g', (SELECT id FROM categories WHERE name = 'Sữa & Sản phẩm từ sữa'), 'hộp', 24),

-- Đồ dùng gia đình
('8934588053010', 'Bột giặt OMO 3kg', (SELECT id FROM categories WHERE name = 'Đồ dùng gia đình'), 'gói', 5),
('8934588053027', 'Nước rửa chén Sunlight 750g', (SELECT id FROM categories WHERE name = 'Đồ dùng gia đình'), 'chai', 10),
('8934588053034', 'Giấy vệ sinh Pulppy 10 cuộn', (SELECT id FROM categories WHERE name = 'Đồ dùng gia đình'), 'lốc', 15);

-- ============================================
-- 6. SAMPLE CUSTOMERS
-- ============================================

INSERT INTO customers (name, phone, address) VALUES
('Khách vãng lai', NULL, NULL),
('Nguyễn Văn A', '0901234567', '123 Đường ABC, Quận 1'),
('Trần Thị B', '0912345678', '456 Đường XYZ, Quận 2'),
('Lê Văn C', '0923456789', '789 Đường DEF, Quận 3');

-- ============================================
-- NOTES
-- ============================================

-- After running this seed data:
-- 1. Create your first admin user via Supabase Auth
-- 2. Manually insert into profiles table:
--    INSERT INTO profiles (id, full_name, role_id)
--    VALUES (
--      'your-auth-user-id',
--      'Admin User',
--      (SELECT id FROM roles WHERE name = 'Admin')
--    );
