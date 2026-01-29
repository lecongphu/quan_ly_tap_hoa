import { createAnonClient, createUserClient } from '../lib/supabase.js';
import { asyncHandler } from '../lib/http.js';

const extractToken = (req) => {
  const authHeader = req.headers.authorization || '';
  const [type, token] = authHeader.split(' ');
  if (type?.toLowerCase() === 'bearer' && token) {
    return token.trim();
  }
  return null;
};

export const requireAuth = asyncHandler(async (req, res, next) => {
  const token = extractToken(req);
  if (!token) {
    return res.status(401).json({ message: 'Unauthorized' });
  }

  const supabase = createAnonClient();
  const { data, error } = await supabase.auth.getUser(token);

  if (error || !data?.user) {
    return res.status(401).json({ message: 'Invalid session' });
  }

  req.user = data.user;
  req.accessToken = token;
  req.supabase = createUserClient(token);
  return next();
});

export const getTokenFromRequest = extractToken;