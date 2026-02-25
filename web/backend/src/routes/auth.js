import { Router } from 'express';
import { z } from 'zod';
import { createAnonClient, createUserClient, createAdminClient } from '../lib/supabase.js';
import { asyncHandler, getRequestIp } from '../lib/http.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6)
});

const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
  full_name: z.string().min(2),
  store_name: z.string().min(2),
  phone: z.string().optional().nullable()
});

router.post(
  '/register',
  asyncHandler(async (req, res) => {
    const parsed = registerSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Invalid registration payload.' });
    }

    const { email, password, full_name, store_name, phone } = parsed.data;
    const anon = createAnonClient();

    const { data, error } = await anon.auth.signUp({
      email,
      password,
      options: {
        data: {
          full_name
        }
      }
    });

    if (error || !data?.user) {
      return res.status(400).json({ message: error?.message || 'Sign up failed.' });
    }

    const admin = createAdminClient();

    const { error: bootstrapErr } = await admin.rpc('bootstrap_user_store', {
      p_user_id: data.user.id,
      p_full_name: full_name,
      p_store_name: store_name,
      p_phone: phone ?? null
    });

    if (bootstrapErr) {
      return res.status(400).json({ message: bootstrapErr.message });
    }

    return res.status(201).json({
      message: data.session
        ? 'Registration successful.'
        : 'Registration successful. Please confirm your email before logging in.',
      user: data.user,
      session: data.session ?? null
    });
  })
);

router.post(
  '/login',
  asyncHandler(async (req, res) => {
    const parsed = loginSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Invalid credentials.' });
    }

    const supabase = createAnonClient();
    const { email, password } = parsed.data;

    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password
    });

    if (error || !data?.session || !data?.user) {
      return res.status(401).json({ message: 'Authentication failed.' });
    }

    const userClient = createUserClient(data.session.access_token);

    const { data: profile, error: profileError } = await userClient
      .from('profiles')
      .select('*, role:roles(name)')
      .eq('id', data.user.id)
      .single();

    if (profileError) {
      return res.status(403).json({ message: 'Profile not found.' });
    }

    let permissions = [];
    if (profile?.role_id) {
      const { data: permissionRows } = await userClient
        .from('role_permissions')
        .select('permission:permissions(code,name,module,description)')
        .eq('role_id', profile.role_id);

      if (Array.isArray(permissionRows)) {
        permissions = permissionRows
          .map((row) => row.permission)
          .filter(Boolean);
      }
    }

    const ipAddress = getRequestIp(req);
    const { error: auditError } = await userClient.from('audit_logs').insert({
      user_id: data.user.id,
      action: 'login',
      ip_address: ipAddress
    });
    if (auditError) {
      // Ignore audit logging failures to avoid blocking login.
    }

    return res.json({
      session: data.session,
      user: data.user,
      profile: {
        ...profile,
        role_name: profile?.role?.name
      },
      permissions
    });
  })
);

router.get(
  '/me',
  requireAuth,
  asyncHandler(async (req, res) => {
    const supabase = req.supabase;
    const { data: profile, error } = await supabase
      .from('profiles')
      .select('*, role:roles(name)')
      .eq('id', req.user.id)
      .single();

    if (error) {
      return res.status(404).json({ message: 'Profile not found.' });
    }

    return res.json({
      user: req.user,
      profile: {
        ...profile,
        role_name: profile?.role?.name
      }
    });
  })
);

router.get(
  '/stores',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { data, error } = await req.supabase.rpc('get_my_stores');
    if (error) return res.status(400).json({ message: error.message });
    return res.json(data ?? []);
  })
);

router.post(
  '/stores/active',
  requireAuth,
  asyncHandler(async (req, res) => {
    const schema = z.object({ store_id: z.string().uuid() });
    const parsed = schema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ message: 'Invalid store_id.' });

    const { data, error } = await req.supabase.rpc('set_my_default_store', {
      target_store: parsed.data.store_id
    });

    if (error) return res.status(400).json({ message: error.message });
    if (!data) return res.status(403).json({ message: 'Store access denied.' });
    return res.json({ ok: true, store_id: parsed.data.store_id });
  })
);

router.post(
  '/logout',
  requireAuth,
  asyncHandler(async (req, res) => {
    const supabase = req.supabase;
    const ipAddress = getRequestIp(req);
    const { error: auditError } = await supabase.from('audit_logs').insert({
      user_id: req.user.id,
      action: 'logout',
      ip_address: ipAddress
    });
    if (auditError) {
      // Ignore audit logging failures to avoid blocking logout.
    }

    return res.status(204).send();
  })
);

export default router;
