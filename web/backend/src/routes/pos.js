import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler } from '../lib/http.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();

router.get(
  '/customers',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { data, error } = await req.supabase
      .from('customers')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) {
      return res.status(400).json({ message: error.message });
    }

    return res.json(data ?? []);
  })
);

router.get(
  '/sales',
  requireAuth,
  asyncHandler(async (req, res) => {
    const limit = Number.parseInt(req.query.limit, 10) || 200;
    const dateFrom = req.query.dateFrom ? String(req.query.dateFrom) : null;
    const dateTo = req.query.dateTo ? String(req.query.dateTo) : null;

    let query = req.supabase
      .from('sales')
      .select(
        'id, invoice_number, customer_id, total_amount, discount_amount, final_amount, payment_method, payment_status, due_date, notes, created_at, is_locked, locked_at, refunded_at, refund_notes, customer:customers(name, phone, address)'
      )
      .order('created_at', { ascending: false })
      .limit(limit);

    if (dateFrom) {
      query = query.gte('created_at', dateFrom);
    }
    if (dateTo) {
      query = query.lte('created_at', dateTo);
    }

    const { data, error } = await query;

    if (error) {
      return res.status(400).json({ message: error.message });
    }

    const mapped = (data ?? []).map((sale) => ({
      ...sale,
      customer_name: sale.customer?.name ?? null,
      customer_phone: sale.customer?.phone ?? null,
      customer_address: sale.customer?.address ?? null
    }));

    return res.json(mapped);
  })
);

router.get(
  '/sales/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { data, error } = await req.supabase
      .from('sales')
      .select(
        'id, invoice_number, customer_id, total_amount, discount_amount, final_amount, payment_method, payment_status, due_date, notes, created_at, is_locked, locked_at, refunded_at, refund_notes, customer:customers(name, phone, address), items:sale_items(id, sale_id, product_id, batch_id, quantity, unit_price, cost_price, discount, subtotal, created_at, product:products(name, unit))'
      )
      .eq('id', req.params.id)
      .single();

    if (error) {
      return res.status(400).json({ message: error.message });
    }

    const items = Array.isArray(data?.items)
      ? data.items.map((item) => ({
          ...item,
          product_name: item.product?.name ?? null,
          unit: item.product?.unit ?? null
        }))
      : [];

    return res.json({
      ...data,
      items,
      customer_name: data?.customer?.name ?? null,
      customer_phone: data?.customer?.phone ?? null,
      customer_address: data?.customer?.address ?? null
    });
  })
);

router.post(
  '/sales/:id/lock',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { data: sale, error: saleError } = await req.supabase
      .from('sales')
      .select('id, is_locked')
      .eq('id', req.params.id)
      .single();

    if (saleError || !sale) {
      return res.status(404).json({ message: 'Sale not found.' });
    }

    if (sale.is_locked) {
      return res.status(400).json({ message: 'Invoice already locked.' });
    }

    const { data: updated, error } = await req.supabase
      .from('sales')
      .update({
        is_locked: true,
        locked_at: new Date().toISOString(),
        locked_by: req.user.id
      })
      .eq('id', req.params.id)
      .select(
        'id, invoice_number, is_locked, locked_at, refunded_at, refund_notes, customer_id'
      )
      .single();

    if (error) {
      return res.status(400).json({ message: error.message });
    }

    return res.json(updated);
  })
);

router.post(
  '/sales/:id/refund',
  requireAuth,
  asyncHandler(async (req, res) => {
    const reason = req.body?.reason ? String(req.body.reason) : null;

    const { data: sale, error: saleError } = await req.supabase
      .from('sales')
      .select('id, refunded_at, is_locked')
      .eq('id', req.params.id)
      .single();

    if (saleError || !sale) {
      return res.status(404).json({ message: 'Sale not found.' });
    }

    if (sale.refunded_at) {
      return res.status(400).json({ message: 'Invoice already refunded.' });
    }

    const { data: updated, error } = await req.supabase
      .from('sales')
      .update({
        refunded_at: new Date().toISOString(),
        refunded_by: req.user.id,
        refund_notes: reason,
        is_locked: true,
        locked_at: sale.is_locked ? undefined : new Date().toISOString(),
        locked_by: sale.is_locked ? undefined : req.user.id
      })
      .eq('id', req.params.id)
      .select(
        'id, invoice_number, is_locked, locked_at, refunded_at, refund_notes, customer_id'
      )
      .single();

    if (error) {
      return res.status(400).json({ message: error.message });
    }

    return res.json(updated);
  })
);

router.post(
  '/checkout',
  requireAuth,
  asyncHandler(async (req, res) => {
    const schema = z.object({
      customer_id: z.string().uuid().optional().nullable(),
      payment_method: z.enum(['cash', 'transfer', 'debt']),
      discount_amount: z.number().nonnegative().optional(),
      due_date: z.string().optional().nullable(),
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

    if (parsed.data.payment_method === 'debt' && !parsed.data.customer_id) {
      return res
        .status(400)
        .json({ message: 'Customer is required for debt payments.' });
    }

    const itemsWithBatch = [];

    for (const item of parsed.data.items) {
      const { data: batchId, error: batchError } = await req.supabase.rpc(
        'get_fefo_batch',
        {
          p_product_id: item.product_id,
          p_quantity: item.quantity
        }
      );

      if (batchError || !batchId) {
        return res.status(400).json({
          message: `Insufficient stock for product ${item.product_id}.`
        });
      }

      const { data: batch, error: batchFetchError } = await req.supabase
        .from('inventory_batches')
        .select('cost_price')
        .eq('id', batchId)
        .single();

      if (batchFetchError || !batch) {
        return res.status(400).json({
          message: `Unable to resolve batch for product ${item.product_id}.`
        });
      }

      itemsWithBatch.push({
        ...item,
        batch_id: batchId,
        cost_price: Number(batch.cost_price)
      });
    }

    const totalAmount = itemsWithBatch.reduce(
      (sum, item) => sum + item.quantity * item.unit_price,
      0
    );
    const discountAmount = parsed.data.discount_amount ?? 0;
    const finalAmount = totalAmount - discountAmount;

    const { data: sale, error: saleError } = await req.supabase
      .from('sales')
      .insert({
        customer_id: parsed.data.customer_id ?? null,
        total_amount: totalAmount,
        discount_amount: discountAmount,
        final_amount: finalAmount,
        payment_method: parsed.data.payment_method,
        payment_status:
          parsed.data.payment_method === 'debt' ? 'unpaid' : 'paid',
        due_date: parsed.data.due_date ?? null,
        notes: parsed.data.notes ?? null,
        created_by: req.user.id
      })
      .select('*')
      .single();

    if (saleError) {
      return res.status(400).json({ message: saleError.message });
    }

    const saleItemsPayload = itemsWithBatch.map((item) => ({
      sale_id: sale.id,
      product_id: item.product_id,
      batch_id: item.batch_id,
      quantity: item.quantity,
      unit_price: item.unit_price,
      cost_price: item.cost_price,
      discount: 0,
      subtotal: item.quantity * item.unit_price
    }));

    const { error: itemsError } = await req.supabase
      .from('sale_items')
      .insert(saleItemsPayload);

    if (itemsError) {
      return res.status(400).json({ message: itemsError.message });
    }

    return res.status(201).json({
      sale,
      items: saleItemsPayload
    });
  })
);

export default router;
