-- ============================================
-- Multi-tenant phase 2: backfill + tenant RLS hardening
-- ============================================
-- This migration does:
-- 1) Backfill existing data into a default store
-- 2) Ensure users are members of at least one store
-- 3) Add auto-fill trigger for store_id on INSERT
-- 4) Enforce tenant scope via RESTRICTIVE RLS policies

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- --------------------------------------------
-- Helpers
-- --------------------------------------------
CREATE OR REPLACE FUNCTION set_store_id_default()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.store_id IS NULL THEN
    NEW.store_id := get_default_store_id();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- --------------------------------------------
-- Ensure at least one default store exists
-- --------------------------------------------
DO $$
DECLARE
  v_store_id UUID;
  v_owner UUID;
BEGIN
  SELECT id INTO v_store_id FROM stores ORDER BY created_at ASC LIMIT 1;

  IF v_store_id IS NULL THEN
    SELECT id INTO v_owner FROM profiles ORDER BY created_at ASC LIMIT 1;

    INSERT INTO stores (code, name, owner_id)
    VALUES ('default-store', 'Default Store', v_owner)
    RETURNING id INTO v_store_id;
  END IF;

  -- Ensure every profile has membership to at least one store
  INSERT INTO store_members (store_id, user_id, role_id, is_default, is_active)
  SELECT v_store_id, p.id, p.role_id, true, true
  FROM profiles p
  WHERE NOT EXISTS (
    SELECT 1 FROM store_members sm
    WHERE sm.user_id = p.id
  );

  -- If user has memberships but none marked default, mark oldest active as default
  WITH ranked AS (
    SELECT
      sm.store_id,
      sm.user_id,
      sm.created_at,
      ROW_NUMBER() OVER (PARTITION BY sm.user_id ORDER BY sm.created_at ASC) AS rn,
      MAX(CASE WHEN sm.is_default THEN 1 ELSE 0 END) OVER (PARTITION BY sm.user_id) AS has_default
    FROM store_members sm
    WHERE sm.is_active = true
  )
  UPDATE store_members sm
  SET is_default = true,
      updated_at = NOW()
  FROM ranked r
  WHERE sm.store_id = r.store_id
    AND sm.user_id = r.user_id
    AND r.rn = 1
    AND r.has_default = 0;
END $$;

-- --------------------------------------------
-- Backfill store_id for existing rows
-- --------------------------------------------
DO $$
DECLARE
  t TEXT;
  tables TEXT[] := ARRAY[
    'categories',
    'products',
    'inventory_batches',
    'stock_movements',
    'suppliers',
    'purchase_orders',
    'purchase_order_items',
    'customers',
    'customer_images',
    'sales',
    'sale_items',
    'debt_payments',
    'daily_reports',
    'audit_logs'
  ];
BEGIN
  FOREACH t IN ARRAY tables LOOP
    EXECUTE format('UPDATE %I SET store_id = get_default_store_id() WHERE store_id IS NULL', t);
  END LOOP;
END $$;

-- --------------------------------------------
-- Auto-fill store_id trigger on INSERT
-- --------------------------------------------
DO $$
DECLARE
  t TEXT;
  tables TEXT[] := ARRAY[
    'categories',
    'products',
    'inventory_batches',
    'stock_movements',
    'suppliers',
    'purchase_orders',
    'purchase_order_items',
    'customers',
    'customer_images',
    'sales',
    'sale_items',
    'debt_payments',
    'daily_reports',
    'audit_logs'
  ];
BEGIN
  FOREACH t IN ARRAY tables LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_%I_set_store_id ON %I', t, t);
    EXECUTE format(
      'CREATE TRIGGER trg_%I_set_store_id BEFORE INSERT ON %I FOR EACH ROW EXECUTE FUNCTION set_store_id_default()',
      t,
      t
    );
  END LOOP;
END $$;

-- --------------------------------------------
-- Set NOT NULL where safe/critical
-- --------------------------------------------
ALTER TABLE categories ALTER COLUMN store_id SET NOT NULL;
ALTER TABLE products ALTER COLUMN store_id SET NOT NULL;
ALTER TABLE inventory_batches ALTER COLUMN store_id SET NOT NULL;
ALTER TABLE stock_movements ALTER COLUMN store_id SET NOT NULL;
ALTER TABLE suppliers ALTER COLUMN store_id SET NOT NULL;
ALTER TABLE purchase_orders ALTER COLUMN store_id SET NOT NULL;
ALTER TABLE purchase_order_items ALTER COLUMN store_id SET NOT NULL;
ALTER TABLE customers ALTER COLUMN store_id SET NOT NULL;
ALTER TABLE customer_images ALTER COLUMN store_id SET NOT NULL;
ALTER TABLE sales ALTER COLUMN store_id SET NOT NULL;
ALTER TABLE sale_items ALTER COLUMN store_id SET NOT NULL;
ALTER TABLE debt_payments ALTER COLUMN store_id SET NOT NULL;
ALTER TABLE daily_reports ALTER COLUMN store_id SET NOT NULL;
ALTER TABLE audit_logs ALTER COLUMN store_id SET NOT NULL;

-- --------------------------------------------
-- Tenant RLS hardening (RESTRICTIVE policies)
-- Existing permission-based policies remain; these add mandatory tenant scope.
-- --------------------------------------------
DO $$
DECLARE
  t TEXT;
  tables TEXT[] := ARRAY[
    'categories',
    'products',
    'inventory_batches',
    'stock_movements',
    'suppliers',
    'purchase_orders',
    'purchase_order_items',
    'customers',
    'customer_images',
    'sales',
    'sale_items',
    'debt_payments',
    'daily_reports',
    'audit_logs'
  ];
BEGIN
  FOREACH t IN ARRAY tables LOOP
    EXECUTE format('DROP POLICY IF EXISTS tenant_scope_%I ON %I', t, t);
    EXECUTE format(
      'CREATE POLICY tenant_scope_%I ON %I AS RESTRICTIVE FOR ALL USING (is_member_of_store(store_id)) WITH CHECK (is_member_of_store(store_id))',
      t,
      t
    );
  END LOOP;
END $$;

-- Optional: lock table bypasses if any owner role accidentally bypasses RLS in app clients
ALTER TABLE categories FORCE ROW LEVEL SECURITY;
ALTER TABLE products FORCE ROW LEVEL SECURITY;
ALTER TABLE inventory_batches FORCE ROW LEVEL SECURITY;
ALTER TABLE stock_movements FORCE ROW LEVEL SECURITY;
ALTER TABLE suppliers FORCE ROW LEVEL SECURITY;
ALTER TABLE purchase_orders FORCE ROW LEVEL SECURITY;
ALTER TABLE purchase_order_items FORCE ROW LEVEL SECURITY;
ALTER TABLE customers FORCE ROW LEVEL SECURITY;
ALTER TABLE customer_images FORCE ROW LEVEL SECURITY;
ALTER TABLE sales FORCE ROW LEVEL SECURITY;
ALTER TABLE sale_items FORCE ROW LEVEL SECURITY;
ALTER TABLE debt_payments FORCE ROW LEVEL SECURITY;
ALTER TABLE daily_reports FORCE ROW LEVEL SECURITY;
ALTER TABLE audit_logs FORCE ROW LEVEL SECURITY;
