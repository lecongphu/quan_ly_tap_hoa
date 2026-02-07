import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { APP_CONFIG } from './config';

export const supabase: SupabaseClient = createClient(
  APP_CONFIG.supabaseUrl,
  APP_CONFIG.supabaseAnonKey,
  {
    auth: {
      persistSession: true,
      autoRefreshToken: true
    }
  }
);
