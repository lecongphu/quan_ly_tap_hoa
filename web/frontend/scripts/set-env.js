const fs = require('node:fs');
const path = require('node:path');

const supabaseUrl =
  process.env.SUPABASE_URL || 'https://feddgbxjuowpsmtokwco.supabase.co';
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY || '';
const safeSupabaseUrl = supabaseUrl.replace(/\\/g, '\\\\').replace(/'/g, "\\'");
const safeSupabaseAnonKey = supabaseAnonKey
  .replace(/\\/g, '\\\\')
  .replace(/'/g, "\\'");

const content = `export const APP_CONFIG = {\n  supabaseUrl: '${safeSupabaseUrl}',\n  supabaseAnonKey: '${safeSupabaseAnonKey}'\n};\n`;
const targetPath = path.join(process.cwd(), 'src', 'app', 'core', 'config.ts');

fs.writeFileSync(targetPath, content, 'utf8');
console.log(`APP_CONFIG written to ${targetPath}`);
