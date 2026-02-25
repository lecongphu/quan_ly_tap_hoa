-- ============================================
-- Multi-tenant foundation (phase 1)
-- ============================================
-- Goal:
-- 1) Introduce stores + memberships
-- 2) Add store_id to core business tables
-- 3) Add helper functions for RLS/store context

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1) Stores
CREATE TABLE IF NOT EXISTS stores (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  owner_id UUID REFERENCES profiles(id),
  phone TEXT,
  address TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_stores_owner ON stores(owner_id);

-- 2) User-store membership
CREATE TABLE IF NOT EXISTS store_members (
  store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role_id UUID REFERENCES roles(id),
  is_default BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (store_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_store_members_user ON store_members(user_id);
CREATE INDEX IF NOT EXISTS idx_store_members_role ON store_members(role_id);

-- 3) Add store_id to core business tables (non-breaking)
ALTER TABLE categories ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES stores(id);
ALTER TABLE products ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES stores(id);
ALTER TABLE inventory_batches ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES stores(id);
ALTER TABLE stock_movements ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES stores(id);
ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES stores(id);
ALTER TABLE purchase_orders ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES stores(id);
ALTER TABLE purchase_order_items ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES stores(id);
ALTER TABLE customers ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES stores(id);
ALTER TABLE customer_images ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES stores(id);
ALTER TABLE sales ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES stores(id);
ALTER TABLE sale_items ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES stores(id);
ALTER TABLE debt_payments ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES stores(id);
ALTER TABLE daily_reports ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES stores(id);
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES stores(id);

-- Useful indexes
CREATE INDEX IF NOT EXISTS idx_categories_store ON categories(store_id);
CREATE INDEX IF NOT EXISTS idx_products_store ON products(store_id);
CREATE INDEX IF NOT EXISTS idx_inventory_batches_store ON inventory_batches(store_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_store ON stock_movements(store_id);
CREATE INDEX IF NOT EXISTS idx_suppliers_store ON suppliers(store_id);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_store ON purchase_orders(store_id);
CREATE INDEX IF NOT EXISTS idx_purchase_order_items_store ON purchase_order_items(store_id);
CREATE INDEX IF NOT EXISTS idx_customers_store ON customers(store_id);
CREATE INDEX IF NOT EXISTS idx_customer_images_store ON customer_images(store_id);
CREATE INDEX IF NOT EXISTS idx_sales_store ON sales(store_id);
CREATE INDEX IF NOT EXISTS idx_sale_items_store ON sale_items(store_id);
CREATE INDEX IF NOT EXISTS idx_debt_payments_store ON debt_payments(store_id);
CREATE INDEX IF NOT EXISTS idx_daily_reports_store ON daily_reports(store_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_store ON audit_logs(store_id);

-- 4) Helpers for tenant-scoped access
CREATE OR REPLACE FUNCTION get_default_store_id()
RETURNS UUID AS $$
  SELECT sm.store_id
  FROM store_members sm
  WHERE sm.user_id = auth.uid()
    AND sm.is_active = true
  ORDER BY sm.is_default DESC, sm.created_at ASC
  LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION is_member_of_store(target_store UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1
    FROM store_members sm
    WHERE sm.user_id = auth.uid()
      AND sm.store_id = target_store
      AND sm.is_active = true
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- NOTE:
-- Phase 1 keeps existing data working and introduces columns/functions only.
-- Phase 2 should backfill store_id and update all RLS policies to enforce:
--   store_id = get_default_store_id() OR is_member_of_store(store_id)
