import { Router } from 'express';
import { asyncHandler } from '../lib/http.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();

router.get(
  '/daily',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { data, error } = await req.supabase
      .from('daily_reports')
      .select('*')
      .order('report_date', { ascending: false });

    if (error) {
      return res.status(400).json({ message: error.message });
    }

    return res.json(data ?? []);
  })
);

export default router;