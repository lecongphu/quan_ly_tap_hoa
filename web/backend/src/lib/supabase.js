import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

const supabaseUrl = process.env.SUPABASE_URL;
const anonKey = process.env.SUPABASE_ANON_KEY;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

const sharedOptions = {
  auth: {
    persistSession: false,
    autoRefreshToken: false,
    detectSessionInUrl: false
  }
};

export const getSupabaseConfig = () => ({
  supabaseUrl,
  anonKey,
  serviceRoleKey
});

export const createAnonClient = () => {
  if (!supabaseUrl || !anonKey) {
    throw new Error('Missing SUPABASE_URL or SUPABASE_ANON_KEY.');
  }
  return createClient(supabaseUrl, anonKey, sharedOptions);
};

export const createUserClient = (accessToken) => {
  if (!supabaseUrl || !anonKey) {
    throw new Error('Missing SUPABASE_URL or SUPABASE_ANON_KEY.');
  }
  if (!accessToken) {
    throw new Error('Missing access token.');
  }
  return createClient(supabaseUrl, anonKey, {
    ...sharedOptions,
    global: {
      headers: {
        Authorization: `Bearer ${accessToken}`
      }
    }
  });
};

export const createAdminClient = () => {
  if (!supabaseUrl || !serviceRoleKey) {
    throw new Error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.');
  }
  return createClient(supabaseUrl, serviceRoleKey, sharedOptions);
};