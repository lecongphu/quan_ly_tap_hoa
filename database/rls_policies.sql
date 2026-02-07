-- ============================================
-- Row Level Security (RLS) Policies
-- ============================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE debt_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_order_items ENABLE ROW LEVEL SECURITY;

-- ============================================
-- Helper function to get user role
-- ============================================

CREATE OR REPLACE FUNCTION get_user_role()
RETURNS TEXT AS $$
    SELECT r.name
    FROM profiles p
    JOIN roles r ON p.role_id = r.id
    WHERE p.id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER;

-- ============================================
-- Helper function to check permission
-- ============================================

CREATE OR REPLACE FUNCTION has_permission(permission_code TEXT)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1
        FROM profiles p
        JOIN role_permissions rp ON p.role_id = rp.role_id
        JOIN permissions perm ON rp.permission_id = perm.id
        WHERE p.id = auth.uid()
          AND perm.code = permission_code
    );
$$ LANGUAGE sql SECURITY DEFINER;

-- ============================================
-- PROFILES - Users can view their own profile
-- ============================================

CREATE POLICY "Users can view own profile"
    ON profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Admins can view all profiles"
    ON profiles FOR SELECT
    USING (get_user_role() = 'Admin');

CREATE POLICY "Admins can update profiles"
    ON profiles FOR UPDATE
    USING (get_user_role() = 'Admin');

-- ============================================
-- PRODUCTS - Based on permissions
-- ============================================

CREATE POLICY "Users with inventory.view can view products"
    ON products FOR SELECT
    USING (has_permission('inventory.view'));

CREATE POLICY "Users with inventory.edit can modify products"
    ON products FOR ALL
    USING (has_permission('inventory.edit'));

-- ============================================
-- INVENTORY BATCHES - Hide cost from cashiers
-- ============================================

CREATE POLICY "Users with inventory.view can view batches"
    ON inventory_batches FOR SELECT
    USING (has_permission('inventory.view'));

CREATE POLICY "Users with inventory.edit can modify batches"
    ON inventory_batches FOR ALL
    USING (has_permission('inventory.edit'));

-- ============================================
-- SALES - Cashiers can create, cannot delete
-- ============================================

CREATE POLICY "Users with pos.sell can view sales"
    ON sales FOR SELECT
    USING (has_permission('pos.sell'));

CREATE POLICY "Users with debt.view can view debt sales"
    ON sales FOR SELECT
    USING (has_permission('debt.view') AND payment_method = 'debt');

CREATE POLICY "Users with pos.sell can create sales"
    ON sales FOR INSERT
    WITH CHECK (has_permission('pos.sell'));

CREATE POLICY "Users with debt.edit can create debt sales"
    ON sales FOR INSERT
    WITH CHECK (has_permission('debt.edit') AND payment_method = 'debt');

CREATE POLICY "Users with pos.edit_invoice can update sales"
    ON sales FOR UPDATE
    USING (has_permission('pos.edit_invoice'));

CREATE POLICY "Users with debt.edit can update debt sales"
    ON sales FOR UPDATE
    USING (has_permission('debt.edit') AND payment_method = 'debt')
    WITH CHECK (has_permission('debt.edit') AND payment_method = 'debt');

CREATE POLICY "Users with pos.delete_invoice can delete sales"
    ON sales FOR DELETE
    USING (has_permission('pos.delete_invoice'));

CREATE POLICY "Users with debt.edit can delete debt sales"
    ON sales FOR DELETE
    USING (has_permission('debt.edit') AND payment_method = 'debt');

-- ============================================
-- SALE ITEMS - Follow sales permissions
-- ============================================

CREATE POLICY "Users can view sale items if they can view sales"
    ON sale_items FOR SELECT
    USING (has_permission('pos.sell'));

CREATE POLICY "Users with debt.view can view debt sale items"
    ON sale_items FOR SELECT
    USING (
        has_permission('debt.view')
        AND EXISTS (
            SELECT 1
            FROM sales s
            WHERE s.id = sale_items.sale_id
              AND s.payment_method = 'debt'
        )
    );

