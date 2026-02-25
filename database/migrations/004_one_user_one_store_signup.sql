-- ============================================
-- Phase 4: self-signup + one-user-one-store enforcement
-- ============================================

-- 1) Enforce exactly one store membership per user
-- NOTE: Existing data must satisfy this before applying unique index.
DO $$
BEGIN
  -- Keep oldest active membership when duplicates exist
  WITH ranked AS (
    SELECT
      sm.store_id,
      sm.user_id,
      sm.created_at,
      ROW_NUMBER() OVER (PARTITION BY sm.user_id ORDER BY sm.created_at ASC) AS rn
    FROM store_members sm
  )
  DELETE FROM store_members sm
  USING ranked r
  WHERE sm.store_id = r.store_id
    AND sm.user_id = r.user_id
    AND r.rn > 1;
EXCEPTION WHEN OTHERS THEN
  -- no-op safe guard
  NULL;
END $$;

-- One user -> one store (global)
CREATE UNIQUE INDEX IF NOT EXISTS uq_store_members_user_id
  ON store_members(user_id);

-- 2) Convenience function for signup bootstrap
CREATE OR REPLACE FUNCTION bootstrap_user_store(
  p_user_id UUID,
  p_full_name TEXT,
  p_store_name TEXT,
  p_phone TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_role_id UUID;
  v_store_id UUID;
  v_store_code TEXT;
BEGIN
  -- pick Owner role if exists, else fallback to Admin, else null
  SELECT id INTO v_role_id FROM roles WHERE name = 'Owner' LIMIT 1;
  IF v_role_id IS NULL THEN
    SELECT id INTO v_role_id FROM roles WHERE name = 'Admin' LIMIT 1;
  END IF;

  INSERT INTO profiles (id, full_name, role_id, is_active)
  VALUES (p_user_id, p_full_name, v_role_id, true)
  ON CONFLICT (id) DO UPDATE
  SET full_name = EXCLUDED.full_name,
      role_id = COALESCE(EXCLUDED.role_id, profiles.role_id),
      updated_at = NOW();

  v_store_code := regexp_replace(lower(coalesce(p_store_name, 'store')), '[^a-z0-9]+', '-', 'g');
  v_store_code := trim(both '-' from v_store_code);
  IF v_store_code = '' THEN
    v_store_code := 'store';
  END IF;
  v_store_code := v_store_code || '-' || substr(replace(p_user_id::text, '-', ''), 1, 8);

  INSERT INTO stores (code, name, owner_id, phone, is_active)
  VALUES (v_store_code, p_store_name, p_user_id, p_phone, true)
  RETURNING id INTO v_store_id;

  INSERT INTO store_members (store_id, user_id, role_id, is_default, is_active)
  VALUES (v_store_id, p_user_id, v_role_id, true, true)
  ON CONFLICT (user_id) DO UPDATE
  SET store_id = EXCLUDED.store_id,
      role_id = COALESCE(EXCLUDED.role_id, store_members.role_id),
      is_default = true,
      is_active = true,
      updated_at = NOW();

  RETURN v_store_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
