import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler } from '../lib/http.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();

router.get(
  '/categories',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { data, error } = await req.supabase
      .from('categories')
      .select('*')
      .order('name', { ascending: true });

    if (error) {
      return res.status(400).json({ message: error.message });
    }
    return res.json(data ?? []);
  })
);

router.post(
  '/categories',
  requireAuth,
  asyncHandler(async (req, res) => {
    const schema = z.object({
      name: z.string().min(1),
      description: z.string().optional().nullable()
    });
    const parsed = schema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Invalid payload.' });
    }

    const { data, error } = await req.supabase
      .from('categories')
      .insert(parsed.data)
      .select('*')
      .single();

    if (error) {
      return res.status(400).json({ message: error.message });
    }

    return res.status(201).json(data);
  })
);

router.get(
  '/products',
  requireAuth,
  asyncHandler(async (req, res) => {
    const includeInactive = req.query.includeInactive === 'true';

    const productQuery = req.supabase
      .from('products')
      .select('*, category:categories(name)')
      .order('created_at', { ascending: false });

    if (!includeInactive) {
      productQuery.eq('is_active', true);
    }

    const { data: products, error } = await productQuery;

    if (error) {
      return res.status(400).json({ message: error.message });
    }

    const { data: inventoryRows } = await req.supabase
      .from('current_inventory')
      .select('*');

    const inventoryMap = new Map();
    (inventoryRows ?? []).forEach((row) => {
      inventoryMap.set(row.product_id, row);
    });

    const merged = (products ?? []).map((product) => {
      const inventory = inventoryMap.get(product.id);
      return {
        ...product,
        category_name: product.category?.name ?? null,
        total_quantity: inventory?.total_quantity ?? 0,
        avg_cost_price: inventory?.avg_cost_price ?? null,
        nearest_expiry_date: inventory?.nearest_expiry_date ?? null
      };
    });

    return res.json(merged);
  })
);

router.post(
  '/products',
  requireAuth,
  asyncHandler(async (req, res) => {
    const schema = z.object({
      barcode: z.string().optional().nullable(),
      name: z.string().min(1),
      category_id: z.string().uuid().optional().nullable(),
      unit: z.string().min(1),
      min_stock_level: z.number().nonnegative().optional(),
      is_active: z.boolean().optional()
    });

    const parsed = schema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Invalid payload.' });
    }

    const payload = {
      ...parsed.data,
      min_stock_level: parsed.data.min_stock_level ?? 0
    };

    const { data, error } = await req.supabase
      .from('products')
      .insert(payload)
      .select('*, category:categories(name)')
      .single();

    if (error) {
      return res.status(400).json({ message: error.message });
    }

    return res.status(201).json({
      ...data,
      category_name: data?.category?.name ?? null
    });
  })
);

router.put(
  '/products/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    const schema = z.object({
      barcode: z.string().optional().nullable(),
      name: z.string().min(1).optional(),
      category_id: z.string().uuid().optional().nullable(),
      unit: z.string().min(1).optional(),
      min_stock_level: z.number().nonnegative().optional(),
      is_active: z.boolean().optional()
    });

    const parsed = schema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Invalid payload.' });
    }

    const { data, error } = await req.supabase
      .from('products')
      .update(parsed.data)
      .eq('id', req.params.id)
      .select('*, category:categories(name)')
      .single();

    if (error) {
      return res.status(400).json({ message: error.message });
    }

    return res.json({
      ...data,
      category_name: data?.category?.name ?? null
    });
  })
);

router.delete(
  '/products/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { data, error } = await req.supabase
      .from('products')
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

export default router;