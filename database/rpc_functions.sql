-- ============================================
-- Supabase RPC Functions (backend replacement)
-- ============================================

CREATE OR REPLACE FUNCTION public.get_my_profile_with_permissions()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile profiles%ROWTYPE;
  v_role_name text;
  v_permissions jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT *
  INTO v_profile
  FROM profiles
  WHERE id = auth.uid();

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  SELECT name
  INTO v_role_name
  FROM roles
  WHERE id = v_profile.role_id;

  SELECT jsonb_agg(
    jsonb_build_object(
      'code', perm.code,
      'name', perm.name,
      'module', perm.module,
      'description', perm.description
    )
  )
  INTO v_permissions
  FROM role_permissions rp
  JOIN permissions perm ON perm.id = rp.permission_id
  WHERE rp.role_id = v_profile.role_id;

  RETURN jsonb_build_object(
    'profile', to_jsonb(v_profile) || jsonb_build_object('role_name', v_role_name),
    'permissions', COALESCE(v_permissions, '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.pos_checkout(
  p_payment_method text,
  p_items jsonb,
  p_customer_id uuid DEFAULT NULL,
  p_discount_amount numeric DEFAULT 0,
  p_due_date timestamptz DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sale sales%ROWTYPE;
  v_total_amount numeric := 0;
  v_final_amount numeric := 0;
  v_missing_batches int := 0;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT has_permission('pos.sell') THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Cart items required.';
  END IF;

  IF p_payment_method NOT IN ('cash', 'transfer', 'debt') THEN
    RAISE EXCEPTION 'Invalid payment method.';
  END IF;

  IF p_payment_method = 'debt' AND p_customer_id IS NULL THEN
    RAISE EXCEPTION 'Customer is required for debt payments.';
  END IF;

  WITH items AS (
    SELECT
      (item->>'product_id')::uuid AS product_id,
      (item->>'quantity')::numeric AS quantity,
      (item->>'unit_price')::numeric AS unit_price
    FROM jsonb_array_elements(p_items) AS item
  ),
  items_with_batch AS (
    SELECT i.*, get_fefo_batch(i.product_id, i.quantity) AS batch_id
    FROM items i
  ),
  items_with_cost AS (
    SELECT iwb.*, ib.cost_price
    FROM items_with_batch iwb
    JOIN inventory_batches ib ON ib.id = iwb.batch_id
  )
  SELECT COUNT(*) INTO v_missing_batches
  FROM items_with_batch
  WHERE batch_id IS NULL;

  IF v_missing_batches > 0 THEN
    RAISE EXCEPTION 'Insufficient stock.';
  END IF;

  SELECT COALESCE(SUM(quantity * unit_price), 0)
  INTO v_total_amount
  FROM items_with_cost;

  v_final_amount := v_total_amount - COALESCE(p_discount_amount, 0);

  INSERT INTO sales (
    customer_id,
    total_amount,
    discount_amount,
    final_amount,
    payment_method,
    payment_status,
    due_date,
    notes,
    created_by
  )
  VALUES (
    p_customer_id,
    v_total_amount,
    COALESCE(p_discount_amount, 0),
    v_final_amount,
    p_payment_method,
    CASE WHEN p_payment_method = 'debt' THEN 'unpaid' ELSE 'paid' END,
    p_due_date,
    p_notes,
    auth.uid()
  )
  RETURNING * INTO v_sale;

  INSERT INTO sale_items (
    sale_id,
    product_id,
    batch_id,
    quantity,
    unit_price,
    cost_price,
    discount,
    subtotal
  )
  SELECT
    v_sale.id,
    product_id,
    batch_id,
    quantity,
    unit_price,
    cost_price,
    0,
    quantity * unit_price
  FROM items_with_cost;

  RETURN jsonb_build_object(
    'sale', to_jsonb(v_sale),
    'items', (
      SELECT COALESCE(jsonb_agg(to_jsonb(si)), '[]'::jsonb)
      FROM sale_items si
      WHERE si.sale_id = v_sale.id
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.stock_in(
  p_product_id uuid,
  p_quantity numeric,
  p_cost_price numeric,
  p_batch_number text DEFAULT NULL,
  p_expiry_date date DEFAULT NULL,
  p_received_date date DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_batch inventory_batches%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT has_permission('inventory.edit') THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  INSERT INTO inventory_batches (
    product_id,
    quantity,
    cost_price,
    batch_number,
    expiry_date,
    received_date
  )
  VALUES (
    p_product_id,
    p_quantity,
    p_cost_price,
    p_batch_number,
    p_expiry_date,
    COALESCE(p_received_date, CURRENT_DATE)
  )
  RETURNING * INTO v_batch;

  INSERT INTO stock_movements (
    product_id,
    batch_id,
    movement_type,
    quantity,
    reference_id,
    reference_type,
    created_by
  )
  VALUES (
    p_product_id,
    v_batch.id,
    'in',
    p_quantity,
    v_batch.id,
    'purchase',
    auth.uid()
  );

  RETURN to_jsonb(v_batch);
END;
$$;

CREATE OR REPLACE FUNCTION public.create_purchase_order(
  p_items jsonb,
  p_order_number text DEFAULT NULL,
  p_supplier_id uuid DEFAULT NULL,
  p_warehouse text DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order purchase_orders%ROWTYPE;
  v_total_amount numeric := 0;
  v_order_number text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT has_permission('inventory.edit') THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Order items required.';
  END IF;

  v_order_number := COALESCE(
    p_order_number,
    'PO' || TO_CHAR(NOW(), 'YYYYMMDD') || LPAD((EXTRACT(EPOCH FROM NOW())::bigint % 10000)::text, 4, '0')
  );

  SELECT COALESCE(SUM((item->>'quantity')::numeric * (item->>'unit_price')::numeric), 0)
  INTO v_total_amount
  FROM jsonb_array_elements(p_items) AS item;

  INSERT INTO purchase_orders (
    order_number,
    supplier_id,
    status,
    total_amount,
    warehouse,
    notes,
    created_by
  )
  VALUES (
    v_order_number,
    p_supplier_id,
    'pending',
    v_total_amount,
    p_warehouse,
    p_notes,
    auth.uid()
  )
  RETURNING * INTO v_order;

  INSERT INTO purchase_order_items (
    purchase_order_id,
    product_id,
    quantity,
    unit_price,
    subtotal
  )
  SELECT
    v_order.id,
    (item->>'product_id')::uuid,
    (item->>'quantity')::numeric,
    (item->>'unit_price')::numeric,
    (item->>'quantity')::numeric * (item->>'unit_price')::numeric
  FROM jsonb_array_elements(p_items) AS item;

  RETURN jsonb_build_object(
    'order', to_jsonb(v_order),
    'total_items', (
      SELECT COALESCE(SUM((item->>'quantity')::numeric), 0)
      FROM jsonb_array_elements(p_items) AS item
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.lock_sale(p_sale_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sale sales%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT has_permission('pos.edit_invoice') THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT * INTO v_sale FROM sales WHERE id = p_sale_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Sale not found.';
  END IF;

  IF v_sale.is_locked THEN
    RAISE EXCEPTION 'Invoice already locked.';
  END IF;

  UPDATE sales
  SET is_locked = true,
      locked_at = NOW(),
      locked_by = auth.uid()
  WHERE id = p_sale_id
  RETURNING * INTO v_sale;

  RETURN to_jsonb(v_sale);
END;
$$;

CREATE OR REPLACE FUNCTION public.refund_sale(p_sale_id uuid, p_reason text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sale sales%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT (has_permission('pos.edit_invoice') OR has_permission('debt.edit')) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT * INTO v_sale FROM sales WHERE id = p_sale_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Sale not found.';
  END IF;

  IF v_sale.refunded_at IS NOT NULL THEN
    RAISE EXCEPTION 'Invoice already refunded.';
  END IF;

  UPDATE sales
  SET refunded_at = NOW(),
      refunded_by = auth.uid(),
      refund_notes = p_reason,
      is_locked = true,
      locked_at = CASE WHEN v_sale.is_locked THEN v_sale.locked_at ELSE NOW() END,
      locked_by = CASE WHEN v_sale.is_locked THEN v_sale.locked_by ELSE auth.uid() END
  WHERE id = p_sale_id
  RETURNING * INTO v_sale;

  RETURN to_jsonb(v_sale);
END;
$$;

CREATE OR REPLACE FUNCTION public.update_debt_line(
  p_sale_id uuid,
  p_amount numeric DEFAULT NULL,
  p_purchase_date timestamptz DEFAULT NULL,
  p_due_date timestamptz DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sale sales%ROWTYPE;
  v_new_amount numeric;
  v_delta numeric;
  v_current_debt numeric;
  v_new_debt numeric;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT has_permission('debt.edit') THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT * INTO v_sale FROM sales WHERE id = p_sale_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Debt line not found.';
  END IF;

  IF v_sale.payment_method <> 'debt' THEN
    RAISE EXCEPTION 'Only debt sales can be edited.';
  END IF;

  IF EXISTS (SELECT 1 FROM sale_items WHERE sale_id = v_sale.id LIMIT 1) THEN
    RAISE EXCEPTION 'Không thể chỉnh sửa nợ phát sinh từ hóa đơn.';
  END IF;

  v_new_amount := COALESCE(p_amount, v_sale.final_amount);
  v_delta := v_new_amount - v_sale.final_amount;

  IF v_delta <> 0 THEN
    SELECT current_debt INTO v_current_debt FROM customers WHERE id = v_sale.customer_id;
    v_new_debt := COALESCE(v_current_debt, 0) + v_delta;
    IF v_new_debt < 0 THEN
      RAISE EXCEPTION 'Amount exceeds current debt.';
    END IF;

    UPDATE customers
    SET current_debt = v_new_debt
    WHERE id = v_sale.customer_id;
  END IF;

  UPDATE sales
  SET total_amount = v_new_amount,
      discount_amount = 0,
      final_amount = v_new_amount,
      due_date = COALESCE(p_due_date, v_sale.due_date),
      notes = COALESCE(p_notes, v_sale.notes),
      created_at = COALESCE(p_purchase_date, v_sale.created_at)
  WHERE id = p_sale_id
  RETURNING * INTO v_sale;

  RETURN to_jsonb(v_sale);
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_debt_line(p_sale_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sale sales%ROWTYPE;
  v_current_debt numeric;
  v_new_debt numeric;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT has_permission('debt.edit') THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT * INTO v_sale FROM sales WHERE id = p_sale_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Debt line not found.';
  END IF;

  IF v_sale.payment_method <> 'debt' THEN
    RAISE EXCEPTION 'Only debt sales can be deleted.';
  END IF;

  IF EXISTS (SELECT 1 FROM sale_items WHERE sale_id = v_sale.id LIMIT 1) THEN
    RAISE EXCEPTION 'Không thể xóa nợ phát sinh từ hóa đơn.';
  END IF;

  SELECT current_debt INTO v_current_debt FROM customers WHERE id = v_sale.customer_id;
  v_new_debt := COALESCE(v_current_debt, 0) - v_sale.final_amount;
  IF v_new_debt < 0 THEN
    RAISE EXCEPTION 'Amount exceeds current debt.';
  END IF;

  DELETE FROM sales WHERE id = p_sale_id;

  UPDATE customers
  SET current_debt = v_new_debt
  WHERE id = v_sale.customer_id;

  RETURN jsonb_build_object('id', p_sale_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.update_debt_payment(
  p_payment_id uuid,
  p_amount numeric DEFAULT NULL,
  p_payment_method text DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_payment debt_payments%ROWTYPE;
  v_new_amount numeric;
  v_delta numeric;
  v_current_debt numeric;
  v_new_debt numeric;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT has_permission('debt.edit') THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT * INTO v_payment FROM debt_payments WHERE id = p_payment_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payment not found.';
  END IF;

  v_new_amount := COALESCE(p_amount, v_payment.amount);
  v_delta := v_new_amount - v_payment.amount;

  IF v_delta <> 0 THEN
    SELECT current_debt INTO v_current_debt FROM customers WHERE id = v_payment.customer_id;
    v_new_debt := COALESCE(v_current_debt, 0) - v_delta;
    IF v_new_debt < 0 THEN
      RAISE EXCEPTION 'Amount exceeds current debt.';
    END IF;

    UPDATE customers
    SET current_debt = v_new_debt
    WHERE id = v_payment.customer_id;
  END IF;

  UPDATE debt_payments
  SET amount = v_new_amount,
      payment_method = COALESCE(p_payment_method, v_payment.payment_method),
      notes = COALESCE(p_notes, v_payment.notes)
  WHERE id = p_payment_id
  RETURNING * INTO v_payment;

  RETURN to_jsonb(v_payment);
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_debt_payment(p_payment_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_payment debt_payments%ROWTYPE;
  v_current_debt numeric;
  v_new_debt numeric;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT has_permission('debt.edit') THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT * INTO v_payment FROM debt_payments WHERE id = p_payment_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payment not found.';
  END IF;

  SELECT current_debt INTO v_current_debt FROM customers WHERE id = v_payment.customer_id;
  v_new_debt := COALESCE(v_current_debt, 0) + v_payment.amount;

  DELETE FROM debt_payments WHERE id = p_payment_id;

  UPDATE customers
  SET current_debt = v_new_debt
  WHERE id = v_payment.customer_id;

  RETURN jsonb_build_object('id', p_payment_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_duplicate_debt_lines(
  p_customer_id uuid,
  p_year integer DEFAULT NULL
)
RETURNS TABLE(
  id uuid,
  invoice_number text,
  created_at timestamptz,
  due_date date,
  final_amount numeric,
  notes text,
  items jsonb
)
LANGUAGE sql
STABLE
AS $$
  WITH base AS (
    SELECT s.*
    FROM sales s
    WHERE s.customer_id = p_customer_id
      AND s.payment_method = 'debt'
      AND s.created_at IS NOT NULL
      AND (
        p_year IS NULL OR
        s.created_at >= make_timestamptz(p_year, 1, 1, 0, 0, 0) AND
        s.created_at < make_timestamptz(p_year + 1, 1, 1, 0, 0, 0)
      )
  ),
  dup_dates AS (
    SELECT date(created_at) AS purchase_date
    FROM base
    GROUP BY date(created_at)
    HAVING count(*) > 1
  ),
  lines AS (
    SELECT b.id,
           b.invoice_number,
           b.created_at,
           b.due_date,
           b.final_amount,
           b.notes
    FROM base b
    JOIN dup_dates d ON date(b.created_at) = d.purchase_date
  )
  SELECT l.id,
         l.invoice_number,
         l.created_at,
         l.due_date,
         l.final_amount,
         l.notes,
         COALESCE(
           jsonb_agg(
             jsonb_build_object(
               'quantity', si.quantity,
               'unit_price', si.unit_price,
               'subtotal', si.subtotal,
               'product_name', p.name,
               'unit', p.unit
             )
           ) FILTER (WHERE si.id IS NOT NULL),
           '[]'::jsonb
         ) AS items
  FROM lines l
  LEFT JOIN sale_items si ON si.sale_id = l.id
  LEFT JOIN products p ON p.id = si.product_id
  GROUP BY l.id, l.invoice_number, l.created_at, l.due_date, l.final_amount, l.notes
  ORDER BY l.created_at DESC NULLS LAST, l.invoice_number DESC;
$$;

-- Restrict function execution to authenticated users
REVOKE ALL ON FUNCTION public.get_my_profile_with_permissions() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_my_profile_with_permissions() TO authenticated;

REVOKE ALL ON FUNCTION public.pos_checkout(text, jsonb, uuid, numeric, timestamptz, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pos_checkout(text, jsonb, uuid, numeric, timestamptz, text) TO authenticated;

REVOKE ALL ON FUNCTION public.stock_in(uuid, numeric, numeric, text, date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.stock_in(uuid, numeric, numeric, text, date, date) TO authenticated;

REVOKE ALL ON FUNCTION public.create_purchase_order(jsonb, text, uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_purchase_order(jsonb, text, uuid, text, text) TO authenticated;

REVOKE ALL ON FUNCTION public.lock_sale(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.lock_sale(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.refund_sale(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.refund_sale(uuid, text) TO authenticated;

REVOKE ALL ON FUNCTION public.update_debt_line(uuid, numeric, timestamptz, timestamptz, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_debt_line(uuid, numeric, timestamptz, timestamptz, text) TO authenticated;

REVOKE ALL ON FUNCTION public.delete_debt_line(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_debt_line(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.update_debt_payment(uuid, numeric, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_debt_payment(uuid, numeric, text, text) TO authenticated;

REVOKE ALL ON FUNCTION public.delete_debt_payment(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_debt_payment(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.get_duplicate_debt_lines(uuid, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_duplicate_debt_lines(uuid, integer) TO authenticated;
