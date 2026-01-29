import { Router } from 'express';
import { z } from 'zod';
import { createAnonClient, createUserClient } from '../lib/supabase.js';
import { asyncHandler, getRequestIp } from '../lib/http.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6)
});

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
