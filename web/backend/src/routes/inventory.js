import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler } from '../lib/http.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();

router.get(
  '/alerts',
  requireAuth,
  asyncHandler(async (req, res) => {
    const daysThreshold = Number.parseInt(req.query.days, 10) || 7;

    const { data: nearExpiry, error: expiryError } = await req.supabase.rpc(
      'get_products_near_expiry',
      {
        days_threshold: daysThreshold
      }
    );

    const { data: lowStock, error: lowStockError } = await req.supabase.rpc(
      'get_low_stock_products'
    );

    if (expiryError || lowStockError) {
      return res.status(400).json({
        message: expiryError?.message || lowStockError?.message || 'Failed to load alerts.'
      });
    }

    return res.json({
      nearExpiry: nearExpiry ?? [],
      lowStock: lowStock ?? []
    });
  })
);

router.get(
  '/suppliers',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { data, error } = await req.supabase
      .from('suppliers')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) {
      return res.status(400).json({ message: error.message });
    }

    return res.json(data ?? []);
  })
);

router.post(
  '/suppliers',
  requireAuth,
  asyncHandler(async (req, res) => {
    const schema = z.object({
      code: z.string().min(1),
      name: z.string().min(1),
      phone: z.string().optional().nullable(),
      email: z.string().optional().nullable(),
      address: z.string().optional().nullable(),
      tax_code: z.string().optional().nullable(),
      is_active: z.boolean().optional()
    });

    const parsed = schema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Invalid payload.' });
    }

    const { data, error } = await req.supabase
      .from('suppliers')
      .insert(parsed.data)
      .select('*')
      .single();

    if (error) {
      return res.status(400).json({ message: error.message });
    }

    return res.status(201).json(data);
  })
);

router.put(
  '/suppliers/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    const schema = z.object({
      code: z.string().min(1).optional(),
      name: z.string().min(1).optional(),
      phone: z.string().optional().nullable(),
      email: z.string().optional().nullable(),
      address: z.string().optional().nullable(),
      tax_code: z.string().optional().nullable(),
      is_active: z.boolean().optional()
    });

    const parsed = schema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Invalid payload.' });
    }

    const { data, error } = await req.supabase
      .from('suppliers')
      .update(parsed.data)
      .eq('id', req.params.id)
      .select('*')
      .single();

    if (error) {
      return res.status(400).json({ message: error.message });
    }

    return res.json(data);
  })
);

router.get(
  '/purchase-orders',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { data, error } = await req.supabase
      .from('purchase_orders')
      .select('*, supplier:suppliers(name), items:purchase_order_items(*)')
      .order('created_at', { ascending: false });

    if (error) {
      return res.status(400).json({ message: error.message });
    }

    const mapped = (data ?? []).map((order) => ({
      ...order,
      supplier_name: order.supplier?.name ?? null,
      total_items: Array.isArray(order.items)
        ? order.items.reduce((sum, item) => sum + Number(item.quantity || 0), 0)
        : 0
    }));

    return res.json(mapped);
  })
);

router.post(
  '/purchase-orders',
  requireAuth,
  asyncHandler(async (req, res) => {
    const schema = z.object({
      order_number: z.string().optional().nullable(),
      supplier_id: z.string().uuid().optional().nullable(),
      warehouse: z.string().optional().nullable(),
      notes: z.string().optional().nullable(),
      items: z
        .array(
          z.object({
            product_id: z.string().uuid(),
            quantity: z.number().positive(),
            unit_price: z.number().nonnegative()
          })
        )
        .min(1)
    });

    const parsed = schema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Invalid payload.' });
    }

    const generatedNumber = `PO${new Date()
      .toISOString()
      .slice(0, 10)
      .replace(/-/g, '')}${Date.now().toString().slice(-4)}`;
    const orderNumber = parsed.data.order_number || generatedNumber;

    const totalAmount = parsed.data.items.reduce(
      (sum, item) => sum + item.quantity * item.unit_price,
      0
    );

    const { data: order, error: orderError } = await req.supabase
      .from('purchase_orders')
      .insert({
        order_number: orderNumber,
        supplier_id: parsed.data.supplier_id ?? null,
        status: 'pending',
        total_amount: totalAmount,
        warehouse: parsed.data.warehouse ?? null,
        notes: parsed.data.notes ?? null,
        created_by: req.user.id
      })
      .select('*')
      .single();

    if (orderError) {
      return res.status(400).json({ message: orderError.message });
    }

    const itemsPayload = parsed.data.items.map((item) => ({
      purchase_order_id: order.id,
      product_id: item.product_id,
      quantity: item.quantity,
      unit_price: item.unit_price,
      subtotal: item.quantity * item.unit_price
    }));

    const { error: itemsError } = await req.supabase
      .from('purchase_order_items')
      .insert(itemsPayload);

    if (itemsError) {
      return res.status(400).json({ message: itemsError.message });
    }

    return res.status(201).json({
      ...order,
      total_items: itemsPayload.reduce((sum, item) => sum + item.quantity, 0)
    });
  })
);

