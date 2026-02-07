import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler } from '../lib/http.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();

router.get(
  '/customers',
  requireAuth,
  asyncHandler(async (req, res) => {
    const onlyDebt = req.query.onlyDebt === 'true';
    const includeInactive = req.query.includeInactive === 'true';
    const phone = req.query.phone ? String(req.query.phone) : null;
    let query = req.supabase.from('customers').select('*');

    if (!includeInactive) {
      query = query.eq('is_active', true);
    }

    if (onlyDebt) {
      query = query.gt('current_debt', 0);
    }

    if (phone) {
      query = query.eq('phone', phone);
    }

    const { data, error } = await query.order('created_at', {
      ascending: false
    });

    if (error) {
      return res.status(400).json({ message: error.message });
    }

    return res.json(data ?? []);
  })
);

router.post(
  '/customers',
  requireAuth,
  asyncHandler(async (req, res) => {
    const schema = z.object({
      name: z.string().min(1),
      phone: z.string().optional().nullable(),
      address: z.string().optional().nullable()
    });

    const parsed = schema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Invalid payload.' });
    }

    const { data, error } = await req.supabase
      .from('customers')
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
  '/customers/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    const schema = z.object({
      name: z.string().min(1).optional(),
      phone: z.string().optional().nullable(),
      address: z.string().optional().nullable(),
      is_active: z.boolean().optional()
    });

    const parsed = schema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Invalid payload.' });
    }

    if (Object.keys(parsed.data).length === 0) {
      return res.status(400).json({ message: 'No fields to update.' });
    }

    const { data, error } = await req.supabase
      .from('customers')
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

router.delete(
  '/customers/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { data, error } = await req.supabase
      .from('customers')
      .update({ is_active: false })
      .eq('id', req.params.id)
      .select('id')
      .single();

    if (error) {
      return res.status(400).json({ message: error.message });
    }

    return res.json({ id: data?.id });
  })
);

router.get(
  '/customers/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { data, error } = await req.supabase
      .from('customers')
      .select('*')
      .eq('id', req.params.id)
      .single();

    if (error) {
      return res.status(400).json({ message: error.message });
    }

    return res.json(data);
  })
);

router.get(
  '/customers/:id/history',
  requireAuth,
  asyncHandler(async (req, res) => {
    const limit = Number.parseInt(req.query.limit, 10) || 20;
    const year = Number.parseInt(req.query.year, 10);
    const hasYear = Number.isFinite(year);
    const yearStart = hasYear ? new Date(Date.UTC(year, 0, 1)).toISOString() : null;
    const yearEnd = hasYear ? new Date(Date.UTC(year + 1, 0, 1)).toISOString() : null;

    let salesQuery = req.supabase
      .from('sales')
      .select(
        'id, invoice_number, total_amount, discount_amount, final_amount, payment_method, payment_status, created_at, due_date'
      )
      .eq('customer_id', req.params.id)
      .order('created_at', { ascending: false })
      .limit(limit);

    if (hasYear && yearStart && yearEnd) {
      salesQuery = salesQuery.gte('created_at', yearStart).lt('created_at', yearEnd);
    }

    const { data: sales, error: salesError } = await salesQuery;

    let paymentsQuery = req.supabase
      .from('debt_payments')
      .select('id, amount, payment_method, notes, created_at')
      .eq('customer_id', req.params.id)
      .order('created_at', { ascending: false })
      .limit(limit);

    if (hasYear && yearStart && yearEnd) {
      paymentsQuery = paymentsQuery
        .gte('created_at', yearStart)
        .lt('created_at', yearEnd);
    }

    const { data: payments, error: paymentsError } = await paymentsQuery;

    if (salesError || paymentsError) {
      return res.status(400).json({
        message: salesError?.message || paymentsError?.message || 'Failed to load history.'
      });
    }

    return res.json({
      sales: sales ?? [],
      payments: payments ?? []
    });
  })
);

