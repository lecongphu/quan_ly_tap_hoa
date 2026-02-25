# Multi-tenant rollout roadmap

This project is being upgraded from single-store to multi-store (SaaS-ready).

## ✅ Done (Phase 1 foundation)

- Added `stores` table
- Added `store_members` table
- Added `store_id` to core business tables
- Added helper SQL functions:
  - `get_default_store_id()`
  - `is_member_of_store(target_store uuid)`

Migration file:
- `database/migrations/001_multi_tenant_foundation.sql`

## ✅ Done (Phase 2 - database hardening)

- Backfilled existing data into a default store
- Ensured store membership for existing users
- Added `store_id` auto-fill trigger on inserts
- Set `store_id NOT NULL` for core business tables
- Added tenant-scoped **RESTRICTIVE** RLS policies with `is_member_of_store(store_id)`
- Forced RLS on tenant tables

Migration file:
- `database/migrations/002_multi_tenant_backfill_and_rls.sql`

## ✅ In progress (Phase 3)

Implemented:
1. Added migration `003_store_context_and_active_store_scope.sql`
   - `get_my_stores()`
   - `set_my_default_store(target_store)`
   - RLS for `stores` and `store_members`
   - tenant scope tightened to active/default store context
2. Backend `requireAuth` now supports `x-store-id` and switches active store context
3. Added backend auth APIs:
   - `GET /auth/stores`
   - `POST /auth/stores/active`
4. Frontend store context service:
   - `StoreContextService` (load stores, switch active store, persist active store)
   - interceptor now sends `x-store-id`

Remaining:
- Add store switcher UI in frontend pages (top bar/dropdown)
- Add onboarding flow: create store + invite members

## Next (Phase 3)

- Add owner/manager/staff permissions per store
- Add onboarding flow: create store + invite members
- Add billing plan limits by store
