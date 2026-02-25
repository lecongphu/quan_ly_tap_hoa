-- ============================================
-- Phase 3: active store context + store APIs
-- ============================================

-- 1) RLS for stores & memberships
ALTER TABLE stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS stores_member_select ON stores;
CREATE POLICY stores_member_select
  ON stores FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM store_members sm
      WHERE sm.store_id = stores.id
        AND sm.user_id = auth.uid()
        AND sm.is_active = true
    )
  );

DROP POLICY IF EXISTS store_members_self_select ON store_members;
CREATE POLICY store_members_self_select
  ON store_members FOR SELECT
  USING (user_id = auth.uid());

-- 2) Functions for store context
CREATE OR REPLACE FUNCTION get_my_stores()
RETURNS TABLE (
  store_id UUID,
  store_code TEXT,
  store_name TEXT,
  is_default BOOLEAN,
  role_name TEXT
) AS $$
  SELECT
    s.id,
    s.code,
    s.name,
    sm.is_default,
    r.name
  FROM store_members sm
  JOIN stores s ON s.id = sm.store_id
  LEFT JOIN roles r ON r.id = sm.role_id
  WHERE sm.user_id = auth.uid()
    AND sm.is_active = true
    AND s.is_active = true
  ORDER BY sm.is_default DESC, s.name ASC;
$$ LANGUAGE sql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION set_my_default_store(target_store UUID)
RETURNS BOOLEAN AS $$
DECLARE
  allowed BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM store_members sm
    WHERE sm.user_id = auth.uid()
      AND sm.store_id = target_store
      AND sm.is_active = true
  ) INTO allowed;

  IF NOT allowed THEN
    RETURN FALSE;
  END IF;

  UPDATE store_members
  SET is_default = FALSE,
      updated_at = NOW()
  WHERE user_id = auth.uid()
    AND is_active = true
    AND is_default = true;

  UPDATE store_members
  SET is_default = TRUE,
      updated_at = NOW()
  WHERE user_id = auth.uid()
    AND store_id = target_store
    AND is_active = true;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3) Tighten tenant scope to active/default store only
-- Previous phase used is_member_of_store(store_id), which allows cross-store reads.
-- New phase enforces active context: store_id = get_default_store_id().
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
      'CREATE POLICY tenant_scope_%I ON %I AS RESTRICTIVE FOR ALL USING (store_id = get_default_store_id()) WITH CHECK (store_id = get_default_store_id())',
      t,
      t
    );
  END LOOP;
END $$;