router.get(
  '/customers/:id/debt-lines',
  requireAuth,
  asyncHandler(async (req, res) => {
    const year = Number.parseInt(req.query.year, 10);
    const hasYear = Number.isFinite(year);
    const yearStart = hasYear ? new Date(Date.UTC(year, 0, 1)).toISOString() : null;
    const yearEnd = hasYear ? new Date(Date.UTC(year + 1, 0, 1)).toISOString() : null;
    const duplicateOnly = req.query.duplicateOnly === 'true';

    if (duplicateOnly) {
      const { data, error } = await req.supabase.rpc('get_duplicate_debt_lines', {
        p_customer_id: req.params.id,
        p_year: hasYear ? year : null
      });

      if (error) {
        return res.status(400).json({ message: error.message });
      }

      return res.json(data ?? []);
    }

    let query = req.supabase
      .from('sales')
      .select(
        'id, invoice_number, created_at, due_date, final_amount, notes, payment_method, sale_items(quantity, unit_price, subtotal, product:products(name, unit))'
      )
      .eq('customer_id', req.params.id)
      .eq('payment_method', 'debt')
      .order('created_at', { ascending: false });

    if (hasYear && yearStart && yearEnd) {
      query = query.gte('created_at', yearStart).lt('created_at', yearEnd);
    }

    const { data, error } = await query;

    if (error) {
      return res.status(400).json({ message: error.message });
    }

    const mapped = (data ?? []).map((sale) => ({
      id: sale.id,
      invoice_number: sale.invoice_number,
      created_at: sale.created_at,
      due_date: sale.due_date,
      final_amount: sale.final_amount,
      notes: sale.notes ?? null,
      items: Array.isArray(sale.sale_items)
        ? sale.sale_items.map((item) => ({
            quantity: item.quantity,
            unit_price: item.unit_price,
            subtotal: item.subtotal,
            product_name: item.product?.name ?? '',
            unit: item.product?.unit ?? ''
          }))
        : []
    }));

    return res.json(mapped);
  })
);

router.post(
  '/customers/:id/debt-lines',
  requireAuth,
  asyncHandler(async (req, res) => {
    const dateSchema = z
      .string()
      .refine((value) => !Number.isNaN(Date.parse(value)), {
        message: 'Invalid date.'
      });
    const schema = z.object({
      amount: z.number().positive(),
      purchase_date: dateSchema.optional().nullable(),
      due_date: z.string().optional().nullable(),
      notes: z.string().optional().nullable()
    });

    const parsed = schema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Invalid payload.' });
    }

    const createdAt = parsed.data.purchase_date
      ? new Date(parsed.data.purchase_date).toISOString()
      : null;

    const { data: sale, error: saleError } = await req.supabase
      .from('sales')
      .insert({
        customer_id: req.params.id,
        total_amount: parsed.data.amount,
        discount_amount: 0,
        final_amount: parsed.data.amount,
        payment_method: 'debt',
        payment_status: 'unpaid',
        due_date: parsed.data.due_date ?? null,
        notes: parsed.data.notes ?? null,
        created_at: createdAt ?? undefined,
        created_by: req.user.id
      })
      .select('*')
      .single();

    if (saleError) {
      return res.status(400).json({ message: saleError.message });
    }

    return res.status(201).json(sale);
  })
);

