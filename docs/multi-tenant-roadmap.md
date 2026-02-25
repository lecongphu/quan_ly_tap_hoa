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

## Next (Phase 3)

1. Update backend routes to always filter/write by `store_id`
2. Add middleware for active store context (from token/header)
3. Update frontend with store switcher and active-store persistence
4. Add onboarding flow: create store + invite members

## Next (Phase 3)

- Add owner/manager/staff permissions per store
- Add onboarding flow: create store + invite members
- Add billing plan limits by store
