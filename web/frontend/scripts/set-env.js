const fs = require('node:fs');
const path = require('node:path');

function readEnvFile(filePath) {
  if (!fs.existsSync(filePath)) return {};

  const content = fs.readFileSync(filePath, 'utf8');
  const result = {};

  for (const rawLine of content.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) continue;

    const separatorIndex = line.indexOf('=');
    if (separatorIndex === -1) continue;

    const key = line.slice(0, separatorIndex).trim();
    let value = line.slice(separatorIndex + 1).trim();

    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }

    result[key] = value;
  }

  return result;
}

const rootEnvPath = path.resolve(process.cwd(), '..', '..', '.env');
const envFromFile = readEnvFile(rootEnvPath);
const getEnv = (key, fallback = '') =>
  process.env[key] ?? envFromFile[key] ?? fallback;

const supabaseUrl = getEnv(
  'SUPABASE_URL',
  'https://feddgbxjuowpsmtokwco.supabase.co'
);
const supabaseAnonKey = getEnv('SUPABASE_ANON_KEY', '');
const googleMapsApiKey = getEnv('GOOGLE_MAPS_API_KEY', '');
const vietQrBaseUrl = getEnv('VIETQR_BASE_URL', 'https://img.vietqr.io/image');
const vietQrTemplate = getEnv('VIETQR_TEMPLATE', 'compact');
const vietQrBankCode = getEnv('VIETQR_BANK_CODE', 'MSB');
const vietQrAccountNumber = getEnv('VIETQR_ACCOUNT_NUMBER', '04201012814032');
const vietQrAccountName = getEnv('VIETQR_ACCOUNT_NAME', 'LE CONG PHU');
const safeSupabaseUrl = supabaseUrl.replace(/\\/g, '\\\\').replace(/'/g, "\\'");
const safeSupabaseAnonKey = supabaseAnonKey
  .replace(/\\/g, '\\\\')
  .replace(/'/g, "\\'");
const safeGoogleMapsApiKey = googleMapsApiKey
  .replace(/\\/g, '\\\\')
  .replace(/'/g, "\\'");
const safeVietQrBaseUrl = vietQrBaseUrl.replace(/\\/g, '\\\\').replace(/'/g, "\\'");
const safeVietQrTemplate = vietQrTemplate.replace(/\\/g, '\\\\').replace(/'/g, "\\'");
const safeVietQrBankCode = vietQrBankCode.replace(/\\/g, '\\\\').replace(/'/g, "\\'");
const safeVietQrAccountNumber = vietQrAccountNumber
  .replace(/\\/g, '\\\\')
  .replace(/'/g, "\\'");
const safeVietQrAccountName = vietQrAccountName
  .replace(/\\/g, '\\\\')
  .replace(/'/g, "\\'");

const content = `export const APP_CONFIG = {\n  supabaseUrl: '${safeSupabaseUrl}',\n  supabaseAnonKey: '${safeSupabaseAnonKey}',\n  googleMapsApiKey: '${safeGoogleMapsApiKey}',\n  vietQrBaseUrl: '${safeVietQrBaseUrl}',\n  vietQrTemplate: '${safeVietQrTemplate}',\n  vietQrBankCode: '${safeVietQrBankCode}',\n  vietQrAccountNumber: '${safeVietQrAccountNumber}',\n  vietQrAccountName: '${safeVietQrAccountName}'\n};\n`;
const targetPath = path.join(process.cwd(), 'src', 'app', 'core', 'config.ts');

fs.writeFileSync(targetPath, content, 'utf8');
console.log(`APP_CONFIG written to ${targetPath}`);