router.put(
  '/debt-lines/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    const dateSchema = z
      .string()
      .refine((value) => !Number.isNaN(Date.parse(value)), {
        message: 'Invalid date.'
      });
    const schema = z.object({
      amount: z.number().positive().optional(),
      purchase_date: dateSchema.optional().nullable(),
      due_date: z.string().optional().nullable(),
      notes: z.string().optional().nullable()
    });

    const parsed = schema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Invalid payload.' });
    }

    if (Object.keys(parsed.data).length === 0) {
      return res.status(400).json({ message: 'No fields to update.' });
    }

    const { data: sale, error: saleError } = await req.supabase
      .from('sales')
      .select('id, customer_id, final_amount, payment_method')
      .eq('id', req.params.id)
      .single();

    if (saleError || !sale) {
      return res.status(404).json({ message: 'Debt line not found.' });
    }

    if (sale.payment_method !== 'debt') {
      return res.status(400).json({ message: 'Only debt sales can be edited.' });
    }

    const { data: existingItems, error: itemsError } = await req.supabase
      .from('sale_items')
      .select('id')
      .eq('sale_id', sale.id)
      .limit(1);

    if (itemsError) {
      return res.status(400).json({ message: itemsError.message });
    }

    if ((existingItems ?? []).length > 0) {
      return res
        .status(400)
        .json({ message: 'Không thể chỉnh sửa nợ phát sinh từ hóa đơn.' });
    }

    const newAmount =
      parsed.data.amount !== undefined ? parsed.data.amount : Number(sale.final_amount);
    const delta = newAmount - Number(sale.final_amount);
    let newDebt = null;

    if (delta !== 0) {
      const { data: customer, error: customerError } = await req.supabase
        .from('customers')
        .select('current_debt')
        .eq('id', sale.customer_id)
        .single();

      if (customerError || !customer) {
        return res.status(400).json({ message: 'Customer not found.' });
      }

      const currentDebt = Number(customer.current_debt ?? 0);
      newDebt = currentDebt + delta;
      if (newDebt < 0) {
        return res.status(400).json({ message: 'Amount exceeds current debt.' });
      }
    }

    const payload = {
      total_amount: newAmount,
      discount_amount: 0,
      final_amount: newAmount,
      due_date: parsed.data.due_date ?? null,
      notes: parsed.data.notes ?? null
    };

    if (parsed.data.purchase_date) {
      payload.created_at = new Date(parsed.data.purchase_date).toISOString();
    }

    const { data: updatedSale, error: updateError } = await req.supabase
      .from('sales')
      .update(payload)
      .eq('id', req.params.id)
      .select('*')
      .single();

    if (updateError) {
      return res.status(400).json({ message: updateError.message });
    }

    if (delta !== 0 && newDebt !== null) {
      const { error: updateDebtError } = await req.supabase
        .from('customers')
        .update({ current_debt: newDebt })
        .eq('id', sale.customer_id);

      if (updateDebtError) {
        return res.status(400).json({ message: updateDebtError.message });
      }
    }

    return res.json(updatedSale);
  })
);

router.delete(
  '/debt-lines/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { data: sale, error: saleError } = await req.supabase
      .from('sales')
      .select('id, customer_id, final_amount, payment_method')
      .eq('id', req.params.id)
      .single();

    if (saleError || !sale) {
      return res.status(404).json({ message: 'Debt line not found.' });
    }

    if (sale.payment_method !== 'debt') {
      return res.status(400).json({ message: 'Only debt sales can be deleted.' });
    }

    const { data: existingItems, error: itemsError } = await req.supabase
      .from('sale_items')
      .select('id')
      .eq('sale_id', sale.id)
      .limit(1);

    if (itemsError) {
      return res.status(400).json({ message: itemsError.message });
    }

    if ((existingItems ?? []).length > 0) {
      return res
        .status(400)
        .json({ message: 'Không thể xóa nợ phát sinh từ hóa đơn.' });
    }

    const { data: customer, error: customerError } = await req.supabase
      .from('customers')
      .select('current_debt')
      .eq('id', sale.customer_id)
      .single();

    if (customerError || !customer) {
      return res.status(400).json({ message: 'Customer not found.' });
    }

    const currentDebt = Number(customer.current_debt ?? 0);
    const newDebt = currentDebt - Number(sale.final_amount);
    if (newDebt < 0) {
      return res.status(400).json({ message: 'Amount exceeds current debt.' });
    }

    const { error: deleteError } = await req.supabase
      .from('sales')
      .delete()
      .eq('id', sale.id);

    if (deleteError) {
      return res.status(400).json({ message: deleteError.message });
    }

    const { error: updateDebtError } = await req.supabase
      .from('customers')
      .update({ current_debt: newDebt })
      .eq('id', sale.customer_id);

    if (updateDebtError) {
      return res.status(400).json({ message: updateDebtError.message });
    }

    return res.json({ id: sale.id });
  })
);