router.get(
  '/purchase-orders/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { data, error } = await req.supabase
      .from('purchase_orders')
      .select('*, supplier:suppliers(name), items:purchase_order_items(*)')
      .eq('id', req.params.id)
      .single();

    if (error) {
      return res.status(400).json({ message: error.message });
    }

    const mapped = {
      ...data,
      supplier_name: data?.supplier?.name ?? null,
      total_items: Array.isArray(data?.items)
        ? data.items.reduce((sum, item) => sum + Number(item.quantity || 0), 0)
        : 0
    };

    return res.json(mapped);
  })
);

router.put(
  '/purchase-orders/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    const schema = z.object({
      status: z.enum(['pending', 'in_progress', 'completed', 'cancelled']).optional(),
      warehouse: z.string().optional().nullable(),
      notes: z.string().optional().nullable(),
      supplier_id: z.string().uuid().optional().nullable(),
      received_by: z.string().uuid().optional().nullable()
    });

    const parsed = schema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Invalid payload.' });
    }

    if (Object.keys(parsed.data).length === 0) {
      return res.status(400).json({ message: 'No fields to update.' });
    }

    const { data, error } = await req.supabase
      .from('purchase_orders')
      .update({
        ...parsed.data,
        updated_at: new Date().toISOString()
      })
      .eq('id', req.params.id)
      .select('*, supplier:suppliers(name), items:purchase_order_items(*)')
      .single();

    if (error) {
      return res.status(400).json({ message: error.message });
    }

    return res.json({
      ...data,
      supplier_name: data?.supplier?.name ?? null,
      total_items: Array.isArray(data?.items)
        ? data.items.reduce((sum, item) => sum + Number(item.quantity || 0), 0)
        : 0
    });
  })
);

router.delete(
  '/purchase-orders/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { data, error } = await req.supabase
      .from('purchase_orders')
      .delete()
      .eq('id', req.params.id)
      .select('id')
      .single();

    if (error) {
      return res.status(400).json({ message: error.message });
    }

    return res.json({ id: data?.id });
  })
);

router.post(
  '/stock-in',
  requireAuth,
  asyncHandler(async (req, res) => {
    const schema = z.object({
      product_id: z.string().uuid(),
      quantity: z.number().positive(),
      cost_price: z.number().positive(),
      batch_number: z.string().optional().nullable(),
      expiry_date: z.string().optional().nullable(),
      received_date: z.string().optional().nullable()
    });

    const parsed = schema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Invalid payload.' });
    }

    const payload = {
      product_id: parsed.data.product_id,
      quantity: parsed.data.quantity,
      cost_price: parsed.data.cost_price,
      batch_number: parsed.data.batch_number ?? null,
      expiry_date: parsed.data.expiry_date ?? null,
      received_date: parsed.data.received_date ?? null
    };

    const { data: batch, error } = await req.supabase
      .from('inventory_batches')
      .insert(payload)
      .select('*')
      .single();

    if (error) {
      return res.status(400).json({ message: error.message });
    }

    const { error: movementError } = await req.supabase
      .from('stock_movements')
      .insert({
        product_id: parsed.data.product_id,
        batch_id: batch.id,
        movement_type: 'in',
        quantity: parsed.data.quantity,
        reference_id: batch.id,
        reference_type: 'purchase',
        created_by: req.user.id
      });
    if (movementError) {
      // Ignore stock movement logging failures to avoid blocking stock-in.
    }

    return res.status(201).json(batch);
  })
);

export default router;
