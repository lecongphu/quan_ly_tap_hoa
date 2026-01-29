export const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

export const getRequestIp = (req) => {
  const forwarded = req.headers['x-forwarded-for'];
  if (typeof forwarded === 'string' && forwarded.length > 0) {
    return forwarded.split(',')[0].trim();
  }
  return req.ip;
};

export const mapSupabaseError = (error) => {
  if (!error) return null;
  const status = error.status || error.statusCode || 400;
  return {
    status,
    message: error.message || 'Request failed',
    code: error.code || 'supabase_error'
  };
};