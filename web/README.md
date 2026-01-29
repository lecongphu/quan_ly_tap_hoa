# Web version (Angular + Node.js + Supabase)

Thư mục `web/` chứa phiên bản web của dự án.

## 1) Backend (Node.js)

```bash
cd web/backend
npm install
cp .env.example .env
# điền SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY
npm run dev
```

API mặc định chạy tại `http://localhost:4000`.

## 2) Frontend (Angular)

```bash
cd web/frontend
npm install
npm run start
```

Frontend mặc định chạy tại `http://localhost:4200` và gọi API từ `http://localhost:4000`.
Nếu cần thay đổi, chỉnh trong `web/frontend/src/app/core/config.ts`.

## 3) Database

Cấu trúc database vẫn nằm trong thư mục `database/` ở root project.