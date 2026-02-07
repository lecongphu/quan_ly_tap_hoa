-- ============================================
-- Database Triggers & Functions
-- ============================================

-- ============================================
-- 1. AUTO-UPDATE TIMESTAMPS
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_customers_updated_at BEFORE UPDATE ON customers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 2. CUSTOMER DEBT MANAGEMENT
-- ============================================

-- Function to update customer debt
CREATE OR REPLACE FUNCTION update_customer_debt()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_TABLE_NAME = 'sales' THEN
        -- When a sale is made with debt payment method
        IF NEW.payment_method = 'debt' THEN
            UPDATE customers 
            SET current_debt = current_debt + NEW.final_amount
            WHERE id = NEW.customer_id;
        END IF;
    ELSIF TG_TABLE_NAME = 'debt_payments' THEN
        -- When customer pays debt
        UPDATE customers 
        SET current_debt = current_debt - NEW.amount
        WHERE id = NEW.customer_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for debt updates
CREATE TRIGGER trigger_sales_update_debt AFTER INSERT ON sales
    FOR EACH ROW EXECUTE FUNCTION update_customer_debt();

CREATE TRIGGER trigger_debt_payment_update_debt AFTER INSERT ON debt_payments
    FOR EACH ROW EXECUTE FUNCTION update_customer_debt();

-- ============================================
-- 3. INVENTORY MANAGEMENT (FEFO)
-- ============================================

-- Function to get FEFO batch (First Expired, First Out)
CREATE OR REPLACE FUNCTION get_fefo_batch(
    p_product_id UUID,
    p_quantity DECIMAL
)
RETURNS UUID AS $$
DECLARE
    v_batch_id UUID;
BEGIN
    SELECT id INTO v_batch_id
    FROM inventory_batches
    WHERE product_id = p_product_id 
      AND quantity >= p_quantity
      AND quantity > 0
    ORDER BY 
        CASE WHEN expiry_date IS NULL THEN 1 ELSE 0 END,
        expiry_date ASC,
        received_date ASC
    LIMIT 1;
    
    RETURN v_batch_id;
END;
$$ LANGUAGE plpgsql;

-- Function to deduct inventory from batch
CREATE OR REPLACE FUNCTION deduct_inventory(
    p_batch_id UUID,
    p_quantity DECIMAL
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE inventory_batches
    SET quantity = quantity - p_quantity
    WHERE id = p_batch_id
      AND quantity >= p_quantity;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 4. STOCK MOVEMENT TRACKING
-- ============================================

-- Function to record stock movement after sale
CREATE OR REPLACE FUNCTION record_sale_stock_movement()
RETURNS TRIGGER AS $$
BEGIN
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
        NEW.product_id,
        NEW.batch_id,
        'out',
        NEW.quantity,
        NEW.sale_id,
        'sale',
        (SELECT created_by FROM sales WHERE id = NEW.sale_id)
    );
    
    -- Deduct from inventory batch
    PERFORM deduct_inventory(NEW.batch_id, NEW.quantity);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for stock movement on sale
CREATE TRIGGER trigger_sale_item_stock_movement AFTER INSERT ON sale_items
    FOR EACH ROW EXECUTE FUNCTION record_sale_stock_movement();

-- ============================================
-- 5. INVOICE NUMBER GENERATION
-- ============================================

-- Function to generate invoice number
CREATE OR REPLACE FUNCTION generate_invoice_number()
RETURNS TEXT AS $$
DECLARE
    v_date TEXT;
    v_sequence INT;
    v_invoice_number TEXT;
BEGIN
    v_date := TO_CHAR(NOW(), 'YYYYMMDD');

    -- Serialize generation per day to avoid duplicates under concurrency.
    PERFORM pg_advisory_xact_lock(hashtext('sales_invoice_' || v_date));
    
    -- Get next sequence for today (sequence starts at position 11).
    SELECT COALESCE(
        MAX(CAST(SUBSTRING(invoice_number FROM 11) AS INTEGER)),
        0
    ) + 1
    INTO v_sequence
    FROM sales
    WHERE invoice_number ~ ('^HD' || v_date || '\\d{4}$');
    
    v_invoice_number := 'HD' || v_date || LPAD(v_sequence::TEXT, 4, '0');
    
    RETURN v_invoice_number;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-generate invoice number
CREATE OR REPLACE FUNCTION set_invoice_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.invoice_number IS NULL OR NEW.invoice_number = '' THEN
        NEW.invoice_number := generate_invoice_number();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_generate_invoice_number BEFORE INSERT ON sales
    FOR EACH ROW EXECUTE FUNCTION set_invoice_number();

-- ============================================
-- 6. EXPIRY DATE ALERTS
-- ============================================

-- Function to get products near expiry
CREATE OR REPLACE FUNCTION get_products_near_expiry(days_threshold INT DEFAULT 7)
RETURNS TABLE (
    product_id UUID,
    product_name TEXT,
    batch_id UUID,
    batch_number TEXT,
    quantity DECIMAL,
    expiry_date DATE,
    days_until_expiry INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.name,
        ib.id,
        ib.batch_number,
        ib.quantity,
        ib.expiry_date,
        (ib.expiry_date - CURRENT_DATE) as days_until_expiry
    FROM inventory_batches ib
    JOIN products p ON ib.product_id = p.id
    WHERE ib.expiry_date IS NOT NULL
      AND ib.quantity > 0
      AND ib.expiry_date <= CURRENT_DATE + days_threshold
    ORDER BY ib.expiry_date ASC;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 7. LOW STOCK ALERTS
-- ============================================

-- Function to get low stock products
CREATE OR REPLACE FUNCTION get_low_stock_products()
RETURNS TABLE (
    product_id UUID,
    product_name TEXT,
    current_stock DECIMAL,
    min_stock_level DECIMAL,
    unit TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ci.product_id,
        ci.name,
        ci.total_quantity,
        ci.min_stock_level,
        ci.unit
    FROM current_inventory ci
    WHERE ci.total_quantity <= ci.min_stock_level
      AND ci.min_stock_level > 0
    ORDER BY (ci.total_quantity / NULLIF(ci.min_stock_level, 0)) ASC;
END;
$$ LANGUAGE plpgsql;