CREATE POLICY "Users can create sale items if they can create sales"
    ON sale_items FOR INSERT
    WITH CHECK (has_permission('pos.sell'));

-- ============================================
-- CUSTOMERS - Based on debt permissions
-- ============================================

CREATE POLICY "Users with debt.view can view customers"
    ON customers FOR SELECT
    USING (has_permission('debt.view') OR has_permission('pos.sell'));

CREATE POLICY "Users with debt.edit can modify customers"
    ON customers FOR ALL
    USING (has_permission('debt.edit'));

-- ============================================
-- DEBT PAYMENTS - Based on debt permissions
-- ============================================

CREATE POLICY "Users with debt.view can view payments"
    ON debt_payments FOR SELECT
    USING (has_permission('debt.view'));

CREATE POLICY "Users with debt.edit can create payments"
    ON debt_payments FOR INSERT
    WITH CHECK (has_permission('debt.edit'));

CREATE POLICY "Users with debt.edit can update payments"
    ON debt_payments FOR UPDATE
    USING (has_permission('debt.edit'));

CREATE POLICY "Users with debt.edit can delete payments"
    ON debt_payments FOR DELETE
    USING (has_permission('debt.edit'));

-- ============================================
-- REPORTS - Based on report permissions
-- ============================================

CREATE POLICY "Users with report.view can view daily reports"
    ON daily_reports FOR SELECT
    USING (has_permission('report.view'));

CREATE POLICY "Admins can modify daily reports"
    ON daily_reports FOR ALL
    USING (get_user_role() = 'Admin');

-- ============================================
-- AUDIT LOGS - Admins only
-- ============================================

CREATE POLICY "Admins can view audit logs"
    ON audit_logs FOR SELECT
    USING (get_user_role() = 'Admin');

CREATE POLICY "All authenticated users can create audit logs"
    ON audit_logs FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL);

-- ============================================
-- CATEGORIES - All can view, admins can modify
-- ============================================

CREATE POLICY "Authenticated users can view categories"
    ON categories FOR SELECT
    USING (auth.uid() IS NOT NULL);

CREATE POLICY "Admins can modify categories"
    ON categories FOR ALL
    USING (get_user_role() = 'Admin');

-- ============================================
-- STOCK MOVEMENTS - Based on inventory permissions
-- ============================================

CREATE POLICY "Users with inventory.view can view stock movements"
    ON stock_movements FOR SELECT
    USING (has_permission('inventory.view'));

CREATE POLICY "System can create stock movements"
    ON stock_movements FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL);

-- ============================================
-- SUPPLIERS - Based on inventory permissions
-- ============================================

CREATE POLICY "Users with inventory.view can view suppliers"
    ON suppliers FOR SELECT
    USING (has_permission('inventory.view'));

CREATE POLICY "Users with inventory.edit can modify suppliers"
    ON suppliers FOR ALL
    USING (has_permission('inventory.edit'));

-- ============================================
-- PURCHASE ORDERS - Based on inventory permissions
-- ============================================

CREATE POLICY "Users with inventory.view can view purchase orders"
    ON purchase_orders FOR SELECT
    USING (has_permission('inventory.view'));

CREATE POLICY "Users with inventory.edit can modify purchase orders"
    ON purchase_orders FOR ALL
    USING (has_permission('inventory.edit'));

CREATE POLICY "Users with inventory.view can view purchase order items"
    ON purchase_order_items FOR SELECT
    USING (has_permission('inventory.view'));

CREATE POLICY "Users with inventory.edit can modify purchase order items"
    ON purchase_order_items FOR ALL
    USING (has_permission('inventory.edit'));

-- ============================================
-- ROLES & PERMISSIONS - Admins only
-- ============================================

CREATE POLICY "Admins can view roles"
    ON roles FOR SELECT
    USING (get_user_role() = 'Admin');

CREATE POLICY "Admins can view permissions"
    ON permissions FOR SELECT
    USING (get_user_role() = 'Admin');

CREATE POLICY "Admins can view role_permissions"
    ON role_permissions FOR SELECT
    USING (get_user_role() = 'Admin');
