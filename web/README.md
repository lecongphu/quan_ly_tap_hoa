# Web version (Angular + Supabase)

Thư mục `web/` chứa phiên bản web của dự án.

## 1) Frontend (Angular)

```bash
cd web/frontend
npm install
npm run start
```

Frontend mặc định chạy tại `http://localhost:4200`.

Trước khi chạy, hãy cấu hình Supabase:

```bash
# Ví dụ trên Windows PowerShell
$env:SUPABASE_URL="https://your-project.supabase.co"
$env:SUPABASE_ANON_KEY="your-anon-key"
npm run start
```

Hoặc chỉnh trực tiếp trong `web/frontend/src/app/core/config.ts`.

## 2) Database

Cấu trúc database vẫn nằm trong thư mục `database/` ở root project.