router.post(
  '/payments',
  requireAuth,
  asyncHandler(async (req, res) => {
    const schema = z.object({
      customer_id: z.string().uuid(),
      amount: z.number().positive(),
      payment_method: z.enum(['cash', 'transfer']),
      notes: z.string().optional().nullable()
    });

    const parsed = schema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Invalid payload.' });
    }

    const { data, error } = await req.supabase
      .from('debt_payments')
      .insert({
        customer_id: parsed.data.customer_id,
        amount: parsed.data.amount,
        payment_method: parsed.data.payment_method,
        notes: parsed.data.notes ?? null,
        created_by: req.user.id
      })
      .select('*')
      .single();

    if (error) {
      return res.status(400).json({ message: error.message });
    }

    return res.status(201).json(data);
  })
);

router.put(
  '/payments/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    const schema = z.object({
      amount: z.number().positive().optional(),
      payment_method: z.enum(['cash', 'transfer']).optional(),
      notes: z.string().optional().nullable()
    });

    const parsed = schema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Invalid payload.' });
    }

    if (Object.keys(parsed.data).length === 0) {
      return res.status(400).json({ message: 'No fields to update.' });
    }

    const { data: existingPayment, error: existingError } = await req.supabase
      .from('debt_payments')
      .select('id, customer_id, amount')
      .eq('id', req.params.id)
      .single();

    if (existingError || !existingPayment) {
      return res.status(404).json({ message: 'Payment not found.' });
    }

    const newAmount =
      parsed.data.amount !== undefined ? parsed.data.amount : Number(existingPayment.amount);
    const delta = newAmount - Number(existingPayment.amount);
    let newDebt = null;

    if (delta !== 0) {
      const { data: customer, error: customerError } = await req.supabase
        .from('customers')
        .select('current_debt')
        .eq('id', existingPayment.customer_id)
        .single();

      if (customerError || !customer) {
        return res.status(400).json({ message: 'Customer not found.' });
      }

      const currentDebt = Number(customer.current_debt ?? 0);
      newDebt = currentDebt - delta;
      if (newDebt < 0) {
        return res.status(400).json({ message: 'Amount exceeds current debt.' });
      }
    }

    const { data: updatedPayment, error: updateError } = await req.supabase
      .from('debt_payments')
      .update(parsed.data)
      .eq('id', req.params.id)
      .select('*')
      .single();

    if (updateError) {
      return res.status(400).json({ message: updateError.message });
    }

    if (delta !== 0 && newDebt !== null) {
      const { error: updateDebtError } = await req.supabase
        .from('customers')
        .update({ current_debt: newDebt })
        .eq('id', existingPayment.customer_id);

      if (updateDebtError) {
        return res.status(400).json({ message: updateDebtError.message });
      }
    }

    return res.json(updatedPayment);
  })
);

router.delete(
  '/payments/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { data: existingPayment, error: existingError } = await req.supabase
      .from('debt_payments')
      .select('id, customer_id, amount')
      .eq('id', req.params.id)
      .single();

    if (existingError || !existingPayment) {
      return res.status(404).json({ message: 'Payment not found.' });
    }

    const { data: customer, error: customerError } = await req.supabase
      .from('customers')
      .select('current_debt')
      .eq('id', existingPayment.customer_id)
      .single();

    if (customerError || !customer) {
      return res.status(400).json({ message: 'Customer not found.' });
    }

    const currentDebt = Number(customer.current_debt ?? 0);
    const newDebt = currentDebt + Number(existingPayment.amount);

    const { error: deleteError } = await req.supabase
      .from('debt_payments')
      .delete()
      .eq('id', req.params.id);

    if (deleteError) {
      return res.status(400).json({ message: deleteError.message });
    }

    const { error: updateDebtError } = await req.supabase
      .from('customers')
      .update({ current_debt: newDebt })
      .eq('id', existingPayment.customer_id);

    if (updateDebtError) {
      return res.status(400).json({ message: updateDebtError.message });
    }

    return res.json({ id: existingPayment.id });
  })
);

export default router;
