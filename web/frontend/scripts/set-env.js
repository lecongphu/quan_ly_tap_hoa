const fs = require('node:fs');
const path = require('node:path');

const apiBaseUrl = process.env.APP_API_BASE_URL || 'http://localhost:4000';
const safeApiBaseUrl = apiBaseUrl.replace(/\\/g, '\\\\').replace(/'/g, "\\'");

const content = `export const APP_CONFIG = {\n  apiBaseUrl: '${safeApiBaseUrl}'\n};\n`;
const targetPath = path.join(process.cwd(), 'src', 'app', 'core', 'config.ts');

fs.writeFileSync(targetPath, content, 'utf8');
console.log(`APP_CONFIG written to ${targetPath}`);